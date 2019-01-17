import pymongo
from pymongo import MongoClient

hostnames=["10.2.0.200", "10.2.0.201", "10.2.0.202"]

for hostname in hostnames:
	port=27017
	replset = "rs0"
	client = MongoClient(hostname, port, replicaset=replset)
	res = client.admin.command("replSetGetStatus")
	members = res["members"]
	member = [m for m in members if "self" in m and m["self"]][0]
	print hostname, member['stateStr']