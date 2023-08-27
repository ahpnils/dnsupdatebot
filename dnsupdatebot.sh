#!/usr/bin/env bash
#set -x
curl_bin=$(which curl)
curl_opts="-s"
dig_bin=$(which dig)
nsupdate_bin=$(which nsupdate)
ip_check_service="https://ottertelecom.com/ip"
keyfile="/etc/ddns.key"
current_ip=$(${curl_bin} ${curl_opts} ${ip_check_service})
# 80.67.169.40 is ns1.fdn.org
current_reverse=$(${dig_bin} +short @80.67.169.40 -x ${current_ip})
previous_cname=$(${dig_bin} +short +norecurse @dnsserver.example.org dyn-host.example.org)
#dns_server=$(dig +short -t A dnsserver.example.org)
dns_server="dnsserver.example.org"

#if [ "${current_reverse}" eq "${previous_cname}" ]; then 
#       exit 0
#else
        cat > /tmp/majdnscloud.txt << EOF
server ${dns_server}
zone example.org.
update delete dyn-host.example.org.
update add dyn-host.example.org. 180 CNAME ${current_reverse}
show
send
EOF
        nsupdate -k ${keyfile} -v /tmp/majdnscloud.txt
        rm -f /tmp/majdnscloud.txt
#fi
