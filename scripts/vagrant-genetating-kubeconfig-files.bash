#!/bin/bash

set -euo pipefail

WORKERS=$1
CLUSTER_IP=$2

for i in `seq 1 $WORKERS`;
do
	echo "Generating configuration files for authentication for worker-$i"
    if [ ! -f /home/vagrant/shared/worker-$i.kubeconfig ]
    then
    	kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://${CLUSTER_IP}:6443 --kubeconfig=worker-$i.kubeconfig
        kubectl config set-credentials system:node:worker-$i --client-certificate=worker-$i.pem --client-key=worker-$i-key.pem --embed-certs=true --kubeconfig=worker-$i.kubeconfig
        kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:node:worker-$i --kubeconfig=worker-$i.kubeconfig
        kubectl config use-context default --kubeconfig=worker-$i.kubeconfig
        cp worker-$i.kubeconfig shared
    fi
done

echo "Generating the kube-proxy for authentication"
if [ ! -f /home/vagrant/shared/kube-proxy.kubeconfig ]
then
	kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://${CLUSTER_IP}:6443 --kubeconfig=kube-proxy.kubeconfig
    kubectl config set-credentials kube-proxy --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=kube-proxy.kubeconfig
    kubectl config set-context default --cluster=kubernetes-the-hard-way --user=kube-proxy --kubeconfig=kube-proxy.kubeconfig 
    kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
    cp kube-proxy.kubeconfig shared
fi

echo 'Configuring the client to access our kubernates cluster with admin rights'
if grep -sq "kubectl config use-context kubernetes-the-hard-way" /home/vagrant/.bashrc; then
    echo "Admin configuration already added..."
    exit 0;
fi
echo "kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=shared/ca.pem --embed-certs=true --server=https://${CLUSTER_IP}:6443" >> /home/vagrant/.bashrc
echo 'kubectl config set-credentials admin --client-certificate=shared/admin.pem --client-key=shared/admin-key.pem' >> /home/vagrant/.bashrc
echo 'kubectl config set-context kubernetes-the-hard-way --cluster=kubernetes-the-hard-way --user=admin' >> /home/vagrant/.bashrc
echo 'kubectl config use-context kubernetes-the-hard-way' >> /home/vagrant/.bashrc