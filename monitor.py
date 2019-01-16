import pymongo

hostname="10.2.0.200"
port=27017
replset = "rs0"
client = MongoClient(hostname, port, replicaset=replset)
res = client.admin.command("replSetGetStatus")
print res
