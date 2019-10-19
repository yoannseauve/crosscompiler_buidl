#!/bin/bash

arch=arm
target=${arch}-linux-gnueabi
prefix=/home/user/cross

version_GCC="7.4.0"
version_binutils="2.31"
version_glibc="2.26"
kernel_location="/home/user/linux/"


nproc=$(nproc)
#nproc=1
export PATH=${prefix}/bin:$PATH

function clean {
  echo "Removing gcc-${version_GCC}"
  rm -Rf gcc-${version_GCC}
  
  echo "Removing binutils-${version_binutils}"
  rm -Rf binutils-${version_binutils}

  echo "Removing gcc_build_dir"
  rm -Rf gcc_build_dir

  echo "Removing glibc-${version_glibc}"
  rm -Rf glibc-${version_glibc}

  echo "Removing glibc_build_dir"
  rm -Rf glibc_build_dir
}

function clear {
  clean
  echo "Removing ${prefix}"
  rm -Rf ${prefix}
}

function download {
  echo "Downloading gcc-${version_GCC}"
  wget -nc ftpmirror.gnu.org/gcc/gcc-${version_GCC}/gcc-${version_GCC}.tar.gz

  echo "Downloading binutils-${version_binutils}"
  wget -nc ftpmirror.gnu.org/binutils/binutils-${version_binutils}.tar.gz
  
  echo "Downloading glibc-${version_glibc}"
  wget -nc ftpmirror.gnu.org/glibc/glibc-${version_glibc}.tar.gz
}

function extract {
  echo "extracting gcc-${version_GCC}"
  tar -k -xf gcc-${version_GCC}.tar.gz

  echo "extracting binutils-${version_binutils}"
  tar -k -xf binutils-${version_binutils}.tar.gz

  echo "extracting glibc-${version_glibc}"
  tar -k -xf glibc-${version_glibc}.tar.gz

}

function build_ginutils {
  pushd binutils-${version_binutils}
  ./configure --prefix=${prefix} --target=${target} || exit $?
  make -j${nproc}
  make install
  popd
}

function extract_kernel_headers {
  pushd ${kernel_location}
  make ARCH=${arch} INSTALL_HDR_PATH="${prefix}/${target}" headers_install || exit $?
  popd
}

function build_gcc_first {
  pushd gcc-${version_GCC}
  ./contrib/download_prerequisites
  popd

  mkdir -p gcc_build_dir
  pushd gcc_build_dir
  ./../gcc-${version_GCC}/configure --prefix=${prefix} --target=${target} --enable-languages=c,c++
  make -j${nproc} all-gcc || exit $?
  make install-gcc || exit $?
  popd
} 

function build_gcc_libgcc {
  pushd gcc_build_dir
  make -j${nproc} all-target-libgcc || exit $?
  make install-target-libgcc || exit $?
  popd
}

function build_glibc_first {
  mkdir -p glibc_build_dir
  pushd glibc_build_dir
  ./../glibc-${version_glibc}/configure --build=$MACHTYPE --host=${target} --target=${target} --prefix=${prefix}/${target} --with-headers=${prefix}/${target}/include libc_cv_forced_unwind=yes
  make install-bootstrap-headers=yes install-headers || exit $?
  make -j${nproc} csu/subdir_lib
  install csu/crt1.o csu/crti.o csu/crtn.o ${prefix}/${target}/lib
  ##
  ${target}-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o ${prefix}/${target}/lib/libc.so
  ##
  popd 
  cp -R glibc-${version_glibc}/include/gnu ${prefix}/${target}/include/
}

function build_glibc {
  pushd glibc_build_dir
  make all || exit $?
  make install || exit $?
  popd
}

if [ $# == 1 ] && [ $1 == "clean" ]
then
  clean
elif [ $# == 1 ] && [ $1 == "clear" ]
then
  clear
else

  download
  extract
  extract_kernel_headers
  build_ginutils
  build_gcc_first
  build_glibc_first
  build_gcc_libgcc
  build_glibc

fi
