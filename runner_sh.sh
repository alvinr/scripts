#!/bin/sh
SUITE=$1
LABEL=$2
DURATION=$3
THREADS=$4

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

DBPATH=/data2/db
LOGPATH=/data3/logs

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

for VER in "2.8.0-rc2";  do
#for VER in "2.8.0-rc2";  do
#  for STORAGE_ENGINE in "wiredTiger" "mmapv1" "mmapv0" ; do
  for STORAGE_ENGINE in "mmapv1" ; do
    for SH_CONF in "1s1c" "2s1c" "2s3c" ; do
      killall mongod
      killall mongos
      echo "3" | sudo tee /proc/sys/vm/drop_caches
      rm -r $DBPATH/
      rm -r $LOGPATH/

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
           SE_CONF="--wiredTigerEngineConfig 'checkpoint=(wait=14400)'"
         else
           SE_CONF="--syncdelay 14400"
         fi
      else
         SE_OPTION=""
         SE_CONF=""
      fi
      
      SH_EXTRA=""
           
      # start config servers
      NUM_MONGOC=1;
      if [ "$SH_CONF" == "2s3c" ]
      then
         NUM_MONGOC=3;
      fi
      
      CONF_PORTS=""
      for i in `seq 1 $NUM_MONGOC`
      do
         PORT_NUM=$((i+30000)) 
         CONF_HOSTS=$CONF_PORTS"localhost:"$PORT_NUM","
         mkdir -p $LOGPATH/conf$PORT_NUM
         mkdir -p $DBPATH/conf$PORT_NUM
         (eval numactl --physcpubind=24-31 --interleave=all $MONGOD --configsvr --port $PORT_NUM --dbpath $DBPATH/conf$PORT_NUM --logpath $LOGPATH/conf$PORT_NUM/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA --smallfiles )
      done
      CONF_HOSTS="${CONF_HOSTS%?}"
      sleep 10

      # start mongos
      mkdir -p $LOGPATH/mongos
      (eval numactl --physcpubind=24-31 --interleave=all $MONGOS --port 27017 --configdb $CONF_HOSTS --logpath $LOGPATH/mongos/server.log --fork )
      
      # start the first
      mkdir -p $DBPATH/db100
      mkdir -p $LOGPATH/db100
      (eval numactl --physcpubind=16-23 --interleave=all $MONGOD --shardsvr --port 28001 --dbpath $DBPATH/db100 --logpath $LOGPATH/db100/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA )
      sleep 20
      ${MONGO} --port 27017 --quiet --eval 'sh.addShard("localhost:28001");' 
      
      NUM_SHARDS=1
      if [ "$SH_CONF" != "1s1c" ]
      then
        NUM_SHARDS=2
        mkdir -p $DBPATH/db200
        mkdir -p $LOGPATH/db200
        (eval numactl --physcpubind=8-15 --interleave=all $MONGOD --shardsvr --port 28002 --dbpath $DBPATH/db200 --logpath $LOGPATH/db200/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA )
        sleep 20
        ${MONGO} --port 27017 --quiet --eval 'sh.addShard("localhost:28002");' 
      fi

      # start mongo-perf
      taskset -c 0-7 python benchrun.py -f testcases/*.js -t $THREADS -l $LABEL-$VER-$STORAGE_ENGINE-$SH_CONF --rhost "54.191.70.12" --rport 27017 -s $MONGO_SHELL --writeCmd true --trialCount 1 --trialTime $DURATION --testFilter="'$SUITE'" --shard $NUM_SHARDS
    done
  done
done
