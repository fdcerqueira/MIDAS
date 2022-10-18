# MIDAS pipeline

Pipeline to process in easy way the metagenome assembled genomes (MAGs) obtained from the Metagenomics workflow (binning.sh) in the repository fdcerqueira/Metagenomics.

The aim of this pipeline is to process the metagenomics data and detect SNVs in metagenomic assembled genomes (MAGs) with the MIDAS software.

The script will prepare all the necessary files, create a custom database, with the genomes chosen by the user. It may be from a local folder or download them with the NCBI genome acession ID.
Run MIDAS, and merge SNVs frequencies to the final tables.
 <br/>
 <br/>
 <br/>
**MIDAS.sh:**

1)Select genomes to work with

3)CheckM and dRep (optional)

4)Gene annotations with prokka

5)Create intermediate files: .gene (scaffold_id,gene_type,start,end,strand,gene_id ) and .mapfile 

6)Create MIDAS custom database

7)Run MIDAS species

8)Run MIDAS snps

9)Run MIDAS merge snps

10)Merge SNVs frequencies to the final tables
