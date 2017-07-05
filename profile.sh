#!/bin/bash

(
set -x

source /usr/local/osmosix/etc/userenv
source /usr/local/osmosix/etc/.osmosix.sh
export

BASE_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export BASE_DIR

source ${BASE_DIR}/util/function.sh
USE_PROFILE_LOG == "true"
export

prepareEnvironment

local CMD=$1
TIER=${cliqrAppTierName}
export

# main entry

if [ -f ${BASE_DIR}/${TIER}/${TIER}.sh ]; then
  log "[$CMD] $TIER"
  ${BASE_DIR}/${TIER}/${TIER}.sh ${CMD}
else
  log "[$CMD] Error: ${BASE_DIR}/${TIER}/${TIER}.sh not found"
fi


)>> /var/tmp/master.log 2>&1
