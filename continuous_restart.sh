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

# Continuously kill and restart mongod processes running locally.
while true
do
	echo "Killing mongod."
	killall -9 mongod
	echo "Restarting mongod."
	mongodb/bin/mongod --config /tmp/mongo_port_27017.conf

	# Sleep a bit before next restart.
	sleep_secs=`randexp`
	echo "Sleeping for ${sleep_secs} seconds before next restart"
	echo ""
	sleep $sleep_secs
done