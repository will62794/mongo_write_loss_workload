#!/bin/bash

#
# Continuously kill and restart local mongod processes.
#
# e.g. Restart nodes every 30 seconds:
#
# 	./restart_mongod.sh 30
#


# The interval between node restarts in seconds.
interval_secs=$1

# Continuously kill and restart mongod processes running locally.
while true
do
	echo "Killing mongod..."
	killall -9 mongod
	echo "Restarting mongod..."
	mongodb/bin/mongod --config /tmp/mongo_port_27017.conf
	# Sleep a bit before next restart.
	sleep_secs=`./rand.py`
	echo $sleep_secs
	echo "Sleeping for ${sleep_secs} seconds before next restart"
	echo "---------"
	echo ""
	sleep $sleep_secs
	#sleep $interval_secs
done