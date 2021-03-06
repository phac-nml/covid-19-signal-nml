#!/bin/bash

# Cores to use
CORES=$1
# Path to Prename
BASE_SCRIPTPATH=$2
# Ncov-tools env name
NCOV_ENV=$3
# Run PDF report
PDF=$4

# Activate env
eval "$(conda shell.bash hook)"

# Default name is ncov-qc from https://github.com/jts/ncov-tools/blob/master/workflow/envs/environment.yml
# May have to switch to a container or something similar later to make it easier
conda activate $NCOV_ENV

# If we have a matching negative control, we modify the config to make sure its gotten
# If we don't find any, then no negative controls are added
if $(ls signal_results/ | grep -q -i "negative\|ntc\|water\|blank\|neg")
then
    ls -1 signal_results/ > name_list.txt
    negative_list=$(grep -i -e ntc -e negative -e water -e blank -e neg name_list.txt | cut -f 1 | sed 's/^/"/g' | sed 's/$/"/g' | tr "\n" ',' | sed 's/^/[/' | sed 's/$/]/')
    echo "negative_control_samples: ${negative_list}" >> ./ncov-tools/config.yaml
fi

# Configs gotten and set, now we need the files!
# Files are: *.consensus.fa, *_ivar_variants.tsv, and *_viral_reference.mapping.primertrimmed.sorted.bam
# File names are consistent so we can easily do this!
mkdir -p ncov-tools/files/
find ./signal_results/ -type f -name *.consensus.fasta -exec cp {} ncov-tools/files/ \;
find ./signal_results/ -type f -name *.sorted.bam* -exec cp {} ncov-tools/files/ \;
find ./signal_results/ -type f -name *.variants.norm.vcf -exec cp {} ncov-tools/files/ \;

# Rename files to give consistent structure that is easier to work with
cd ./ncov-tools/files
$BASE_SCRIPTPATH/scripts/prename "s/_viral_reference././" *.sorted.bam

# Back to ncov-tools root directory to run it
cd ../
snakemake -s workflow/Snakefile --cores 1 build_snpeff_db
snakemake -s workflow/Snakefile all --cores $CORES

if [ "$PDF" = true ]; then
    snakemake -s workflow/Snakefile all_final_report --cores 1
fi

conda deactivate
cd ..
