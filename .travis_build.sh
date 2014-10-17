#!/bin/bash

setup () {
sudo apt-get install -qq bison
sudo apt-get install -qq autoconf

# clang needs the updated libstdc++
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get update -qq
sudo apt-get install -qq gcc-4.8 g++-4.8

case $COMPILER in
  gcc)
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 100 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8
    sudo update-alternatives --auto gcc
    sudo update-alternatives --query gcc
    export CXX="/usr/bin/g++"
    $CXX -v
    ;;
  clang)
    sudo wget -q http://llvm.org/releases/3.5.0/clang+llvm-3.5.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
    sudo tar axvf clang+llvm-3.5.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
    export CXX="$PWD/clang+llvm-3.5.0-x86_64-linux-gnu/bin/clang++"
    $CXX -v
    ;;
esac

if [ "$BUILD" = "i386" ]; then
  sudo apt-get remove libevent-dev libevent-* libssl-dev
  sudo apt-get install g++-multilib g++-4.8-multilib
  sudo apt-get --no-install-recommends install valgrind:i386
  sudo apt-get install libevent-2.0-5:i386
  sudo apt-get install libevent-dev:i386
  sudo apt-get --no-install-recommends install libz-dev:i386
else
  sudo apt-get install valgrind
  sudo apt-get install libevent-dev libmysqlclient-dev libsqlite3-dev libpq-dev libz-dev libssl-dev libpcre3-dev
fi
}

if [ -n "$(git branch | grep coverity_scan)" ]; then
  if [ -z "$COVERITY" ]; then
    echo "Only doing coverity scan in this branch, skipping this build"
    exit 0
  fi
else
  if [ -n "$COVERITY" ]; then
    echo "Skipping coverity on this branch."
    exit 0
  fi
fi

# do setup
setup

# stop on first error down below
set -eo pipefail

# testing part
cd src
./autogen.sh
cp local_options.$CONFIG local_options

if [ -n "$GCOV" ]; then
  ./build.FluffOS $TYPE --enable-gcov=yes
else
  ./build.FluffOS $TYPE
fi

# For coverity, we don't need to actually run tests, just build
if [ -n "$COVERITY" ]; then
  if [ "$(git branch)" != "coverity_scan" ]; then
    echo "Not on branch coverity_scan, skipping"
    exit 0
  fi


  wget https://scan.coverity.com/download/linux-64 --post-data "token=DW98q3VnP4QKLy4wwLwReQ&project=fluffos%2Ffluffos" -O coverity_tool.tgz
  tar zxvf coverity_tool.tgz
  $PWD/cov-analysis-linux64-7.5.0/bin/cov-build --dir cov-int make -j 2
  tar czvf cov.tgz cov-int
  curl --form token=DW98q3VnP4QKLy4wwLwReQ \
       --form email=sunyucong@gmail.com \
       --form file=@cov.tgz \
       --form version="$(git describe --always)" \
       --form description="FluffOS Autobuild" \
       https://scan.coverity.com/builds?project=fluffos%2Ffluffos
  exit 0
fi

# Otherwise, continue
make -j 2

cd testsuite

if [ -n "$GCOV" ]; then
  # run in gcov mode and submit the result
  ../driver etc/config.test -ftest -d
  cd ..
  sudo pip install cpp-coveralls
  coveralls --exclude packages --exclude thirdparty --exclude testsuite --exclude-pattern '.*.tab.+$' --gcov /usr/bin/gcov-4.8 --gcov-options '\-lp' -r $PWD -b $PWD
else
  valgrind --malloc-fill=0x75 --free-fill=0x73 --track-origins=yes --leak-check=full ../driver etc/config.test -ftest -d
fi
