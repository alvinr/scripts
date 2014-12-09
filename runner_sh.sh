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

DATADEV=/dev/xvdb
LOGDEV=/dev/xvdc
MONGO_ROOT=/home/ec2-user
DBPATH=/data2/db
LOGPATH=/data3/logs
RH=32

MONGO_OPTIONS=""

echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
echo "0" | sudo tee /proc/sys/kernel/randomize_va_space

for VER in "2.6.5" "2.8.0-rc0" "2.8.0-rc1" "2.8.0-rc2";  do
  for STORAGE_ENGINE in "wiredtiger" "wiredTiger" "mmapv1" "mmapv0" ; do
    for SH_CONF in "single" "two_one_conf" "two_three_conf" ; do
      killall mongod
      echo "3" | sudo tee /proc/sys/vm/drop_caches
      sudo blockdev --setra $RH $DATADEV
      sudo blockdev --setra $RH $LOGDEV
      rm -r $DBPATH/
      rm -r $LOGPATH/

      MONGOD=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongod
      MONGO=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongo
      MONGOS=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongos
      
      if [ ! -f $MONGOD ]
      then
        continue;
      fi

      SE_SUPPORTED=`$MONGOD --help | grep -i storageEngine | wc -l`

      if [ "$SE_SUPPORT" = 1 ] && [ "$STORAGE_ENGINE" = "mmapv0" ]
      then
        continue
      fi

      if [ "$SE_SUPPORT" = 0 ] && [ "$STORAGE_ENGINE" != "mmapv0" ]
      then
        continue
      fi
      
      if [ "$SE_SUPPORTED" == 1 ]
      then
         SE_OPTION="--storageEngine="$STORAGE_ENGINE
      else
         SE_OPTION=""
      fi
      
      if [ [ "$STORAGE_ENGINE" == "wiredtiger" ] || [ "$STORAGE_ENGINE" == "wiredTiger" ] ]
      then
        SE_CONF="--wiredTigerEngineConfig 'checkpoint=(wait=14400)'"
      else
        SE_CONF="--syncdelay 14400"
      fi
      
      SH_EXTRA=""
           
      # start the first
      mkdir -p $DBPATH/db100
      mkdir -p $LOGPATH/db100
      (eval numactl --physcpubind=16-23 --interleave=all $MONGOD --shardsvr --port 28001 --dbpath $DBPATH/db100 --logpath $LOGPATH/db100/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA )
      sleep 20
      
      if [ "$SH_CONF" != "single" ]
      then
        mkdir -p $DBPATH/db200
        mkdir -p $LOGPATH/db200
        (eval numactl --physcpubind=8-15 --interleave=all $MONGOD --shardsvr --port 28002 --dbpath $DBPATH/db200 --logpath $LOGPATH/db200/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA )
        sleep 20
        ${MONGO} --quiet --eval 'sh.add("localhost:28002");' 
      fi
      
      # start config servers
      NUM_MONGOC=0;
      if [ "$SH_CONF" == "two_one_conf" ]
      then
         NUM_MONGOC=1;
      elif [ "$SH_CONF" == "two_three_conf" ]
      then
         NUM_MONGOC=3;
      fi
      
      CONF_PORTS=""
      for i in `seq 1 $NUM_MONGOC`
      do
         PORT_NUM=30000 + i
         CONF_HOSTS=$CONF_PORTS",localhost:"$PORT_NUM
         mkdir -p $LOGPATH/conf$PORT_NUM
         mkdir -p $DBPATH/conf$PORT_NUM
         (eval numactl --physcpubind=24-31 --interleave=all $MONGO --configsvr --port $PORT_NUM --dbpath $DBPATH/conf$PORT_NUM --logpath $LOGPATH/conf$PORT_NUM/server.log --fork $MONGO_OPTIONS $SE_OPTION $SE_CONF $SH_EXTRA )
      done
      
      # start mongos
      mkdir -p $LOGPATH/mongos
      (eval numactl --physcpubind=24-31 --interleave=all $MONGOS --configdb $CONF_HOSTS --logpath $LOGPATH/mongos/server.log --fork )
      
      # start mongo-perf
      taskset -c 0-7 python benchrun.py -f testcases/*.js -t 1 2 4 8 12 16 20 -l $LABEL-$VER-$STORAGE_ENGINE-$RS_CONF --rhost "54.191.70.12" --rport 27017 -s ../mongo/mongo --mongo-repo-path /home/ec2-user/mongo --writeCmd true --trialCount 1 --nodyno --testFilter="'$SUITE'"
    done
  done
done
