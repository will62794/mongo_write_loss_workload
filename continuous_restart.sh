#!/bin/bash

#
# Continuously kill and restart local mongod processes. 
#
# Usage:
#
# ./continuous_restart.sh <mean>
#
# where "mean" is the mean of the exponential distribution to be used for the failure
# frequency.
#

set -e

restart_interval_mean="$1"

# Draw a random variable from an exponential distribution with specified mean.
randexp(){
	python -c "import random;print int(random.expovariate(1.0/$restart_interval_mean))"
}

# Kill and restart the node so we know it's running.
echo "Making sure the mongod is running."
killall -q -9 mongod
mongodb/bin/mongod --config /tmp/mongo_port_27017.conf

# Sleep initially so we don't kill the node right away.
sleep_secs=`randexp`
echo "Sleeping initially for ${sleep_secs}"
sleep $sleep_secs

# Continuously kill and restart mongod processes running locally.
while true
do

	# Kill the mongod.
	echo "[RUNNING] Killing mongod on `hostname`"
	killall -9 mongod

	# Sleep a bit before restarting.
	sleep_before_restart_secs=`randexp`
	echo "[STOPPED] Restarting mongod in $sleep_before_restart_secs seconds."
	sleep $sleep_before_restart_secs

	# Restart the node.
	mongodb/bin/mongod --config /tmp/mongo_port_27017.conf

	# Sleep a bit before next restart.
	sleep_secs=`randexp`
	echo "[RUNNING] Restarted mongod. Sleeping for ${sleep_secs} seconds before the next restart."
	sleep $sleep_secs

done