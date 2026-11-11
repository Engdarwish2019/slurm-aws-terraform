#!/bin/bash
#SBATCH --job-name=hpl
#SBATCH --partition=compute
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=01:00:00
#SBATCH --output=hpl-%j.out

# HPL across the allocated nodes. Submit from this directory after build-hpl.sh:
#   sbatch hpl.sbatch
# Set --ntasks-per-node to the physical cores per node: one MPI rank per core, OpenBLAS
# single-threaded. The problem size is derived from the job's memory so the matrix uses
# about 70% of it, and the process grid is as square as the rank count allows.
set -euo pipefail

HPL="${HPL:-/shared/apps/hpl/2.3}"
NB="${NB:-192}"

if ! command -v module >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . /etc/profile.d/modules.sh
fi
module load mpi/openmpi-x86_64
export OPENBLAS_NUM_THREADS=1

mem_mb="${SLURM_MEM_PER_NODE:-$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)}"
n="$(awk -v m="$mem_mb" -v nodes="$SLURM_JOB_NUM_NODES" -v nb="$NB" \
  'BEGIN { n = sqrt(0.70 * m * 1048576 * nodes / 8); print int(n / nb) * nb }')"

ranks="$SLURM_NTASKS"
p="$(awk -v r="$ranks" 'BEGIN { for (p = int(sqrt(r)); p > 1; p--) if (r % p == 0) break; print p }')"
q=$((ranks / p))

run="$SLURM_SUBMIT_DIR/hpl-run-$SLURM_JOB_ID"
mkdir -p "$run"
cd "$run"
"$SLURM_SUBMIT_DIR/hpl-dat.sh" "$n" "$NB" "$p" "$q" > HPL.dat
echo "N=$n NB=$NB grid=${p}x${q} ranks=$ranks nodes=$SLURM_JOB_NUM_NODES memory/node=${mem_mb}MB"

mpirun -np "$ranks" -x OPENBLAS_NUM_THREADS "$HPL/bin/xhpl" | tee hpl.log

# The result line starts with WR: time in seconds, then Gflops. PASSED is the residual check.
grep -E '^WR' hpl.log
grep -q 'PASSED' hpl.log
