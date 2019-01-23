import pymongo
from pymongo import MongoClient

#
# Ping a set of replica set nodes and print out their health/states.
#
# Run `watch -n 1 python monitor.py` for easy monitoring.
#

hostnames=["10.2.0.200", "10.2.0.201", "10.2.0.202"]

for hostname in hostnames:
	port=27017
	replset = "rs0"
	try:
		client = MongoClient(hostname, port, replicaset=replset, connectTimeoutMS=300, serverSelectionTimeoutMS=300)
		res = client.admin.command("replSetGetStatus")
		members = res["members"]
		member = [m for m in members if hostname in m["name"]][0]
		print hostname, member['stateStr']
	except:
		print hostname, "unreachable"