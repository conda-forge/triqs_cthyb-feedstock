#!/usr/bin/env bash

mkdir build
cd build

# Specific setup for cross-compilation
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  # Openmpi
  export OPAL_PREFIX="$PREFIX"
fi

# Build nfft library
if [[ "$target_platform" == "osx-arm64" ]]; then
  nfft_install_dir=${BUILD_PREFIX}
  wget https://www-user.tu-chemnitz.de/~potts/nfft/download/nfft-3.5.3.tar.gz
  tar -zxf nfft-3.5.3.tar.gz
  cd nfft-3.5.3
  rm aclocal.m4
  aclocal
  autoconf
  ./bootstrap.sh
  ./configure --prefix=$nfft_install_dir \
      --build=$BUILD \
      --host=$HOST \
      --with-fftw3-libdir=${PREFIX}/lib \
      --with-fftw3-includedir=${PREFIX}/include \
      --enable-all \
      --enable-openmp \
      --disable-shared
  make
  make install
  cd ..
fi

export CXXFLAGS="$CXXFLAGS -D_LIBCPP_DISABLE_AVAILABILITY"
source $PREFIX/share/triqs/triqsvars.sh

cmake ${CMAKE_ARGS} \
    -DCMAKE_CXX_COMPILER=${BUILD_PREFIX}/bin/$(basename ${CXX}) \
    -DCMAKE_C_COMPILER=${BUILD_PREFIX}/bin/$(basename ${CC}) \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_BUILD_TYPE=Release \
    -DMeasureG2=ON \
    -DNFFT3_ROOT=${nfft_install_dir} \
    ..

make -j1 VERBOSE=1

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
  CTEST_OUTPUT_ON_FAILURE=1 ctest
fi

make install

# Set correct paths in cmake file
if [[ "$target_platform" == "osx-arm64" ]]; then
  sed "s|$BUILD_PREFIX|$PREFIX|g" ${PREFIX}/lib/cmake/triqs_cthyb/triqs_cthyb-targets.cmake > tmp_file
  cp tmp_file ${PREFIX}/lib/cmake/triqs_cthyb/triqs_cthyb-targets.cmake
fi
