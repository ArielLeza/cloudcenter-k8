
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

  for i in ${__files} ; do
    scp -o StrictHostKeyChecking=no ${__target}:${__path}/${i} ${__path}/.
  done
}

# Push files from to other nodes
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

# Parse CloudCenter Userenv variables
prepareEnvironment() {
  IFS=',' read -a wkr_ip <<< "$CliqrTier_k8worker_IP"
  IFS=',' read -a mgr_ip <<< "$CliqrTier_k8manager_IP"
  IFS=',' read -a etcd_ip <<< "$CliqrTier_k8etcd_IP"
  IFS=',' read -a nodes <<< "$CliqrTier_k8etcd_PUBLIC_IP"
  IFS=',' read -a names <<< "$CliqrTier_k8etcd_HOSTNAME"

  KUBERNETES_PUBLIC_ADDR="$CliqrTier_k8lb_PUBLIC_IP"
  KUBERNETES_MGR_ADDRS="$CliqrTier_k8manager_PUBLIC_IP"
  ETCD_ADDRS="$CliqrTier_k8etcd_PUBLIC_IP"
  SERVICE_CLUSTER_IP_RANGE="$ServiceClusterIpRange"
  SERVICE_CLUSTER_ROUTER="$ServiceClusterRouter"
  export KUBERNETES_PUBLIC_ADDR KUBERNETES_MGR_ADDRS ETCD_ADDRS SERVICE_CLUSTER_IP_RANGE SERVICE_CLUSTER_ROUTER

  IFS=',' read -a wkr_ip <<< "$CliqrTier_k8worker_IP"
  IFS=',' read -a mgr_ip <<< "$CliqrTier_k8manager_IP"
  IFS=',' read -a etcd_ip <<< "$CliqrTier_k8etcd_IP"

  __SERVICE_CIDR=${ServiceClusterIpRange}
  __CLUSTER_CIDR=${K8ClusterCIDR}

}
