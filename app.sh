### ZLIB ###
_build_zlib() {
local VERSION="1.2.8"
local FOLDER="zlib-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://zlib.net/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --prefix="${DEPS}" --libdir="${DEST}/lib"
make
make install
rm -v "${DEST}/lib"/*.a
popd
}

### OPENSSL ###
_build_openssl() {
local VERSION="1.0.2e"
local FOLDER="openssl-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://mirror.switch.ch/ftp/mirror/openssl/source/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
cp -vf "src/${FOLDER}-parallel-build.patch" "target/${FOLDER}/"
pushd "target/${FOLDER}"
patch -p1 -i "${FOLDER}-parallel-build.patch"
./Configure --prefix="${DEPS}" --openssldir="${DEST}/etc/ssl" \
  zlib-dynamic --with-zlib-include="${DEPS}/include" --with-zlib-lib="${DEPS}/lib" \
  shared threads linux-armv4 -DL_ENDIAN ${CFLAGS} ${LDFLAGS} \
  -Wa,--noexecstack -Wl,-z,noexecstack \
  no-asm
sed -i -e "s/-O3//g" Makefile
make
make install_sw
mkdir -p "${DEST}/libexec"
cp -vfa "${DEPS}/bin/openssl" "${DEST}/libexec/"
cp -vfa "${DEPS}/lib/libssl.so"* "${DEST}/lib/"
cp -vfa "${DEPS}/lib/libcrypto.so"* "${DEST}/lib/"
cp -vfaR "${DEPS}/lib/engines" "${DEST}/lib/"
cp -vfaR "${DEPS}/lib/pkgconfig" "${DEST}/lib/"
rm -vf "${DEPS}/lib/libcrypto.a" "${DEPS}/lib/libssl.a"
sed -e "s|^libdir=.*|libdir=${DEST}/lib|g" -i "${DEST}/lib/pkgconfig/libcrypto.pc"
sed -e "s|^libdir=.*|libdir=${DEST}/lib|g" -i "${DEST}/lib/pkgconfig/libssl.pc"
popd
}

### OPENSSH ###
_build_openssh() {
local VERSION="7.1p2"
local FOLDER="openssh-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://mirror.switch.ch/ftp/pub/OpenBSD/OpenSSH/portable/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
sed -i -e "s/sshd\.pid/pid.txt/" pathnames.h
./configure --host="${HOST}" --prefix="${DEST}" --disable-strip \
  --with-zlib="${DEPS}" --with-ssl-dir="${DEPS}" \
  --with-pid-dir=/tmp/DroboApps/openssh --with-privsep-path="${DEST}/var/empty" \
  --with-privsep-user=sshd \
  --with-sandbox=rlimit select_works_with_rlimit=yes \
  --without-hardening --without-stackprotect
make
make install-nokeys
mv "${DEST}/etc"/ssh_config{,.default}
mv "${DEST}/etc"/sshd_config{,.default}
popd
}

### SHADOW ###
_build_shadow() {
# version 4.2~4.2.1 does not cross-compile due to missing SUBIDS ifdefs.
local VERSION="4.1.4.3"
local FOLDER="shadow-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://pkg-shadow.alioth.debian.org/releases/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
sed -i -e "s/DIST_SUBDIRS =.*/DIST_SUBDIRS = /g" -e "/zh_CN zh_TW/d" man/Makefile.in
./configure --host="${HOST}" --prefix="${DEPS}" --disable-shadowgrp ac_cv_func_setpgrp_void=yes
make
make install
mkdir -p "${DEST}/libexec"
cp "${DEPS}/sbin/useradd" "${DEST}/libexec/"
popd
}

_build() {
  _build_zlib
  _build_openssl
  _build_openssh
  _build_shadow
  _package
}
