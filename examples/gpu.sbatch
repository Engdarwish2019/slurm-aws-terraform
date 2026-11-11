#!/bin/bash
#SBATCH --job-name=gpu-check
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --time=00:05:00
#SBATCH --output=gpu-%j.out

# Slurm exposes only the allocated GPU to the job (ConstrainDevices=yes).
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
