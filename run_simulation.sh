#
# Commands to run from inside DSI work directory.
#

git_repo="https://github.com/will62794/mongo_write_loss_workload"
python2 ../bin/conn.py md.0 -c "git clone $git_repo"
python2 ../bin/conn.py md.1 -c "git clone $git_repo"
python2 ../bin/conn.py md.2 -c "git clone $git_repo"