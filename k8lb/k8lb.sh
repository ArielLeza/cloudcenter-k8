#!/bin/bash

set -x

install() {

  # Install and configure HAProxy
  cd ${BASE_DIR}/${TIER}/haproxy
  export WD=$(pwd)
  #source ${WD}/service
  sudo ${WD}/service install
  # installHaproxy
  sudo ${WD}/service configure "$MGR_ADDRS"
  #generateHAProxyConfig
  sudo ${WD}/service start
  #startHAProxyService
  #cd ${BASE_DIR}

  # Generate CA and TLS certificates
  cd ${BASE_DIR}/${TIER}/cfssl
  export WD=$(pwd)
  source ${WD}/generate.sh
  generate

  cp ${WD}/*.pem ~/.

  cd ${BASE_DIR}

  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin

  #for each worker node
  for ((i=0; i<${#wkr_name[*]}; i++)); do
    kubectl config set-cluster ${ClusterName} \
      --certificate-authority=ca.pem \
      --embed-certs=true \
      --server=https://${K8_PUBLIC_ADDR}:6443 \
      --kubeconfig=${wkr_name[i]}.kubeconfig

    kubectl config set-credentials system:node:${wkr_name[i]} \
      --client-certificate=${wkr_name[i]}.pem \
      --client-key=${wkr_name[i]}-key.pem \
      --embed-certs=true \
      --kubeconfig=${wkr_name[i]}.kubeconfig

    kubectl config set-context default \
      --cluster=kubernetes-the-hard-way \
      --user=system:node:${wkr_name[i]} \
      --kubeconfig=${wkr_name[i]}.kubeconfig

    kubectl config use-context default --kubeconfig=${wkr_name[i]}.kubeconfig

    mv ${wkr_name[i]}.kubeconfig ~
  done

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${K8_PUBLIC_ADDR}:6443 \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config set-credentials kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

  mv kube-proxy.kubeconfig ~

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

  mv encryption-config.yaml ~

  # Create kubelet bootstrap token
  #BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')

  #cat > ${BASE_DIR}/token.csv <<EOF
  #${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
#EOF

  #cp ${BASE_DIR}/token.csv ~/.
}
