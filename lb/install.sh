#!/bin/bash

(
set -x

source /usr/local/osmosix/etc/userenv
source /usr/local/osmosix/etc/.osmosix.sh
export

BASE_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# for augmentCsvList()
source ${BASE_DIR}/../util/function.sh
source ${BASE_DIR}/cfssl/generate.sh

KUBERNETES_PUBLIC_ADDR="$CliqrTier_k8lb_PUBLIC_IP"
KUBERNETES_MGR_ADDRS="$CliqrTier_k8manager_PUBLIC_IP"
ETCD_ADDRS="$CliqrTier_k8etcd_PUBLIC_IP"
SERVICE_CLUSTER_IP_RANGE="$ServiceClusterIpRange"
export KUBERNETES_PUBLIC_ADDR KUBERNETES_MGR_ADDRS ETCD_ADDRS

# Generate CA and TLS certificates
export WD=${BASE_DIR}/cfssl
generateCerts

cp ${WD}/*.pem ~/.

# Create kubelet bootstrap token
BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')

cat > ${WD}/token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

cp ${WD}/token.csv ~/.

)>> /var/tmp/master.log 2>&1
