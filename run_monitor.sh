#!/bin/bash
#
# Command to monitor the replica set nodes from DSI replica set. Assumes the nodes have already been set up with 
# the write loss workload files.
#
# Run this from inside the DSI "work directory". 
#

set -e

# Set up the monitor script.
echo ""
echo "##################################"
echo "### MONITOR REPLICA SET STATES ###"
echo "##################################"
python ../bin/conn.py wc -c "python mongo_write_loss_workload/monitor.py"

# Monitor the continuous restart scripts.
echo ""
echo "###################################"
echo "### MONITOR CONTINUOUS RESTARTS ###"
echo "###################################"
python ../bin/conn.py md.0 md.1 md.2 -c "printf 'HOST:' && hostname && tail -n 4 restarts.log && echo ''"
# python ../bin/conn.py md.0 md.1 md.2 -c './bin/mongo --quiet --eval "rs.status().members.filter(m => m.self)[0].stateStr"'
