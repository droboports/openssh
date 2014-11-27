#!/usr/bin/env sh
#
# Sudo install script

for deffile in etc/*.default; do
  basefile="etc/$(basename ${deffile} .default)"
  if [ ! -f "${basefile}" ]; then
    cp "${deffile}" "${basefile}"
  fi
done

bin/ssh-keygen -A
