
# Reformat simple comma separated list of values for each
# list item to be surrounded by prepend and append values
augmentCsvList() {
  local __resultvar=$1
  local __input=$2
  local __prepend=$3
  local __append=$4
  local __output

  IFS=',' read -a addr <<< "$__input"

  count=${#addr[@]}
  index=0

  while [ "$index" -lt "$count" ]; do
    if [ "$index" -eq "0" ]; then
      __output="${__prepend}${addr[${index}]}${__append}"
    else
      __output="${__output},${__prepend}${addr[${index}]}${__append}"
    fi
    let "index++"
  done

  eval $__resultvar="'$__output'"

}

# Retrieve files from other node
retrieveFiles() {
  local __target=$1
  local __path=$2
  local __files=$3

  if [ ! -z "$__target" ]; then
    for i in ${__files} ; do
      scp -o StrictHostKeyChecking=no ${__target}:${__path}/${i} ${__path}/.
    done
  else
    log "[${TIER} ${CMD} retrieveFiles()] Error: target host undefined"
    exit 127
  fi
}

# CLUSTER_CIDRm to other nodes
pushFiles() {
  local __targets=$1
  local __path=$2
  local __files=$3

  for i in ${__files} ; do
    for j in ${__targets} ; do
      scp -o StrictHostKeyChecking=no ${__path}/${i} ${j}:${__path}/.
    done
  done
}

# Run command on other nodes
runRemoteCommand() {
  local __target=$1
  local __output=$2
  local __cmd=$3

  ssh -o StrictHostKeyChecking=no -c "${__cmd}"
}

# Approve TLS certs on remote Controller
approveTlsCerts() {
  local __target=$1
  local __nodes=$2
  local __timeout=$3

  local __count=0
  while [ ${__count} -lt ${__timeout} ]; do
    __cmdoutput=""
    runRemoteCommand ${__target} __cmdoutput 'kubectl get csr'

    echo $__cmdoutput

    let "__count++"
    sleep 60
  done

}

# Standard get for external files
downloadFile() {
  local __file="$1"

  echo "Downloading ${__file}..."
  wget --tries=3 -q $__file
}

# Calculate AWS hostname from private IP address
calcAwsHostnames() {
  local __resultvar=$1
  local __input=$2
  local __output

  for i in $(echo ${__input}|sed s/,/ /g); do
    __output=ip-$(echo ${__input} | sed 's/\./-/g')
  done

  eval $__resultvar="'$__output'"
}

# Parse CloudCenter Userenv variables
prepareEnvironment() {

  # Preprocess environment data
  if [ ! -z $CliqrTier_k8lb_IP ]; then
    local __K8_LB_IP="${CliqrTier_k8lb_IP}"
    local __K8_LB_PUBIP="${CliqrTier_k8lb_PUBLIC_IP}"
  else
    local __K8_LB_IP="${CliqrTier_k8lb_PUBLIC_IP}"
    local __K8_LB_PUBIP="${CliqrTier_k8lb_PUBLIC_IP}"
  fi
  if [ ! -z $CliqrTier_k8worker_IP ]; then
    local __K8_WKR_IP="$CliqrTier_k8worker_IP"
  else
    local __K8_WKR_IP="$CliqrTier_k8worker_PUBLIC_IP"
  fi
  if [ ! -z $CliqrTier_k8manager_IP ]; then
    local __K8_MGR_IP="$CliqrTier_k8manager_IP"
  else
    local __K8_MGR_IP="$CliqrTier_k8manager_PUBLIC_IP"
  fi
  if [ ! -z $CliqrTier_k8etcd_IP ]; then
    local __K8_ETCD_IP="$CliqrTier_k8etcd_IP"
  else
    local __K8_ETCD_IP="$CliqrTier_k8etcd_PUBLIC_IP"
  fi

  # Create IP addr and name arrays
  IFS=',' read -a wkr_ip <<< "$__K8_WKR_IP"
  IFS=',' read -a mgr_ip <<< "$__K8_MGR_IP"
  IFS=',' read -a etcd_ip <<< "$__K8_ETCD_IP"
  #IFS=',' read -a etcd_name <<< "$CliqrTier_k8etcd_HOSTNAME"

  # Calculate hostname based on IP address for AWS, otherwise use userenv variable
  if [ ${OSMOSIX_CLOUD} == 'amazon' ]; then
    # Calc etcd names
    for ((i=0; i<${#etcd_ip[*]}; i++)); do
      local __AWSNAME="ip-$(echo ${etcd_ip[i]} | sed 's/\./-/g')"
      etcd_name[${i}]=${__AWSNAME}
      echo ${etcd_name[${i}]}
    done
  elif [ ! -z $CliqrTier_k8etcd_HOSTNAME ]; then
    IFS=',' read -a etcd_name <<< "$CliqrTier_k8etcd_HOSTNAME"
  else
    log "[${TIER} ${CMD}] Error: CliqrTier_k8etcd_HOSTNAME undefined"
    exit 127
  fi

  # Ditto workers
  if [ ${OSMOSIX_CLOUD} == 'amazon' ]; then
    for ((i=0; i<${#wkr_ip[*]}; i++)); do
      local __AWSNAME="ip-$(echo ${wkr_ip[i]} | sed 's/\./-/g')"
      wkr_name[${i}]=${__AWSNAME}
      echo ${wkr_name[${i}]}
    done
  elif [ ! -z $CliqrTier_k8worker_HOSTNAME ]; then
    IFS=',' read -a wkr_name <<< "$CliqrTier_k8worker_HOSTNAME"
  else
    log "[${TIER} ${CMD}] Error: CliqrTier_k8worker_HOSTNAME undefined"
    exit 127
  fi

  # Ditto managers
  if [ ${OSMOSIX_CLOUD} == 'amazon' ]; then
    for ((i=0; i<${#mgr_ip[*]}; i++)); do
      local __AWSNAME="ip-$(echo ${mgr_ip[i]} | sed 's/\./-/g')"
      mgr_name[${i}]=${__AWSNAME}
      echo ${mgr_name[${i}]}
    done
  elif [ ! -z $CliqrTier_k8manager_HOSTNAME ]; then
    IFS=',' read -a mgr_name <<< "$CliqrTier_k8manager_HOSTNAME"
  else
    log "[${TIER} ${CMD}] Error: CliqrTier_k8manager_HOSTNAME undefined"
    exit 127
  fi

  # Set final global variables with addresses
  K8_PUBLIC_ADDR=${__K8_LB_PUBIP}
  LB_ADDR=${__K8_LB_IP}
  ETCD_ADDRS=${__K8_ETCD_IP}
  MGR_ADDRS=${__K8_MGR_IP}
  WKR_ADDRS=${__K8_WKR_IP}

  SERVICE_CIDR="${ServiceClusterIpRange}"
  SERVICE_RTR="${ServiceClusterRouter}"
  CLUSTER_CIDR="${K8ClusterNET}/${K8ClusterMASK}"
  CLUSTER_NAME="${ClusterName}"

  # local __HOSTNAME=$(echo ${cliqrNodeHostname} | cut -d'.' -f1)
  # sudo echo ${__HOSTNAME} > /etc/hostname
  # sudo hostname ${__HOSTNAME}

  if [ ${OSMOSIX_CLOUD} == 'vmware' ]; then
    sudo mv ${BASE_DIR}/util/dns-update.sh /etc/sysconfig/network-scripts
    sudo /etc/sysconfig/network-scripts/dns-update.sh
  fi

  export

  if [ ! -z "$DEBUG" ]; then
    env
  fi

}

# Use agent logging facility
log() {
	if [ -n "$USE_PROFILE_LOG"  -a "$USE_PROFILE_LOG" == "true" ];then
	    echo "$*"
	fi
}

# Install software based on OS Type
#  OSSVC_CONFIG="ubuntu16"
#  OSSVC_CONFIG="CentOS"
installSoft() {
	if [ ${OSSVC_CONFIG} == "ubuntu16" ];then
	  sudo apt-get -y install "$*"
  elif [ ${OSSVC_CONFIG} == "CentOS" ]; then
    sudo yum -y install "$*"
  else
    log "[${TIER} ${CMD}] Error: OSSVC_CONFIG unsupported type - ${OSSVC_CONFIG}"
    exit 127
	fi
}
