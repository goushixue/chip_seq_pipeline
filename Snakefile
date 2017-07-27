import os
import yaml

from utils.file_getters import read_sample_sheet, sample_vs_group
from snakemake.shell import shell

shell.executable("bash")

from itertools import product
import pandas as pd

tss_or_tes = "(tss|tes)"

# if the config dict is empty, no config file was given on the command line
if not config:
    configfile: "config.yaml"

prefix = config["prefix"]
sample_sheet = read_sample_sheet(config["sample_sheet"])
ss = sample_sheet


leave_one_out_sample_sheet = "{prefix}/simulation_sample_sheet.txt".format(prefix=prefix)
if os.path.exists(leave_one_out_sample_sheet):
    loo_ss = pd.read_table(leave_one_out_sample_sheet, sep=" ")
    loo_groups = list(loo_ss.Group.drop_duplicates())
else:
    loo_groups = []

if config.get("external_control_sample_sheet", ""):
    ec_ss = pd.read_table(config["external_control_sample_sheet"])
    ec_groups = list(ec_ss.Group.drop_duplicates())
    ec_samples = list(ec_ss.Name.drop_duplicates())
else:
    ec_samples, ec_groups = [], []

to_include = ["download/annotation", "deeptools/bamcompare","deeptools/bigwig_compare",
              "deeptools/heatmap", "deeptools/profileplot",
              "deeptools/computematrix", "deeptools/bamcoverage",
              "deeptools/bigwig", "merge_lanes/merge_lanes",
              "compute_tss/compute_tss", "trim/atropos", "align/hisat2",
              "sort_index_bam/sort_index_bam", "bamtobed/bamtobed",
              "chip_seq/epic", "chip_seq/macs2", "epic/epic_merge",
              "epic/epic_cluster", "leave_one_out/bam_sample_sheet"]


path_prefix = config["prefix"]
chip_samples = list(ss[ss.ChIP == "ChIP"].Name.drop_duplicates())
input_samples = list(ss[ss.ChIP == "Input"].Name.drop_duplicates())
groups = list(sample_sheet.Group.drop_duplicates())
first_group = groups[0]
all_but_first_group = groups[1:]
second_group = None
if all_but_first_group:
    second_group = groups[1]


regions = ["CDS", "exon", "five_prime_UTR", "gene", "start_codon",
           "stop_codon", "stop_codon_redefined_as_selenocysteine", "three_prime_UTR",
           "transcript", "internal_exon"]

regular_regions = config["region_types"] if config["region_types"] else []

custom_regions = list(config["region_files"]) if config["region_files"] else []
all_regions = regular_regions + custom_regions


wildcard_constraints:
    sample = "({})".format("|".join(chip_samples + input_samples + ec_samples)),
    group = "({})".format("|".join(groups + loo_groups + ec_groups)),
    chip = "(chip|input|log2ratio|ChIP|Input)",
    region_type = "({})".format("|".join(regions + custom_regions))


for rule in to_include:
    include: "rules/{rule}.rules".format(rule=rule)

rule log2_ratio_heatmaps:
    input:
        expand("{prefix}/data/heatmap/{region_type}/{chip}/scale_regions/{group}_{region_type}.png",
                group=groups, region_type=all_regions, chip="log2ratio", prefix=prefix),

rule peaks:
    input:
        expand("{prefix}/data/peaks/{cs_caller}/{group}.csv", group=list(set(sample_sheet.Group)),
               cs_caller=config["cs_callers"], prefix=prefix)


rule input_profileplots:
    input:
        expand("{prefix}/data/profileplot/{region_type}_{chip}_scale_regions_{group}_profile_plot.png",
               group=groups, region_type=all_regions, chip="input", prefix=prefix)


rule log2_ratio_profileplots:
    input:
        expand("{prefix}/data/profileplot/{region_type}_{chip}_scale_regions_{group}_profile_plot.png",
                group=groups, region_type=all_regions, chip="log2ratio", prefix=prefix)


rule input_heatmaps:
    input:
        expand("{prefix}/data/heatmap/{region_type}/{chip}/scale_regions/{group}_{region_type}.png",
               group=groups, region_type=all_regions, chip="input", prefix=prefix)


rule chip_heatmaps:
    input:
        expand("{prefix}/data/heatmap/{region_type}/{chip}/scale_regions/{group}_{region_type}.png",
                group=groups, region_type=all_regions, chip="chip", prefix=prefix)


rule input_tss_tes_plots:
    input:
        expand("{prefix}/data/profileplot/{region_type}_{chip}_{scaled}_{group}_reference_plot.png", scaled="tss tes".split(),
               group=groups, region_type=all_regions, chip="input", prefix=prefix)


rule chip_tss_tes_plots:
    input:
        expand("{prefix}/data/profileplot/{region_type}_{chip}_{scaled}_{group}_reference_plot.png", scaled="tss tes".split(),
                group=groups, region_type=all_regions, chip="chip", prefix=prefix)


rule log2_ratio_tss_tes_plots:
    input:
        expand("{prefix}/data/profileplot/{region_type}_{chip}_{scaled}_{group}_reference_plot.png", scaled="tss tes".split(),
                group=groups, region_type=all_regions, chip="log2ratio", prefix=prefix)


rule group_merged_chip_vs_merged_input:
    input:
        expand("{prefix}/data/bigwigcompare/group_{group}_chip_vs_input.bigwig",
               group=groups, prefix=prefix)


rule chip_sample_vs_merged_input_bigwigs:
    input:
        expand("{prefix}/data/bigwigcompare/sample_{sample}_vs_merged_input.bw", sample=sample_sheet.loc[sample_sheet.ChIP == "ChIP"].Name, prefix=prefix)


rule chip_bigwigs:
    input:
        expand("{prefix}/data/bigwig/{sample}.bigwig", sample=sample_sheet.loc[sample_sheet.ChIP == "ChIP"].Name, prefix=prefix)


rule input_bigwigs:
    input:
        expand("{prefix}/data/bigwig/{sample}.bigwig", sample=sample_sheet.loc[sample_sheet.ChIP == "Input"].Name, prefix=prefix)


rule merged_input_bigwigs:
    input:
        expand("{prefix}/data/merged_bigwig/{group}_Input.bigwig", group=groups, prefix=prefix)


rule merged_chip_bigwigs:
    input:
        expand("{prefix}/data/merged_bigwig/{group}_ChIP.bigwig", group=groups, prefix=prefix)


rule limma:
    input:
        expand("{prefix}/data/epic_cluster/{caller}_cluster.csv", caller=config["cs_callers"], prefix=prefix)


rule loo_sample_sheet:
    input:
        leave_one_out_sample_sheet

if os.path.exists(leave_one_out_sample_sheet):

    rule leave_one_out:
        input:
            expand("{prefix}/data/peaks/{cs_caller}/{group}.csv", group=list(set(loo_ss.Group)),
                cs_caller=config["cs_callers"], prefix=prefix)


if not len(ss.Group.drop_duplicates()) == 1:

    svsg = sample_vs_group(ss, "ChIP")

    rule bigwig_log2ratio_sample_vs_group:
        input:
            expand("{prefix}/data/bigwigcompare/sample_{sample}_vs_group_{group}.bigwig", zip, sample=svsg.Sample, group=svsg.OtherGroup, prefix=prefix)

    # cartesian product without duplicates
    group1, group2 = [], []
    for g1, g2 in product(groups, groups):
        if g1 != g2:
            group1.append(g1)
            group2.append(g2)


    rule log2_ratio_group_vs_group_bigwig_chip_only:
        input:
            expand("{prefix}/data/bigwigcompare/group_{group1}_vs_group_{group2}.bigwig", zip,
                    group1=group1, group2=group2, prefix=prefix)


    rule log2_ratio_input_normalized_group_vs_input_normalized_group:
        input:
            expand("{prefix}/data/heatmap/{region_type}/{chip}/scale_regions/group_vs_group/{group1}_vs_{group2}_{region_type}.png",
                   group1="WT GENE2_KO".split(), group2="GENE1_KO",
                   region_type=all_regions, chip="log2ratio", prefix=prefix)


# bad: should not hinge on having design_matrix available;
# we should make one for them
# if config["design_matrix"]:
#     design_matrix = pd.read_table(config["design_matrix"], sep="\s+")

#     rule differential_analysis:
#         input:
#             expand("{prefix}/data/limma/{group}_{coefficient}.toptable", group=groups,
#                 coefficient=design_matrix)

# else:
#     print("No design matrix given so target differential_analysis not available.")