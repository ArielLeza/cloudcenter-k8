#!/bin/bash

set -x

install() {

  cd ${TIER}
  export WD=$(pwd)

  # Verify needed data
  echo LB_ADDR=$LB_ADDR ETCD_LOCAL_ADDR=$ETCD_LOCAL_ADDR

  # Fetch certificates
  retrieveFiles "$LB_ADDR" ~ "ca.pem kubernetes-key.pem kubernetes.pem admin.pem admin-key.pem "

  downloadFile https://github.com/coreos/etcd/releases/download/v3.1.4/etcd-v3.1.4-linux-amd64.tar.gz
  tar xzf etcd-v3.1.4-linux-amd64.tar.gz

  sudo mkdir -p /etc/etcd/
  sudo mv ~/ca.pem ~/kubernetes-key.pem ~/kubernetes.pem /etc/etcd/
  sudo mv etcd-v3.1.4-linux-amd64/etcd* /usr/bin/
  sudo mkdir -p /var/lib/etcd

  # Here we are taking public ip of all node in array. Current etcd cluster node
  # name is based on order in IP list, current etcd name is stored for later use.

  local __CLUSTER_LIST=""
  count=${#etcd_ip[@]}

  index=0
  while [ "$index" -lt "$count" ]; do
      CLUSTER_NODE=${etcd_ip[$index]}

  	__CLUSTER_LIST="${__CLUSTER_LIST}${etcd_name[$index]}=https://${etcd_ip[$index]}:2380"

  	echo index=$index count=$count etcd_name=${etcd_name[$index]} etcd_ip=${etcd_ip[$index]}

  	let "index++"
  	if [ "$index" -lt "$count" ]; then
  		__CLUSTER_LIST="${__CLUSTER_LIST},"
  	fi
  	echo __CLUSTER_LIST=$__CLUSTER_LIST
  done

  cat > etcd.service <<EOF
  [Unit]
  Description=etcd
  Documentation=https://github.com/coreos

  [Service]
  ExecStart=/usr/bin/etcd \\
    --name ${cliqrNodeHostname} \\
    --cert-file=/etc/etcd/kubernetes.pem \\
    --key-file=/etc/etcd/kubernetes-key.pem \\
    --peer-cert-file=/etc/etcd/kubernetes.pem \\
    --peer-key-file=/etc/etcd/kubernetes-key.pem \\
    --trusted-ca-file=/etc/etcd/ca.pem \\
    --peer-trusted-ca-file=/etc/etcd/ca.pem \\
    --peer-client-cert-auth \\
    --client-cert-auth \\
    --initial-advertise-peer-urls https://${OSMOSIX_PRIVATE_IP}:2380 \\
    --listen-peer-urls https://${OSMOSIX_PRIVATE_IP}:2380 \\
    --listen-client-urls https://${OSMOSIX_PRIVATE_IP}:2379,http://127.0.0.1:2379 \\
    --advertise-client-urls https://${OSMOSIX_PRIVATE_IP}:2379 \\
    --initial-cluster-token etcd-cluster-0 \\
    --initial-cluster ${__CLUSTER_LIST} \\
    --initial-cluster-state new \\
    --data-dir=/var/lib/etcd
  Restart=on-failure
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
EOF


  sudo mv etcd.service /etc/systemd/system/

  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd

  #sleep 180
  #sudo systemctl status etcd --no-pager

  #sudo etcdctl \
  #  --ca-file=/etc/etcd/ca.pem \
  #  --cert-file=/etc/etcd/kubernetes.pem \
  #  --key-file=/etc/etcd/kubernetes-key.pem \
  #  cluster-health

}
