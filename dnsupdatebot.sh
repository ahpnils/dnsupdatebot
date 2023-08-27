#!/usr/bin/env bash
# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any function or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR.
set -o nounset
# Catch the error in case cmd1 fails (but cmd2 succeeds) in  `cmd1 | cmd2 `.
set -o pipefail
# Turn on traces, useful while debugging but commentend out by default
#set -o xtrace

############
# Variables
conf_file="/etc/dnsupdatebotrc"
curl_opts="-s"
ip_check_service="https://ottertelecom.com/ip"
keyfile="/etc/ddns.key"
dns_server="dnsserver.example.org"

############
# Functions

# For quitting on error
die() {
  echo "${@}" 2>&1
  echo "Quitting..." 2>&1
  exit 1
}

# Explains how the script works
usage() {
  # to be implemented later.
	:
}

# Checks presence of mandatory software
check_binaries() {
  for binary in "$@"; do
	  type "$binary" > /dev/null 2>&1 || die "$binary : binary missing"
	done
}

# Main function. Will be splitted in multiple ones later.
main() {
current_ip=$(curl ${curl_opts} ${ip_check_service})
# 80.67.169.40 is ns1.fdn.org
current_reverse=$(dig +short @80.67.169.40 -x ${current_ip})
previous_cname=$(dig +short +norecurse @dnsserver.example.org dyn-host.example.org)
#dns_server=$(dig +short -t A dnsserver.example.org)
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
}

############
# Mutex

if [ "${FLOCKER:-}" != "$0" ] ; then
  # re-launching itself with a lock
  #
  # -e - exclusive
  # -n - non-block
  # -E - --conflict-exit-code
  # "$0" - lock-file (itself)
  #
  # "$0" - programm to launch (itself)
  # "$@" - with its arguments
  LOCK_FAIL_CODE=66
  # Not an exec, as we want to check if it failed because of the lock, or for
  # an other reason
  env FLOCKER="$0" flock -en -E "$LOCK_FAIL_CODE" "$0" "$0" "$@" || ret="$?"
  if [ "${ret:-}" = "$LOCK_FAIL_CODE" ] ; then
    die "Already running."
  elif [ -z "${ret:-}" ] ; then
    exit 0
  else
    exit "${ret:-}"
  fi
fi

############
# Main

check_binaries curl dig nsupdate
main

# vim:ts=2:sw=2
