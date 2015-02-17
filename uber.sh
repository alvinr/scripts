#!/bin/bash
if [ "$#" -eq 0 ]
then
    echo "illegal number of parameters"
    exit
fi

CONFIG=$1
SUITE=$2
LABEL=$3
VERSIONS=$4
DURATION=$5
THREADS=$6
TRIAL_COUNT=$7
STORAGE_ENGINES=$8
TIMESERIES=$9

MONGO_ROOT=/home/$USER

MONGO_OPTIONS="--bind_ip 127.0.0.1"

function log() {
   echo "$1" >> $2
   echo "" >> $2
}

function determineSystemLayout() {
   local __type=$1
    
   local NUM_CPUS=$(grep ^processor /proc/cpuinfo | wc -l)
   local NUM_SOCKETS=$(grep ^physical\ id /proc/cpuinfo | sort | uniq | wc -l)
   
## TODO, this needs to be computed rather than hard wired
   if [ "$NUM_CPUS" -gt 12 ]
   then
      case "$__type" in
         standalone)
            CPU_MAP[0]="0-7,16-23" # mongo-perf
            CPU_MAP[1]="8-15,24-31"  # MongoD
            ;;
         sharded)
            CPU_MAP[0]="0-7" # mongo-perf
            CPU_MAP[1]="8-15"  # MongoD
            CPU_MAP[2]="16-23"  # MongoD
            CPU_MAP[3]="24-28"  # Config
            CPU_MAP[4]="29-31"  # Router
            ;;
         replicated)
            CPU_MAP[0]="0-7" # mongo-perf
            CPU_MAP[1]="8-15"  # MongoD
            CPU_MAP[2]="16-23"  # MongoD
            CPU_MAP[3]="24-31"  # MongoD
            ;;
      esac     
   else
      case "$__type" in
         standalone)
            CPU_MAP[0]="0-3" # mongo-perf
            CPU_MAP[1]="4-11"  # MongoD
            ;;
         *)
            echo "dude, get a better machine"
            exit
            ;;
      esac     
   fi
}

function configStorage() {
   local __directory="$@"
   local _rh=32

   while [ $# -gt 0 ]
   do 
      for MOUNTS in $__directory ; do
         local MOUNT_POINT="/"`echo $MOUNTS | cut -f2 -d"/"`
         local DEVICE=`df -P $MOUNT_POINT | grep $MOUNT_POINT | cut -f1 -d" " | sed -r 's.^/dev/..'`
         sudo blockdev --setra $_rh /dev/$DEVICE
         echo "noop" | sudo tee /sys/block/$DEVICE/queue/scheduler
      done
      shift
   done
}

function determineThreads() {
    local NUM_CPUS=$(grep ^processor /proc/cpuinfo | wc -l)
    local NUM_SOCKETS=$(grep ^physical\ id /proc/cpuinfo | sort | uniq | wc -l)

    # want to measure more threads than cores
    THREADS="1 2 4"
    local TOTAL_THREADS=$(bc <<< "($NUM_CPUS * 1.5 )")
    if [[ "${TOTAL_THREADS%.*}" -ge 8 ]]
    then
        for i in `seq 8 4 $TOTAL_THREADS`
        do
            THREADS+=" ${i}"
        done
    else
        THREADS+=" 8"
    fi
}

function configSystem() {
   for i in `seq 0 $[$NUM_CPUS-1]`
   do
      if [ -f /sys/devices/system/cpu/cpu$i/cpufreq ]
      then
         echo "performance" | sudo tee /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
      fi
   done
   echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
   echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
   echo "0" | sudo tee /proc/sys/kernel/randomize_va_space
   echo "0" | sudo tee /proc/sys/vm/swappiness
}

function determineStorageEngineConfig() {
   local __mongod=$1
   local __storageEngine=$2

   local SE_CONF=""
   local SE_OPTION=""

   if [ ! -f $__mongod ]
   then
      echo "$__mongod does not exist - skipping"
      continue;
   fi

   local SE_SUPPORT=`$__mongod --help | grep -i storageEngine | wc -l`

   if [ "$SE_SUPPORT" = 1 ] && [ "$__storageEngine" = "mmapv0" ]
   then
     continue
   fi

   if [ "$SE_SUPPORT" = 0 ] && [ "$__storageEngine" != "mmapv0" ]
   then
     continue
   fi
      
   if [ "$SE_SUPPORT" == 1 ]
   then
      SE_OPTION="--storageEngine="$__storageEngine
      if [ "$__storageEngine" == "wiredtiger" ] || [ "$__storageEngine" == "wiredTiger" ]
      then
        local WT_RC0=`$__mongod --help | grep -i wiredTigerEngineConfig | wc -l`
        local WT_RC3=`$__mongod --help | grep -i wiredTigerCheckpointDelaySecs | wc -l`
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
   MONGO_CONFIG="$SE_CONF $SE_OPTION"
}

function startConfigServers() {
   local __type=$1 # not used
   local __conf=$2 # not used
   local __cpus=$3
   
   CONF_HOSTS=""
   for i in `seq 1 $__numConfigs`
   do
      local PORT_NUM=$((i+30000)) 
      CONF_HOSTS=$CONF_HOSTS"localhost:"$PORT_NUM","
      mkdir -p $DBLOGS/conf$PORT_NUM
      mkdir -p $DBPATH/conf$PORT_NUM
      CMD="$MONGOD --configsvr --port $PORT_NUM --dbpath $DBPATH/conf$PORT_NUM --logpath $DBLOGS/conf$PORT_NUM/server.log --fork --smallfiles $MONGO_OPTIONS"
      log "$CMD" $DBLOGS/cmd.log
      eval numactl --physcpubind=$__cpus --interleave=all $CMD
   done
   CONF_HOSTS="${CONF_HOSTS%?}"
   sleep 20
   
}

function startRouters() {
   local __type=$1
   local __conf=$2 # not used
   local __numRouters=$3 # not used right now
   local __confServers=$4
   local __cpus=$5

   mkdir -p $DBLOGS/mongos
   local CMD="$MONGOS --port 27017 --configdb $__confServers --logpath $DBLOGS/mongos/server.log --fork"
   log "$CMD" $DBLOGS/cmd.log    
   eval numactl --physcpubind=$__cpus --interleave=all $CMD
}

function startShards() {
   local __type=$1
   local __conf=$2
   local __num_shards=$3
   
   local CMD=""
   local port=28000

   shift 3
   for i in `seq 1 $__num_shards`
   do
      local cpu=$1
      mkdir -p $DBPATH/db${i}00
      mkdir -p $DBLOGS/db${i}00
      CMD="$MONGOD --shardsvr --port $[$port+$i] --dbpath $DBPATH/db${i}00 --logpath $DBLOGS/db${i}00/server.log --fork $__conf"
      log "$CMD" $DBLOGS/cmd.log
      eval numactl --physcpubind=$cpu --interleave=all $CMD
      sleep 20

      CMD="$MONGO --port 27017 --quiet --eval 'sh.addShard(\"localhost:$[$port+$i]\");sh.setBalancerState(false);'"
      log "$CMD" $DBLOGS/cmd.log
      eval $CMD
      shift
   done
}

function startupSharded() {
   local __type=$1
   local __conf=$2

   local numShards=0
   local numConfigs=0
   local numRouters=0
   
   if [ "$__type" == "1s1c" ]
   then
      numConfigs=1
      numShards=1
      numRouters=1
   elif [ "$__type" == "2s1c" ]
   then
      numConfigs=1
      numShards=2
      numRouters=1
   elif [ "$__type" == "2s3c" ]
   then
      numConfigs=3
      numShards=2
      numRouters=1
   fi

   startConfigServers "$__type" "$__conf" "$numConfigs" "${CPU_MAP[3]}"
   startRouters "$__type" "$__conf" "$numRouters" "${CONF_HOSTS}" "${CPU_MAP[4]}"
   startShards "$__type" "$__conf" "$numShards" "${CPU_MAP[1]}" "${CPU_MAP[2]}"

   EXTRA_OPTS="--shard $numShards"
}

function startupReplicated() {
   local __type=$1
   local __conf=$2
   
   local num=0
   local rs_extra=""
   
   if [ "$__type" == "none" ]
   then
      num=1
      rs_extra=""
   elif [ "$__type" == "single" ]
   then
      num=1
      rs_extra="--master --oplogSize 500"
   elif [ "$__type" == "set" ]
   then
      num=3
      rs_extra="--replSet mp --oplogSize 500"
   fi

   local port=27017
   for i in `seq 1 $num`
   do
      mkdir -p $DBPATH/db${i}00
      mkdir -p $DBLOGS/db${i}00
      CMD="$MONGOD --port $[$port+$i-1] --dbpath $DBPATH/db${i}00 --logpath $DBLOGS/db${i}00/server.log --fork $__conf $rs_extra $MONGO_OPTIONS"
      log "$CMD" $DBLOGS/cmd.log
      eval numactl --physcpubind=${CPU_MAP[$i]} --interleave=all $CMD
   done      
   sleep 20

   if [ "$__type" == "set" ]
   then
      CMD="$MONGO --quiet --port 27017 --eval 'var config = { _id: \"mp\", members: [ { _id: 0, host: \"localhost:27017\",priority:10 }, { _id: 1, host: \"localhost:27018\" }, { _id: 3, host: \"localhost:27019\" } ],settings: {chainingAllowed: true} }; rs.initiate( config ); while (rs.status().startupStatus || (rs.status().hasOwnProperty(\"myState\") && rs.status().myState != 1)) { sleep(1000); };' "
      log "$CMD" $DBLOGS/cmd.log
      eval $CMD
   fi
}

function startupStandalone() {
   local __type=$1
   local __conf=$2

   local CMD="$MONGOD --dbpath $DBPATH --logpath $DBLOGS/server.log --fork $__conf $MONGO_OPTIONS"
   log "$CMD" $DBLOGS/cmd.log
   eval numactl --physcpubind=${CPU_MAP[1]} --interleave=all $CMD
   sleep 20
}

function startTimeSeries() {
   local __path=$1
   local __delay=$2

   if [ "$__delay" = "" ]
   then
      __delay=1
   fi

   checkOneDependency iostat

   local mount_point="/"`echo $__path | cut -f2 -d"/"`
   local device=`df -P $mount_point | grep $mount_point | cut -f1 -d" " | sed -r 's.^/dev/..'`

   eval taskset -c ${CPU_MAP[0]} "$MONGO --eval 'while(true) {print(JSON.stringify(db.serverStatus())); sleep(1000*$__delay)}'" >$DBLOGS/ss.log &
   eval taskset -c ${CPU_MAP[0]} iostat -k -t -x ${__delay} ${device} >$DBLOGS/iostat.log &

   if [ -f $TS/sysmon.py ]
   then
      eval taskset -c ${CPU_MAP[0]} python $TS/sysmon.py $__delay >$DBLOGS/sysmon.log &
   fi

   if [ -f $TS/sysmon.py ]
   then
      eval taskset -c ${CPU_MAP[0]} python $TS/gdbmon.py $(pidof mongod) $__delay >$DBLOGS/gdbmon.log &
   fi
}

function stopTimeSeries() {
   killall -w -s 9 mongo
   killall iostat
   killall python
}

function cleanup() {
   killall -w -s 9 $MONGOD
   killall -w -s 9 $MONGO
   killall -w -s 9 $MONGOS
   killall -w -s 9 iostat
   killall -w -s 9 python
   exit
}

function checkOneDependency() {
   local __cmd=$1

   if [ ! -x "$(which $__cmd)" ]
   then
     echo ${__cmd} not available, install to proceeed. Now exiting
     exit
   fi
}
function checkDependencies() {
   checkOneDependency numactl
   checkOneDependency taskset
   checkOneDependency python
   checkOneDependency killall
}

## MAIN
trap cleanup SIGINT SIGTERM

for CFG in $CONFIG
do
   case "$CFG" in
      standalone)
         ;;
      sharded)
         ;;
      replicated)
         ;;
      *)
         echo "config needs to be one of [standalone | sharded | replicated]"
         exit
   esac
done
    
if [ "$SUITE" = "" ]
then
  SUITE="sanity"
fi

if [ "$LABEL" = "" ]
then
  LABEL=$SUITE
fi

if [ "$DURATION" = "" ] || [ "$DURATION" = "default" ]
then
  DURATION=5
fi

if [ "$VERSIONS" = "" ] || [ "$VERSIONS" = "default" ]
then
  # If not passed, run the latest found (based on timestamp) - its a proxy for the "right" thing
  # should integrate with get_binaries to get the latest
  PATTERN="$MONGO_ROOT/mongodb-linux-x86_64-"
  VERSIONS=`ls -t $PATTERN* | head -1 | sed -r "s.^$PATTERN.." | cut -f1 -d":"`
fi

if [ "$THREADS" = "" ] || [ "$THREADS" = "default" ]
then
#   determineThreads
   THREADS="1 2 4 8 12 16 20"
fi

if [ "$TRIAL_COUNT" = "" ] || [ "$TRIAL_COUNT" = "default" ]
then
  TRIAL_COUNT="1"
fi

if [ "$STORAGE_ENGINES" = "" ] || [ "$STORAGE_ENGINES" = "default" ]
then
  STORAGE_ENGINES="wiredTiger mmapv1 mmapv0"
fi

if [ "$TIMESERIES" = "" ] || [ "$TIMESERIES" = "default" ]
then
  TIMESERIES=true
fi

MONGO_ROOT=/home/$USER

MONGO_SHELL=$MONGO_ROOT/mongo-perf-shell/mongo
if [  ! -f "$MONGO_SHELL" ]
then
   echo $MONGO_SHELL does not exist
   exit
fi

TS=/home/$USER/support-tools/timeseries
DBPATH=/data2/db
DBLOGS=/data3/logs/db
TARFILES=/data3/logs/archive
mkdir -p $TARFILES
DYNO="--dyno"

checkDependencies
configStorage $DBPATH $LOGPATH
configSystem 

for TYPE in $CONFIG
do
   case "$TYPE" in
      standalone)
         CONFIG_OPTS="c1 c8 m8";
         ;;
      sharded)
         CONFIG_OPTS="1s1c 2s1c 2s3c"
         ;;
      replicated)
         CONFIG_OPTS="single set none"
         ;;
   esac           
   determineSystemLayout $TYPE

for VER in $VERSIONS ;  do
  for SE in $STORAGE_ENGINES ; do
    for CONF in $CONFIG_OPTS ; do
      MONGOD=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongod
      MONGO=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongo
      MONGOS=$MONGO_ROOT/mongodb-linux-x86_64-$VER/bin/mongos
      
      determineStorageEngineConfig $MONGOD $SE 

      EXTRA_OPTS=""
      case "$TYPE" in
         standalone)
            startupStandalone $CONF "$MONGO_CONFIG"
            EXTRA_OPTS="-"${CONF:0:1}" "${CONF:1:1}
            ;;
         sharded)
            startupSharded $CONF "$MONGO_CONFIG"
            ;;
         replicated)
            startupReplicated $CONF "$MONGO_CONFIG"
            ;;
      esac           

      # start mongo-perf
      LBL=`echo $LABEL-$VER-$SE-$CONF| tr -d ' '`
      
      rm -r $DBPATH/
      rm -r $DBLOGS/     

      for f in testcases/*.js
      do
          testcase=`echo $f | cut -f1 -d"." | cut -f2 -d"/"`

          killall -w -s 9 mongod
          killall -w -s 9 mongos    
          echo "3" | sudo tee /proc/sys/vm/drop_caches
          rm -r $DBPATH/
          rm -r $DBLOGS/$testcase

          mkdir -p $DBPATH
          mkdir -p $DBLOGS/$testcase

          CMD="python benchrun.py -f $f -t $THREADS -l $LBL --rhost \"54.191.70.12\" --rport 27017 -s $MONGO_SHELL --writeCmd true --trialCount $TRIAL_COUNT --trialTime $DURATION --testFilter \'$SUITE\' $EXTRA_OPTS $DYNO"
          log "$CMD" $DBLOGS/$testcase/cmd.log

          if [ "$TIMESERIES" = true ]
          then
            startTimeSeries $DBPATH
          fi

          eval taskset -c ${CPU_MAP[0]} unbuffer $CMD 2>&1 | tee $DBLOGS/$testcase/mp.log

          killall -w -s 9 mongod
          killall -w -s 9 mongos
          stopTimeSeries          
      done

      pushd .
      cd $DBLOGS
      tar zcf $TARFILES/$LBL.tgz * 
      popd
    done
  done
done
done
