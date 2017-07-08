#!/bin/bash

set -x

install() {

  cd ${TIER}
  export WD=$(pwd)

  # Fetch certificates and token from LB node home directory
  retrieveFiles "${LB_ADDR}" ~ "token.csv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem  admin.pem admin-key.pem kube-proxy.pem kube-proxy-key.pem"

  sudo mkdir -p /var/lib/kubernetes/
  cd ~
  sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
  cd ${WD}

  # Authentication Initialization
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin


  # Manager Setup
  sudo cp ~/token.csv /var/lib/kubernetes/

  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kube-apiserver
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kube-controller-manager
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kube-scheduler
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubectl
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/bin/

  # Create kube-apiserver systemd file
  local ETCD_SVR_LIST=""
  augmentCsvList ETCD_SVR_LIST "${ETCD_ADDRS}" "https://" ":2379"

  cat > kube-apiserver.service <<EOF
  [Unit]
  Description=Kubernetes API Server
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes

  [Service]
  ExecStart=/usr/bin/kube-apiserver \\
    --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
    --advertise-address=${OSMOSIX_PRIVATE_IP} \\
    --allow-privileged=true \\
    --apiserver-count=3 \\
    --audit-log-maxage=30 \\
    --audit-log-maxbackup=3 \\
    --audit-log-maxsize=100 \\
    --audit-log-path=/var/lib/audit.log \\
    --authorization-mode=RBAC \\
    --bind-address=0.0.0.0 \\
    --client-ca-file=/var/lib/kubernetes/ca.pem \\
    --enable-swagger-ui=true \\
    --etcd-cafile=/var/lib/kubernetes/ca.pem \\
    --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
    --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
    --etcd-servers=${ETCD_SVR_LIST} \\
    --event-ttl=1h \\
    --experimental-bootstrap-token-auth \\
    --insecure-bind-address=0.0.0.0 \\
    --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
    --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
    --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
    --kubelet-https=true \\
    --runtime-config=rbac.authorization.k8s.io/v1alpha1 \\
    --service-account-key-file=/var/lib/kubernetes/ca-key.pem \\
    --service-cluster-ip-range=${SERVICE_CIDR} \\
    --service-node-port-range=30000-32767 \\
    --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
    --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
    --token-auth-file=/var/lib/kubernetes/token.csv \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  sudo mv kube-apiserver.service /etc/systemd/system/

  # create kube-controller-manager systemd file

  cat > kube-controller-manager.service <<EOF
  [Unit]
  Description=Kubernetes Controller Manager
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes

  [Service]
  ExecStart=/usr/bin/kube-controller-manager \\
    --address=0.0.0.0 \\
    --allocate-node-cidrs=true \\
    --cluster-cidr=${CLUSTER_CIDR} \\
    --cluster-name=kubernetes \\
    --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
    --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
    --leader-elect=true \\
    --master=http://${OSMOSIX_PRIVATE_IP}:8080 \\
    --root-ca-file=/var/lib/kubernetes/ca.pem \\
    --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \\
    --service-cluster-ip-range=${SERVICE_CIDR} \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  sudo mv kube-controller-manager.service /etc/systemd/system/

  # create kube-scheduler systemd file

  cat > kube-scheduler.service <<EOF
  [Unit]
  Description=Kubernetes Scheduler
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes

  [Service]
  ExecStart=/usr/bin/kube-scheduler \\
    --leader-elect=true \\
    --master=http://${OSMOSIX_PRIVATE_IP}:8080 \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  sudo mv kube-scheduler.service /etc/systemd/system/

  # Reload systemd to read all new systemd files
  sudo systemctl daemon-reload

  # Enable and start all kube services
  sudo systemctl enable kube-controller-manager
  sudo systemctl start kube-controller-manager
  sudo systemctl enable kube-apiserver
  sudo systemctl start kube-apiserver
  sudo systemctl enable kube-scheduler
  sudo systemctl start kube-scheduler

  sleep 30
  # sudo systemctl status kube-apiserver --no-pager
  # sudo systemctl status kube-controller-manager --no-pager
  # sudo systemctl status kube-scheduler --no-pager
  # kubectl get componentstatuses

  # Prepare for worker join
  kubectl create clusterrolebinding kubelet-bootstrap \
    --clusterrole=system:node-bootstrapper \
    --user=kubelet-bootstrap

  # CREATE BOOTSTRAP AUTHENTICATION (ON MANAGER0 ONLY)
  cd ~
  if [ "$VM_NODE_INDEX" -eq "1" ]; then
    BOOTSTRAP_TOKEN_CSV=$(cat ~/token.csv)
    IFS=',' read -a TOKEN <<< "$BOOTSTRAP_TOKEN_CSV"
    BOOTSTRAP_TOKEN=${TOKEN[0]}

    kubectl config set-cluster ${CLUSTER_NAME} \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${K8_PUBLIC_ADDR}:6443 \
    --kubeconfig=bootstrap.kubeconfig

  kubectl config set-credentials kubelet-bootstrap \
    --token=${BOOTSTRAP_TOKEN} \
    --kubeconfig=bootstrap.kubeconfig

  kubectl config set-context default \
    --cluster=${CLUSTER_NAME} \
    --user=kubelet-bootstrap \
    --kubeconfig=bootstrap.kubeconfig

  kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

  kubectl config set-cluster ${CLUSTER_NAME} \
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
    --cluster=${CLUSTER_NAME} \
    --user=kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig
  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

  mv bootstrap.kubeconfig kube-proxy.kubeconfig ~

  pushFiles "$LB_ADDR" ~ "bootstrap.kubeconfig kube-proxy.kubeconfig"

  fi

  cat > ~/kubectl-cfg.sh <<EOF
  K8_PUBIP=${K8_PUBLIC_ADDR}

  kubectl config set-cluster ${CLUSTER_NAME} \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${K8_PUBIP}:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

  kubectl config set-context ${CLUSTER_NAME} \
    --cluster=${CLUSTER_NAME} \
    --user=admin

  kubectl config use-context ${CLUSTER_NAME}
EOF

  cd ${BASE_DIR}

}
