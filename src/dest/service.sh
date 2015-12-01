#!/usr/bin/env sh
#
# OpenSSH service

# import DroboApps framework functions
. /etc/service.subr

framework_version="2.1"
name="openssh"
version="7.1"
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

# return 1 if $FRAMEWORK_VERSION < $framework_version
_check_framework_version() {
  local _check
  local rc
  if [ ! -x /usr/bin/semver.sh ]; then
    return 1
  fi
  _check=$(/usr/bin/semver.sh "${FRAMEWORK_VERSION:-2.0}" "${framework_version}") && rc=$? || rc=$?
  if [ -z "${_check}" ] || [ "${_check}" = "-1" ]; then
    return 1
  fi
  return 0
}

_enforce_framework_version() {
  rm "${errorfile}" "${statusfile}"
  if ! _check_framework_version; then
    echo "$name requires firmware 3.3.0 or newer." > "${statusfile}"
    echo "1" > "${errorfile}"
    return 1
  fi
  return 0
}

start() {
  _enforce_framework_version
  chmod 4711 "${prog_dir}/libexec/ssh-keysign"
  "${daemon}"
}

restart() {
  start-stop-daemon -K -s HUP -x "${daemon}" -p "${pidfile}" -v
}

# boilerplate
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
STDOUT=">&3"
STDERR=">&4"
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

main "${@}"
