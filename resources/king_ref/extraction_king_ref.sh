#!/bin/bash

# Get number of CPUs
cpus="${SLURM_CPUS_ON_NODE:-$(nproc)}"
echo "💻 Running with $cpus cores"


# Detect memory
if [[ -n "$SLURM_MEM_PER_CPU" ]]; then
  # Memory per CPU × number of CPUs, with 90% safety margin
  mem_MB=$(( SLURM_MEM_PER_CPU * cpus * 90 / 100 ))
elif [[ -n "$SLURM_MEM_PER_NODE" ]]; then
  # Fallback if MEM_PER_CPU is not set
  mem_MB=$(( SLURM_MEM_PER_NODE * 90 / 100 ))
else
  # Fallback to checking system memory
  read total_mem used_mem free_mem shared_mem buff_cache available_mem <<< $(free -m | awk '/Mem:/ {print $2, $3, $4, $5, $6, $7}')
  echo "Available memory (MB): $available_mem"

  # Use 90% of available memory
  mem_MB=$(( available_mem * 90 / 100 ))
fi

echo "Setting PLINK memory to: $mem_MB MB"
echo "Setting PLINK threads to: $cpus"



# ---------------------------
# Download 1000 Genomes reference (GRCh37)
# ---------------------------
wget https://www.kingrelatedness.com/ancestry/KGref.bed.xz
wget https://www.kingrelatedness.com/ancestry/KGref.fam.xz
wget https://www.kingrelatedness.com/ancestry/KGref.bim.xz

## Then command to uncompress :
unxz *.xz

for f in KGref.*; do
  base="${f%.*}"
  ext="${f##*.}"
  mv "$f" "${base}_GRCh37_intermediate.${ext}"
done

# ---------------------------
# Create unique SNP IDs for GRCh37 reference
# ---------------------------
awk -v OFS='\t' '{
  chr = $1
  sub(/^chr/, "", chr)      # Remove leading "chr" if present
  chr = "chr"chr            # Add "chr" prefix explicitly
  new_id = chr"_"$4"_"$5"_"$6
  print $2, new_id
  }' "KGref_GRCh37_intermediate.bim" > "name_to_update.tsv"

plink --bfile KGref_GRCh37_intermediate --update-name name_to_update.tsv --make-bed --out KGref_GRCh37_final --memory ${mem_MB} --threads ${cpus}

genome_version="GRCh38"

# ---------------------------
# Optional: LiftOver to GRCh38
# ---------------------------
if [[ "$genome_version" == "GRCh38" ]]; then
    echo "➡ Converting 1000 Genomes reference from GRCh37 to GRCh38..."

    awk -v OFS='\t' '{print "chr"$1, $4, $4+1, $2, $3, $5, $6}' KGref_GRCh37_final.bim > KGref_GRCh37_map.bed

    wget https://hgdownload.soe.ucsc.edu/goldenPath/hg19/liftOver/hg19ToHg38.over.chain.gz

    # Check if liftOver is available
    if ! command -v liftOver &> /dev/null; then
        echo "liftOver not found — downloading UCSC binary into ~/bin..."
        mkdir -p ~/bin
        
        # Download directly into ~/bin
        wget -q -O ~/bin/liftOver http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/liftOver
        chmod +x ~/bin/liftOver
    
        # Prepend only this binary to PATH
        export PATH="$HOME/bin:$PATH"
    fi
    
    echo "Using liftOver from: $(command -v liftOver)"

    liftOver KGref_GRCh37_map.bed hg19ToHg38.over.chain.gz KGref_GRCh38.bed KGref_unmapped.bed

    awk -v OFS='\t' '{print $1}' KGref_GRCh37_map.bed | uniq -c
    awk -v OFS='\t' '{print $1, $4, $5, $2, $6, $7}' KGref_GRCh38.bed > KGref_GRCh38.bim
    awk -F'\t' '$1 ~ /^chr([0-9]+|X|Y|M)$/' KGref_GRCh38.bim  > KGref_GRCh38_filtered.bim


    #### Process reference genome (hg38)
    # Prepare chromosome and position mappings and SNP selections from hg38.
    cat KGref_GRCh38_filtered.bim | awk -v OFS='\t' '{print $2, $1}' > KGref_GRCh38_SNP_Chr_map.tsv
    cat KGref_GRCh38_filtered.bim | awk -v OFS='\t' '{print $2, $4}' > KGref_GRCh38_SNP_pos_map.tsv
    awk -v OFS='\t' '{print $2}' KGref_GRCh38_filtered.bim > KGref_GRCh38_SNP_selection.txt

    # Extract SNPs matching hg38 reference.
    plink --bfile KGref_GRCh37_final --extract KGref_GRCh38_SNP_selection.txt --make-bed --out KGref_GRCh38_filter --memory ${mem_MB} --threads ${cpus}

    # Update positions for hg38 SNPs.
    plink --bfile KGref_GRCh38_filter --update-map KGref_GRCh38_SNP_pos_map.tsv --make-bed --out KGref_GRCh38_filter_update_position --memory ${mem_MB} --threads ${cpus}

    # Update chromosomes for hg38 SNPs.
    plink --bfile KGref_GRCh38_filter_update_position --update-chr KGref_GRCh38_SNP_Chr_map.tsv --make-bed --out KGref_GRCh38_update_chr --memory ${mem_MB} --threads ${cpus}


    # Update name for hg38 SNPs.
    awk -v OFS='\t' '{
      chr = $1
      sub(/^chr/, "", chr)        # Remove leading "chr" if present
      chr = "chr"chr            # Add "chr" prefix explicitly
      new_id = chr"_"$4"_"$5"_"$6
      print $2, new_id
      }' "KGref_GRCh38_update_chr.bim" > "name_to_update.tsv"

    plink --bfile KGref_GRCh38_filter_update_position --update-name name_to_update.tsv --make-bed --out KGref_GRCh38_final --memory ${mem_MB} --threads ${cpus}
fi

rm *_intermediate* *_filter* *_update* hg19ToHg38.over.chain.gz KGref_unmapped.bed KGref_GRCh37_map.bed KGref_GRCh38_SNP_Chr_map.tsv KGref_GRCh38_SNP_pos_map.tsv KGref_GRCh38_SNP_selection.txt

######### TO CHECK GENOME REFERENCE

## Genome check reference nucleotides
# wget https://hgdownload.soe.ucsc.edu/goldenpath/hg38/bigZips/hg38.fa.gz
# wget https://hgdownload.soe.ucsc.edu/goldenpath/hg19/bigZips/hg19.fa.gz
# gunzip hg38.fa.gz
# gunzip hg19.fa.gz

# # King on verion GRCh38
# awk -v OFS='\t' '{print $1":"$4"-"$4}' KGref_GRCh38.bim > coord_hg38

# module load samtools
# samtools faidx hg38.fa -r coord_hg38 | grep -v ">" | tr '[:lower:]' '[:upper:]' > ref.txt

# paste <(cut -f5-6 KGref_GRCh38.bim) ref.txt | awk '$3 != $1 && $3 != $2' | wc -l


# # King on verion GRCh37
# awk -v OFS='\t' '{print $1":"$4"-"$4}' KGref.bim > coord_hg37
# sed -i 's/^/chr/' coord_hg37

# module load samtools
# samtools faidx hg19.fa -r coord_hg37 | grep -v ">" | tr '[:lower:]' '[:upper:]' > ref.txt

# paste <(cut -f5-6 KGref.bim) ref.txt | awk '$3 != $1 && $3 != $2' | wc -l

