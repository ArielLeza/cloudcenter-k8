#!/bin/bash

set -x

# Approve TLS certs on Controller
approveTlsCerts() {

  local __cmdoutput=""
    __cmdoutput=$(kubectl get csr)

    echo $__cmdoutput

}

while true; do

  # Loop looking for certs to approve every minute
  approveTlsCerts()
  sleep 60

}

done
