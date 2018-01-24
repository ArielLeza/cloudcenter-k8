#!/bin/bash

set -x

install() {

  cd ${TIER}
  export WD=$(pwd)

  # Fetch certificates, configs, and token from LB node home directory
  retrieveFiles "${LB_ADDR}" ~ "ca.pem kubernetes-key.pem kubernetes.pem kube-proxy.kubeconfig ${cliqrNodeHostname}.pem ${cliqrNodeHostname}-key.pem ${cliqrNodeHostname}.kubeconfig"

  POD_CIDR=$(echo $CLUSTER_CIDR | cut -d"." -f1-2)
  POD_CIDR="${POD_CIDR}.${VM_NODE_INDEX}.0/24"

  installSoft socat

  sudo mkdir -p /var/lib/{kubelet,kube-proxy,kubernetes} \
    /var/run/kubernetes \
    /etc/cni/net.d \
    /opt/cni/bin

  # Download binaries
  downloadFile https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz
  downloadFile https://github.com/kubernetes-incubator/cri-containerd/releases/download/v1.0.0-beta.0/cri-containerd-1.0.0-beta.0.linux-amd64.tar.gz
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet
  # Install CNI, CRI, kube-proxy, kubelet
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

  # Configure the Kubelet and Kube-Proxy
  sudo mv ~/ca.pem /var/lib/kubernetes/
  sudo mv "~/*.pem" /var/lib/kubelet/
  sudo mv "~/kube-proxy.kubeconfig" /var/lib/kube-proxy/kubeconfig
  sudo mv "~/*.kubeconfig" /var/lib/kubelet/kubeconfig

  # Configure kubelet service
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

  #Configure the kube-proxy service
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

  sudo mv kubelet.service kube-proxy.service /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable containerd cri-containerd kubelet kube-proxy
  sudo systemctl start containerd cri-containerd kubelet kube-proxy

  ### VERIFY Worker
  # SSH Manager
  # kubectl get nodes | grep ${cliqrNodeHostname}

}
