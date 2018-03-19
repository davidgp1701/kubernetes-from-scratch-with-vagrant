#!/bin/bash

set -euo pipefail

CONTROLLERS=$1
WORKERS=$2

echo 'Starting to create hosts file'
sudo echo '127.0.0.1 localhost' > /etc/hosts
sudo echo '192.168.199.40 lb' >> /etc/hosts

for i in `seq 1 $CONTROLLERS`;
do
	sudo echo "192.168.199.1$i controller-$i" >> /etc/hosts
done

for i in `seq 1 $WORKERS`;
do
	sudo echo "192.168.199.2$i worker-$i" >> /etc/hosts
done