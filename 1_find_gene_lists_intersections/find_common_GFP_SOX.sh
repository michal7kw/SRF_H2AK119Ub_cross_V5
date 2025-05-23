#!/bin/bash
#SBATCH --job-name=find_common_GFP_SOX
#SBATCH --account=kubacki.michal
#SBATCH --mem=64GB
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=16
#SBATCH --mail-type=ALL
#SBATCH --mail-user=kubacki.michal@hsr.it
#SBATCH --error="logs/find_common_GFP_SOX.err"
#SBATCH --output="logs/find_common_GFP_SOX.out"

# Load necessary modules (adjust as needed for your cluster)
source /opt/common/tools/ric.cosr/miniconda3/bin/activate
conda activate snakemake 

# Set working directory
cd /beegfs/scratch/ric.broccoli/kubacki.michal/SRF_H2AK119Ub_cross_V5/1_find_gene_lists_intersections

# Create logs directory if it doesn't exist
mkdir -p logs

Rscript scripts/find_common_GFP_SOX.R