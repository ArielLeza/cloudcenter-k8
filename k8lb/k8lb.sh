#!/bin/bash

set -x

install() {

  # Install and configure HAProxy
  cd ${TIER}/haproxy
  export WD=$(pwd)
  sudo ${WD}/service install
  #sudo cp ${WD}/etc/haproxy.cfg /etc/haproxy/haproxy.cfg
  sudo ${WD}/service configure
  sudo ${WD}/service start
  cd ${BASE_DIR}

  # Generate CA and TLS certificates
  cd ${TIER}/cfssl
  export WD=$(pwd)
  source ${WD}/generate.sh
  generate

  cp ${WD}/*.pem ~/.

  cd ${BASE_DIR}

  # Create kubelet bootstrap token
  BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')

  cat > ${BASE_DIR}/token.csv <<EOF
  ${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

  cp ${BASE_DIR}/token.csv ~/.
}
