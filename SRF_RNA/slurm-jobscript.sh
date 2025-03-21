#!/bin/bash
#SBATCH --parsable
#SBATCH --partition={resources.slurm_partition}
#SBATCH --cpus-per-task={threads}
#SBATCH --mem={resources.mem_mb}M
#SBATCH --time={resources.runtime}
#SBATCH --account=kubacki.michal
#SBATCH --output=logs/cluster_logs/%j.out
#SBATCH --error=logs/cluster_logs/%j.err

# Load conda environment
source /home/kubacki.michal/.bashrc
conda activate snakemake

# Execute the command
{exec_job}
