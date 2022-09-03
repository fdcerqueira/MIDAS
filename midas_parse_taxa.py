#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Apr 27 17:54:26 2022

@author: chico
"""

from Bio import Entrez
from Bio import SeqIO
import sys
import os

#system input
WD = sys.argv[1]

#set work directory
os.chdir(WD)

#receive input from user
input_string = input("Enter all genomes NCBI accessions and version (e.g NC_000913.2) separated by a comma (,) ")

# Split string into words
genome_ids = input_string.split(",")
print(genome_ids)

#mail to identify myself to NCBI
Entrez.email = "fdcerqueira@igc.gulbenkian.pt"

#download and write file to specified directory (sys.argv[1])
for genome_id in genome_ids:
    record = Entrez.efetch(db="nucleotide", id=genome_id, rettype="fasta", retmode="text")

    filename = '{}.fasta'.format(genome_id)
    print('Writing: {}'.format(filename),"to",WD)
    with open(filename, 'w') as f:
        f.write(record.read())