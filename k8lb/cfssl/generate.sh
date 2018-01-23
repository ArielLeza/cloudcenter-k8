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
  set CSR_MGR_ADDRS CSR_ETCD_ADDRS CSR_K8_PUBLIC_ADDR CSR_SERVICE_RTR
  augmentCsvList CSR_MGR_ADDRS "$MGR_ADDRS" "\"" "\""
  augmentCsvList CSR_ETCD_ADDRS "$ETCD_ADDRS" "\"" "\""
  augmentCsvList CSR_K8_PUBLIC_ADDR "$K8_PUBLIC_ADDR" "\"" "\""
  augmentCsvList CSR_SERVICE_RTR "$SERVICE_RTR" "\"" "\""

  #for each worker node
  for ((i=0; i<${#wkr_name[*]}; i++)); do
  cat > ${wkr_name[i]}-csr.json <<EOF
{
  "CN": "system:node:${wkr_name[i]}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Philadelphia",
      "O": "system:nodes",
      "OU": "BRKCLD2235",
      "ST": "Pennsylvania"
    }
  ]
}
EOF

# REMOVED EXTERNAL IP
  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=${wkr_name[i]},${wkr_ip[i]} \
    -profile=kubernetes \
    ${wkr_name[i]}-csr.json | cfssljson -bare ${wkr_name[i]}

done

#  cat > kubernetes-csr.json <<EOF
#   {
#     "CN": "kubernetes",
#     "hosts": [
#       ${CSR_MGR_ADDRS},
#       ${CSR_ETCD_ADDRS},
#       ${CSR_K8_PUBLIC_ADDR},
#       ${CSR_SERVICE_RTR},
#       "127.0.0.1",
#       "kubernetes.default"
#     ],
#     "key": {
#       "algo": "rsa",
#       "size": 2048
#     },
#     "names": [
#       {
#         "C": "US",
#         "L": "Las Vegas",
#         "O": "Kubernetes",
#         "OU": "Cluster",
#         "ST": "Nevada"
#       }
#     ]
#   }
# EOF

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=10.32.0.1,${CliqrTier_k8manager_HOSTNAME},${K8_PUBLIC_ADDR},127.0.0.1,kubernetes.default \
    -profile=kubernetes \
    kubernetes-csr.json | cfssljson -bare kubernetes

  # ${WD}/cfssl gencert \
  #   -ca=ca.pem \
  #   -ca-key=ca-key.pem \
  #   -config=ca-config.json \
  #   -profile=kubernetes \
  #   kubernetes-csr.json | ${WD}/cfssljson -bare kubernetes

}
