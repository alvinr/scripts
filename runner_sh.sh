#!/bin/bash
SUITE=$1
LABEL=$2
DURATION=$3
THREADS=$4
TRIAL_COUNT=$5

if [ "$SUITE" = "" ]
then
  SUITE="sanity"
fi

if [ "$LABEL" = "" ]
then
  LABEL=$SUITE
fi

if [ "$DURATION" = "" ]
then
  DURATION=5
fi

if [ "$THREADS" = "" ]
then
  THREADS="1 2 4 8 12 16 20"
fi

MONGO_ROOT=/home/$USER

MONGO_SHELL=$MONGO_ROOT/mongo-perf-shell/mongo

if [  ! -f "$MONGO_SHELL" ]
then
   echo $MONGO_SHELL does not exist
   exit
fi

if [ "$TRIAL_COUNT" = "" ]
then
  TRIAL_COUNT="1"
fi

DBPATH=/data2/db
DBLOGS=/data3/logs/db
TARFILES=/data3/logs/archive
mkdir -p $DBPATH
mkdir -p $DBLOGS
mkdir -p $TARFILES

RH=32
for MOUNTS in $DBPATH $LOGPATH ; do
   MOUNT_POINT="/"`echo $MOUNTS | cut -f2 -d"/"`
   DEVICE=`df -P $MOUNT_POINT | grep $MOUNT_POINT | cut -f1 -d" "`
   sudo blockdev --setra $RH $DEVICE
done

MONGO_OPTIONS=""

echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
echo "0" | sudo tee /proc/sys/kernel/randomize_va_space

killall -w -s 9 mongod
killall -w -s 9 mongos

for VER in "3.0.0-rc6" ;  do
  for STORAGE_ENGINE in "mmapv0" "wiredTiger" "mmapv1" ; do
    for SH_CONF in "1s1c" "2s1c" "2s3c" ; do
      echo "3" | sudo tee /proc/sys/vm/drop_caches

      MONGOD=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongod
      MONGO=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongo
      MONGOS=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongos
      
      if [ ! -f $MONGOD ]
      then
        continue;
      fi

      SE_SUPPORT=`$MONGOD --help | grep -i storageEngine | wc -l`

      if [ "$SE_SUPPORT" = 1 ] && [ "$STORAGE_ENGINE" = "mmapv0" ]
      then
        continue
      fi

      if [ "$SE_SUPPORT" = 0 ] && [ "$STORAGE_ENGINE" != "mmapv0" ]
      then
        continue
      fi
      
      if [ "$SE_SUPPORT" == 1 ]
      then
         SE_OPTION="--storageEngine="$STORAGE_ENGINE
         if [ "$STORAGE_ENGINE" == "wiredtiger" ] || [ "$STORAGE_ENGINE" == "wiredTiger" ]
         then
           WT_RC0=`$MONGOD --help | grep -i wiredTigerEngineConfig | wc -l`
           WT_RC3=`$MONGOD --help | grep -i wiredTigerCheckpointDelaySecs | wc -l`
           if [ "$WT_RC3" == 1 ]
           then
              SE_CONF="--wiredTigerCheckpointDelaySecs 14400"
           elif [ "$WT_RC0" == 1 ]
           then
              SE_CONF="--wiredTigerEngineConfig checkpoint=(wait=14400)"
           else
              SE_CONF="--syncdelay 14400"
           fi
         else
           SE_CONF="--syncdelay 14400"
         fi
      else
         SE_OPTION=""
         SE_CONF=""
      fi
      
      SH_EXTRA=""
           
      rm -r $DBPATH/
      rm -r $DBLOGS/

      # start config servers
      NUM_MONGOC=1;
      if [ "$SH_CONF" == "2s3c" ]
      then
         NUM_MONGOC=3;
      fi
      
      CONF_HOSTS=""
      for i in `seq 1 $NUM_MONGOC`
      do
         PORT_NUM=$((i+30000)) 
         CONF_HOSTS=$CONF_HOSTS"localhost:"$PORT_NUM","
         mkdir -p $DBLOGS/conf$PORT_NUM
         mkdir -p $DBPATH/conf$PORT_NUM
         numactl --physcpubind=24-28 --interleave=all $MONGOD --configsvr --port $PORT_NUM --dbpath $DBPATH/conf$PORT_NUM --logpath $DBLOGS/conf$PORT_NUM/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA --smallfiles
      done
      CONF_HOSTS="${CONF_HOSTS%?}"
      sleep 10

      # start mongos
      mkdir -p $DBLOGS/mongos
      numactl --physcpubind=29-31 --interleave=all $MONGOS --port 27017 --configdb $CONF_HOSTS --logpath $DBLOGS/mongos/server.log --fork
      
      # start the first
      mkdir -p $DBPATH/db100
      mkdir -p $DBLOGS/db100
      numactl --physcpubind=16-23 --interleave=all $MONGOD --shardsvr --port 28001 --dbpath $DBPATH/db100 --logpath $DBLOGS/db100/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA
      sleep 20
      ${MONGO} --port 27017 --quiet --eval 'sh.addShard("localhost:28001");sh.setBalancerState(false);' 
#      ${MONGO} --port 27017 --quiet --eval 'sh.addShard("localhost:28001");' 
      
      NUM_SHARDS=1
      if [ "$SH_CONF" != "1s1c" ]
      then
        NUM_SHARDS=2
        mkdir -p $DBPATH/db200
        mkdir -p $DBLOGS/db200
        numactl --physcpubind=8-15 --interleave=all $MONGOD --shardsvr --port 28002 --dbpath $DBPATH/db200 --logpath $DBLOGS/db200/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA 
        sleep 20
#        ${MONGO} --port 27017 --quiet --eval 'sh.addShard("localhost:28002");' 
        ${MONGO} --port 27017 --quiet --eval 'sh.addShard("localhost:28002");sh.setBalancerState(false);' 
      fi

      # start mongo-perf
      LBL=$LABEL-$VER-$STORAGE_ENGINE-$SH_CONF
      taskset -c 0-7 unbuffer python benchrun.py -f testcases/*.js -t $THREADS -l $LBL --rhost "54.191.70.12" --rport 27017 -s $MONGO_SHELL --writeCmd true --trialCount $TRIAL_COUNT --trialTime $DURATION --testFilter $SUITE --shard $NUM_SHARDS 2>&1 | tee $DBLOGS/mp.log

      killall -w -s 9 mongod
      killall -w -s 9 mongos

      pushd .
      cd $DBLOGS
      tar zcf $TARFILES/$LBL.tgz * 
      popd
    done
  done
done
