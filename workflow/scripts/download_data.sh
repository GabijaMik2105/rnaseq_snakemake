#!/usr/bin/env bash
#SBATCH --job-name=download
#SBATCH --partition=main
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=06:00:00
#SBATCH --output=logs/download_%j.out
#
# Naudojimas: sbatch workflow/scripts/download_data.sh [samples.tsv] [isvesties_aplankas]
# Numatytieji: config/samples.tsv  data/raw
# Lentelė (tab-separated, su antraštės eilute): 1 stulpelis = mėginio vardas, 2 stulpelis = SRR.
set -uo pipefail

SAMPLES="${1:-config/samples.tsv}"
OUTDIR="${2:-data/raw}"
mkdir -p "$OUTDIR"
FAILED=0

while IFS=$'\t' read -r sample srr; do
    echo "== $sample ($srr)"
    if [[ -s "$OUTDIR/${sample}_R1.fastq.gz" && -s "$OUTDIR/${sample}_R2.fastq.gz" ]]; then
        echo "   jau yra, praleidziu"
        continue
    fi
    for n in 1 2; do
        url=$(curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${srr}&result=read_run&fields=fastq_ftp&format=tsv" \
            | tail -n +2 | cut -f2 | tr ';' '\n' | grep -E "_${n}\.fastq\.gz$" | head -n1)
        if [[ -z "$url" ]]; then echo "KLAIDA: nera nuorodos ${srr} _${n}"; FAILED=1; continue; fi
        if wget -nv -c -O "$OUTDIR/${sample}_R${n}.fastq.gz" "https://${url}"; then
            :
        else
            echo "KLAIDA: nepavyko ${srr} _${n}"; FAILED=1
        fi
    done
done < <(tail -n +2 "$SAMPLES" | cut -f1,2)

echo "Baigta, FAILED=$FAILED"
exit $FAILED
