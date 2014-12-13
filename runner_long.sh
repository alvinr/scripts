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
  DURATION=600
fi

if [ "$THREADS" = "" ]
then
  THREADS="24"
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

EXTRA_OPTS="--testFilter='$SUITE' --reportInterval 10"

echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

for VER in "2.8.0-rc2" "2.6.6" "2.8.0-rc1" "2.8.0-rc0"; do

  MONGOD=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongod

  if [  ! -f "$MONGOD" ]
  then
    echo $MONGOD does not exist
    continue
  fi

  for STORAGE_ENGINE in "mmapv0" "mmapv1" "wiredTiger" ; do
#    for BENCHRUN_OPTS in "-c 8" "-c 1" "-m 8"; do
    for BENCHRUN_OPTS in "-c 1" ; do

      SE_SUPPORT=$($MONGOD --help | grep storageEngine | wc -l)

      if [ "$SE_SUPPORT" = 1 ] && [ "$STORAGE_ENGINE" = "mmapv0" ]
      then
        continue
      fi

      if [ "$SE_SUPPORT" = 0 ] && [ "$STORAGE_ENGINE" != "mmapv0" ]
      then
        continue
      fi

      if [ "$SE_SUPPORT" = 1 ]
      then
         SE_OPTION="--storageEngine="$STORAGE_ENGINE
         if [ "$STORAGE_ENGINE" = "wiredtiger" ] || [ "$STORAGE_ENGINE" = "wiredTiger" ]
         then
           SE_CONF="--wiredTigerEngineConfig 'checkpoint=(wait=14400)'"
         else
           SE_CONF="--syncdelay 14400"
         fi
      else
         SE_OPTION=""
         SE_CONF=""
      fi

      killall mongod
      echo "3" | sudo tee /proc/sys/vm/drop_caches
      rm -r $DBPATH/*
      rm $LOGPATH/server.log

      numactl --physcpubind=0-23 --interleave=all $MONGOD --dbpath $DBPATH --logpath $LOGPATH/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF
      sleep 20

      CONFIG=`echo $BENCHRUN_OPTS| tr -d ' '`
      taskset -c 24-31 python benchrun.py -f testcases/* -t $THREADS -l $LABEL-$VER-$STORAGE_ENGINE$CONFIG --rhost 54.191.70.12 --rport 27017 -s $MONGO_SHELL --mongo-repo-path /home/alvin/mongo --writeCmd true --trialCount 1 --trialTime $DURATION $BENCHRUN_OPTS $EXTRA_OPTS
     done
  done
done

