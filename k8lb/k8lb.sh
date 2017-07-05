#!/bin/bash

(
set -x

k8lb_install() {

  # Install and configure HAProxy
  cd ${cliqrAppTierName}/haproxy
  export WD=$(pwd)
  sudo ${WD}/service install
  sudo cp etc/haproxy.cfg /etc/haproxy/haproxy.cfg
  sudo ${WD}/service configure
  sudo ${WD}/service start
  cd $BASE_DIR

  # Generate CA and TLS certificates
  cd ${cliqrAppTierName}/cfssl
  export WD=$(pwd)
  ${WD}/generate.sh

  cp ${WD}/*.pem ~/.

  # Create kubelet bootstrap token
  BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')

  cat > ${WD}/token.csv <<EOF
  ${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

  cp ${WD}/token.csv ~/.
}

# Action selection
local CMD=$1
case $CMD in
	install)
		log "[INSTALL] Installing $cliqrAppTierName"
		k8lb_install
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
		log "[RESTART k8lb] Invoking pre-restart user script"
		;;
	reload)
		log "[RELOAD k8lb] Invoking pre-reload user script"
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
