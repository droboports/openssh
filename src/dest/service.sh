#!/usr/bin/env sh
#
# OpenSSH service

# import DroboApps framework functions
. /etc/service.subr

framework_version="2.1"
name="openssh"
version="7.1p2"
description="OpenSSH is a suite of security-related network-level utilities based on the Secure Shell protocol."
depends=""
webui=""

prog_dir="$(dirname "$(realpath "${0}")")"
daemon="${prog_dir}/sbin/sshd"
homedir="${prog_dir}/var/empty"
tmp_dir="/tmp/DroboApps/${name}"
pidfile="${tmp_dir}/pid.txt"
logfile="${tmp_dir}/log.txt"
statusfile="${tmp_dir}/status.txt"
errorfile="${tmp_dir}/error.txt"

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
}

# create user/group sshd, if missing
_create_user() {
  if [[ ! -f /etc/login.defs ]]; then touch /etc/login.defs; fi
  if ! id -u sshd; then "${prog_dir}/libexec/useradd" -r -M -d "${homedir}" -s /bin/false -g 99 -u 103 sshd; fi
}

# _is_running
# returns: 0 if app is running, 1 if not running or pidfile does not exist.
_is_running() {
  /sbin/start-stop-daemon -K -t -x "${daemon}" -p "${pidfile}" -q
}

# _is_stopped
# returns: 0 if stopped, 1 if running.
_is_stopped() {
  if _is_running; then
    return 1;
  fi
}

start() {
  _fix_permissions
  _create_user
  "${prog_dir}/bin/ssh-keygen" -A
  chmod 4711 "${prog_dir}/libexec/ssh-keysign"
  "${daemon}"
}

_service_start() {
  # /etc/service.subr uses DROBOAPPS without setting it first
  DROBOAPPS=""
  start_service
}

_service_stop() {
  start-stop-daemon -K -x "${daemon}" -p "${pidfile}" -v || echo "${name} is not running" >&3
}

_service_restart() {
  start-stop-daemon -K -s HUP -x "${daemon}" -p "${pidfile}" -v
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|restart|status]" >&3
  set +e
  exit 1
}

# boilerplate
if ! grep -q ^tmpfs /proc/mounts; then mount -t tmpfs tmpfs /tmp; fi
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
STDOUT=">&3"
STDERR=">&4"
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

case "${1:-}" in
  start|stop|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
