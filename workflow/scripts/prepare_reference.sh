#!/usr/bin/env bash
#SBATCH --job-name=reference
#SBATCH --partition=main
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=03:00:00
#SBATCH --output=logs/reference_%j.out
#
# Naudojimas: sbatch workflow/scripts/prepare_reference.sh [release] [isvesties_aplankas]
# Numatytieji: 50  resources/reference
set -euo pipefail

REL="${1:-50}"
OUTDIR="${2:-resources/reference}"
BASE="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_${REL}"

GENOME="GRCh38.primary_assembly.genome.fa"
GTF="gencode.v${REL}.primary_assembly.annotation.gtf"
TRANS="gencode.v${REL}.transcripts.fa"

mkdir -p "$OUTDIR"
cd "$OUTDIR"

for f in "$GENOME" "$GTF" "$TRANS"; do
    if [[ -s "$f" ]]; then
        echo "$f jau yra, praleidziu"
        continue
    fi
    echo "== $f"
    wget -nv -c -O "${f}.gz" "${BASE}/${f}.gz"
    gunzip -f "${f}.gz"
done

ls -lh
echo "Baigta"
