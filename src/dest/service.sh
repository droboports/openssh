#!/usr/bin/env sh
#
# OpenSSH service

# import DroboApps framework functions
. /etc/service.subr

framework_version="2.1"
name="openssh"
version="6.8"
description="SSH server"
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

# backwards compatibility
if [ -z "${FRAMEWORK_VERSION:-}" ]; then
  . "${prog_dir}/libexec/service.subr"
fi

# fixes device permisions to enable non-root logins
_fix_permissions() {
  local devices="/dev/null /dev/full /dev/random /dev/urandom /dev/tty /dev/ptmx /dev/zero /dev/crypto"
  for device in ${devices}; do
    if [ -c "${device}" ]; then
      if [ "$(stat -c %a ${device})" -ne "666" ]; then
        chmod a+rw "${device}"
      fi
    fi
  done
  if [ ! -f "/var/log/lastlog" ]; then touch "/var/log/lastlog"; fi
  if [ ! -f "/etc/login.defs" ]; then touch "/etc/login.defs"; fi
  chmod 4711 "${prog_dir}/libexec/ssh-keysign"
}

start() {
  _fix_permissions
  "${daemon}"
}

restart() {
  start-stop-daemon -K -s HUP -x "${daemon}" -p "${pidfile}" -v
}

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
STDOUT=">&3"
STDERR=">&4"
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe
set -o xtrace   # enable script tracing

main "${@}"
