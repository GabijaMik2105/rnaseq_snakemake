RNA-seq preprocessing workflow (Snakemake)
==========================================

Reproducible Snakemake workflow for paired-end eukaryotic (human) RNA-seq data:
quality control, trimming, alignment-based and alignment-free quantification,
alignment quality assessment and a MultiQC report.

Example dataset: 4 human airway smooth muscle samples from GEO GSE52778
(untreated, albuterol, dexamethasone), reference GENCODE release 50 (GRCh38).


1. What the workflow does
-------------------------
Read QC            FastQC (raw reads)
Trimming           fastp
Trimmed read QC    FastQC (trimmed reads)
Alignment          HISAT2 (index built once) + samtools sort/index
Gene counts        featureCounts (paired-end, one table for all samples)
Transcript counts  kallisto (index built once)
Alignment QC       RSeQC: bam_stat, infer_experiment, read_distribution,
                   geneBody_coverage, inner_distance
Sample comparison  deepTools: multiBamSummary, plotCorrelation, plotPCA
Report             MultiQC (all logs and summary files in one HTML report)

Every tool runs in its own conda environment (workflow/envs/*.yaml). Samples are
processed in parallel using wildcards. Reference indexes are built only if they
do not exist. Logs of every program are saved in logs/.


2. Repository structure
-----------------------
config/config.yaml           paths, threads, strandedness, parameters
config/samples.tsv           sample table (sample, srr, condition, donor)
config/multiqc_config.yaml   MultiQC module settings (raw/trimmed FastQC)
workflow/Snakefile           the workflow
workflow/envs/               conda environment definitions
workflow/scripts/            download_data.sh, prepare_reference.sh
profiles/slurm/config.yaml   SLURM execution profile
README.txt                   this file

Not in Git (see .gitignore): raw data, references, indexes, BAM files,
results, logs and conda environments.


3. Requirements
---------------
Linux, conda/mamba (e.g. Miniforge), git, and a SLURM cluster (the profile can
be changed to run locally).

  conda create -n snakemake -c conda-forge -c bioconda snakemake
  conda activate snakemake
  conda install -c conda-forge -c bioconda snakemake-executor-plugin-slurm pandas

All other software is installed automatically by Snakemake from the
environment files.


4. How to run
-------------
Run all commands from the project root.

Step 1. Reference preparation (separate script, not part of Snakemake):

  sbatch workflow/scripts/prepare_reference.sh [gencode_release] [output_dir]

Defaults: release 50, output resources/reference. It downloads the GRCh38
primary assembly genome, the primary assembly GTF annotation and the
transcript FASTA from GENCODE.

Step 2. Download the sequencing data (ENA, according to the sample table):

  sbatch workflow/scripts/download_data.sh [samples.tsv] [output_dir]

Defaults: config/samples.tsv and data/raw. The script uses the first column
(sample name) and the second column (SRR accession) and saves
<sample>_R1.fastq.gz and <sample>_R2.fastq.gz.

Step 3. Dry run, then run the workflow:

  snakemake -n -s workflow/Snakefile --profile profiles/slurm
  snakemake -s workflow/Snakefile --profile profiles/slurm

Each rule is submitted as a separate SLURM job with the threads and memory
given in the Snakefile and config. The final target (rule all) produces all
results; the MultiQC report is results/multiqc/multiqc_report.html.

Important note for this cluster: the Snakemake controller process must be
started on the login node (it only submits and monitors jobs and does no
computation). Started inside a compute job it crashes (Python multiprocessing
error). To keep it running after logout:

  setsid nohup snakemake -s workflow/Snakefile --profile profiles/slurm \
      --rerun-incomplete > logs/snakemake_run.out 2>&1 < /dev/null &

Start only one Snakemake instance per directory.


5. Analysing other data without editing the Snakefile
-----------------------------------------------------
1. Prepare a sample table with a header and columns sample, srr, condition,
   donor (tab-separated). Only the "sample" column is used by the workflow.
2. Put FASTQ files in one directory named <sample>_R1.fastq.gz and
   <sample>_R2.fastq.gz (or download them with download_data.sh).
3. Change the paths in config/config.yaml, or override them:

  snakemake -s workflow/Snakefile --profile profiles/slurm \
      --config samples=config/my_samples.tsv fastq_dir=data/my_fastq outdir=results_my

Main settings in config/config.yaml:
  samples        sample table
  fastq_dir      directory with input FASTQ files
  outdir         results directory
  reference      genome, gtf and transcripts FASTA paths
  threads        threads for fastp, hisat2, featurecounts, kallisto
  strandedness   featureCounts -s value: 0 unstranded, 1 stranded,
                 2 reversely stranded (check with RSeQC infer_experiment;
                 this dataset is unstranded)
  genebody_genes number of random genes used for gene body coverage (10000)

The workflow is written for human paired-end reads. For another species, change
the reference paths.


6. Main outputs (results/)
--------------------------
fastqc_raw/, fastqc_trimmed/   FastQC reports
fastp/                         trimming reports
hisat2/                        sorted, indexed BAM files
featurecounts/counts.txt       gene count table (+ .summary)
kallisto/<sample>/             transcript abundances (abundance.tsv/.h5)
rseqc/                         RSeQC results and plots
deeptools/                     correlation heatmap and PCA
multiqc/multiqc_report.html    combined report


7. Data and references
----------------------
Data: GEO GSE52778 (BioProject PRJNA229998), Himes et al., PLoS ONE 2014;
9(6):e99625.
Reference: GENCODE release 50, GRCh38 primary assembly genome, primary
assembly GTF annotation and transcript sequences.