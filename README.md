# MongoDB w:1 Write Loss Workload

This repository contains scripts for running experiments to quantify the amount of w:1 writes that will be lost by a replica set under standard failure modes. The workloads are designed to work with MongoDB's DSI testing framework. The [failover_workload.py](failover_workload.py) script is an insert-only Python workload that runs against a specified replica set. It runs a number of concurrent clients that each insert globally unique documents into the database at a given write concern. At the end of the test, it compares the number of inserts that were acknowledged to the client with the number of inserts that actually appeared in the databae i.e. were durable. Here is an example of how to run the workload script from the command line:

```
python mongo_write_loss_workload/failover_workload.py --host localhost --port 27017 --replset rs0 --numDocs 2000000 --numWorkers 30 --writeConcern "1" --timeLimitSecs 3600
```

There is also the [continuous_restart.sh](continuous_restart.sh) script which handles the continuous shut down and restart of locally running mongod processes. It models the time between failure of a particular node using a Weibull distribution, and you can specify the scale parameter of that distribution with a command line parameter e.g.

```
./continuous_restart.sh <weibull_scale_param> <sleep_before_restart_secs>
```