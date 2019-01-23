import pymongo
import time
from pymongo import MongoClient
import threading
import argparse
import pprint
import logging

#
# A basic write workload to measure w:<N> write loss in the face of failovers.
#

class WriteWorker(threading.Thread):

	def __init__(self, hostname, port, replset, dbName, collName, nDocs, writeConcern, tid):
		threading.Thread.__init__(self)
		self.client = MongoClient(hostname, port, replicaset=replset)
		self.db = self.client[dbName]
		self.collection = self.db[collName].with_options(write_concern=writeConcern)
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
				logging.info("Worker %d, inserted doc: %s" % (self.tid, doc_to_insert))
			except pymongo.errors.AutoReconnect as e:
				logging.info("Caught AutoReconnect exception: " + str(e))
			# time.sleep(0.2)		

	def get_acknowledged_ids(self):
		""" Return the set of all document ids whose insert op was acknowledged as successful."""
		return [d["_id"] for d in self.docs_acknowledged]

	def run(self):
		self.insert_docs()

def check_docs(db, coll, acknowledged_doc_ids):
	""" Compare the set of acknowledged inserts versus the set of documents in the database. 

	Returns a set of documents that were acknowledged but are not present in the database."""

	# Find all documents in the collection the workload ran against.
	doc_ids_found = set([d["_id"] for d in list(coll.find())])
	diff = acknowledged_doc_ids.difference(doc_ids_found)
	return {
		"acknowledged" : len(acknowledged_doc_ids),
		"found" : len(doc_ids_found),
		# The set of writes that were acknowledged but did not appear in the database.
		"lost": diff,
		"lost_count" : len(diff)
	}

def cmdline_args():
	""" Parse workload parameters. """
	p = argparse.ArgumentParser()
	# 'host' should be a node in the test replica set.
	p.add_argument("--host", type=str, required=True)
	p.add_argument("--port", type=int, required=True)
	p.add_argument("--replset", type=str, required=True)
	p.add_argument("--numWorkers", type=int, default=10)
	p.add_argument("--numDocs", type=int, default=1000)
	p.add_argument("--writeConcern", type=str, default="1")
	p.add_argument("--dbName", type=str, default="test")
	p.add_argument("--collName", type=str, default="docs")
	p.add_argument("--log", type=str, default="workload.log")
	args = p.parse_args()

	return args

def run_workload():
	args = cmdline_args()

	# Support numeric or 'majority' write concerns.
	writeConcern = args.writeConcern
	if not args.writeConcern == "majority":
		writeConcern = int(writeConcern)

	# Set up basic logging.
	logging.basicConfig(filename=args.log, filemode='w', format='%(asctime)s %(message)s', level=logging.INFO)

	# Clean up the test collection.
	logging.info("Dropping test collection.")
	client = MongoClient(args.host, args.port, replicaset=args.replset)
	db = client[args.dbName]
	coll = db[args.collName].with_options(write_concern=pymongo.write_concern.WriteConcern(w="majority"))
	coll.drop()	

	logging.info("Running workload with parameters:")
	logging.info(vars(args))
	logging.info("Using writeConcern=" + str(writeConcern))

	# Run the write workloads.
	workers = []
	for wid in range(args.numWorkers):
		wConcern = pymongo.write_concern.WriteConcern(w=writeConcern)
		worker = WriteWorker(args.host, args.port, args.replset, args.dbName, args.collName, args.numDocs, wConcern, wid)
		worker.start()
		workers.append(worker)

	for w in workers:
		w.join()

	logging.info("Tried to insert %d total documents across %d workers. " % (args.numDocs * args.numWorkers, args.numWorkers))
	for w in workers:
		logging.info("Worker %d, writes acknowledged by server: %d" % (w.tid, len(w.get_acknowledged_ids())))

	# Do a dummy majority write to ensure that all previous writes committed.
	dummyColl = db["_dummy_"].with_options(write_concern=pymongo.write_concern.WriteConcern(w="majority"))
	dummyColl.insert_one({"dummy": 1})

	acknowledged_docid_set = []
	for w in workers:
		acknowledged_docid_set.extend(w.get_acknowledged_ids())
	acknowledged_docid_set = set(acknowledged_docid_set)

	# Create a new client for the checking procedure.
	client = MongoClient(args.host, args.port, replicaset=args.replset)
	db = client[args.dbName]
	coll = db[args.collName]
	stats = check_docs(db, coll, acknowledged_docid_set)
	logging.info("Finished checking collection.")
	logging.info(stats)

if __name__ == '__main__':
	run_workload()
