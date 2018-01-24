#!/bin/bash

set -x

install() {

  cd ${TIER}
  export WD=$(pwd)

  # Fetch certificates, configs, and token from LB node home directory
  retrieveFiles "${LB_ADDR}" ~ "ca.pem ca-key.pem admin.pem admin-key.pem kubernetes-key.pem kubernetes.pem kube-proxy.kubeconfig ${cliqrNodeHostname}.pem ${cliqrNodeHostname}-key.pem ${cliqrNodeHostname}.kubeconfig"

  POD_CIDR=$(echo $CLUSTER_CIDR | cut -d"." -f1-2)
  POD_CIDR="${POD_CIDR}.${VM_NODE_INDEX}.0/24"

  installSoft socat

  sudo mkdir -p /var/lib/{kubelet,kube-proxy,kubernetes} \
    /var/run/kubernetes \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/run/kubernetes
  # Created on Manager, pushed to LB, pulled to Worker
  #sudo mv ~/bootstrap.kubeconfig /var/lib/kubelet
  #sudo mv ~/kube-proxy.kubeconfig /var/lib/kube-proxy

  #Move the TLS certificates in place
  #sudo mv ~/ca.pem /var/lib/kubernetes/

  # Install Docker
  #downloadFile https://get.docker.com/builds/Linux/x86_64/docker-1.12.6.tgz
  downloadFile https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz
  downloadFile https://github.com/kubernetes-incubator/cri-containerd/releases/download/v1.0.0-beta.0/cri-containerd-1.0.0-beta.0.linux-amd64.tar.gz
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet
  #tar -xvf docker-1.12.6.tgz
  #sudo cp docker/docker* /usr/bin/
  sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
  sudo tar -xvf cri-containerd-1.0.0-beta.0.linux-amd64.tar.gz -C /
  chmod +x kubectl kube-proxy kubelet
  sudo mv kubectl kube-proxy kubelet /usr/local/bin/

  # Configure CNI Networking

  cat > 10-bridge.conf <<EOF
  {
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

  cat > 99-loopback.conf <<EOF
  {
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF

  sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/


  # Install the kubelet

  ## Install the CNI plugin
  #sudo mkdir -p /opt/cni
  #downloadFile https://storage.googleapis.com/kubernetes-release/network-plugins/cni-amd64-0799f5732f2a11b329d9e3d51b9c8f2e3759f2ff.tar.gz
  #sudo tar -xvf cni-amd64-0799f5732f2a11b329d9e3d51b9c8f2e3759f2ff.tar.gz -C /opt/cni

  # downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubectl
  # downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kube-proxy
  # downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubelet
  # chmod +x kubectl kube-proxy kubelet
  # sudo mv kubectl kube-proxy kubelet /usr/bin/

  #API_SERVERS=$(sudo cat /var/lib/kubelet/bootstrap.kubeconfig | \
  #  grep server | cut -d ':' -f2,3,4 | tr -d '[:space:]')

  # Configure the Kubelet

  sudo mv "${cliqrNodeHostname}-key.pem" "${cliqrNodeHostname}.pem" /var/lib/kubelet/
  sudo mv "${cliqrNodeHostname}.kubeconfig" /var/lib/kubelet/kubeconfig
  sudo mv ca.pem /var/lib/kubernetes/

  cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=cri-containerd.service
Requires=cri-containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --anonymous-auth=false \\
  --authorization-mode=Webhook \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --cloud-provider= \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/cri-containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --pod-cidr=${POD_CIDR} \\
  --register-node=true \\
  --runtime-request-timeout=15m \\
  --tls-cert-file=/var/lib/kubelet/${cliqrNodeHostname}.pem \\
  --tls-private-key-file=/var/lib/kubelet/${cliqrNodeHostname}-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  #Configure the Kubernetes Proxy
  sudo mv ~/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

  cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=${CLUSTER_CIDR} \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#   cat > kubelet.service <<EOF
#   [Unit]
#   Description=Kubernetes Kubelet
#   Documentation=https://github.com/GoogleCloudPlatform/kubernetes
#   After=docker.service
#   Requires=docker.service
#
#   [Service]
#   ExecStart=/usr/bin/kubelet \\
#     --api-servers=${K8_PUBLIC_ADDR} \\
#     --allow-privileged=true \\
#     --cluster-dns=10.32.0.10 \\
#     --cluster-domain=cluster.local \\
#     --container-runtime=docker \\
#     --experimental-bootstrap-kubeconfig=/var/lib/kubelet/bootstrap.kubeconfig \\
#     --network-plugin=kubenet \\
#     --kubeconfig=/var/lib/kubelet/kubeconfig \\
#     --serialize-image-pulls=false \\
#     --register-node=true \\
#     --tls-cert-file=/var/lib/kubelet/kubelet-client.crt \\
#     --tls-private-key-file=/var/lib/kubelet/kubelet-client.key \\
#     --cert-dir=/var/lib/kubelet \\
#     --v=2
#   Restart=on-failure
#   RestartSec=5
#
#   [Install]
#   WantedBy=multi-user.target
# EOF

  # sudo mv kubelet.service /etc/systemd/system/kubelet.service
  # sudo systemctl daemon-reload
  # sudo systemctl enable kubelet
  # sudo systemctl start kubelet
  #sudo systemctl status kubelet --no-pager

  sudo mv kubelet.service kube-proxy.service /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable containerd cri-containerd kubelet kube-proxy
  sudo systemctl start containerd cri-containerd kubelet kube-proxy

  # kube-proxy

#   cat > kube-proxy.service <<EOF
#   [Unit]
#   Description=Kubernetes Kube Proxy
#   Documentation=https://github.com/GoogleCloudPlatform/kubernetes
#
#   [Service]
#   ExecStart=/usr/bin/kube-proxy \\
#     --cluster-cidr=${CLUSTER_CIDR} \\
#     --masquerade-all=true \\
#     --kubeconfig=/var/lib/kube-proxy/kube-proxy.kubeconfig \\
#     --proxy-mode=iptables \\
#     --v=2
#   Restart=on-failure
#   RestartSec=5
#
#   [Install]
#   WantedBy=multi-user.target
# EOF
#
#   sudo mv kube-proxy.service /etc/systemd/system/kube-proxy.service
#   sudo systemctl daemon-reload
#   sudo systemctl enable kube-proxy
#   sudo systemctl start kube-proxy
  # sudo systemctl status kube-proxy --no-pager

  # Approve TLS Certificate requests

  #if [ "$VM_NODE_INDEX" -eq "1" ]; then
  #  sleep 60
  #
  #  IFS=',' read -a mgr_ip <<< "$CliqrTier_k8manager_IP"
  #  KUBECTL_GET_CSR=""
  #  approveTlsCerts ${mgr_ip[0]} 1 1
  #fi

  ### VERIFY Worker
  # SSH Manager
  # kubectl get nodes | grep ${cliqrNodeHostname}

}
