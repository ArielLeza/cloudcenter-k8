#!/bin/bash

(
set -x

source /usr/local/osmosix/etc/userenv
source /usr/local/osmosix/etc/.osmosix.sh
export

BASE_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# For retrieveFiles()
source ${BASE_DIR}/../util/function.sh

# Fetch certificates
retrieveFiles "$CliqrTier_k8lb_IP" ~ "ca.pem kubernetes-key.pem kubernetes.pem"

downloadFile https://github.com/coreos/etcd/releases/download/v3.1.4/etcd-v3.1.4-linux-amd64.tar.gz
tar xzf etcd-v3.1.4-linux-amd64.tar.gz

sudo mkdir -p /etc/etcd/
sudo cp ~/ca.pem ~/kubernetes-key.pem ~/kubernetes.pem /etc/etcd/
sudo mv etcd-v3.1.4-linux-amd64/etcd* /usr/bin/
sudo mkdir -p /var/lib/etcd

# Here we are taking public ip of all node in array. Current etcd cluster node
# name is based on order in IP list, current etcd name is stored for later use.


if [ -z $CliqrTier_k8etcd_PUBLIC_IP ]; then
  IFS=',' read -a nodes <<< "$CliqrTier_k8etcd_IP"
else
  IFS=',' read -a nodes <<< "$CliqrTier_k8etcd_PUBLIC_IP"
fi
#IFS=',' read -a nodes <<< "$CliqrTier_k8etcd_PUBLIC_IP"
IFS=',' read -a names <<< "$CliqrTier_k8etcd_HOSTNAME"

CLUSTER_LIST=""
count=${#nodes[@]}
#let count="$numClusterNodes - 1"
index=0
while [ "$index" -lt "$count" ]; do
    CLUSTER_NODE=${nodes[$index]}

	CLUSTER_LIST="${CLUSTER_LIST}${names[$index]}=https://${nodes[$index]}:2380"

	echo index=$index count=$count names=${names[$index]} nodes=${nodes[$index]}

	let "index++"
	if [ "$index" -lt "$count" ]; then
		CLUSTER_LIST="${CLUSTER_LIST},"
	fi
	echo CLUSTER_LIST=$CLUSTER_LIST
done

cat > etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/bin/etcd \\
  --name ${cliqrNodeHostname} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${OSMOSIX_PUBLIC_IP}:2380 \\
  --listen-peer-urls https://${OSMOSIX_PUBLIC_IP}:2380 \\
  --listen-client-urls https://${OSMOSIX_PUBLIC_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls https://${OSMOSIX_PUBLIC_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${CLUSTER_LIST} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


sudo mv etcd.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

#sleep 180
#sudo systemctl status etcd --no-pager

#sudo etcdctl \
#  --ca-file=/etc/etcd/ca.pem \
#  --cert-file=/etc/etcd/kubernetes.pem \
#  --key-file=/etc/etcd/kubernetes-key.pem \
#  cluster-health

)>> /var/tmp/master.log 2>&1
