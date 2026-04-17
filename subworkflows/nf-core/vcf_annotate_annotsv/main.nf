include { UNTAR as UNTAR_ANNOTSV } from '../../../modules/nf-core/untar/main'
include { UNTAR as UNTAR_VCF2CIRCOS } from '../../../modules/nf-core/untar/main'
include { ANNOTSV_INSTALLANNOTATIONS      } from '../../../modules/nf-core/annotsv/installannotations/main'
include { ANNOTSV_ANNOTSV     } from '../../../modules/nf-core/annotsv/annotsv/main'
include { KNOTANNOTSV     } from '../../../modules/nf-core/knotannotsv/main'
include { VCF2CIRCOS     } from '../../../modules/nf-core/vcf2circos/main'

workflow VCF_ANNOTATE_ANNOTSV {

    take:
    ch_vcf // channel: [ val(meta), [ vcf, vcf_index, candidate_small_variants, knot_output_xl, vcf2circos_extension ]
    annotsv_annotations
    vcf2circos_options
    ch_annotsv_candidate_genes
    ch_annotsv_false_positive_snv
    ch_annotsv_gene_transcripts

    main:
    if(!annotsv_annotations) {
        ANNOTSV_INSTALLANNOTATIONS()
        ANNOTSV_INSTALLANNOTATIONS.out.annotations
            .map { annotations -> [ [id:"annotsv"], annotations ] }
            .collect()
            .set { ch_annotsv_annotations }
    } else {
        if(annotsv_annotations.endsWith(".tar.gz")) {
            UNTAR_ANNOTSV(annotsv_annotations)
            UNTAR_ANNOTSV.out.untar
                .collect()
                .set { ch_annotsv_annotations }
        } else {
            channel.fromPath(annotsv_annotations)
                .map { annotations -> [ [id:"annotsv"], annotations ] }
                .collect()
                .set { ch_annotsv_annotations }
        }
    }


    // Run annotSV
    ch_vcf
        .map { meta, vcf, vcf_index, candidate_small_variants, _knot_output_xl, _vcf2circos_extension -> [ meta, vcf, vcf_index, candidate_small_variants] }
        .set { ch_annotsv_in }
    ANNOTSV_ANNOTSV (
        ch_annotsv_in,
        ch_annotsv_annotations,
        ch_annotsv_candidate_genes,
        ch_annotsv_false_positive_snv,
        ch_annotsv_gene_transcripts,
    )

    // Run knotAnnotSV
    ch_vcf
        .map { meta, _vcf, _vcf_index, _candidate_small_variants, knot_output_xl, _vcf2circos_extension -> [ meta, knot_output_xl] }
        .set { ch_knot_output_xl }
    ANNOTSV_ANNOTSV.out.tsv
        .join(ch_knot_output_xl)
        .set { ch_knot_in }
    KNOTANNOTSV ( ch_knot_in )

    // Run vcf2circos if 'options.json' provided
    if(vcf2circos_options) {
        if(vcf2circos_options.endsWith(".tar.gz")) {
            UNTAR_VCF2CIRCOS(vcf2circos_options)
            UNTAR_VCF2CIRCOS.out.untar
                .collect()
                .set { ch_vcf2circos_options }
        } else {
            channel.fromPath(vcf2circos_options)
                .map { annotations -> [ [id:"vcf2circos"], annotations ] }
                .collect()
                .set { ch_vcf2circos_options }
        }
        ch_vcf
            .map { meta, vcf, vcf_index, _candidate_small_variants, _knot_output_xl, vcf2circos_extension -> [ meta, vcf, vcf_index, vcf2circos_extension] }
            .set { ch_vcf2circos_in }
        VCF2CIRCOS(
            ch_vcf2circos_in,
            ch_vcf2circos_options,
        )
    }

    emit:
    annotsv_tsv      = ANNOTSV_ANNOTSV.out.tsv           // channel: [ val(meta), [ annotsv_tsv ] ]
    knotannotsv_out      = KNOTANNOTSV.out.out_file          // channel: [ val(meta), [ knot_out ] ]
    circos_plot      = VCF2CIRCOS.out.circos          // channel: [ val(meta), [ circos ] ]
}
