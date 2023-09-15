#!/usr/bin/env bash

mkdir build
cd build

# Specific setup for cross-compilation
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  # Openmpi
  export OPAL_PREFIX="$PREFIX"
fi

if [[ "$target_platform" == "osx-arm64" ]]; then
  wget https://www-user.tu-chemnitz.de/~potts/nfft/download/nfft-3.5.3.tar.gz
  tar -zxf nfft-3.5.3.tar.gz
  cd nfft-3.5.3
  rm aclocal.m4
  aclocal
  autoconf
  ./bootstrap.sh
  ./configure --prefix=$PREFIX --build=$BUILD --host=$HOST --with-fftw3-libdir=${PREFIX}/lib --with-fftw3-includedir=${PREFIX}/include --enable-all --enable-openmp
  make
  make install
  cd ..
fi

# Openmpi Specific environment setup - Cf. https://github.com/conda-forge/libnetcdf-feedstock/pull/80
export OMPI_MCA_btl=self,tcp
export OMPI_MCA_plm=isolated
export OMPI_MCA_rmaps_base_oversubscribe=yes
export OMPI_MCA_btl_vader_single_copy_mechanism=none
mpiexec="mpiexec --allow-run-as-root"

export CXXFLAGS="$CXXFLAGS -D_LIBCPP_DISABLE_AVAILABILITY"
source $PREFIX/share/triqs/triqsvars.sh

cmake ${CMAKE_ARGS} \
    -DCMAKE_CXX_COMPILER=${BUILD_PREFIX}/bin/$(basename ${CXX}) \
    -DCMAKE_C_COMPILER=${BUILD_PREFIX}/bin/$(basename ${CC}) \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_BUILD_TYPE=Release \
    ..

make -j${CPU_COUNT} VERBOSE=1

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
  CTEST_OUTPUT_ON_FAILURE=1 ctest
fi

make install
