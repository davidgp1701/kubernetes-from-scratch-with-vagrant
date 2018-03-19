#!/bin/bash

set -euo pipefail

WORKERS=$1
CONTROLLERS_IPS=$2
PUBLIC_IP=$3

if [ ! -f /home/vagrant/shared/ca.pem ]; then
	echo 'Provisioning a CA and Generating TLS Certificates'
    cfssl gencert -initca ca-csr.json | cfssljson -bare ca
    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
    cp ca-key.pem ca.pem admin-key.pem admin.pem shared

  	for i in `seq 1 $WORKERS`;
	do
		echo "Provisioning the worker-$i certificate"
		cp worker-csr.json worker-$i-csr.json
		sed -i "s/INSTANCE/worker-$i/g" worker-$i-csr.json
        cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=worker-$i,192.168.199.2$i -profile=kubernetes worker-$i-csr.json | cfssljson -bare worker-$i
        cp worker-$i-key.pem worker-$i.pem shared
	done

	echo "Provisioning the certificate of the kube-proxy"
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
    cp kube-proxy-key.pem kube-proxy.pem shared

	echo "Provisioning the certificate of kubernetes cluster"
    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=10.32.0.1,${CONTROLLERS_IPS},${PUBLIC_IP},127.0.0.1,kubernetes.default -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
    cp kubernetes-key.pem kubernetes.pem shared

else
	echo 'CA and Generating TLS Certificates already created in a previous provision...'
fi