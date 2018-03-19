#!/bin/bash

set -euo pipefail

WORKER_NUMBER=$1
HOSTNAME="worker-$WORKER_NUMBER"
IP_ADDRESS_WORKER="192.168.199.2$WORKER_NUMBER"

apt-get update
apt-get install -y socat libgpgme11

echo 'Configuring the network bridge'
if [ ! -f /etc/cni/net.d/10-bridge.conf ]
then
  curl -sSL -O "https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz"
  mkdir -p /etc/cni/net.d \
           /opt/cni/bin
  tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
  sed -i "s/SUBNET/10.200.${WORKER_NUMBER}.0\/24/g" 10-bridge.conf
  sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
fi

echo 'Configuring Kubelet'
if [ ! -f /etc/systemd/system/kubelet.service ]
then
  curl -sSL \
    -O "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet" \
    -O "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl"

  sed -i "s/POD_CIDR/--pod-cidr=10.200.${WORKER_NUMBER}.0\/24/g" kubelet.service
  sed -i "s/TLS_CERT/--tls-cert-file=\/var\/lib\/kubelet\/${HOSTNAME}.pem/g" kubelet.service
  sed -i "s/TLS_PRIVATE/--tls-private-key-file=\/var\/lib\/kubelet\/${HOSTNAME}-key.pem/g" kubelet.service

  mkdir -p  /var/lib/kubelet \
    /var/lib/kubernetes \
    /var/run/kubernetes

  cp kubelet kubectl /usr/local/bin/
  chmod 700 /usr/local/bin/kubectl
  chmod 700 /usr/local/bin/kubelet

  cp ca.pem /var/lib/kubernetes/
  cp kubelet.service /etc/systemd/system/kubelet.service
  cp ${HOSTNAME}.pem ${HOSTNAME}-key.pem /var/lib/kubelet
  cp ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
fi

echo 'Configuring Kube Proxy service'
if [ ! -f /var/lib/kube-proxy/kubeconfig ]
then
  curl -sSL -O "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy"
  mkdir -p /var/lib/kube-proxy
  cp kube-proxy /usr/local/bin/
  chmod 700 /usr/local/bin/kube-proxy
  cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
  cp kube-proxy.service /etc/systemd/system/
fi

echo 'Configuring CRI-O container service'
if [ ! -f /etc/systemd/system/crio.service ]
then
  mkdir -p \
    /etc/containers \
    /etc/crio \
    /usr/local/libexec/crio 

  curl -sSL \
    -O "https://github.com/opencontainers/runc/releases/download/v1.0.0-rc4/runc.amd64" \
    -O "https://files.schu.io/pub/cri-o/crio-amd64-v1.9.0.tar.gz"

  tar -xf "crio-amd64-v1.9.0.tar.gz"
  mv runc.amd64 /usr/local/bin/runc
  chmod 700 /usr/local/bin/runc

  cp crio /usr/local/bin/
  cp conmon pause /usr/local/libexec/crio/
  cp crio.conf seccomp.json /etc/crio/
  cp policy.json /etc/containers/

  sed -i "s/IP_ADDRESS_WORKER/${IP_ADDRESS_WORKER}/g" crio.service

  cp crio.service /etc/systemd/system/crio.service
fi

echo 'Starting services CRI-O, Kubelet and Kube-proxy'
systemctl daemon-reload
systemctl enable crio kubelet kube-proxy
systemctl start crio kubelet kube-proxy