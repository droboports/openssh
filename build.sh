#!/usr/bin/env bash

### bash best practices ###
# exit on error code
set -o errexit
# exit on unset variable
set -o nounset
# return error of last failed command in pipe
set -o pipefail
# expand aliases
shopt -s expand_aliases
# print trace
set -o xtrace

### logfile ###
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
logfile="logfile_${timestamp}.txt"
echo "${0} ${@}" > "${logfile}"
# save stdout to logfile
exec 1> >(tee -a "${logfile}")
# redirect errors to stdout
exec 2> >(tee -a "${logfile}" >&2)

### environment variables ###
source crosscompile.sh
export NAME="openssh"
export DEST="/mnt/DroboFS/Shares/DroboApps/${NAME}"
export DEPS="${PWD}/target/install"
export CFLAGS="${CFLAGS:-} -Os -fPIC"
export CXXFLAGS="${CXXFLAGS:-} ${CFLAGS}"
export CPPFLAGS="-I${DEPS}/include"
export LDFLAGS="${LDFLAGS:-} -Wl,-rpath,${DEST}/lib -L${DEST}/lib"
alias make="make -j8 V=1 VERBOSE=1"

# $1: file
# $2: url
# $3: folder
_download_tgz() {
  [[ ! -f "download/${1}" ]] && wget -O "download/${1}" "${2}"
  [[ -d "target/${3}" ]] && rm -v -fr "target/${3}"
  [[ ! -d "target/${3}" ]] && tar -zxvf "download/${1}" -C target
}

### ZLIB ###
_build_zlib() {
local VERSION="1.2.8"
local FOLDER="zlib-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://zlib.net/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd target/"${FOLDER}"
./configure --prefix="${DEPS}" --libdir="${DEST}/lib"
make
make install
rm -v "${DEST}/lib"/*.a
popd
}

### OPENSSL ###
_build_openssl() {
local OPENSSL_VERSION="1.0.1i"
local OPENSSL_FOLDER="openssl-${OPENSSL_VERSION}"
local OPENSSL_FILE="${OPENSSL_FOLDER}.tar.gz"
local OPENSSL_URL="http://www.openssl.org/source/${OPENSSL_FILE}"

_download_tgz "${OPENSSL_FILE}" "${OPENSSL_URL}" "${OPENSSL_FOLDER}"
pushd target/"${OPENSSL_FOLDER}"
./Configure --prefix="${DEPS}" \
  --openssldir="${DEST}/etc/ssl" \
  --with-zlib-include="${DEPS}/include" \
  --with-zlib-lib="${DEPS}/lib" \
  shared zlib-dynamic threads linux-armv4 -DL_ENDIAN ${CFLAGS} ${LDFLAGS}
sed -i -e "s/-O3//g" Makefile
make -j1
make install_sw
mkdir -p "${DEST}"/libexec
cp -avR "${DEPS}/bin/openssl" "${DEST}/libexec/"
cp -avR "${DEPS}/lib"/* "${DEST}/lib/"
rm -fvr "${DEPS}/lib"
rm -fv "${DEST}/lib"/*.a
sed -i -e "s|^exec_prefix=.*|exec_prefix=${DEST}|g" "${DEST}"/lib/pkgconfig/openssl.pc
popd
}

### OPENSSH ###
_build_openssh() {
local VERSION="6.6p1"
local FOLDER="openssh-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://mirror.switch.ch/ftp/pub/OpenBSD/OpenSSH/portable/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd target/"${FOLDER}"
sed -i -e "s/sshd\.pid/pid.txt/" pathnames.h
./configure --host=arm-none-linux-gnueabi --prefix="${DEST}" --with-zlib="${DEPS}" --disable-strip --with-ssl-dir="${DEPS}" --with-pid-dir=/tmp/DroboApps/openssh --with-sandbox=rlimit --with-privsep-path="${DEST}/var/empty" --with-privsep-user=sshd select_works_with_rlimit=yes
make
make install-nokeys
popd
}

### BUILD ###
_build() {
  _build_zlib
  _build_openssl
  _build_openssh
  _package
}

_create_tgz() {
  local appname="$(basename ${PWD})"
  local appfile="${PWD}/${appname}.tgz"

  if [[ -f "${appfile}" ]]; then
    rm -v "${appfile}"
  fi

  pushd "${DEST}"
  tar --verbose --create --numeric-owner --owner=0 --group=0 --gzip --file "${appfile}" *
  popd
}

_package() {
  mv -v "${DEST}/etc/ssh_config"{,.default} || true
  mv -v "${DEST}/etc/sshd_config"{,.default} || true

  cp -v -faR src/dest/* "${DEST}"/
  chmod -R g-w "${DEST}/var/empty"
  find "${DEST}" -name "._*" -print -delete
  _create_tgz
}

_clean() {
  rm -v -fr "${DEPS}"
  rm -v -fr "${DEST}"
  rm -v -fr target/*
}

_dist_clean() {
  _clean
  rm -v -f logfile*
  rm -v -fr download/*
}

case "${1:-}" in
  clean)     _clean ;;
  distclean) _dist_clean ;;
  package)   _package ;;
  "")        _build ;;
  *)         _build_${1} ;;
esac
