#!/bin/bash

(
set -x

source /usr/local/osmosix/etc/userenv
source /usr/local/osmosix/etc/.osmosix.sh
export

BASE_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export BASE_DIR

source ${BASE_DIR}/util/function.sh

prepareEnvironment

CMD=$1
TIER=${cliqrAppTierName}

# main entry

if [ -f ${BASE_DIR}/${cliqrAppTierName}/${cliqrAppTierName}.sh ]; then
  log "[$CMD] $cliqrAppTierName"
  ${BASE_DIR}/${cliqrAppTierName}/${cliqrAppTierName}.sh ${CMD}
else
  log "[$CMD] Error: ${BASE_DIR}/${cliqrAppTierName}/${cliqrAppTierName}.sh not found"
fi


)>> /var/tmp/master.log 2>&1
