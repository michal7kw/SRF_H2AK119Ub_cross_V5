#!/bin/bash
#SBATCH --job-name=ChIP_H2AK119Ub
#SBATCH --output=logs/snakemake.out
#SBATCH --error=logs/snakemake.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=120:00:00
#SBATCH --account=kubacki.michal
#SBATCH --partition=workq

# Create necessary directories
mkdir -p logs/cluster_logs

# Set working directory
cd /beegfs/scratch/ric.broccoli/kubacki.michal/SRF_H2AK119Ub_cross_V5/SRF_H2AK119Ub

# Activate conda environment
source /opt/common/tools/ric.cosr/miniconda3/bin/activate
conda activate snakemake

# Unlock snakemake working directory if necessary
snakemake --unlock

# Clean up any previous temporary directories that might be causing issues
find . -name "tmp_*" -type d -exec rm -rf {} + 2>/dev/null || true

# Run snakemake
snakemake \
    --snakefile Snakefile \
    --executor slurm \
    --jobs 100 \
    --default-resources \
        slurm_partition=workq \
        mem_mb=32000 \
        runtime=1440 \
        threads=8 \
        nodes=1 \
    --set-threads align=16 \
    --set-resources align:mem_mb=128000 \
    --jobscript slurm-jobscript.sh \
    --latency-wait 120 \
    --rerun-incomplete \
    --keep-going \
    --forcerun align \
    --notemp \
    --verbose