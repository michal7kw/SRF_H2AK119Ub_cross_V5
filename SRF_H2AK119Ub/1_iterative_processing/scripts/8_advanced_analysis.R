# Function to install and load required packages
install_and_load_packages <- function(packages) {
    for(package in packages) {
        if(!requireNamespace(package, quietly = TRUE)) {
            message(paste("Installing package:", package))
            if(package %in% c("motifmatchr", "BSgenome.Hsapiens.UCSC.hg38", "TxDb.Hsapiens.UCSC.hg38.knownGene", "JASPAR2020")) {
                if(!requireNamespace("BiocManager", quietly = TRUE)) {
                    install.packages("BiocManager")
                }
                BiocManager::install(package, quiet = TRUE)
            } else {
                install.packages(package, quiet = TRUE)
            }
        }
        library(package, character.only = TRUE)
    }
}

# List of required packages
required_packages <- c(
    "GenomicRanges",
    "ComplexHeatmap",
    "circlize",
    "ggplot2",
    "dplyr",
    "tidyr",
    "ChIPseeker",
    "TxDb.Hsapiens.UCSC.hg38.knownGene",
    "motifmatchr",
    "JASPAR2020",
    "BSgenome.Hsapiens.UCSC.hg38",
    "DiffBind"
)

# Install and load packages
suppressPackageStartupMessages({
    install_and_load_packages(required_packages)
})

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)
peak_type <- if(length(args) > 0) args[1] else "broad"

# Create output directories
base_dir <- file.path("analysis", paste0("advanced_analysis_", peak_type))
subdirs <- c("motifs", "clusters", "profiles", "plots")
sapply(file.path(base_dir, subdirs), dir.create, recursive = TRUE, showWarnings = FALSE)

# Read data
diff_peaks <- readRDS(file.path("analysis", paste0("diffbind_", peak_type), "significant_peaks.rds"))
peak_annotation <- readRDS(file.path("analysis", paste0("annotation_", peak_type), "peak_annotation.rds"))

# Ensure chromosome names are consistent
seqlevelsStyle(diff_peaks) <- "UCSC"
genome(diff_peaks) <- "hg38"

# 1. Peak Width Analysis
peak_widths <- data.frame(
    width = width(diff_peaks),
    type = ifelse(diff_peaks$Fold > 0, "YAF_enriched", "GFP_enriched")
)

pdf(file.path(base_dir, "plots", "peak_width_distribution.pdf"), width = 8, height = 6)
ggplot(peak_widths, aes(x = width, fill = type)) +
    geom_density(alpha = 0.5) +
    scale_x_log10() +
    labs(title = paste("Peak Width Distribution -", peak_type, "peaks"),
         x = "Peak Width (bp)",
         y = "Density") +
    theme_minimal()
dev.off()

# 2. Signal Intensity Correlation - Skip if no signal columns
if(any(grepl("^signal", colnames(mcols(diff_peaks))))) {
    peak_signals <- as.matrix(mcols(diff_peaks)[, grep("^signal", colnames(mcols(diff_peaks)))])
    cor_matrix <- cor(peak_signals, method = "pearson")
    
    pdf(file.path(base_dir, "plots", "signal_correlation_heatmap.pdf"), width = 8, height = 8)
    Heatmap(cor_matrix,
            name = "Correlation",
            column_title = "Sample Correlation",
            col = colorRamp2(c(0.5, 0.75, 1), c("blue", "white", "red")))
    dev.off()
}

# 3. Genomic Distribution Analysis
txdb <- TxDb.Hsapiens.UCSC.hg38.knownGene
seqlevelsStyle(txdb) <- "UCSC"

genomic_distribution <- annotatePeak(diff_peaks,
                                   TxDb = txdb,
                                   annoDb = "org.Hs.eg.db",
                                   level = "transcript")

pdf(file.path(base_dir, "plots", "genomic_distribution.pdf"), width = 10, height = 8)
plotAnnoBar(genomic_distribution)
plotDistToTSS(genomic_distribution)
dev.off()

# 4. Signal Profile Analysis
# Get TSS regions with consistent chromosome naming
genes_txdb <- genes(txdb)
seqlevelsStyle(genes_txdb) <- "UCSC"

# Keep only standard chromosomes to avoid issues with alternative contigs
standard_chroms <- paste0("chr", c(1:22, "X", "Y"))
genes_txdb <- keepSeqlevels(genes_txdb, standard_chroms, pruning.mode = "coarse")
diff_peaks <- keepSeqlevels(diff_peaks, standard_chroms, pruning.mode = "coarse")

# Create TSS regions
tss <- promoters(genes_txdb, upstream = 3000, downstream = 3000)

# Initialize coverage matrix
coverage_matrix <- matrix(0, nrow = 6000, ncol = length(tss))
tss_indices <- seq_along(tss)
names(tss_indices) <- as.character(tss)

# Calculate coverage for each chromosome separately
for(chr in seqlevels(tss)) {
    message("Processing chromosome ", chr)
    
    # Subset peaks and TSS for current chromosome
    chr_peaks <- diff_peaks[seqnames(diff_peaks) == chr]
    chr_tss <- tss[seqnames(tss) == chr]
    
    if(length(chr_tss) > 0 && length(chr_peaks) > 0) {
        # Calculate coverage for each TSS region
        for(i in seq_along(chr_tss)) {
            if(i %% 1000 == 0) message("  Processing TSS ", i, " of ", length(chr_tss))
            
            # Get current TSS region
            region <- chr_tss[i]
            current_tss_index <- tss_indices[as.character(region)]
            
            # Create bins for the region
            bins <- seq(start(region), end(region), length.out = 6001)
            bin_ranges <- GRanges(
                seqnames = seqnames(region),
                ranges = IRanges(start = bins[-length(bins)],
                               end = bins[-1])
            )
            
            # Calculate coverage
            region_coverage <- countOverlaps(bin_ranges, chr_peaks)
            coverage_matrix[, current_tss_index] <- region_coverage
        }
    }
}

# Calculate and plot average profile
avg_profile <- rowMeans(coverage_matrix)
pdf(file.path(base_dir, "plots", "tss_profile.pdf"), width = 8, height = 6)
plot(1:6000, avg_profile,
     type = "l",
     xlab = "Distance from TSS (bp)",
     ylab = "Average Coverage",
     main = "Average Signal Profile around TSS",
     xaxt = "n")
axis(1, at = c(1, 1500, 3000, 4500, 6000),
     labels = c("-3000", "-1500", "TSS", "+1500", "+3000"))
dev.off()

# 5. Motif Analysis (if peaks are narrow enough)
if(median(width(diff_peaks)) < 1000) {
    # Get JASPAR motifs
    pfm <- getMatrixSet(JASPAR2020,
                        opts = list(species = "Homo sapiens",
                                  collection = "CORE"))
    
    # Scan for motifs
    motif_ix <- matchMotifs(pfm,
                           diff_peaks,
                           genome = BSgenome.Hsapiens.UCSC.hg38)
    
    # Calculate enrichment
    motif_enrichment <- motifEnrichment(motif_ix,
                                       diff_peaks$Fold > 0)
    
    # Plot top enriched motifs
    pdf(file.path(base_dir, "plots", "motif_enrichment.pdf"), width = 8, height = 10)
    plotMotifEnrichment(motif_enrichment, top_n = 20)
    dev.off()
}

# 6. Peak Clustering Analysis
peak_signals <- assay(diff_peaks)
peak_clusters <- kmeans(peak_signals, centers = 3)

cluster_df <- data.frame(
    cluster = peak_clusters$cluster,
    fold_change = diff_peaks$Fold,
    fdr = diff_peaks$FDR
)

pdf(file.path(base_dir, "plots", "peak_clusters.pdf"), width = 8, height = 6)
ggplot(cluster_df, aes(x = fold_change, y = -log10(fdr), color = factor(cluster))) +
    geom_point(alpha = 0.6) +
    theme_minimal() +
    labs(title = "Peak Clusters",
         x = "Fold Change",
         y = "-log10(FDR)",
         color = "Cluster")
dev.off()

# Save summary statistics
write.table(
    data.frame(
        metric = c("Total Peaks",
                  "Median Peak Width",
                  "Number of Clusters",
                  "Peaks in Promoters",
                  "Peaks in Enhancers"),
        value = c(length(diff_peaks),
                 median(width(diff_peaks)),
                 3,
                 sum(genomic_distribution@annoStat$Feature == "Promoter"),
                 sum(genomic_distribution@annoStat$Feature == "Enhancer"))
    ),
    file.path(base_dir, "summary_statistics.txt"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)

print(paste("Advanced analysis completed successfully for", peak_type, "peaks")) 