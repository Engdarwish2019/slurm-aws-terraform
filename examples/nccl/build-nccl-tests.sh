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

if ! command -v module >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . /etc/profile.d/modules.sh
fi
module load mpi/openmpi-x86_64

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL "https://github.com/NVIDIA/nccl-tests/archive/refs/tags/$VERSION.tar.gz" -o "$work/src.tar.gz"
echo "$SHA256  $work/src.tar.gz" | sha256sum --check --quiet
tar -xzf "$work/src.tar.gz" -C "$work"

# NVCC_GENCODE limits the GPU architectures compiled for (faster builds), for example
# NVCC_GENCODE="-gencode=arch=compute_86,code=sm_86" for the A10G in g5 instances.
make -C "$work/nccl-tests-${VERSION#v}" -j "$(nproc)" \
  MPI=1 MPI_HOME="$MPI_HOME" CUDA_HOME="$CUDA_HOME" NCCL_HOME="$NCCL_HOME" \
  ${NVCC_GENCODE:+NVCC_GENCODE="$NVCC_GENCODE"}

mkdir -p "$PREFIX"
cp "$work/nccl-tests-${VERSION#v}"/build/*_perf "$PREFIX/"
echo "nccl-tests $VERSION installed in $PREFIX"
