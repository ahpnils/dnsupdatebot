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
# Extra options for curl that can be used in the config file
curl_extra_opts=""
# initialize the record type variable with empty value so it's easier to 
# throw an error if options -4 and -6 are both absent.
record_type=""
# initialize empty config file options so it's easier to
# throw an error if they are not filled.
ip_check_service=""
key_file=""
dns_server=""
zone=""
fqdn=""
ttl=""

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
  You must choose one between -4 and -6.
"
  exit 1
}

# Checks presence of mandatory software
check_binaries() {
  for binary in "$@"; do
    type "$binary" > /dev/null 2>&1 || die "$binary : binary missing"
  done
}

# More sanity checks
sanity_checks() {
  if [ -r "${conf_file}" ]; then
    # shellcheck source=dnsupdatebotrc.example
    source "${conf_file}"
  else
    die "CRITICAL : config file not found. Ensure ${conf_file} exist and is readable."
  fi

  if [ -z "${record_type}" ]; then
    die "CRITICAL : you have to use option -4 or -6."
  fi

  if ! [ -r "${key_file}" ]; then
    die "CRITICAL : TSIG key file not found. Ensure ${key_file} exist and is readable."
  fi

  for config_opt in ip_check_service dns_server zone fqdn ttl; do
    if [ -z "${!config_opt}" ]; then
      die "${config_opt} : unconfigured option. Please add it to ${conf_file} ."
    fi
  done
}

get_current_ip() {
  # We actually want word-splitting for the first two variables...
  # shellcheck disable=SC2086
  curl ${curl_opts} ${curl_extra_opts} "${ip_check_service}" || die "Cannot get current IP address. Check the remote service URL or the network connection."
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

  cat > "${query_file}" << EOF
server ${dns_server}
zone ${zone}.
update delete ${fqdn}.
update add ${fqdn}. ${ttl} ${record_type} ${current_ip}
show
send
EOF

  nsupdate -k "${key_file}" -v "${query_file}" || die "DNS record update failed."
  rm -f "${query_file}"
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

sanity_checks
current_ip=$(get_current_ip)
update_record

# vim:ts=8:sw=2:expandtab
