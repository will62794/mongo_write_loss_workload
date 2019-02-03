#!/bin/bash

#
# Continuously kill and restart local mongod processes. 
#
# Usage:
#
# ./continuous_restart.sh <mean> <sleep_before_restart_secs>
#
# where "mean" is the scale parameter used for Weibull restart distribution, and 'sleep_before_restart_secs' is 
# how long to wait before restarting a mongod node after killing it.
#

set -e

restart_interval_mean="$1"

# Sleep for a fixed amount of time before restarting nodes.
sleep_before_restart_secs="$2"


# Draw a random value from an exponential distribution with specified mean.
randexp(){
	python -c "import random;print int(random.expovariate(1.0/$restart_interval_mean))"
}

# Draw a random value from a Weibull distribution with specified shape parameter.
randweibull() {
	weibull_shape_param="1.5" # obtained empirically.
	python -c "import numpy;print int(numpy.random.weibull($weibull_shape_param)*$restart_interval_mean)"
}

# Kill and restart the node so we know it's running.
echo "Making sure the mongod is running."
killall -9 mongod || true
sleep $sleep_before_restart_secs # sleep a bit to be safe.
mongodb/bin/mongod --config /tmp/mongo_port_27017.conf

# Sleep initially so we don't kill the node right away.
sleep_secs=`randweibull`
echo "[RUNNING] Sleeping initially for ${sleep_secs} seconds"
sleep $sleep_secs

# Continuously kill and restart mongod processes running locally.
while true
do

	# Kill the mongod.
	echo "[RUNNING] Killing mongod on `hostname`"
	killall -9 mongod

	# Sleep a bit before restarting.
	echo "[STOPPED] Restarting mongod in $sleep_before_restart_secs seconds."
	sleep $sleep_before_restart_secs

	# Restart the node.
	echo "[STOPPED] Restarting mongod."
	mongodb/bin/mongod --config /tmp/mongo_port_27017.conf

	# Sleep a bit before next restart.
	sleep_secs=`randweibull`
	echo "[RUNNING] Restarted mongod. Sleeping for ${sleep_secs} seconds before the next restart."
	sleep $sleep_secs

done