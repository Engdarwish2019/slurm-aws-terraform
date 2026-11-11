#!/bin/bash
# Build HPL 2.3 (the LINPACK benchmark behind the TOP500 list) against OpenBLAS and Open MPI.
# Run once on the head node; the binary lands on the shared file system for every node:
#   ./build-hpl.sh                 # installs to /shared/apps/hpl/2.3
# The source tarball is pinned and its checksum verified before anything is compiled.
set -euo pipefail

VERSION=2.3
SHA256=32c5c17d22330e6f2337b681aded51637fb6008d3f0eb7c277b163fadd612830
PREFIX="${1:-/shared/apps/hpl/$VERSION}"

if ! command -v module >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . /etc/profile.d/modules.sh
fi
module load mpi/openmpi-x86_64

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL "https://www.netlib.org/benchmark/hpl/hpl-$VERSION.tar.gz" -o "$work/hpl.tar.gz"
echo "$SHA256  $work/hpl.tar.gz" | sha256sum --check --quiet
tar -xzf "$work/hpl.tar.gz" -C "$work"

cd "$work/hpl-$VERSION"
# No -march=native: the head node may be a different CPU generation than the compute nodes.
# OpenBLAS picks the fastest kernels for each CPU at run time anyway.
./configure --prefix="$PREFIX" CC=mpicc CFLAGS="-O3"
make -j "$(nproc)"
make install
echo "HPL $VERSION installed: $PREFIX/bin/xhpl"
