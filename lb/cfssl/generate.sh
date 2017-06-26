#!/bin/bash

set -x

generateCerts() {

if [ -z "${WD}" ]; then
  WD="."
  set -x
fi

${WD}/cfssl gencert -initca ${WD}/ca-csr.json | ${WD}/cfssljson -bare ca

${WD}/cfssl gencert \
  -ca=${WD}/ca.pem \
  -ca-key=${WD}/ca-key.pem \
  -config=${WD}/ca-config.json \
  -profile=kubernetes \
  ${WD}/admin-csr.json | ${WD}/cfssljson -bare admin

${WD}/cfssl gencert \
  -ca=${WD}/ca.pem \
  -ca-key=${WD}/ca-key.pem \
  -config=${WD}/ca-config.json \
  -profile=kubernetes \
  ${WD}/kube-proxy-csr.json | ${WD}/cfssljson -bare kube-proxy

augmentCsvList __K8_ADDRS "$KUBERNETES_MGR_ADDRS" "\"" "\""
augmentCsvList __ETCD_ADDRS "$ETCD_ADDRS" "\"" "\""
augmentCsvList __K8_PUBLIC_ADDR "$KUBERNETES_PUBLIC_ADDR" "\"" "\""
augmentCsvList __SERVICE_CIDR "$ServiceClusterIpRange" "\"" "\""

if [ -n "$__K8_ADDRS" ]; then
  __K8_ADDRS="${__K8_ADDRS},"
fi
if [ -n "$__ETCD_ADDRS" ]; then
  __ETCD_ADDRS="${__ETCD_ADDRS},"
fi
if [ -n "$__K8_PUBLIC_ADDR" ]; then
  __K8_PUBLIC_ADDR="${__K8_PUBLIC_ADDR},"
fi
if [ -n "${__SERVICE_CIDR}" ]; then
  __SERVICE_CIDR="${__SERVICE_CIDR},"
fi


cat > ${WD}/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    ${__K8_ADDRS}
    ${__ETCD_ADDRS}
    ${__K8_PUBLIC_ADDR}
    ${__SERVICE_CIDR}
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
  -ca=${WD}/ca.pem \
  -ca-key=${WD}/ca-key.pem \
  -config=${WD}/ca-config.json \
  -profile=kubernetes \
  ${WD}/kubernetes-csr.json | ${WD}/cfssljson -bare kubernetes

}
