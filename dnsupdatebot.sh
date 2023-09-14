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
# we follow HTTP 3XX redirects with curl
curl_opts="--silent --location"

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
  echo 2>&1 "Usage: $(basename "${0}") [options...]
  -h show this help.
  -c config file location (optional - defaults to /etc/dnsupdatebotrc)
  -n dry run. Does not actually update DNS record.
  -4 IPv4 only.
  -6 IPv6 only.
"
  exit 1
}

# Checks presence of mandatory software
check_binaries() {
  for binary in "$@"; do
    type "$binary" > /dev/null 2>&1 || die "$binary : binary missing"
  done
}

get_current_ip() {
  curl ${curl_opts} ${curl_extra_opts} ${ip_check_service} || die "Cannot get current IP address. Check the remote service URL or the network connection."
}

# Update the DNS record.
# Needs :
# - the current IP address
# - the zone (domain)
# - the fqdn to update
# - the DNS server IP or hostname
# - the TSIG key file

update_record() {
  query_file=$(mktemp)

  cat > ${query_file} << EOF
server ${dns_server}
zone ${zone}.
update delete ${fqdn}.
update add ${fqdn}. ${ttl} ${record_type} ${current_ip}
show
send
EOF

  nsupdate -k ${key_file} -v ${query_file} || die "DNS record update failed."
  rm -f ${query_file}
}

# Main function. Will be completed later.
main() {
  echo "Main part of the script should be here."
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

optstring=":c:hn46"
while getopts ${optstring} arg; do
  case "${arg}" in
    c)
      echo "Config file ${OPTARG} used."
      conf_file="${OPTARG}"
      ;;
    h)
      usage
      ;;
    n)
      echo "Dry run not implemented yet."
      ;;
    4)
      echo "IPv4 only not implemented yet."
      record_type="A"
      ;;
    6)
      echo "IPv6 only not implemented yet."
      record_type="AAAA"
      ;;
    :)
      die "Option -${OPTARG} requires an argument."
      ;;
    ?)
      echo "Invalid option : -${OPTARG}"
      usage
      ;;
  esac
done

if [ -r "${conf_file}" ]; then
  source "${conf_file}"
else
  die "CRITICAL : config file not found. Ensure ${conf_file} exist and is readable."
fi

#get_current_ip > /dev/null && echo "IP address successfully retrieved."
current_ip=$(get_current_ip)
echo ${current_ip}
main

# vim:ts=8:sw=2:expandtab
