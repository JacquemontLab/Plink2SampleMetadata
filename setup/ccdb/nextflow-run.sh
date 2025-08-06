

plink_path_prefix=/lustre09/project/6008022//flben/Ancestry_SPARK/iWGS1.1/merged_plink

king_ref_directory=/lustre09/project/6008022//LAB_WORKSPACE/RAW_DATA/Genetic/Reference_Data/king_ref


export NXF_OFFLINE=true

nextflow run main.nf \
    --plink_file $plink_path_prefix \
    --king_ref $king_ref_directory \
    --genome_version GRCh38 \
    -c setup/ccdb/ccdb.config \
    -with-report report.html \
    -resume
