#!/usr/bin/env sh
#
# OpenSSH service

# import DroboApps framework functions
source /etc/service.subr

### app-specific section

# DroboApp framework version
framework_version="2.0"

# app description
name="openssh"
version="6.7"
description="SSH server"

# framework-mandated variables
pidfile="/tmp/DroboApps/${name}/pid.txt"
logfile="/tmp/DroboApps/${name}/log.txt"
statusfile="/tmp/DroboApps/${name}/status.txt"
errorfile="/tmp/DroboApps/${name}/error.txt"

# app-specific variables
prog_dir="$(dirname $(realpath ${0}))"
daemon="${prog_dir}/sbin/sshd"
homedir="${prog_dir}/var/empty"

# fixes device permisions to enable non-root logins
_fix_permissions() {
  local devices="/dev/null /dev/full /dev/random /dev/urandom /dev/tty /dev/ptmx /dev/zero /dev/crypto"
  for device in ${devices}; do
    if [[ -c "${device}" ]]; then
      if [[ "$(stat -c %a ${device})" -ne "666" ]]; then
        chmod a+rw "${device}"
      fi
    fi
  done
  if [[ ! -f /var/log/lastlog ]]; then touch /var/log/lastlog; fi
  if [[ ! -f /etc/login.defs ]]; then touch /etc/login.defs; fi
  chmod 4711 "${prog_dir}/libexec/ssh-keysign"
}

# create user/group sshd, if missing
_create_user() {
  if ! id -g sshd; then addgroup -g 103 sshd; fi
  if ! id -u sshd; then adduser -S -H -h "${homedir}" -D -s /bin/false -G sshd -u 103 sshd; fi
}

start() {
  set -u # exit on unset variable
  set -e # exit on uncaught error code
  set -x # enable script trace
  _fix_permissions
  _create_user
  "${daemon}"
}

### common section

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe

# ensure log folder exists
if ! grep -q ^tmpfs /proc/mounts; then mount -t tmpfs tmpfs /tmp; fi
logfolder="$(dirname ${logfile})"
if [[ ! -d "${logfolder}" ]]; then mkdir -p "${logfolder}"; fi

# redirect all output to logfile
exec 3>&1 1>> "${logfile}" 2>&1

# log current date, time, and invocation parameters
echo $(date +"%Y-%m-%d %H-%M-%S"): ${0} ${@}

# _is_running
# args: path to pid file
# returns: 0 if pid is running, 1 if not running or if pidfile does not exist.
_is_running() {
  /sbin/start-stop-daemon -K -s 0 -x "${daemon}" -p "${pidfile}" -q
}

_service_start() {
  if _is_running "${pidfile}"; then
    echo ${name} is already running >&3
    set +e
    return 1
  fi
  set +x # disable script trace
  set +e # disable error code check
  set +u # disable unset variable check
  start_service
}

_service_stop() {
  if ! /sbin/start-stop-daemon -K -x "${daemon}" -p "${pidfile}" -v; then echo "${name} is not running" >&3; fi
}

_service_restart() {
  _service_stop
  sleep 3
  _service_start
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|restart|status]" >&3
  set +e # disable error code check
  exit 1
}

# enable script tracing
set -o xtrace

case "${1:-}" in
  start|stop|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
