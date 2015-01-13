#!/bin/sh
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

if [ "$TRIAL_COUNT" = "" ]
then
  TRIAL_COUNT="1"
fi

MONGO_ROOT=/home/$USER

MONGO_SHELL=$MONGO_ROOT/mongo-perf-shell/mongo

if [  ! -f "$MONGO_SHELL" ]
then
   echo $MONGO_SHELL does not exist
   exit
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

for VER in "2.8.0-rc5"  ;  do
  for STORAGE_ENGINE in "mmapv1" "wiredTiger" "mmapv0" ; do
    for RS_CONF in "set" "none" "single" ; do
      echo "3" | sudo tee /proc/sys/vm/drop_caches
      rm -r $DBPATH/
      rm -r $DBLOGS/

      MONGOD=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongod
      MONGO=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongo

      if [ ! -f $MONGOD ]
      then
        continue;
      fi

      SE_SUPPORT=`$MONGOD --help | grep -i storageEngine | wc -l`

      if [ "$SE_SUPPORT" == 1 ] && [ "$STORAGE_ENGINE" == "mmapv0" ]
      then
        continue
      fi

      if [ "$SE_SUPPORT" == 0 ] && [ "$STORAGE_ENGINE" != "mmapv0" ]
      then
        continue
      fi
      
      if [ "$SE_SUPPORT" == 1 ]
      then
         SE_OPTION="--storageEngine="$STORAGE_ENGINE
         if [ "$STORAGE_ENGINE" == "wiredtiger" ] || [ "$STORAGE_ENGINE" == "wiredTiger" ]
         then
           WT_NEW=`$MONGOD --help | grep -i wiredTigerCheckpointDelaySecs | wc -l`
           if [ "$WT_NEW" == 1 ]
           then
              SE_CONF="--wiredTigerCheckpointDelaySecs 14400"
           else
              SE_CONF="--wiredTigerEngineConfig checkpoint=(wait=14400)"
           fi
         else
           SE_CONF="--syncdelay 14400"
         fi
      else
         SE_OPTION=""
         SE_CONF=""
      fi
      
      if [ "$RS_CONF" == "single" ]
      then
#        RS_EXTRA="--replSet mp --oplogSize 500"
        RS_EXTRA="--master --oplogSize 500"
      elif [ "$RS_CONF" == "set" ]
      then
        RS_EXTRA="--replSet mp --oplogSize 500"
      else
        RS_EXTRA=""
      fi
           
      # start the primary
      mkdir -p $DBPATH/db100
      mkdir -p $DBLOGS/db100
      numactl --physcpubind=16-23 --interleave=all $MONGOD --port 27017 --dbpath $DBPATH/db100 --logpath $DBLOGS/db100/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $RS_EXTRA
      sleep 20
      # start other members (if needed)
      if [ "$RS_CONF" == "single" ]
      then
echo      ${MONGO} --quiet --port 27017 --eval 'rs.initiate( ); while (rs.status().startupStatus || (rs.status().hasOwnProperty("myState") && rs.status().myState != 1)) { sleep(1000); };'
      fi
      if [ "$RS_CONF" == "set" ]
      then
        mkdir -p $DBPATH/db200
        mkdir -p $DBLOGS/db200
        numactl --physcpubind=8-15 --interleave=all $MONGOD --port 27018 --dbpath $DBPATH/db200 --logpath $DBLOGS/db200/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $RS_EXTRA
        mkdir -p $DBPATH/db300
        mkdir -p $DBLOGS/db300
        numactl --physcpubind=24-31 --interleave=all $MONGOD --port 27019 --dbpath $DBPATH/db300 --logpath $DBLOGS/db300/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $RS_EXTRA
        sleep 20
        ${MONGO} --quiet --port 27017 --eval 'var config = { _id: "mp", members: [ { _id: 0, host: "ip-10-93-7-23.ec2.internal:27017",priority:10 }, { _id: 1, host: "ip-10-93-7-23.ec2.internal:27018" }, { _id: 3, host: "ip-10-93-7-23.ec2.internal:27019" } ],settings: {chainingAllowed: true} }; rs.initiate( config ); while (rs.status().startupStatus || (rs.status().hasOwnProperty("myState") && rs.status().myState != 1)) { sleep(1000); };' 
      fi
      # start mongo-perf
      LBL=$LABEL-$VER-$STORAGE_ENGINE-$RS_CONF
      taskset -c 0-7 python benchrun.py -f testcases/*.js -t $THREADS -l $LBL --rhost "54.191.70.12" --rport 27017 -s $MONGO_SHELL --writeCmd true --trialCount 1 --trialTime $DURATION --testFilter=$SUITE >> $DBLOGS/mp.log 2>&1

      killall -w -s 9 mongod

      pushd .
      cd $DBLOGS
      tar zcf $TARFILES/$LBL.tgz * 
      popd
    done
  done
done
