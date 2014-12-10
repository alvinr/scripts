#!/bin/sh
SUITE=$1
LABEL=$2

if [ "$SUITE" = "" ]
then
  SUITE="sanity"
fi

if [ "$LABEL" = "" ]
then
  LABEL=$SUITE
fi

DATADEV=/dev/sde
JOURDEV=/dev/sde
LOGDEV=/dev/sdf
fred=`df -P | awk '$6=="/data3" {print $1}'`

MONGO_ROOT=/home/$USER

DBPATH=/data2/db
LOGPATH=/data3/logs

RH=32
for DEV in $DBPATH $LOGPATH; do
   DEVICE="/"`cut -f2 -d"/" <<< $DEV`
   sudo blockdev --setra $RH $DEV
done

MONGO_OPTIONS=""

EXTRA_OPTS="--testFilter='$SUITE'"

echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

for VER in "2.8.0-rc2" ; do

  MONGOD=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongod

  if [  ! -f "$MONGOD" ]
  then
    echo $MONGOD does not exist
    continue
  fi

  for STORAGE_ENGINE in "mmapv0" "mmapv1" "wiredtiger" "wiredTiger" ; do
    for BENCHRUN_OPTS in "-c 8" "-c 1" "-m 8"; do

      SE_SUPPORT=$($MONGOD --help | grep storageEngine | wc -l)

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
      fi

      killall mongod
      echo "3" | sudo tee /proc/sys/vm/drop_caches
      rm -r $JOURPATH/journal
      rm -r $DBPATH/*
      rm $LOGPATH/server.log

      if [ "$JOURPATH" != "$DBPATH" ]
      then
        mkdir -p $JOURPATH/journal
        ln -s $JOURPATH/journal $DBPATH/journal
      fi

      numactl --physcpubind=0-7 --interleave=all $MONGOD --dbpath $DBPATH --logpath $LOGPATH/server.log --fork $MONGO_OPTIONS $MONGO_EXTRA $SE_EXTRA
      sleep 20

      CONFIG=`echo $BENCHRUN_OPTS| tr -d ' '`
      taskset 0xf00 python benchrun.py -f testcases/* -t 1 2 4 8 12 16 20 -l $LABEL-$VER-$STORAGE_ENGINE$CONFIG --rhost 54.191.70.12 --rport 27017 -s ../mongo-perf-shell/mongo --mongo-repo-path /home/alvin/mongo --writeCmd true --trialCount 1 $BENCHRUN_OPTS $EXTRA_OPTS
     done
  done
done

