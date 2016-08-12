#!/bin/bash -ex

# Remember this root directory
rootdir=$(cd $(dirname $0)/..; pwd)

# Clean up any old run and make new space
cd $HOME
rm -rf asterix-perf-workspace
mkdir asterix-perf-workspace
cd asterix-perf-workspace
export WORKSPACE=`pwd`

# Download and build latest build source code
export VERSION=0.8.9-ceej
export BLD_NUM=`curl http://172.23.120.24/builds/latestbuilds/analytics/$VERSION/latestBuildNumber`
echo @@@@ DOWNLOADING SOURCE FOR BUILD $BLD_NUM @@@@
curl -o analytics-source.tar.gz \
  http://172.23.120.24/builds/latestbuilds/analytics/$VERSION/$BLD_NUM/analytics-$VERSION-$BLD_NUM-source.tar.gz

echo @@@@ UNPACKING SOURCE @@@@
tar xzf analytics-source.tar.gz

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

JAVA_OPTS="-Djava.security.egd=file:/dev/urandom -Djava.rmi.server.hostname=$HOST1" bash -x \
  $WORKSPACE/asterix-experiments/asterix-experiments-0.8.9-SNAPSHOT-binary-assembly/bin/lsmexprunner \
  -ler $WORKSPACE/asterix-experiments/asterix-experiments-0.8.9-SNAPSHOT-binary-assembly/ \
  -mh ignored -jh ignored -u ignored \
  -rh $HOST1 -rp 19002 -regex '.*PresetClusterPerfBuilder.*'

cp $WORKSPACE/asterix-experiments/target/asterix-experiments-0.8.9-SNAPSHOT-binary-assembly/agg_results.csv \
$WORKSPACE

# Clean up
echo @@@ KILLING ASTERIXDB @@@
ansible-playbook -i inventory kill-asterix.yml

