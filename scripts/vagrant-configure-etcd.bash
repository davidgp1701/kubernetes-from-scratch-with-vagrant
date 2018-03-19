 #!/bin/bash

set -euo pipefail

CONTROLLER_NUMBER=$1
INITIAL_CLUSTER=$2           

echo "Installing and configuring etcd in controller-${CONTROLLER_NUMBER} of a complete cluster of ${INITIAL_CLUSTER}"
wget -q --https-only --timestamping "https://github.com/coreos/etcd/releases/download/v3.2.11/etcd-v3.2.11-linux-amd64.tar.gz"
tar -xvf etcd-v3.2.11-linux-amd64.tar.gz
sudo mv etcd-v3.2.11-linux-amd64/etcd* /usr/local/bin/
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
sed -i "s/ETCD_NAME/controller-${CONTROLLER_NUMBER}/g" etcd.service
sed -i "s/INTERNAL_IP/192.168.199.1${CONTROLLER_NUMBER}/g" etcd.service
sed -i "s/INITIAL_CLUSTER/${INITIAL_CLUSTER}/g" etcd.service
sudo mv etcd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd