#!/bin/bash

# for augmentCsvList()
source ${BASE_DIR}/../util/function.sh

set -x

if [ -z "${WD}" ]; then
  WD="."
  set -x
fi

${WD}/cfssl gencert -initca ca-csr.json | ${WD}/cfssljson -bare ca

${WD}/cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | ${WD}/cfssljson -bare admin

${WD}/cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | ${WD}/cfssljson -bare kube-proxy

augmentCsvList __K8_ADDRS "$KUBERNETES_MGR_ADDRS" "\"" "\""
augmentCsvList __ETCD_ADDRS "$ETCD_ADDRS" "\"" "\""
augmentCsvList __K8_PUBLIC_ADDR "$KUBERNETES_PUBLIC_ADDR" "\"" "\""
augmentCsvList __SERVICE_RTR "$SERVICE_CLUSTER_ROUTER" "\"" "\""

if [ -n "$__K8_ADDRS" ]; then
  __K8_ADDRS="${__K8_ADDRS},"
fi
if [ -n "$__ETCD_ADDRS" ]; then
  __ETCD_ADDRS="${__ETCD_ADDRS},"
fi
if [ -n "$__K8_PUBLIC_ADDR" ]; then
  __K8_PUBLIC_ADDR="${__K8_PUBLIC_ADDR},"
fi
if [ -n "${__SERVICE_RTR}" ]; then
  __SERVICE_RTR="${__SERVICE_RTR},"
fi


cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    ${__K8_ADDRS}
    ${__ETCD_ADDRS}
    ${__K8_PUBLIC_ADDR}
    ${__SERVICE_RTR}
    "127.0.0.1",
    "kubernetes.default"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Las Vegas",
      "O": "Kubernetes",
      "OU": "Cluster",
      "ST": "Nevada"
    }
  ]
}
EOF


${WD}/cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | ${WD}/cfssljson -bare kubernetes
