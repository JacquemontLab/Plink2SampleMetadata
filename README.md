[![Jacquemont's Lab Header](labheader.png)](https://www.jacquemont-lab.org/)

# PLINK to Sample Metadata Workflow

## Overview

This Nextflow pipeline builds a **consolidated sample metadata table** from a PLINK binary dataset by performing:

* **Sex call rate inference** with PLINK
* **Trio inference** using KING
* **Principal Component Analysis (PCA)** using a KING reference panel
* **Merging results** into a single tab-delimited file (`sample_metadata_from_plink.tsv`)

The workflow is designed for large-scale genomic data projects where accurate sample metadata is essential for downstream analyses.

---

## Inputs

* **PLINK binary dataset** (prefix of `.bed`, `.bim`, `.fam` files)
* **KING reference directory** (contains the KING reference plink files)
* **Genome version** (`GRCh37` by default; `GRCh38` supported)

---

## Outputs

The pipeline produces the following files:

* `sex_callrate.tsv`
  Per-sample sex call rate statistics.
* `trio_inference.tsv`
  Inferred family trios based on KING analysis.
* `pca_inference.tsv`
  PCA results with ancestry components using the KING reference.
* `sample_metadata_from_plink.tsv`
  Merged table of all above results.

---

## Requirements

* **Nextflow** (DSL2 enabled)
* **PLINK** (in `$PATH`)
* **KING** (in `$PATH`)
* **Python ≥3.7** (with required scripts, e.g. `infer_king_trios.py`, `merge_tsv.py`)
* SLURM or another supported workload manager for cluster execution

---

## Usage

```bash
nextflow run main.nf \
    --plink_file /path/to/data/prefix \
    --king_ref /path/to/king_reference_directory \
    --genome_version GRCh38 \
    -c setup/ccdb/ccdb.config \
    -with-report report.html
```

### Parameters

| Parameter          | Description                                         | Default    |
| ------------------ | --------------------------------------------------- | ---------- |
| `--plink_file`     | Path prefix of PLINK dataset (.bed/.bim/.fam)       | *Required* |
| `--king_ref`       | Path to KING reference directory                    | *Required* |
| `--genome_version` | Genome version for PCA analysis (`GRCh37`/`GRCh38`) | GRCh37     |

---

## Example

```bash
nextflow run main.nf \
    --plink_file /lustre09/project/6008022/flben/Ancestry_SPARK/iWGS1.1/merged_plink/sample_data \
    --king_ref /lustre09/project/6008022/LAB_WORKSPACE/RAW_DATA/Genetic/Reference_Data/king_ref \
    --genome_version GRCh38 \
    -c setup/ccdb/ccdb.config \
    -resume
```

---

## Workflow Structure

### Processes

* **`infer_sexe_callrate`**
  Runs `plink_sexe_callrate.sh` to estimate sex call rates per sample.

* **`infer_trio`**
  Uses `infer_king_trios.py` to infer trios from the genotype data.

* **`infer_pca`**
  Executes `run_king_pca.sh` with KING reference data for PCA analysis.

* **`merge_results`**
  Merges outputs into a single metadata file using `merge_tsv.py`.

---

## Merged Results File

The final merged metadata file is:
`results/merged_results.tsv`

Below is a description of each column:

| Column         | Description                                                            |
| -------------- | ---------------------------------------------------------------------- |
| **SampleID**   | Unique sample identifier from the PLINK dataset.                       |
| **Call\_Rate** | Proportion of successfully called genotypes for the sample.            |
| **Sex**        | Inferred biological sex (`male` / `female` / `unknown`) based on PLINK sex check.  |
| **FatherID**   | Sample ID of the inferred father (if available).                       |
| **MotherID**   | Sample ID of the inferred mother (if available).                       |
| **FamilyID**   | Assigned family identifier for SampleID sharing same pair ofparents.   |
| **PC1–PC10**   | Principal component values from KING-based PCA analysis.               |
| **Ancestry**   | Inferred ancestry group based on PCA projection to the KING reference. |

**Example (first lines):**

```tsv
SampleID    Call_Rate   Sex    FatherID   MotherID   FamilyID   PC1    PC2   ...   PC10   Ancestry
SP000XXXX   0.97516     female                     -0.0101  0.0274 ... -0.0016  EUR
SP000XXXY   0.97283     male   SP000XXXA  SP000XXXB Family2770 -0.0099  0.0272 ... -0.0017  EUR
```

---

## Notes

* The pipeline resumes by default (`-resume`), so reruns skip completed steps.
* The KING reference directory must be consistent with the chosen genome version.
* For HPC runs, see the example SLURM submission script (`run_plink_metadata.sh`).






