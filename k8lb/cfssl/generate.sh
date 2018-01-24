#!/bin/bash

set -x

generate() {

  if [ -z "${WD}" ]; then
    WD="."
    set -x
  fi

  cfssl gencert -initca ca-csr.json | cfssljson -bare ca

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    admin-csr.json | cfssljson -bare admin

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    kube-proxy-csr.json | cfssljson -bare kube-proxy


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

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=${SERVICE_RTR},${CliqrTier_k8manager_HOSTNAME},${MGR_ADDRS},${ETCD_ADDRS},${K8_PUBLIC_ADDR},127.0.0.1,kubernetes.default \
    -profile=kubernetes \
    kubernetes-csr.json | cfssljson -bare kubernetes

mv *.pem $1

}
