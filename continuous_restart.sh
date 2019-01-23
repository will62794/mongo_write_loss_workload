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

# Sleep initially so we don't kill nodes right away.
sleep `randexp`

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