#!/bin/bash

# Copyright Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

packages=(
  automake
  binutils
  bison
  build-essential
  ca-certificates
  cmake
  curl
  flex
  g++
  gcc-9
  git
  libelf-dev
  libmnl-dev
  libtool
  make
  ninja-build
  pkg-config
  python3
  python3-pip
  unzip
)

packages_amd64=(
  binutils-aarch64-linux-gnu
  crossbuild-essential-arm64
  g++-aarch64-linux-gnu
  gcc-9-aarch64-linux-gnu
  libelf-dev:arm64
)

export DEBIAN_FRONTEND=noninteractive

native_arch="$(dpkg --print-architecture)"
if [ "${native_arch}" = "amd64" ] ; then
  native_main_uri="http://archive.ubuntu.com/ubuntu/"
  native_security_uri="http://security.ubuntu.com/ubuntu/"
else
  native_main_uri="http://ports.ubuntu.com/ubuntu-ports/"
  native_security_uri="http://ports.ubuntu.com/ubuntu-ports/"
fi

cat > /etc/apt/sources.list.d/ubuntu.sources << EOF
Types: deb
URIs: ${native_main_uri}
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
Architectures: ${native_arch}

## Ubuntu security updates. Aside from URIs and Suites,
## this should mirror your choices in the previous section.
Types: deb
URIs: ${native_security_uri}
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
Architectures: ${native_arch}
EOF

if [ "${native_arch}" = "amd64" ] ; then
  cat >> /etc/apt/sources.list.d/ubuntu.sources << EOF
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
Architectures: arm64

Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
Architectures: arm64
EOF
  dpkg --add-architecture arm64
fi

apt-get update

ln -fs /usr/share/zoneinfo/UTC /etc/localtime

apt-get install -y --no-install-recommends "${packages[@]}"
if [ "${native_arch}" = "amd64" ] ; then
  apt-get install -y --no-install-recommends "${packages_amd64[@]}"
fi

update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 2
if [ "${native_arch}" = "amd64" ] ; then
  update-alternatives --install /usr/bin/aarch64-linux-gnu-gcc aarch64-linux-gnu-gcc /usr/bin/aarch64-linux-gnu-gcc-9 3
fi
