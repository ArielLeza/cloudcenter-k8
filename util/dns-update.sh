#----------------------------------------------------------------
#/etc/sysconfig/network-scripts/dns-update
#----------------------------------------------------------------
#!/bin/bash
#
set -e

DNSSERVER=$(grep nameserver /etc/resolv.conf | cut -d" " -f2 )
DOMAIN=$(grep search /etc/resolv.conf | cut -d" " -f2)

HOSTNAME=$(hostname -s)
FQDN="${HOSTNAME}.${DOMAIN}"

INTERFACE=$(ls /etc/sysconfig/network-scripts/ifcfg-e* | cut -d'/' -f 5 | cut -d'/' -f2 | cut -d'-' -f2)
IPADDR=$(ip addr show ${INTERFACE} | grep inet | cut -d" " -f6 | cut -d'/' -f 1)

IP=(${IPADDR//./ })
IPREV=${IP[3]}.${IP[2]}.${IP[1]}.${IP[0]}
PTR_UPDATE_RR="update add $IPREV.in-addr.arpa 86400 PTR $FQDN."

#Must be no empty lines in nsupdate command file

cat <<EOF | nsupdate
server $DNSSERVER
prereq nxrrset $FQDN. CNAME
update delete $FQDN. A
update add $FQDN. 86400 A $IPADDR
;show
send
EOF

cat <<EOF | nsupdate
server $DNSSERVER
$PTR_UPDATE_RR
;show
send
EOF
#----------------------------------------------------------------
