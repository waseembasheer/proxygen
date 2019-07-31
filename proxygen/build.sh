#!/usr/bin/env bash
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved

## Run this script to build proxygen and run the tests. If you want to
## install proxygen to use in another C++ project on this machine, run
## the sibling file `reinstall.sh`.

# Useful constants
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_OFF="\033[0m"

function detect_platform() {
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     PLATFORM=Linux;;
      Darwin*)    PLATFORM=Mac;;
      *)          PLATFORM="UNKNOWN:${unameOut}"
  esac
  echo -e "${COLOR_GREEN}Detected platform: $PLATFORM ${COLOR_OFF}"
}

function install_dependencies_linux() {
  sudo apt-get install -yq \
    git \
    cmake \
    g++ \
    flex \
    bison \
    libgflags-dev \
    libgoogle-glog-dev \
    libkrb5-dev \
    libsasl2-dev \
    libnuma-dev \
    pkg-config \
    libssl-dev \
    libcap-dev \
    gperf \
    libevent-dev \
    libtool \
    libboost-all-dev \
    libjemalloc-dev \
    libsnappy-dev \
    wget \
    unzip \
    libiberty-dev \
    liblz4-dev \
    liblzma-dev \
    make \
    zlib1g-dev \
    binutils-dev \
    libsodium-dev \
    libzstd-dev \
    libdouble-conversion-dev
}

function install_dependencies_mac() {
  # install the default dependencies from homebrew
  brew install               \
    cmake                    \
    boost                    \
    double-conversion        \
    gflags                   \
    glog                     \
    libevent                 \
    lz4                      \
    snappy                   \
    xz                       \
    openssl                  \
    libsodium                \
    zstd

  brew link                 \
    cmake                   \
    boost                   \
    double-conversion       \
    gflags                  \
    glog                    \
    libevent                \
    lz4                     \
    snappy                  \
    openssl                 \
    xz                      \
    libsodium               \
    zstd
}

function install_dependencies() {
  echo -e "${COLOR_GREEN}[ INFO ] install dependencies ${COLOR_OFF}"
  if [ "$PLATFORM" = "Linux" ]; then
    install_dependencies_linux
  elif [ "$PLATFORM" = "Mac" ]; then
    install_dependencies_mac
  else
    echo -e "${COLOR_RED}[ ERROR ] Unknown platform: $PLATFORM ${COLOR_OFF}"
    exit 1
  fi
}

function setup_mvfst() {
  MVFST_DIR=$DEPS_DIR/mvfst
  MVFST_BUILD_DIR=$DEPS_DIR/mvfst/build/
  if [ ! -d "$MVFST_DIR" ] ; then
    echo -e "${COLOR_GREEN}[ INFO ] Cloning mvfst repo ${COLOR_OFF}"
    git clone https://github.com/facebookincubator/mvfst "$MVFST_DIR"
  fi
  cd "$MVFST_DIR"
  git fetch
  MVFST_REV=$(sed 's/Subproject commit //' "$START_DIR"/../build/deps/github_hashes/facebookincubator/mvfst-rev.txt)
  git checkout "$MVFST_REV"
  echo -e "${COLOR_GREEN}Building Mvfst ${COLOR_OFF}"
  mkdir -p "$MVFST_BUILD_DIR"
  cd "$MVFST_BUILD_DIR" || exit
  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR"             \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"          \
    "$MVFST_DIR"
  make -j "$JOBS"
  make install
  echo -e "${COLOR_GREEN}Mvfst is installed ${COLOR_OFF}"
  cd "$BWD" || exit
}

detect_platform
install_dependencies

# Parse args
JOBS=8
WITH_QUIC=false
USAGE="./deps.sh [-j num_jobs] [-q|--with-quic] [-m|--no-jemalloc]"
while [ "$1" != "" ]; do
  case $1 in
    -j | --jobs ) shift
                  JOBS=$1
                  ;;
    -q | --with-quic )
                  WITH_QUIC=true
                  ;;
    -m | --no-jemalloc )
                  NO_JEMALLOC=true
                  ;;
    * )           echo $USAGE
                  exit 1
esac
shift
done


BUILD_DIR=_build
mkdir -p $BUILD_DIR

set -e nounset
START_DIR=$(pwd)
trap 'cd $START_DIR' EXIT
cd $BUILD_DIR || exit
BWD=$(pwd)
DEPS_DIR=$BWD/deps
mkdir -p "$DEPS_DIR"

# Must execute from the directory containing this script
cd "$(dirname "$0")"

MAYBE_BUILD_QUIC=""
if [ "$WITH_QUIC" == true ] ; then
  setup_mvfst
  MAYBE_BUILD_QUIC="-DBUILD_QUIC=On"
fi

# Build proxygen with cmake
cd "$BWD" || exit
cmake                                     \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo       \
  -DCMAKE_PREFIX_PATH="$DEPS_DIR"         \
  -DCMAKE_INSTALL_PREFIX="$BWD"           \
  $MAYBE_BUILD_QUIC                       \
  -DBUILD_TESTS=Off                       \
  ../..

make -j "$JOBS"
echo -e "${COLOR_GREEN}Proxygen build is complete. To run unit test: \
  cd _build/ && make test ${COLOR_OFF}"
