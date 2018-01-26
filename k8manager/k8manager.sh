#!/bin/bash

set -x

install() {

  cd ${TIER}
  export WD=$(pwd)

  log 'BEGIN K8MANAGER'

  # Fetch certificates and token from LB node home directory
  retrieveFiles "${LB_ADDR}" ~ "encryption-config.yaml ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem"

  sudo mkdir -p /var/lib/kubernetes/
  cd ~
  sudo cp encryption-config.yaml ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
  cd ${WD}

  # Authentication Initialization
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin

  # Manager Setup

  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-apiserver
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-controller-manager
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-scheduler
  downloadFile https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

  # Create kube-apiserver systemd file
  local ETCD_SVR_LIST=""
  augmentCsvList ETCD_SVR_LIST "${ETCD_ADDRS}" "https://" ":2379"

  # removed NodeRestriction
  #     --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\

  cat > kube-apiserver.service <<EOF
  [Unit]
  Description=Kubernetes API Server
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes

  [Service]
  ExecStart=/usr/local/bin/kube-apiserver \\
    --admission-control=Initializers,NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
    --advertise-address=${OSMOSIX_PRIVATE_IP} \\
    --allow-privileged=true \\
    --apiserver-count=3 \\
    --audit-log-maxage=30 \\
    --audit-log-maxbackup=3 \\
    --audit-log-maxsize=100 \\
    --audit-log-path=/var/log/audit.log \\
    --authorization-mode=Node,RBAC \\
    --bind-address=0.0.0.0 \\
    --client-ca-file=/var/lib/kubernetes/ca.pem \\
    --enable-swagger-ui=true \\
    --etcd-cafile=/var/lib/kubernetes/ca.pem \\
    --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
    --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
    --etcd-servers=${ETCD_SVR_LIST} \\
    --event-ttl=1h \\
    --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
    --insecure-bind-address=0.0.0.0 \\
    --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
    --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
    --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
    --kubelet-https=true \\
    --runtime-config=api/all \\
    --service-account-key-file=/var/lib/kubernetes/ca-key.pem \\
    --service-cluster-ip-range=${SERVICE_CIDR} \\
    --service-node-port-range=30000-32767 \\
    --tls-ca-file=/var/lib/kubernetes/ca.pem \\
    --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
    --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  # create kube-controller-manager systemd file

  cat > kube-controller-manager.service <<EOF
  [Unit]
  Description=Kubernetes Controller Manager
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes

  [Service]
  ExecStart=/usr/local/bin/kube-controller-manager \\
    --address=0.0.0.0 \\
    --cluster-cidr=${CLUSTER_CIDR} \\
    --cluster-name=kubernetes \\
    --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
    --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
    --leader-elect=true \\
    --master=http://127.0.0.1:8080 \\
    --root-ca-file=/var/lib/kubernetes/ca.pem \\
    --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \\
    --service-cluster-ip-range=${SERVICE_CIDR} \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  # create kube-scheduler systemd file

  cat > kube-scheduler.service <<EOF
  [Unit]
  Description=Kubernetes Scheduler
  Documentation=https://github.com/GoogleCloudPlatform/kubernetes

  [Service]
  ExecStart=/usr/local/bin/kube-scheduler \\
    --leader-elect=true \\
    --master=http://127.0.0.1:8080 \\
    --v=2
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF

  sudo mv kube-apiserver.service kube-controller-manager.service kube-scheduler.service /etc/systemd/system/

  # Reload systemd to read all new systemd files
  sudo systemctl daemon-reload

  # Enable and start all kube services
  sudo systemctl enable kube-controller-manager kube-apiserver kube-scheduler
  sudo systemctl start kube-controller-manager kube-apiserver kube-scheduler

  sleep 60
  kubectl get componentstatuses

  # CREATE BOOTSTRAP AUTHENTICATION (ON MANAGER0 ONLY)
  cd ~
  if [ "$VM_NODE_INDEX" -eq "1" ]; then

    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

  fi

  cd ${BASE_DIR}

}
