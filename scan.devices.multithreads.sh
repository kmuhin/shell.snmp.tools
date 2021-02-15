#!/bin/bash
# Copyright (C) Konstantin Mukhin Al.
#
# Usage: command [address]

prefix=10.0.2
[[ -n $1 ]] && prefix=$1

swalk=$(which snmpwalk || echo snmpwalk)

if ! [[ -x ${swalk} ]]; then
    echo "Command '${swalk}' not found" >&2
    exit 1
fi
snmpcommunity="public"
range=$(echo {1..254})

mib_sysdescr="1.3.6.1.2.1.1.1.0"
mib_sysname="1.3.6.1.2.1.1.5.0"
numthreads=10

cfail=0
cok=0



function tableresult()
{
#8dns 8ping 8snmp 20ip switch snmpresult
    echo -en "\r\033[K" >&2
    printf "%8b%8b%8b %-20b%-40b%-40b%b\n" "$@" | grep --color -iE "(fail|$)"
}

function dnsquery()
{
    if  dnsret=$(getent hosts $1); then
#remove ip
      dnsret=${dnsret##* }
    fi
    echo ${dnsret}
#set exit code
    [[ -n ${dnsret} ]] && true || false
}

function pinger()
{
  ping -w1 -c1 $1
}

function scandevice()
{
    ipaddr=$1
    if dnsret=$(dnsquery $ipaddr); then
      dnsresult=ok
    else
      dnsresult=fail
    fi
    if pingret=$(pinger $ipaddr); then
      pingresult=ok
      ((cok++))
    else
      pingresult=fail
      ((cfail++))
    fi

    sysDescr=
    sysName=
    snmpresult=fail
    if [[ "${pingresult}" == "ok" ]]; then
      if sysName=$(snmpwalk -r1 -v2c -OvQ -c${snmpcommunity} $ipaddr ${mib_sysname} 2>/dev/null);then
        snmpresult=ok
        sysDescr=$(snmpwalk -r1 -v2c -OvQ -c${snmpcommunity} $ipaddr ${mib_sysdescr} | head -n1)
      fi
    fi
    if [[ ${dnsresult} == ok || ${pingresult} == ok ]]; then
        tableresult  "$dnsresult" "$pingresult" "$snmpresult" "$ipaddr" "${dnsret:- }" "${sysName:- }" "${sysDescr::80}"
    fi
}

tableresult "dns" "ping" "snmp" "ip" "dnsname" "sysName" "sysDescr"
for i in ${range}; do
    ipaddr=${prefix}.${i}
    echo -en "\r\033[K${ipaddr}" >&2
    scandevice ${ipaddr} &
    while (( $(jobs | wc -l) >=${numthreads} )); do
          sleep 0.1
          jobs > /dev/null
     done

done
wait

