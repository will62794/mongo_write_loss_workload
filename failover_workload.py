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

	def __init__(self, hostname, port, replset, dbName, collName, nDocs, timeLimitSecs, writeConcern, tid):
		threading.Thread.__init__(self)
		self.client = MongoClient(hostname, port, replicaset=replset)
		self.db = self.client[dbName]
		self.collection = self.db[collName].with_options(write_concern=writeConcern)
		self.tid = tid
		self.nDocs = nDocs
		self.docs_acknowledged = []
		# Terminate if you reach the time limit first. If you finish inserting all of your docs before the time limit,
		# then also terminate.
		self.timeLimitSecs = timeLimitSecs

	def insert_docs(self):
		t_start = time.time()
		for i in xrange(self.nDocs):

			# Check time limit.
			elapsed = time.time() - t_start
			if self.timeLimitSecs and elapsed > self.timeLimitSecs:
				logging.info("Worker %d reached time limit of %d seconds" % (self.tid, self.timeLimitSecs))
				return

			try:
				doc_id = "%d_%d" % (self.tid, i)
				doc_to_insert = {"_id": doc_id}
				res = self.collection.insert_one(doc_to_insert)
				acknowledged = res.acknowledged
				if acknowledged:
					self.docs_acknowledged.append(doc_to_insert);
				strvals = (self.tid, doc_to_insert, elapsed, self.timeLimitSecs, (elapsed/self.timeLimitSecs*100))
				logging.info("Worker %d, inserted doc: %s, elapsed: %d/%d secs, progress: %d%%" % strvals)
			except pymongo.errors.AutoReconnect as e:
				logging.info("Caught AutoReconnect exception: " + str(e))


	def get_acknowledged_ids(self):
		""" Return the set of all document ids whose insert op was acknowledged as successful."""
		return [d["_id"] for d in self.docs_acknowledged]

	def run(self):
		self.insert_docs()

def check_docs(db, coll, acknowledged_doc_ids):
	""" Compare the set of acknowledged inserts versus the set of documents in the database. 

	Returns a set of documents that were acknowledged but are not present in the database."""

	# Find all documents in the collection the workload ran against.
	def get_doc_ids_with_retries(n):
		""" Retry a find command n times. """
		retries = n 	
		while retries > 0 :	
			try:
				return set([d["_id"] for d in list(coll.find())])
			except pymongo.errors.AutoReconnect as e:
				logging.info("AutoReconnect error while checking documents, going to retry.")
				retries -= 1
				time.sleep(0.5)
		return None

	doc_ids_found = get_doc_ids_with_retries(10)
	if not doc_ids_found:
		logging.info("Unable to retrieve documents for checking.")
		return None
	diff = acknowledged_doc_ids.difference(doc_ids_found)
	# The percentage of writes that were acknowledged and also became durable.
	durable_pct = (1.0-float(len(diff))/len(acknowledged_doc_ids)) * 100
	return {
		"acknowledged" : len(acknowledged_doc_ids),
		"found" : len(doc_ids_found),
		# The set of writes that were acknowledged but did not appear in the database.
		"lost": diff,
		"lost_count" : len(diff),
		"durable_pct" : round(durable_pct, 3)
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
	p.add_argument("--timeLimitSecs", type=int, default=None)
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
		worker = WriteWorker(args.host, args.port, args.replset, args.dbName, args.collName, args.numDocs, args.timeLimitSecs, wConcern, wid)
		worker.start()
		workers.append(worker)

	for w in workers:
		w.join()

	logging.info("Tried to insert %d total documents across %d workers. " % (args.numDocs * args.numWorkers, args.numWorkers))
	for w in workers:
		logging.info("Worker %d, writes acknowledged by server: %d" % (w.tid, len(w.get_acknowledged_ids())))

	# Do a dummy majority write to ensure that all previous writes committed.
	logging.info("Doing dummy majority write before checking collection.")
	try:
		dummyColl = db["_dummy_"].with_options(write_concern=pymongo.write_concern.WriteConcern(w="majority"))
		dummyColl.insert_one({"dummy": 1})
	except:
		logging.info("Dummy majority write failed. Sleeping a bit instead.")
		time.sleep(10.0)

	acknowledged_docid_set = []
	for w in workers:
		acknowledged_docid_set.extend(w.get_acknowledged_ids())
	acknowledged_docid_set = set(acknowledged_docid_set)

	# Create a new client for the checking procedure.
	logging.info("Going to check the collection.")
	client = MongoClient(args.host, args.port, replicaset=args.replset)
	db = client[args.dbName]
	coll = db[args.collName]
	stats = check_docs(db, coll, acknowledged_docid_set)
	logging.info("Finished checking collection.")
	if stats is None:
		logging.info("Error checking collection.")
	else:
		logging.info(stats)

if __name__ == '__main__':
	run_workload()
