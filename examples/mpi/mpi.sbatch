#!/bin/bash
#SBATCH --job-name=hello-mpi
#SBATCH --partition=compute
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --time=00:10:00
#SBATCH --output=mpi-%j.out

# Build once on the head node (binary lives on the shared /shared file system):
#   module load mpi/openmpi-x86_64 && mpicc -O2 -o hello_mpi hello_mpi.c
module load mpi/openmpi-x86_64
mpirun ./hello_mpi
