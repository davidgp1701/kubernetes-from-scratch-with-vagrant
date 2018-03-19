 #!/bin/bash

set -euo pipefail

CONTROLLER_NUMBER=$1
CONTROLLERS_TOTAL=$2
ETCD_CLUSTER=$3

echo 'Downloading Kubernate Control Plane Binaries'
if [ ! -f /usr/local/bin/kubectl ]; then
	wget -q --https-only --timestamping "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-apiserver" "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-controller-manager" "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-scheduler" "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl"
    chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
    sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
    sudo mkdir -p /var/lib/kubernetes/
    sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem encryption-config.yaml /var/lib/kubernetes/
fi

echo 'Configuing API server and starting services...'
if [ ! -f /etc/systemd/system/kube-scheduler.service ]; then
	sed -i "s/INTERNAL_IP/192.168.199.1${CONTROLLER_NUMBER}/g" kube-apiserver.service
	sed -i "s/ETCD_SERVERS/${ETCD_CLUSTER}/g" kube-apiserver.service
	sed -i "s/NUMBER_OF_SERVERS/${CONTROLLERS_TOTAL}/g" kube-apiserver.service
	sudo mv kube-apiserver.service kube-scheduler.service kube-controller-manager.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
	sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
fi