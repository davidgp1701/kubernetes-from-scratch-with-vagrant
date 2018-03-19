#!/bin/bash

set -euo pipefail

ACTUAL=$1
WORKERS=$2

for i in `seq 1 $WORKERS`;
do
  if [ ! $i -eq $ACTUAL ]
  then
    route add -net 10.200.$i.0/24 gw 192.168.199.2${i}
  fi
done