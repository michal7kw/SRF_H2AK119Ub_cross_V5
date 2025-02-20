#!/bin/bash
#SBATCH --job-name=6_annotation_and_enrichment
#SBATCH --account=kubacki.michal
#SBATCH --mem=64GB
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=16
#SBATCH --mail-type=ALL
#SBATCH --mail-user=kubacki.michal@hsr.it
#SBATCH --error="logs/6_annotation_and_enrichment.err"
#SBATCH --output="logs/6_annotation_and_enrichment.out"

# Documentation:
# This script performs annotation and enrichment analysis on peaks identified from
# differential binding analysis. It takes the peaks, annotates them relative to genes,
# performs GO enrichment analysis, and generates various visualizations.
#
# Input files:
# - analysis/diffbind_broad/significant_peaks.rds: GRanges object with differential peaks
# - analysis/diffbind_narrow/significant_peaks.rds (optional): Narrow peaks if analyzing both types
#
# Output files:
# In analysis/annotation_{peak_type}/:
#   figures/
#     - annotation_plots.pdf: Peak annotation visualizations (pie chart, TSS distance)
#     - go_enrichment_plots.pdf: GO term enrichment plots (dotplot, emap, cnet)
#   tables/
#     - peak_annotation.csv: Detailed peak annotations
#     - go_enrichment.csv: GO enrichment analysis results
#   peak_annotation.rds: R object with full annotation data
#
# In analysis/gene_lists_{peak_type}/:
#   - YAF_enriched_genes_{peak_type}_full.csv: All enriched genes with details
#   - YAF_enriched_genes_{peak_type}_symbols.txt: List of gene symbols only
#
# Dependencies:
# - ChIPseeker for peak annotation
# - clusterProfiler for GO enrichment
# - org.Hs.eg.db for gene ID mapping
# - TxDb.Hsapiens.UCSC.hg38.knownGene for genome annotations
# - ggupset (optional) for upset plots

set -e
set -u
set -o pipefail

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Activate conda environment
source /opt/common/tools/ric.cosr/miniconda3/bin/activate
conda activate snakemake

# Define working directory
WORKDIR="/beegfs/scratch/ric.broccoli/kubacki.michal/SRF_H2AK119Ub_cross_V5/SRF_H2AK119Ub/1_iterative_processing"
cd $WORKDIR || { log_message "ERROR: Failed to change to working directory"; exit 1; }

# Create necessary directories
log_message "Creating output directories..."
mkdir -p logs
mkdir -p analysis/annotation_broad/{figures,tables}
# mkdir -p analysis/annotation_narrow/{figures,tables}
mkdir -p analysis/gene_lists_broad
# mkdir -p analysis/gene_lists_narrow

# Check for required input files
log_message "Checking input files..."
for type in broad; do #in broad narrow
    files=(
        "analysis/diffbind_${type}/all_peaks.rds"
        "analysis/diffbind_${type}/significant_peaks.rds"
    )
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_message "ERROR: Required file not found: $file"
            exit 1
        fi
    done
done

# Run R script for annotation and enrichment analysis
log_message "Running annotation and enrichment analysis..."
Rscript scripts/6_annotation_and_enrichment.R

log_message "Annotation and enrichment analysis completed" 