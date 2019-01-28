#!/bin/bash
#
# Commands to run the write loss workload against existing DSI replica set.
#
# Run this from inside the DSI "work directory". 
#

set -e


restart_interval_mean_secs="80"
numDocs="200000000"
# timeLimitSecs="3600" # 1 hour
timeLimitSecs="900" # 15 minutes
numWorkers="30"
writeConcern="majority"
netLatencyMS="100"
datestr=`date +"%Y_%m_%d_%I_%M_%S"`
logfile="workload_results/workload_w${writeConcern}_latency_${netLatencyMS}ms_${datestr}.log"

# Make sure Linux traffic control is installed on all nodes.
python ../bin/conn.py -d md.0 md.1 md.2 -c "sudo yum -y install tc"

#
# Set up the mongod nodes.
#
echo "--- Setting up the mongod nodes. ---"
git_repo="https://github.com/will62794/mongo_write_loss_workload"
commands="rm -rf mongo_write_loss_workload"
commands="$commands && git clone --progress $git_repo"
commands="$commands && cp mongo_write_loss_workload/continuous_restart.sh ."
killcmd="pkill -f continuous_restart" # kill previously running scripts.
removelatencycmd="sudo /usr/sbin/tc qdisc del dev eth0 root netem"
addlatencycmd="sudo /usr/sbin/tc qdisc add dev eth0 root netem delay ${netLatency}ms"
runcmd="nohup bash continuous_restart.sh $restart_interval_mean_secs > restarts.log &"
python ../bin/conn.py -d md.0 md.1 md.2 -c "$killcmd"
python ../bin/conn.py -d md.0 md.1 md.2 -c "$removelatencycmd"
python ../bin/conn.py -d md.0 md.1 md.2 -c "$addlatencycmd"
python ../bin/conn.py -d md.0 md.1 md.2 -c "$commands" -c "$runcmd"

#
# Set up the workload client.
#
echo "--- Setting up the workload client. ---"
hostname=`grep -m 1 "private_ip" infrastructure_provisioning.out.yml | sed "s/.*private_ip\: //"`
commands="pip install --user pymongo"
commands="$commands && rm -rf mongo_write_loss_workload"
commands="$commands && git clone $git_repo"
killcmd="pkill -9 -f failover_workload" # kill previously running workload.
workloadcmd="nohup python mongo_write_loss_workload/failover_workload.py --host $hostname --port 27017 --replset rs0 --numDocs $numDocs --numWorkers $numWorkers --writeConcern $writeConcern --log $logfile --timeLimitSecs $timeLimitSecs > /dev/null &"
python ../bin/conn.py wc -c "$killcmd"
python ../bin/conn.py wc -c "$commands" -c "$workloadcmd"



# Set 100ms of latency on device 'eth0'
# sudo tc qdisc add dev eth0 root netem delay 100ms

# Remove tc rule on 'eth0'
# sudo tc qdisc del dev eth0 root netem



