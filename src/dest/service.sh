#!/usr/bin/env sh
#
# OpenSSH service

# import DroboApps framework functions
. /etc/service.subr

# DroboApp framework version
framework_version="2.0"

# app description
name="openssh"
version="6.6"
description="SSH server"

# framework-mandated variables
pidfile="/tmp/DroboApps/${name}/pid.txt"
logfile="/tmp/DroboApps/${name}/log.txt"
statusfile="/tmp/DroboApps/${name}/status.txt"
errorfile="/tmp/DroboApps/${name}/error.txt"

# app-specific variables
prog_dir="$(dirname $(realpath ${0}))"
rsakey="${prog_dir}/etc/ssh_host_rsa_key"
dsakey="${prog_dir}/etc/ssh_host_dsa_key"
ecdsakey="${prog_dir}/etc/ssh_host_ecdsa_key"
daemon="${prog_dir}/sbin/sshd"

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe

# ensure log folder exists
logfolder="$(dirname ${logfile})"
[[ ! -d "${logfolder}" ]] && mkdir -p "${logfolder}"

# redirect all output to logfile
exec 3>&1 1>> "${logfile}" 2>&1

# log current date, time, and invocation parameters
echo $(date +"%Y-%m-%d %H-%M-%S"): ${0} ${@}

# enable script tracing
set -o xtrace

_fix_permissions() {
  chmod a+rw /dev/null /dev/full /dev/random /dev/urandom /dev/tty /dev/ptmx /dev/zero /dev/crypto
  touch /var/log/lastlog
  [[ ! -f /etc/login.defs ]] && touch /etc/login.defs
  chmod 4711 "${prog_dir}/libexec/ssh-keysign"
  chmod -R go-w "${homedir}"
}

_create_user() {
  id -g sshd || addgroup -g 50 sshd
  id -u sshd || adduser -S -H -h "${homedir}" -D -s /bin/false -G sshd -u 50 sshd
}

_create_config() {
  local dst
  for src in "${prog_dir}/etc"/*.default; do
    dst="${prog_dir}/etc/$(basename ${src} .default)"
    [[ ! -f "${dst}" ]] && cp -v "${src}" "${dst}"
  done
}

_create_keys() {
  [[ ! -f "${rsakey}" ]] && "${prog_dir}/bin/ssh-keygen" -t rsa -f "${rsakey}" -N ""
  [[ ! -f "${dsakey}" ]] && "${prog_dir}/bin/ssh-keygen" -t dsa -f "${dsakey}" -N ""
  [[ ! -f "${ecdsakey}" ]] && "${prog_dir}/bin/ssh-keygen" -t ecdsa -f "${ecdsakey}" -N "" 
}

start() {
  _fix_permissions
  _create_user
  _create_config
  _create_keys
  "${daemon}"
}

_service_start() {
  # disable error code and unset variable checks
  set +e
  set +u
  # /etc/service.subr uses DROBOAPPS without setting it first
  DROBOAPPS=""
  # 
  start_service
  set -u
  set -e
}

_service_stop() {
  /sbin/start-stop-daemon -K -x "${daemon}" -p "${pidfile}" -v || echo "${name} is not running" >&3
}

_service_restart() {
  service_stop
  sleep 3
  service_start
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|restart|status]" >&3
  set +e
  exit 1
}

case "${1:-}" in
  start|stop|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
