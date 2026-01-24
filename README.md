[![Jacquemont's Lab Header](labheader.png)](https://www.jacquemont-lab.org/)

[Git Repository Plink2SampleMetadata](https://github.com/JacquemontLab/Plink2SampleMetadata)

# PLINK to Sample Metadata Workflow

## Overview

This Nextflow pipeline builds a **sample metadata table** from a PLINK binary dataset by performing:

* **Sex call rate inference** with PLINK
* **Trio inference** using KING
* **Principal Component Analysis (PCA)** using a KING reference panel
* **Merging results** into a single tab-delimited file (`sample_metadata_from_plink.tsv`)


## Requirements

Refer to the template config files and adjust them to match your infrastructure.

Required software:

* **Nextflow** – workflow engine (nextflow version 25.10.2)
* **Docker** (Apptainer or Singularity) – to run containers

You might need to pull the following containers if working **offline**:
* **docker://ghcr.io/jacquemontlab/plink2metadata:latest**



## Inputs

| Parameter          | Description                                         | Default    |
| ------------------ | --------------------------------------------------- | ---------- |
| `--plink_file`     | Path prefix of PLINK dataset (.bed/.bim/.fam)       | *Required* |
| `--king_ref`       | Path to KING reference directory                    | *Required* |
| `--genome_version` | Genome version for PCA analysis (`GRCh37`/`GRCh38`) | GRCh38     |


## Usage

### Download required KING reference files

From the root directory of the repository, run the following command to install the KING reference data
(plink and liftOver are provided by the Docker image):

```bash
docker run --rm -it \
  -v "$PWD":/project \
  -w /project \
  ghcr.io/jacquemontlab/plink2metadata:latest \
  bash INSTALL.sh
```

### Testing

The pipeline can be tested using the test profile and the images hosted on github using the container of your choice. 

```bash
container=docker # or apptainer or singularity

nextflow run main.nf -profile test,${container}
```

## Example

```bash
plink_file=tests/plink

nextflow run main.nf \
    --plink_file "$plink_file" \
    --king_ref "$PWD"/resources/king_ref \
    --genome_version GRCh38
```

## Outputs

The pipeline produces a merged metadata file:
`results/sample_metadata_from_plink.tsv`

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
ID1   0.97516     female                     -0.0101  0.0274 ... -0.0016  EUR
ID2   0.97283     male   ID3  ID7 Family2770 -0.0099  0.0272 ... -0.0017  EUR
```


## Workflow Structure

### Processes

* **`infer_sex_callrate`**
  Runs `plink_sex_callrate.sh` to estimate sex call rates per sample.

* **`infer_trio`**
  Uses `infer_king_trios.py` to infer trios from the genotype data.

* **`infer_pca`**
  Executes `run_king_pca.sh` with KING reference data for PCA analysis.

* **`merge_results`**
  Merges outputs into a single metadata file using `merge_tsv.py`.
