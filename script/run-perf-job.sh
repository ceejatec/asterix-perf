#!/bin/bash -ex

# Arguments: Gerrit server, project, and change
gerrit_server=$1
gerrit_project=$2
gerrit_refspec=$3

# Remember this root directory
rootdir=$(cd $(dirname $0)/..; pwd)

# Clean up any old run and make new space
cd $HOME
rm -rf asterix-perf-workspace
mkdir asterix-perf-workspace
cd asterix-perf-workspace
export WORKSPACE=`pwd`

# Download and build latest build source code
export VERSION=1.0.0
export BLD_NUM=`curl http://172.23.120.24/builds/latestbuilds/analytics/$VERSION/latestBuildNumber`
echo @@@@ DOWNLOADING SOURCE FOR BUILD $BLD_NUM @@@@
curl -o analytics-source.tar.gz \
  http://172.23.120.24/builds/latestbuilds/analytics/$VERSION/$BLD_NUM/analytics-$VERSION-$BLD_NUM-source.tar.gz

echo @@@@ UNPACKING SOURCE @@@@
tar xzf analytics-source.tar.gz

if [ "x$gerrit_refspec" != "x" ]
then
  echo @@@@ APPLYING PATCH @@@@
  (
    cd `repo forall $gerrit_project -c pwd`
    git config user.name "Couchbase Build Team"
    git config user.email "build-team@couchbase.com"
    git fetch $gerrit_server/$gerrit_project $gerrit_refspec
    git cherry-pick FETCH_HEAD
  )
fi

echo @@@@ BUILDING @@@@
cd asterixdb
export JAVA_HOME=/usr/java/latest
mvn clean package -DskipTests

# Copy LSM Experiments driver for local running
echo @@@@ COPYING LSMEXPERIMENTS @@@@
cp -R $WORKSPACE/asterixdb/asterixdb/asterix-experiments/target $WORKSPACE/asterix-experiments/

# Copy asterix-server tarball for Ansible to deploy
echo @@@ COPYING ASTERIX-SERVER @@@
cp $WORKSPACE/asterixdb/asterixdb/asterix-server/target/*.zip $rootdir/ansible

# Install AsterixDB using Ansible
echo @@@ INSTALLING ASTERIXDB @@@
cd $rootdir/ansible
ansible-playbook -i inventory install-asterix.yml

# Actual perf test!
echo @@@@ RUNNING PERF EXPERIMENT @@@@
HOST1=172.23.100.191

# These references to "0.8.9" are correct for the moment, since they are
# determined by the AsterixDB Maven version, not the Analytics Build version
JAVA_OPTS="-Djava.security.egd=file:/dev/urandom -Djava.rmi.server.hostname=$HOST1" bash -x \
  $WORKSPACE/asterix-experiments/asterix-experiments-0.8.9-SNAPSHOT-binary-assembly/bin/lsmexprunner \
  -ler $WORKSPACE/asterix-experiments/asterix-experiments-0.8.9-SNAPSHOT-binary-assembly/ \
  -mh ignored -jh ignored -u ignored \
  -rh $HOST1 -rp 19002 -regex '.*PresetClusterPerfBuilder.*'

cp $WORKSPACE/asterix-experiments/asterix-experiments-0.8.9-SNAPSHOT-binary-assembly/agg_results.csv \
$WORKSPACE

# Clean up
echo @@@ KILLING ASTERIXDB @@@
ansible-playbook -i inventory kill-asterix.yml

