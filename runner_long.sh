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
  DURATION=600
fi

if [ "$THREADS" = "" ]
then
  THREADS="24"
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

EXTRA_OPTS="--testFilter='$SUITE' --reportInterval 10"

echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
echo "0" | sudo tee /proc/sys/kernel/randomize_va_space

killall -w -s 9 mongod

for VER in "3.0.0-rc8" ; do

  MONGOD=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongod

  if [  ! -f "$MONGOD" ]
  then
    echo $MONGOD does not exist
    continue
  fi

  for STORAGE_ENGINE in "mmapv0" "mmapv1" "wiredTiger" ; do
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

      echo "3" | sudo tee /proc/sys/vm/drop_caches
      rm -r $DBPATH/*
      rm -r $DBLOGS/*

      CMD="$MONGOD --dbpath $DBPATH --logpath $DBLOGS/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF"
      echo $CMD >> $DBLOGS/cmd.log
      echo "" >> $DBLOGS/cmd.log
      numactl --physcpubind=0-23 --interleave=all $CMD
      sleep 20

      CONFIG=`echo $BENCHRUN_OPTS| tr -d ' '`
      LBL=$LABEL-$VER-$STORAGE_ENGINE$CONFIG
      CMD="python benchrun.py -f testcases/* -t $THREADS -l $LBL --rhost 54.191.70.12 --rport 27017 -s $MONGO_SHELL --mongo-repo-path /home/alvin/mongo --writeCmd true --trialCount $TRIAL_COUNT --trialTime $DURATION --testFilter '\$SUITE\'"
      echo $CMD >> $DBLOGS/cmd.log
      echo "" >> $DBLOGS/cmd.log      
      eval taskset -c 24-31 unbuffer $CMD 2>&1 | tee $DBLOGS/mp.log

      killall -w -s 9 mongod

      pushd .
      cd $DBLOGS
      tar zcf $TARFILES/$LBL.tgz * 
      popd     done
  done
done

