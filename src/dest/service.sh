#!/usr/bin/env sh
#
# OpenSSH service

# import DroboApps framework functions
source /etc/service.subr

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

# enable script tracing
set -o xtrace

_fix_permissions() {
  chmod a+rw /dev/null /dev/full /dev/random /dev/urandom /dev/tty /dev/ptmx /dev/zero /dev/crypto
  if [[ ! -f /var/log/lastlog ]]; then touch /var/log/lastlog; fi
  if [[ ! -f /etc/login.defs ]]; then touch /etc/login.defs; fi
  chmod 4711 "${prog_dir}/libexec/ssh-keysign"
}

_create_user() {
  if ! id -g sshd; then addgroup -g 103 sshd; fi
  if ! id -u sshd; then adduser -S -H -h "${homedir}" -D -s /bin/false -G sshd -u 103 sshd; fi
}

start() {
  _fix_permissions
  _create_user
  "${daemon}"
}

_service_start() {
  # disable error code and unset variable checks
  set +e
  set +u
  if _is_running "${pidfile}"; then
    echo ${name} is already running >&3
    return 1
  fi
  start_service
  set -u
  set -e
}

_service_stop() {
  /sbin/start-stop-daemon -K -x "${daemon}" -p "${pidfile}" -v || echo "${name} is not running" >&3
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
  set +e
  exit 1
}

case "${1:-}" in
  start|stop|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
