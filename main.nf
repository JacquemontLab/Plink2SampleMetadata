#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.plink_file     = "${params.plink_file ?: ''}"
params.king_ref       = "${params.king_ref   ?: ''}"
params.genome_version = "${params.genome_version ?: 'GRCh38'}" // default to GRCh38


// ----------------------------------------------------------------------
// Process: infer_sex_callrate
// Purpose: Calculate sex call rate per sample using PLINK binary files.
// Input: PLINK dataset prefix and associated files (.bed, .bim, .fam).
// Output: TSV file with sex call rate per individual, emitted as 'sex' channel.
// ----------------------------------------------------------------------
process infer_sex_callrate {

    input:
    tuple val(plink_prefix), path(plink_files)                 // Path to the PLINK binary dataset (prefix of .bed/.bim/.fam files)

    output:
    path "sex_callrate.tsv", emit: sex  // Output file emitted as channel 'sex'

    script:
    """
    plink_sex_callrate.sh ${plink_prefix} sex_callrate.tsv
    """
}


// ----------------------------------------------------------------------
// Process: infer_trio
// Purpose: Infer family trios from PLINK dataset using KING software.
// Input: PLINK dataset prefix and associated files.
// Output: TSV file listing inferred trios, emitted as 'trio' channel.
// ----------------------------------------------------------------------
process infer_trio {

    input:
    tuple val(plink_prefix), path(plink_files)                 // Path to the PLINK binary dataset (prefix of .bed/.bim/.fam files)

    output:
    path "trio_inference.tsv", emit: trio

    script:
    """
    infer_king_trios.py ${plink_prefix} trio_inference.tsv
    """
}

// ----------------------------------------------------------------------
// Process: infer_pca
// Purpose: Perform PCA on genotype data using KING reference panel.
// Input: PLINK dataset prefix, KING reference directory, genome version.
// Output: TSV file with PCA inference results, emitted as 'pca' channel.
// ----------------------------------------------------------------------
process infer_pca {

    input:
    tuple val(plink_prefix), path(plink_files)                 // Path to the PLINK binary dataset (prefix of .bed/.bim/.fam files)
    path king_ref_directory
    val genome_version

    output:
    path "pca_inference.tsv", emit: pca

    script:
    """
    run_king_pca.sh ${plink_prefix} ${king_ref_directory} pca_inference.tsv ${genome_version}
    """
}


// ----------------------------------------------------------------------
// Process: merge_results
// Purpose: Merge outputs from sex call rate, trio inference, and PCA into
//          a single consolidated sample metadata TSV file.
// Input: sex call rate TSV, trio inference TSV, PCA inference TSV.
// Output: Merged sample metadata TSV file.
// ----------------------------------------------------------------------
process merge_results {

    input:
    path sex
    path trio
    path pca

    output:
    path "sample_metadata_from_plink.tsv"

    script:
    """
    merge_tsv.py -i ${sex} ${trio} ${pca} -o sample_metadata_from_plink.tsv -j full
    """
}


// Build a launch summary file with workflow metadata and timing
process buildSummary {
    
    input:
    val plink_file
    val genome_version
    path last_outfile

    output:
    path "launch_report.txt"

    script:
    """
        # Convert workflow start datetime to epoch seconds
        start_sec=\$(date -d "${workflow.start}" +%s)
        # Get current time in epoch seconds
        end_sec=\$(date +%s)

        # Calculate duration in seconds
        duration=\$(( end_sec - start_sec ))

       # Convert duration to hours, minutes, seconds
       hours=\$(( duration / 3600 ))
       minutes=\$(( (duration % 3600) / 60 ))
       seconds=\$(( duration % 60 ))

       cat <<EOF > launch_report.txt
       Plink2SampleMetadata run summary:
       run name: ${workflow.runName}
       version: ${workflow.manifest.version}
       configs: ${workflow.configFiles}
       workDir: ${workflow.workDir}
       input_file: ${plink_file}
       genome_version: ${genome_version}
       launch_user: ${workflow.userName}
       start_time: ${workflow.start}
       duration: \${hours}h \${minutes}m \${seconds}s

       Command:
       ${workflow.commandLine}

    
    """

    stub:
    """
    touch launch_report.txt
    """
}


workflow {
    main:
    if (!params.plink_file) {
        error "You must provide --plink_file"
    }

    if (!params.king_ref) {
        error "You must provide --king_ref (path to KING reference directory)"
    }

    // Extract the base name (prefix) without directory and extension
    plink_prefix = params.plink_file.split('/').last()  // Extract "prefix"

    // Define the input channel for PLINK dataset prefix and probe file
    plink_ch = Channel.of(
        tuple(
            plink_prefix,
                [
                    file("${params.plink_file}.bed"),
                    file("${params.plink_file}.bim"),
                    file("${params.plink_file}.fam")
                ]
            )
        )

    Channel
        .fromPath(params.king_ref)
        .set { king_ref_ch }

    Channel
        .value(params.genome_version)
        .set { genome_ch }

    sex_ch = infer_sex_callrate(plink_ch)
    trio_ch = infer_trio(plink_ch)
    pca_ch  = infer_pca(plink_ch, king_ref_ch, genome_ch)

    merged_ch = merge_results(sex_ch, trio_ch, pca_ch)


    buildSummary(
        params.plink_file,
        params.genome_version,
        pca_ch
    )


    publish:
    merged_file = merged_ch
    report_summary = buildSummary.out
}

output {
    merged_file {
        mode 'copy'
    }
    report_summary {
        mode 'copy'
    }
}
