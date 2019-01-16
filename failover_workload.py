import pymongo
import time
from pymongo import MongoClient
import threading

#
# A basic write workload to measure w:1 write loss in the face of failovers.
#

class WriteWorker(threading.Thread):

	def __init__(self, hostname, port, replset, dbName, collName, tid, nDocs):
		threading.Thread.__init__(self)
		self.client = MongoClient(hostname, port, replicaset=replset)
		self.db = self.client[dbName]
		self.collection = self.db[collName].with_options(write_concern=pymongo.write_concern.WriteConcern(w=1))
		self.tid = tid
		self.nDocs = nDocs
		self.docs_acknowledged = []

	def insert_docs(self):
		for i in range(self.nDocs):
			try:
				# doc_to_insert = {"tid": tid, "id": i}
				doc_id = "%d_%d" % (self.tid, i)
				doc_to_insert = {"_id": doc_id}
				res = self.collection.insert_one(doc_to_insert)
				acknowledged = res.acknowledged
				if acknowledged:
					self.docs_acknowledged.append(doc_to_insert);
				print "Worker %d, inserted doc: %s" % (self.tid, doc_to_insert)
			except pymongo.errors.AutoReconnect as e:
				print "Caught AutoReconnect exception: ", e
			time.sleep(0.2)		

	def get_acknowledged_docs(self):
		return self.docs_acknowledged

	def run(self):
		self.insert_docs()

def check_docs(db, coll):
	# Do a dummy majority write to ensure that all previous writes committed.
	dummyColl = db["dummy"].with_options(write_concern=pymongo.write_concern.WriteConcern(w="majority"))
	dummyColl.insert_one({"dummy": 1})

	# Find all documents in the collection the workload ran against.
	all_docs = list(coll.find())
	print "Found %d documents in collection at end of test." % len(all_docs)

#
# Workload parameters.
#


hostname = "10.2.0.200" # A node in the DSI replica set.
port = 27017
replset = "rs0"
nDocs = 650
dbName="test"
collName="docs"
nWorkers = 5

def run_workload():
	client = MongoClient(hostname, port, replicaset=replset)
	db = client[dbName]
	collection = db[collName].with_options(write_concern=pymongo.write_concern.WriteConcern(w="majority"))
	print collection.write_concern
	collection.drop()	
	tid = 0

	# Run the write workloads.
	workers = []
	for wid in range(nWorkers):
		worker = WriteWorker(hostname, port, replset, dbName, collName, wid, nDocs)
		worker.start()
		workers.append(worker)

	for w in workers:
		w.join()

	print "Tried to insert %d total documents across %d workers. " % (nDocs * nWorkers, nWorkers)
	for w in workers:
		print "Worker %d, num docs acknowledged by server: %d" % (w.tid, len(w.get_acknowledged_docs()))

	check_docs(db, collection)

run_workload()