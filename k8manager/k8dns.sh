# Await <Timeout> minutes for <Count> Kube nodes to come online,
# then
set -x
__NODECOUNT=$1
__TIMEOUT=${2:-$1}
__DNSFILE=${3:-/opt/remoteFiles/appPackage/k8manager/kube-dns.yaml}

for ((i=0; i<${__TIMEOUT}; i++)); do
  __COUNT=$(kubectl get nodes | grep -v NAME | wc -l)
  if [ ${__COUNT} == ${__NODECOUNT} ]; then
    kubectl create -f ${__DNSFILE}
    exit $?
  else
    sleep 60
  fi
done

# no early return means timeout
exit 99
