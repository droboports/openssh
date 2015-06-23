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
local VERSION="1.0.2a"
local FOLDER="openssl-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://www.openssl.org/source/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
cp -vf "src/${FOLDER}-parallel-build.patch" "target/${FOLDER}/"
pushd "target/${FOLDER}"
patch -p1 -i "${FOLDER}-parallel-build.patch"
./Configure --prefix="${DEPS}" --openssldir="${DEST}/etc/ssl" \
  zlib-dynamic --with-zlib-include="${DEPS}/include" --with-zlib-lib="${DEPS}/lib" \
  shared threads linux-armv4 -DL_ENDIAN ${CFLAGS} ${LDFLAGS} -Wa,--noexecstack -Wl,-z,noexecstack
sed -i -e "s/-O3//g" Makefile
make
make install_sw
mkdir -p "${DEST}/libexec"
cp -avR "${DEPS}/bin/openssl" "${DEST}/libexec/"
cp -avR "${DEPS}/lib"/* "${DEST}/lib/"
rm -vfr "${DEPS}/lib"
rm -vf "${DEST}/lib"/*.a
sed -i -e "s|^exec_prefix=.*|exec_prefix=${DEST}|g" "${DEST}/lib/pkgconfig/openssl.pc"
popd
}

### OPENSSH ###
_build_openssh() {
local VERSION="6.8p1"
local FOLDER="openssh-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://mirror.switch.ch/ftp/pub/OpenBSD/OpenSSH/portable/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
sed -i -e "s/sshd\.pid/pid.txt/" pathnames.h
./configure --host="${HOST}" --prefix="${DEST}" --with-zlib="${DEPS}" --disable-strip --with-ssl-dir="${DEPS}" --with-pid-dir=/tmp/DroboApps/openssh --with-sandbox=rlimit --with-privsep-path="${DEST}/var/empty" --with-privsep-user=sshd select_works_with_rlimit=yes
make
make install-nokeys
mv "${DEST}/etc"/ssh_config{,.default}
mv "${DEST}/etc"/sshd_config{,.default}
popd
}

_build() {
  _build_zlib
  _build_openssl
  _build_openssh
  _package
}
