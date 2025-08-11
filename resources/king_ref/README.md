# Reference Data for Genetic Analyses

This directory contains reference datasets required for ancestry inference, kinship estimation, and genome-wide analyses.  
The files are based on the 1000 Genomes Project reference panel and processed for compatibility with PLINK.

---

## Files (for versions of the genome GRCh37 and GRCh38)

- **KGref_GRCh37_final.bed**  
  Binary PLINK genotype data file for the 1000 Genomes reference panel (GRCh37).

- **KGref_GRCh37_final.bim**  
  Variant information file (SNPs) corresponding to the `.bed` file.  
  Includes standardized SNP IDs in the format:  
  `chr<chromosome>_<position>_<ref>_<alt>`.

- **KGref_GRCh37_final.fam**  
  Sample information file containing individual IDs and family structures for the 1000 Genomes reference panel.

---

## Notes

- All `.bed`, `.bim`, and `.fam` files together form the PLINK reference panel.  
- GRCh38 files are only present if a LiftOver was performed; otherwise, only GRCh37 files are available.  
- SNP IDs are standardized to ensure uniqueness and consistency across analyses.  
- These reference datasets were generated using the script **`extraction_king_ref.sh`**.

---

Maintainer: *Florian Bénitière*  
Last Updated: *2025-07-28*

