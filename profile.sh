#!/bin/bash

(
set -x

source /usr/local/osmosix/etc/userenv
source /usr/local/osmosix/etc/.osmosix.sh

BASE_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

source ${BASE_DIR}/util/function.sh
USE_PROFILE_LOG == "true"

prepareEnvironment

CMD=$1
TIER=${cliqrAppTierName}
export

# main entry

if [ -f ${BASE_DIR}/${TIER}/${TIER}.sh ]; then
  log "[$CMD] $TIER"
  ${BASE_DIR}/${TIER}/${TIER}.sh ${CMD}
else
  log "[$CMD] Error: ${BASE_DIR}/${TIER}/${TIER}.sh not found"
fi

# Action selection
local CMD=$1
case $CMD in
	install)
    if [ -f ${BASE_DIR}/${TIER}/${TIER}.sh ]; then
      source ${BASE_DIR}/${TIER}/${TIER}.sh
      log "[INSTALL ${TIER}] Installing ${TIER}"
      ${BASE_DIR}/${TIER}/${TIER}.sh install
    else
      log "[INSTALL ${TIER}] Error: ${BASE_DIR}/${TIER}/${TIER}.sh not found"
      exit 127
    fi
		;;
	deploy)
		;;
	configure)
		log "[CONFIGURE ${TIER}] Configuring $cliqrAppTierName"

		;;
	start)
	 	log "[START ${TIER}] Mounting storage volumes"

		log "[START ${TIER}] Invoking pre-start user script"

		log "[START ${TIER}] Starting ${TIER}"

		log "[START ${TIER}] Invoking post-start user script"

    log "[START ${TIER}] ${TIER} successfully started."
		;;
	stop)
		log "[STOP ${TIER}] Invoking pre-stop user script"

		log "[STOP ${TIER}] Stopping $cliqrAppTierName"

		log "[STOP ${TIER}] Invoking post-stop user script"

		log "[STOP ${TIER}] $cliqrAppTierName successfully stopped."
		;;
	restart)
		log "[RESTART ${TIER}] Invoking pre-restart user script"
		;;
	reload)
		log "[RELOAD ${TIER}] Invoking pre-reload user script"
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
