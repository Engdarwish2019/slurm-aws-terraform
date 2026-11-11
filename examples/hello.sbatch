#!/bin/bash
#SBATCH --job-name=hello
#SBATCH --partition=compute
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --time=00:05:00
#SBATCH --output=hello-%j.out

srun hostname
