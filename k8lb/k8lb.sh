#!/bin/bash

set -x

install() {

  # Install and configure HAProxy
  cd ${BASE_DIR}/${TIER}/haproxy
  export WD=$(pwd)

  log 'BEGIN K8LB'

  #source ${WD}/service
  sudo ${WD}/service install
  # installHaproxy
  sudo ${WD}/service configure "$MGR_ADDRS" "$WKR_ADDRS"
  #generateHAProxyConfig
  sudo ${WD}/service start
  #startHAProxyService
  #cd ${BASE_DIR}

  # Install CloudFlare SSL utilities
  downloadFile https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
  downloadFile https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

  chmod +x cfssl_linux-amd64 cfssljson_linux-amd64

  sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
  sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

  cfssl version

  # Generate CA and TLS certificates
  cd ${BASE_DIR}/${TIER}/cfssl
  export WD=$(pwd)
  source ${WD}/generate.sh
  generate ~

  cd ${BASE_DIR}

  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin

  cd ~
  #for each worker node
  for ((i=0; i<${#wkr_name[*]}; i++)); do
    local __HOSTNAME=${wkr_name[i]}
    kubectl config set-cluster ${ClusterName} \
      --certificate-authority=ca.pem \
      --embed-certs=true \
      --server=https://${LB_ADDR}:6443 \
      --kubeconfig=${__HOSTNAME}.kubeconfig

    kubectl config set-credentials system:node:${__HOSTNAME} \
      --client-certificate=${__HOSTNAME}.pem \
      --client-key=${__HOSTNAME}-key.pem \
      --embed-certs=true \
      --kubeconfig=${__HOSTNAME}.kubeconfig

    kubectl config set-context default \
      --cluster=${ClusterName} \
      --user=system:node:${__HOSTNAME} \
      --kubeconfig=${__HOSTNAME}.kubeconfig

    kubectl config use-context default --kubeconfig=${__HOSTNAME}.kubeconfig

    #mv ${__HOSTNAME}.kubeconfig ~
  done

  kubectl config set-cluster ${ClusterName} \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${LB_ADDR}:6443 \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config set-credentials kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config set-context default \
    --cluster=${ClusterName} \
    --user=kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

  # Generate admin kubeconfig
kubectl config set-cluster ${ClusterName} \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${K8_PUBLIC_ADDR}:6443 \
  --kubeconfig=${ClusterName}-admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=${ClusterName}-admin.pem \
  --client-key=${ClusterName}-admin-key.pem \
  --embed-certs=true \
  --kubeconfig=${ClusterName}-admin.kubeconfig

kubectl config set-context ${ClusterName} \
  --cluster=${ClusterName} \
  --user=${ClusterName}-admin \
  --kubeconfig=${ClusterName}-admin.kubeconfig

kubectl config use-context ${ClusterName} --kubeconfig=${ClusterName}-admin.kubeconfig

  # Seed Encryption
  ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

  cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

  cd ${BASE_DIR}
  #mv encryption-config.yaml ~

}
