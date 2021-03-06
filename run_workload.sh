#!/bin/bash
#
# Commands to run the write loss workload against existing DSI replica set.
#
# Run this from inside the DSI "work directory". 
#
# e.g.
#
# ./run_workload.sh <timeLimitSecs> <writeConcern> <netLatencyMS>
#
# ./run_workload.sh 3600 1 100
#
# ./run_workload.sh 3600 majority 0
#

set -e

# Require parameters
if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters. 3 parameters required, e.g. ./run_workload.sh 3600 1 100"
    exit 0
fi


restart_interval_weibull_scale_secs="60"
sleep_before_restart_secs="10"
numDocs="200000000"
timeLimitSecs="$1"
numWorkers="30"
writeConcern="$2"
netLatencyMS="$3"
datestr=`date +"%Y_%m_%d_%I_%M_%S"`
logfile="workload_results/workload_w${writeConcern}_latency_${netLatencyMS}ms_timeLimitSecs_${timeLimitSecs}_weibullScale_${restart_interval_weibull_scale_secs}_sleepBeforeRestartSecs_${sleep_before_restart_secs}_${datestr}.log"

# Make sure Linux traffic control and numpy are installed on all nodes.
python ../bin/conn.py -d md.0 md.1 md.2 -c "sudo yum -y install tc numpy"

#
# Set up the mongod nodes.
#
echo "------------------------------------"
echo "--- Setting up the mongod nodes. ---"
echo "------------------------------------"
git_repo="https://github.com/will62794/mongo_write_loss_workload"
commands="rm -rf mongo_write_loss_workload"
commands="$commands && git clone --progress $git_repo"
commands="$commands && cp mongo_write_loss_workload/continuous_restart.sh ."
killcmd="pkill -f continuous_restart" # kill previously running scripts.
removelatencycmd="sudo /usr/sbin/tc qdisc del dev eth0 root"

# Only delay network traffic between mongod hosts.
addlatencycmd="sudo /usr/sbin/tc qdisc add dev eth0 root handle 1: prio"
addlatencycmd0="$addlatencycmd && sudo /usr/sbin/tc filter add dev eth0 parent 1:0 protocol ip prio 1 u32 match ip dst 10.2.0.201 flowid 2:1"
addlatencycmd0="$addlatencycmd0 && sudo /usr/sbin/tc filter add dev eth0 parent 1:0 protocol ip prio 1 u32 match ip dst 10.2.0.202 flowid 2:1"

addlatencycmd1="$addlatencycmd && sudo /usr/sbin/tc filter add dev eth0 parent 1:0 protocol ip prio 1 u32 match ip dst 10.2.0.200 flowid 2:1"
addlatencycmd1="$addlatencycmd1 && sudo /usr/sbin/tc filter add dev eth0 parent 1:0 protocol ip prio 1 u32 match ip dst 10.2.0.202 flowid 2:1"

addlatencycmd2="$addlatencycmd && sudo /usr/sbin/tc filter add dev eth0 parent 1:0 protocol ip prio 1 u32 match ip dst 10.2.0.200 flowid 2:1"
addlatencycmd2="$addlatencycmd2 && sudo /usr/sbin/tc filter add dev eth0 parent 1:0 protocol ip prio 1 u32 match ip dst 10.2.0.201 flowid 2:1"

runcmd="nohup bash continuous_restart.sh $restart_interval_weibull_scale_secs $sleep_before_restart_secs > restarts.log &"

python ../bin/conn.py -d md.0 md.1 md.2 -c "$killcmd"
python ../bin/conn.py -d md.0 md.1 md.2 -c "$removelatencycmd"

# Delay inbound traffic on each node.
python ../bin/conn.py -d md.0 -c "$addlatencycmd0 && sudo /usr/sbin/tc qdisc add dev eth0 parent 1:1 handle 2: netem delay ${netLatencyMS}ms"
python ../bin/conn.py -d md.1 -c "$addlatencycmd1 && sudo /usr/sbin/tc qdisc add dev eth0 parent 1:1 handle 2: netem delay ${netLatencyMS}ms"
python ../bin/conn.py -d md.2 -c "$addlatencycmd2 && sudo /usr/sbin/tc qdisc add dev eth0 parent 1:1 handle 2: netem delay ${netLatencyMS}ms"

python ../bin/conn.py -d md.0 md.1 md.2 -c "$commands" -c "$runcmd"

#
# Set up the workload client.
#
echo "---------------------------------------"
echo "--- Setting up the workload client. ---"
echo "---------------------------------------"
hostname=`grep -m 1 "private_ip" infrastructure_provisioning.out.yml | sed "s/.*private_ip\: //"`
commands="pip install --user pymongo"
commands="$commands && rm -rf mongo_write_loss_workload"
commands="$commands && git clone $git_repo"
killcmd="pkill -9 -f failover_workload" # kill previously running workload.
workloadcmd="nohup python mongo_write_loss_workload/failover_workload.py --host $hostname --port 27017 --replset rs0 --numDocs $numDocs --numWorkers $numWorkers --writeConcern $writeConcern --log $logfile --timeLimitSecs $timeLimitSecs > /dev/null &"
python ../bin/conn.py wc -c "$killcmd"
python ../bin/conn.py wc -c "$commands" -c "$workloadcmd"


