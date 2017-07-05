#!/bin/bash

set -x

install() {

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
