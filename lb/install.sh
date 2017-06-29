#!/bin/bash

(
set -x

source /usr/local/osmosix/etc/userenv
source /usr/local/osmosix/etc/.osmosix.sh
export

BASE_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export BASE_DIR

# for augmentCsvList()
source ${BASE_DIR}/../util/function.sh

CUR_DIR=$(pwd)
cd haproxy
export WD=$(pwd)
sudo ${WD}/service install
sudo cp etc/haproxy.cfg /etc/haproxy/haproxy.cfg
sudo ${WD}/service configure
sudo ${WD}/service start
cd $CUR_DIR

KUBERNETES_PUBLIC_ADDR="$CliqrTier_k8lb_PUBLIC_IP"
KUBERNETES_MGR_ADDRS="$CliqrTier_k8manager_PUBLIC_IP"
ETCD_ADDRS="$CliqrTier_k8etcd_PUBLIC_IP"
SERVICE_CLUSTER_IP_RANGE="$ServiceClusterIpRange"
SERVICE_CLUSTER_ROUTER="$ServiceClusterRouter"
export KUBERNETES_PUBLIC_ADDR KUBERNETES_MGR_ADDRS ETCD_ADDRS SERVICE_CLUSTER_IP_RANGE SERVICE_CLUSTER_ROUTER

# Generate CA and TLS certificates
cd cfssl
export WD=$(pwd)
${WD}/generate.sh

cp ${WD}/*.pem ~/.

# Create kubelet bootstrap token
BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')

cat > ${WD}/token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

cp ${WD}/token.csv ~/.

)>> /var/tmp/master.log 2>&1
