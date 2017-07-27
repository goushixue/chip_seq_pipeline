import pandas as pd


def compute_internal_exons(exons):
    """Avoid first and last exon for each transcript."""

    colnames = "Chromosome Start End Name Score Strand".split()

    info = exons.Name.str.split(":|\.", expand=True).iloc[:,[1, 2, 3]]
    info.columns = "name transcript exon".split()
    info.exon = info.exon.astype(int)

    exons = pd.concat([exons, info], axis=1).sort_values(["transcript", "exon"])

    exons = exons.groupby(["name", "transcript"]).apply(lambda r: r.iloc[1:-1])

    return exons[colnames].reset_index(drop=True)



if __name__ == "__main__":
    exons = pd.read_table(snakemake.input.exons, header=None,
                          names="Chromosome Start End Name Score Strand".split(), index_col=False)

    outdf = compute_internal_exons(exons)

    outdf.to_csv(snakemake.output[0], sep="\t", header=False, index=False)