#!/bin/bash

set -x

install() {

  # Install and configure HAProxy
  cd ${BASE_DIR}/${TIER}/haproxy
  export WD=$(pwd)
  #source ${WD}/service
  sudo ${WD}/service install
  # installHaproxy
  sudo ${WD}/service configure "$MGR_ADDRS"
  #generateHAProxyConfig
  sudo ${WD}/service start
  #startHAProxyService
  #cd ${BASE_DIR}

  # Generate CA and TLS certificates
  cd ${BASE_DIR}/${TIER}/cfssl
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
