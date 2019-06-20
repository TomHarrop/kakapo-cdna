#!/usr/bin/env python3

import os
import multiprocessing

def find_reads(read_dir):
    print(read_dir)
    read_path = os.path.join(read_dir, '{read}.fastq')
    print(read_path)
    reads = glob_wildcards(read_path).read
    print(reads)
    read_files = expand(read_path, read=reads)
    return(read_files)


pychopper = 'shub://TomHarrop/singularity-containers:pychopper_0.6.1'
minionqc = 'shub://TomHarrop/singularity-containers:minionqc_1.4.1'

flowcells = ['KK', 'KB']


rule target:
    input:
        expand('output/020_classified/{fc}/full_length.fastq',
               fc=flowcells),
        'output/030_minionqc/combinedQC/summary.yaml'


rule minionqc:
    input:
        expand('data/basecalled/{fc}/sequencing_summary.txt',
               fc=flowcells)
    output:
        'output/030_minionqc/combinedQC/summary.yaml'
    params:
        search_dir = 'data/basecalled',
        outdir = 'output/030_minionqc'
    threads:
        min(len(flowcells), multiprocessing.cpu_count())
    singularity:
        minionqc
    log:
        'output/logs/minionqc.log'
    shell:
        'MinIONQC.R '
        '--processors={threads} '
        '--input={params.search_dir} '
        '--outputdirectory={params.outdir} '
        '&> {log}'


rule pychopper:
    input:
        reads = 'output/010_combined/{fc}.fastq',
        bc = 'data/cdna_barcodes.fas'
    output:
        full = 'output/020_classified/{fc}/full_length.fastq',
        unclassified = 'output/020_classified/{fc}/unclassified.fastq',
        report = 'output/020_classified/{fc}/report.txt',
        stats = 'output/020_classified/{fc}/stats.txt',
        scores = 'output/020_classified/{fc}/scores.txt',
    log:
        'output/logs/{fc}_pychopper.log'
    singularity:
        pychopper
    shell:
        'cdna_classifier.py '
        '-b {input.bc} '
        '-r {output.report} '
        '-u {output.unclassified} '
        '-S {output.stats} '
        '-A {output.scores} '
        '{input.reads} '
        '{output.full} '
        '&> {log}'

rule combine_passed_reads:
    input:
        read_dir = 'data/basecalled/{fc}/pass'
    params:
        reads = lambda wildcards, input: find_reads(input.read_dir)
    output:
        'output/010_combined/{fc}.fastq'
    singularity:
        pychopper
    shell:
        'cat {params.reads} > {output}'

