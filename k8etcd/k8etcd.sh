#!/bin/bash

(
set -x

k8etcd_install() {

  cd ${cliqrAppTierName}
  export WD=$(pwd)

  # Fetch certificates
  retrieveFiles "$__K8_LB_IP" ~ "ca.pem kubernetes-key.pem kubernetes.pem admin.pem admin-key.pem "

  downloadFile https://github.com/coreos/etcd/releases/download/v3.1.4/etcd-v3.1.4-linux-amd64.tar.gz
  tar xzf etcd-v3.1.4-linux-amd64.tar.gz

  sudo mkdir -p /etc/etcd/
  sudo mv ~/ca.pem ~/kubernetes-key.pem ~/kubernetes.pem /etc/etcd/
  sudo mv etcd-v3.1.4-linux-amd64/etcd* /usr/bin/
  sudo mkdir -p /var/lib/etcd

  # Here we are taking public ip of all node in array. Current etcd cluster node
  # name is based on order in IP list, current etcd name is stored for later use.

  # Swap to unified namespace
  if [ ! -z $__K8_ETCD_IP ]; then
    IFS=',' read -a nodes <<< "$CliqrTier_k8etcd_IP"
    __K8_ETCD_IP="$CliqrTier_k8etcd_IP"
    __K8_ETCD_LOCAL="$OSMOSIX_PRIVATE_IP"
  else
    IFS=',' read -a nodes <<< "$CliqrTier_k8etcd_PUBLIC_IP"
    __K8_ETCD_IP="$CliqrTier_k8etcd_PUBLIC_IP"
    __K8_ETCD_LOCAL="$OSMOSIX_PUBLIC_IP"
  fi
  #IFS=',' read -a nodes <<< "$CliqrTier_k8etcd_PUBLIC_IP"
  IFS=',' read -a names <<< "$CliqrTier_k8etcd_HOSTNAME"

  CLUSTER_LIST=""
  count=${#nodes[@]}
  #let count="$numClusterNodes - 1"
  index=0
  while [ "$index" -lt "$count" ]; do
      CLUSTER_NODE=${nodes[$index]}

  	CLUSTER_LIST="${CLUSTER_LIST}${names[$index]}=https://${nodes[$index]}:2380"

  	echo index=$index count=$count names=${names[$index]} nodes=${nodes[$index]}

  	let "index++"
  	if [ "$index" -lt "$count" ]; then
  		CLUSTER_LIST="${CLUSTER_LIST},"
  	fi
  	echo CLUSTER_LIST=$CLUSTER_LIST
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
    --initial-advertise-peer-urls https://${__K8_ETCD_LOCAL}:2380 \\
    --listen-peer-urls https://${__K8_ETCD_LOCAL}:2380 \\
    --listen-client-urls https://${__K8_ETCD_LOCAL}:2379,http://127.0.0.1:2379 \\
    --advertise-client-urls https://${__K8_ETCD_LOCAL}:2379 \\
    --initial-cluster-token etcd-cluster-0 \\
    --initial-cluster ${CLUSTER_LIST} \\
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

# Action selection

local CMD=$1
case $CMD in
	install)
		log "[INSTALL] Installing $cliqrAppTierName"
		k8etcd_install
		;;
	deploy)
		;;
	configure)
		log "[CONFIGURE] Configuring $cliqrAppTierName"

		;;
	start)
	 	log "[START] Mounting storage volumes"

		log "[START] Invoking pre-start user script"

		log "[START] Starting $cliqrAppTierName"

		log "[START] Invoking post-start user script"

    	log "[START] $cliqrAppTierName successfully started."
		;;
	stop)
		log "[STOP] Invoking pre-stop user script"

		log "[STOP] Stopping $cliqrAppTierName"

		log "[STOP] Invoking post-stop user script"

		log "[STOP] $cliqrAppTierName successfully stopped."
		;;
	restart)
		log "[RESTART] Invoking pre-restart user script"
		;;
	reload)
		log "[RELOAD] Invoking pre-reload user script"
		;;
	cleanup)

        ;;
    upgrade)

        ;;
	*)
		log "[ERROR] unknown command"
		exit 127
		;;
esac

)>> /var/tmp/master.log 2>&1
