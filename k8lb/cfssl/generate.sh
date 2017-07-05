#!/bin/bash

set -x

generate() {

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

  # Swap to unified namespace
  set CSR_K8_ADDRS CSR_ETCD_ADDRS CSR_K8_PUBLIC_ADDR CSR_SERVICE_RTR
  augmentCsvList CSR_K8_ADDRS "$KUBERNETES_MGR_ADDRS" "\"" "\""
  augmentCsvList CSR_ETCD_ADDRS "$ETCD_ADDRS" "\"" "\""
  augmentCsvList CSR_K8_PUBLIC_ADDR "$KUBERNETES_PUBLIC_ADDR" "\"" "\""
  augmentCsvList CSR_SERVICE_RTR "$SERVICE_CLUSTER_ROUTER" "\"" "\""


  cat > kubernetes-csr.json <<EOF
  {
    "CN": "kubernetes",
    "hosts": [
      ${CSR_K8_ADDRS}
      ${CSR_ETCD_ADDRS}
      ${CSR_K8_PUBLIC_ADDR}
      ${CSR_SERVICE_RTR}
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

}
