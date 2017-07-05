#!/bin/bash

set -x

install() {

  cd ${cliqrAppTierName}
  export WD=$(pwd)

  # Fetch certificates, configs, and token from LB node home directory
  retrieveFiles "${__K8_LB_IP}" ~ "token.csv ca.pem ca-key.pem admin.pem admin-key.pem kubernetes-key.pem kubernetes.pem bootstrap.kubeconfig kube-proxy.kubeconfig"

  sudo mkdir -p /var/lib/{kubelet,kube-proxy,kubernetes}
  sudo mkdir -p /var/run/kubernetes
  # Created on Manager, pushed to LB, pulled to Worker
  sudo mv ~/bootstrap.kubeconfig /var/lib/kubelet
  sudo mv ~/kube-proxy.kubeconfig /var/lib/kube-proxy

  #Move the TLS certificates in place
  sudo mv ~/ca.pem /var/lib/kubernetes/

  # Install Docker
  downloadFile https://get.docker.com/builds/Linux/x86_64/docker-1.12.6.tgz
  tar -xvf docker-1.12.6.tgz
  sudo cp docker/docker* /usr/bin/

  # Create the Docker systemd unit file

  cat > docker.service <<EOF
  [Unit]
  Description=Docker Application Container Engine
  Documentation=http://docs.docker.io

  [Service]
  ExecStart=/usr/bin/docker daemon \\
    --iptables=false \\
    --ip-masq=false \\
    --host=unix:///var/run/docker.sock \\
    --log-level=error \\
    --storage-driver=overlay
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  sudo mv docker.service /etc/systemd/system/docker.service
  sudo systemctl daemon-reload
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo docker version

  # Install the kubelet

  ## Install the CNI plugin
  sudo mkdir -p /opt/cni
  downloadFile https://storage.googleapis.com/kubernetes-release/network-plugins/cni-amd64-0799f5732f2a11b329d9e3d51b9c8f2e3759f2ff.tar.gz
  sudo tar -xvf cni-amd64-0799f5732f2a11b329d9e3d51b9c8f2e3759f2ff.tar.gz -C /opt/cni

  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubectl
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kube-proxy
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubelet
  chmod +x kubectl kube-proxy kubelet
  sudo mv kubectl kube-proxy kubelet /usr/bin/

  API_SERVERS=$(sudo cat /var/lib/kubelet/bootstrap.kubeconfig | \
    grep server | cut -d ':' -f2,3,4 | tr -d '[:space:]')

  cat > kubelet.service <<EOF
  [Unit]
  Description=Kubernetes Kubelet
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes
  After=docker.service
  Requires=docker.service

  [Service]
  ExecStart=/usr/bin/kubelet \\
    --api-servers=${API_SERVERS} \\
    --allow-privileged=true \\
    --cluster-dns=10.32.0.10 \\
    --cluster-domain=cluster.local \\
    --container-runtime=docker \\
    --experimental-bootstrap-kubeconfig=/var/lib/kubelet/bootstrap.kubeconfig \\
    --network-plugin=kubenet \\
    --kubeconfig=/var/lib/kubelet/kubeconfig \\
    --serialize-image-pulls=false \\
    --register-node=true \\
    --tls-cert-file=/var/lib/kubelet/kubelet-client.crt \\
    --tls-private-key-file=/var/lib/kubelet/kubelet-client.key \\
    --cert-dir=/var/lib/kubelet \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  sudo mv kubelet.service /etc/systemd/system/kubelet.service
  sudo systemctl daemon-reload
  sudo systemctl enable kubelet
  sudo systemctl start kubelet
  #sudo systemctl status kubelet --no-pager

  # kube-proxy

  cat > kube-proxy.service <<EOF
  [Unit]
  Description=Kubernetes Kube Proxy
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes

  [Service]
  ExecStart=/usr/bin/kube-proxy \\
    --cluster-cidr=${__CLUSTER_CIDR} \\
    --masquerade-all=true \\
    --kubeconfig=/var/lib/kube-proxy/kube-proxy.kubeconfig \\
    --proxy-mode=iptables \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  sudo mv kube-proxy.service /etc/systemd/system/kube-proxy.service
  sudo systemctl daemon-reload
  sudo systemctl enable kube-proxy
  sudo systemctl start kube-proxy
  # sudo systemctl status kube-proxy --no-pager

  # Approve TLS Certificate requests

  #if [ "$VM_NODE_INDEX" -eq "1" ]; then
  #  sleep 60
  #
  #  IFS=',' read -a mgr_ip <<< "$CliqrTier_k8manager_IP"
  #  KUBECTL_GET_CSR=""
  #  approveTlsCerts ${mgr_ip[0]} 1 1
  #fi

}
