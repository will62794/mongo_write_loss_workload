#!/bin/bash
#
# Commands to run the write loss workload against existing DSI replica set.
#
# Run this from inside the DSI "work directory". 
#

set -e

restart_interval_mean_secs="80"

# Set up the mongod nodes.
echo "--- Setting up the mongod nodes. ---"
git_repo="https://github.com/will62794/mongo_write_loss_workload"
commands="rm -rf mongo_write_loss_workload"
commands="$commands && git clone --progress $git_repo"
commands="$commands && cp mongo_write_loss_workload/continuous_restart.sh ."
killcmd="pkill -f continuous_restart" # kill previously running scripts.
runcmd="nohup bash continuous_restart.sh $restart_interval_mean_secs > restarts.log &"
python ../bin/conn.py -d md.0 md.1 md.2 -c "$killcmd"
python ../bin/conn.py -d md.0 md.1 md.2 -c "$commands" -c "$runcmd"

# Set up the workload client.
echo "--- Setting up the workload client. ---"
hostname=`grep -m 1 "private_ip" infrastructure_provisioning.out.yml | sed "s/.*private_ip\: //"`
commands="pip install --user pymongo"
commands="$commands && rm -rf mongo_write_loss_workload"
commands="$commands && git clone $git_repo"
killcmd="pkill -f failover_workload.py" # kill previously running workload.
# runcmd="nohup python mongo_write_loss_workload/failover_workload.py &"
workloadcmd="nohup python mongo_write_loss_workload/failover_workload.py --host $hostname --port 27017 --replset rs0 --numDocs 1000 > workload.log &"
python ../bin/conn.py wc -c "$killcmd"
python ../bin/conn.py wc -c "$commands" -c "$workloadcmd"

