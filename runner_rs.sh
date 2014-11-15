#!/bin/sh
SUITE=$1

if [ "$SUITE" = "" ]
then
  SUITE="sanity"
fi

OUTDIR=/data3/db/logs
DATADEV=/dev/xvde
JOURDEV=/dev/xvde
LOGDEV=/dev/xvdf
MONGO_ROOT=/home/ec2-user
DBPATH=/data2/db
LOGPATH=/data3/db
JOURPATH=/data2/db
RH=32

MONGO_OPTIONS=""

echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
echo "0" | sudo tee /proc/sys/kernel/randomize_va_space

for VER in "2.6.5";  do
  for STORAGE_ENGINE in  "mmapv0" "mmapv1" "wiredtiger" ; do
    for RS_CONF in "none" "single" "set"; done
      killall mongod
      echo "3" | sudo tee /proc/sys/vm/drop_caches
      sudo blockdev --setra $RH $DATADEV
      sudo blockdev --setra $RH $JOURDEV
      sudo blockdev --setra $RH $LOGDEV
      rm -r $JOURPATH/journal
      rm -r $DBPATH/*
      rm $LOGPATH/server.log

      if [ "$JOURPATH" != "$DBPATH" ]
          then
          mkdir -p $JOURPATH/journal
          ln -s $JOURPATH/journal $DBPATH/journal
      fi

      MONGOD=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongod
      MONGO=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongo

      if [ ! -f $MONGOD ]
      then
        continue;
      fi

      SE_SUPPORTED=$MONGOD --help | grep -i storageEngine | wc -l
      if [ "$STORAGE_ENGINE" = "mmapv0" ] && [ "$SE_SUPPORTED" == 1 ]
      then
          continue;
      fi
      
      if [ "$SE_SUPPORTED" == 1 ]
      then
         SE_OPTION="--storageEngine="$STORAGE_ENGINE
      else
         SE_OPTION=""
      fi
      
      if [ "$STORAGE_ENGINE" == "wiredtiger" ]
      then
        SE_CONF='--wiredTigerEngineConfig "checkpoint=(wait=14400)"'
      else
        SE_CONF="--syncdelay=36000"
      fi
      
      if [ "$RS_CONF" == "single" ]
      then
        RS_EXTRA="--master --oplogSize 500"
      elif [ "$RS_CONF" == "set" ]
      then
        RS_EXTRA="-replSet mp --oplogSize 500"
      else
        RS_EXTRA=""
      fi
           
      # start the primary
      mkdir $DBPATH/db100
      mkdir $LOGPATH/db100
      numactl --physcpubind=16-23 --interleave=all $MONGOD --port 27017 --dbpath $DBPATH/db100 --logpath $LOGPATH/db100/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $RS_EXTRA
      sleep 20
      $MONGOD -eval "use admin; rs.initiate()"
      $MONGOD -eval "use admin; rs.add('localhost:27018')"
      $MONGOD -eval "use admin; rs.add('localhost:27019')"
      
      # start other members (if needed)
      if [ "$RS_CONF" == "set" ]
      then
        mkdir $DBPATH/db200
        mkdir $LOGPATH/db200
        numactl --physcpubind=8-15 --interleave=all $MONGOD --port 27018 --dbpath $DBPATH/db200 --logpath $LOGPATH/db200/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $RS_EXTRA
        mkdir $DBPATH/db300
        mkdir $LOGPATH/db300
        numactl --physcpubind=24-31 --interleave=all $MONGOD --port 27019 --dbpath $DBPATH/db300 --logpath $LOGPATH/db300/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $RS_EXTRA
        sleep 20

      fi
      # start mongo-perf
      taskset -c 0-7 python benchrun.py -f testcases/test.js -t 1 2 4 8 12 16 20 -l $SUITE-$VER-$STORAGE_ENGINE-$RS_CONF --rhost "54.191.70.12" --rport 27017 -s ../mongo/bin/mongo 
      --mongo-repo-path /home/ec2-user/mongo-src --writeCmd true --trialCount 1 --testFilter $SUITE
  done
done