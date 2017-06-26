#!/bin/bash

export CliqrTier_Etcd_IP="198.18.1.18,198.18.1.19,198.18.1.22"

createJsonIpLists() {
  local __resultvar=$1
  local __input=$2
  local __output

  IFS=',' read -a addr <<< "$__input"

  count=${#addr[@]}
  index=0

  while [ "$index" -lt "$count" ]; do
    if [ "$index" -eq 0 ]; then
      __output=\"${addr[${index}]}\"
    else
      __output="${__output},\"${addr[${index}]}\""
    fi
    let "index++"
  done

  eval $__resultvar="'$__output'"

}

export OUTPUT=""

createJsonIpLists OUTPUT $CliqrTier_Etcd_IP
echo $OUTPUT
