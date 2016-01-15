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

# check firmware version
_firmware_check() {
  local rc
  local semver
  rm -f "${statusfile}" "${errorfile}"
  if [ -z "${FRAMEWORK_VERSION:-}" ]; then
    echo "Unsupported Drobo firmware, please upgrade to the latest version." > "${statusfile}"
    echo "4" > "${errorfile}"
    return 1
  fi
  semver="$(/usr/bin/semver.sh "${framework_version}" "${FRAMEWORK_VERSION}")"
  if [ "${semver}" == "1" ]; then
    echo "Unsupported Drobo firmware, please upgrade to the latest version." > "${statusfile}"
    echo "4" > "${errorfile}"
    return 1
  fi
  return 0
}

start() {
  _firmware_check
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
