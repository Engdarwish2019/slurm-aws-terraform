#!/bin/bash
#SBATCH --job-name=nccl-allreduce
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --time=00:15:00
#SBATCH --output=nccl-%j.out

# NCCL all-reduce bandwidth across every allocated GPU: one MPI rank per GPU, so set
# --ntasks-per-node and --gres=gpu:N to the number of GPUs per node. Build first with
# build-nccl-tests.sh. The "Avg bus bandwidth" line is the number to compare between runs.
#
# g5 instances have no EFA, so between nodes NCCL uses TCP sockets and the result shows the
# network, not NVLink. On EFA instances (p4d, p5) add the aws-ofi-nccl plugin.
set -euo pipefail

BIN="${NCCL_TESTS:-/shared/apps/nccl-tests/v2.21.1}/all_reduce_perf"

if ! command -v module >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . /etc/profile.d/modules.sh
fi
module load mpi/openmpi-x86_64

export NCCL_DEBUG=WARN
log="nccl-allreduce-$SLURM_JOB_ID.log"

# 8 bytes to 1 GiB, doubling, 1 GPU per rank, check results for correctness
mpirun -np "$SLURM_NTASKS" --map-by "ppr:${SLURM_NTASKS_PER_NODE}:node" -x NCCL_DEBUG -x LD_LIBRARY_PATH \
  "$BIN" -b 8 -e 1G -f 2 -g 1 -c 1 | tee "$log"

grep -E '^# (Out of bounds values|Avg bus bandwidth)' "$log"
grep -qE '^# Out of bounds values : 0 OK' "$log"
