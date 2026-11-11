#!/bin/bash
# Build NVIDIA nccl-tests (MPI enabled) into the shared file system. It needs the CUDA
# toolkit and NCCL that GPU nodes install (gpu_cuda_toolkit = true), so run it on one:
#   srun -p gpu -N 1 --gres=gpu:1 ./build-nccl-tests.sh
# The release tarball is pinned and its checksum verified before anything is compiled.
set -euo pipefail

VERSION=v2.21.1
SHA256=7c06d6e11ce0b5df4342c2c57b847d53dc3b66751992e8680702f5326ce1e495
PREFIX="${1:-/shared/apps/nccl-tests/$VERSION}"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
NCCL_HOME="${NCCL_HOME:-/usr}"

# nccl-tests' makefiles find nvcc with `which` to pick the C++ standard; without it a CUDA 13
# build fails with a misleading "libcu++ requires at least C++ 17" error.
for tool in which cmp make curl tar sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing $tool: dnf install -y which diffutils make curl tar" >&2; exit 1; }
done
[ -x "$CUDA_HOME/bin/nvcc" ] || { echo "no nvcc in $CUDA_HOME: run this on a GPU node with the CUDA toolkit" >&2; exit 1; }

if ! command -v module >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . /etc/profile.d/modules.sh
fi
module load mpi/openmpi-x86_64
# EL keeps Open MPI's headers outside $MPI_HOME (in $MPI_INCLUDE), and some nccl-tests targets
# only look in $MPI_HOME/include, so put the real directory on the compilers' search path.
export CPATH="${MPI_INCLUDE:-$MPI_HOME/include}${CPATH:+:$CPATH}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL "https://github.com/NVIDIA/nccl-tests/archive/refs/tags/$VERSION.tar.gz" -o "$work/src.tar.gz"
echo "$SHA256  $work/src.tar.gz" | sha256sum --check --quiet
tar -xzf "$work/src.tar.gz" -C "$work"

# Open MPI 4 (EL9) enables its deprecated C++ bindings whenever mpi.h is included from C++,
# which then needs libmpi_cxx at link time. Nothing here uses them (Open MPI 5 removed them),
# so skip them. CXX also feeds `nvcc -ccbin`, and nvcc accepts the -D itself.
# NVCC_GENCODE limits the GPU architectures compiled for (faster builds), for example
# NVCC_GENCODE="-gencode=arch=compute_86,code=sm_86" for the A10G in g5 instances.
make -C "$work/nccl-tests-${VERSION#v}" -j "$(nproc)" \
  MPI=1 MPI_HOME="$MPI_HOME" CUDA_HOME="$CUDA_HOME" NCCL_HOME="$NCCL_HOME" \
  CXX="${CXX:-g++} -DOMPI_SKIP_MPICXX=1" \
  ${NVCC_GENCODE:+NVCC_GENCODE="$NVCC_GENCODE"}

mkdir -p "$PREFIX"
cp "$work/nccl-tests-${VERSION#v}"/build/*_perf "$PREFIX/"
echo "nccl-tests $VERSION installed in $PREFIX"
