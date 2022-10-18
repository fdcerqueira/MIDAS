#!/bin/bash

###directory of the bash script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

##metasqueeze project directory and sorted bams directory
project=$(cat /var/tmp/project.$PPID)

##project name
project_name=$(cat /var/tmp/project_name.$PPID)

##read the output directory chosen during the assembly.sh script
START_DIR=$(cat /var/tmp/outputDir.$PPID)

#filtered fastq files
#/EVBfrancisco/final_final/filtered_reads/host_removal add in assembly script PPID
merged=$(cat /var/tmp/host_removal.$PPID)

#auxiliary scripts
download_genomes=$SCRIPT_DIR/midas_parse_taxa.py
format=$SCRIPT_DIR/format.py
MIDAS=$START_DIR/MIDAS	

#directories
midas_database=$MIDAS/midas_database
database=$midas_database/genomes_database
genomes=$MIDAS/genomes
proka=$midas_database/prokka
gene_files=$midas_database/gene_files
map_files=$midas_database/map_files
midas_output=$MIDAS/midas_ouput
midas_final=$MIDAS/midas_final
final_tables=$MIDAS/final_tables
original=$midas_database/original
checkm=$midas_database/checkM
genomes_checkm=$checkm/genomes_checkm
tmp_dir_check=$checkm/tmp_checkm
checkm_final=$checkm/final
dereplicated=$midas_database/dereplicated

function version() {
    echo "Script: MIDAS.sh"
    echo "Author: Francisco Cerqueira"
    echo "Version: 1.0"
    echo "Date of creation: 03/09/2022"
}

function show_help() {

    echo "The script will run MIDAS worflow, and/or will install MIDAS and its necessary dependencies"
    echo ""
    echo "How to use: $0 parameters"
    echo "-n <number of cpus to be used>"
    echo ""
    echo "-specific <if you want to use specific genomes. it will ask for the NCBI genome acession>"
    echo "-drep <just write -drep if you want to use dereplication at 95% ANI>"
    echo "-metagenome <(y/n) if you want to use the genomes assembled from your metagenome>"
    echo ""
    echo "The next option is used in the case you have specific genomes already downloaded. Write the folder were they are"
    echo "-genome_directories <write path/to/folder were specific genomes are>"
}


while [ ! -z "$1" ]
do
      case "$1" in

      -n) shift 1; CORES=$1 ;;
      -h) shift 1; show_help; exit 1 ;;
      -genome_directories) shift 1; genome_directories=$1;;
      -specific) shift 1; specific=$1;;
      -metagenome) shift 1; metagenome=$1;;
      -drep)shift 2; drep=true;;
      *) break;;
    esac
shift
done

if [ -z "$CORES" ]
then
    echo "Need to declare the number of CPUs to be used"
    show_help
    exit 1
fi
	

if [ ! -d $MIDAS ]
then
 	mkdir $MIDAS
else
    echo "output directory  exist. Do you want overwrite it? (y/n)"
    read sim
    
    if [ $sim = "n" ]
    then
        exit 1
    else
        rm -rf $MIDAS
        echo "Creating/overwriting ${instrain} directory"
        mkdir -p $MIDAS
    fi
fi

if [ ! -z $genome_directories ] && [ ! -d "$genome_directories" ]
then
    while true
    do
        echo "Directory does not exist and/or is not properly written"
       	read new_dir
        genome_directories=$new_dir

        if [ -d "$genome_directories" ]
        then
            break
        else
            continue
        fi
        
    done
fi

#function detect worng input directory (extra genomes located on the computer)
function copy() {
    filename=$(basename $i)
    cp $i  $original/${filename}
}

function copy_genomes(){
        filename=$(basename $i)

        mkdir -p $genomes/${filename}
        cp $i $genomes/${filename}
}

function fname {
    R1=$(basename $i)
    R2=${i%%R1.fastq.gz}R2.fastq.gz

    filename=${R1%%_R1.fastq.gz}
    fil=${filename##cleaned-M_t-}
}

#create directories
mkdir -p $midas_database
mkdir -p $genomes
mkdir -p $proka
mkdir -p $gene_files
mkdir -p $map_files
mkdir -p $midas_output
mkdir -p $original
mkdir -p $midas_final
mkdir -p $final_tables
mkdir -p $checkm
mkdir -p $tmp_dir_check
mkdir -p $genomes_checkm
mkdir -p $checkm_final

#print function version
version

#create database: just with specific taxa
if [ "$specific" = "y" ]
then
    python $download_genomes $midas_database

    for i in $midas_database/*.fa*
    do
        copy
    done 
fi

#in case spefic genomes already downloaded should be part of the database
if [ "$metagenome" = "y" ]
then

    ###copy final bins with decided completion and redundancy
    echo "creating lists of the bins generated by squeezemeta"

    #create file with bins of interest    
    touch $project/results/DAS/bins.txt
    awk 'BEGIN {FS= "\t"} $12 >= 50 && $13 <= 10 {print $1} ' \
    $project/results/DAS/${project_name}_DASTool_summary.txt > $project/results/DAS/bins.txt
	
    #add ending pattern to all files
    cp $project/results/DAS/bins.txt $MIDAS/midas.txt
    sed -e 's/$/.contigs.fa/' -i $MIDAS/midas.txt     
    
    #add path to list
    awk '$1="'$project/results/DAS/${project_name}_DASTool_bins/'"$1' $MIDAS/midas.txt > $MIDAS/bins.txt

    #copy bins
    echo "copying all bins"
    for i in `cat $MIDAS/bins.txt`
    do            
        copy
    done
        
    #create taxonomy file
    for i in `cat $project/results/DAS/bins.txt` 
    do  
        echo "$i"
        grep ${i%%.fa} $project/results/tables/${project_name}.bin.tax.tsv >> $midas_database/taxonomy.txt
    done
        
    #create mapfiles
    touch $map_files/.mapfile 

    #change taxnomy names if necessary
    awk '{if($9=="(no")  { print $1"\t" $6 "\t1"}  else { print $1"\t" $8 $9 "\t1"}}' $midas_database/taxonomy.txt | awk '{print}' > $midas_database/.mapfile
    #add suffix .fa to bins names
    awk ' BEGIN{FS="\t"; OFS="\t"} {$1=$1".fa"}1' $midas_database/.mapfile > $midas_database/intermediate.map
fi

if [ ! -z "$genome_directories" ]
then
	echo "copying genomes from selected directory"
	for i in $genome_directories/*.fa*
	do
	    copy
	done
fi

#to run dereplication
if [ "$drep" = "true" ]
then
    
    cp $original/*.fa* $genomes_checkm

    eval "$(conda shell.bash hook)"
    conda activate checkm
	
    ###run checkM separatly. There is a conflict with dRep
    checkm lineage_wf \ 
    -t ${CORES} \
    -x fa \
    --tmpdir $tmp_dir_check \
    $genomes_checkm \
    ${checkm}

    ###get table
    checkm qa $checkm/*.ms ${checkm} \
    --file ${checkm_final}/bins.csv \
    --threads ${CORES} \
    -o 1
    	
    ##python file
    echo "changing checkM output file structure for dREP"
    python $format ${checkm_final}/bins.csv > ${checkm_final}/checkm_out.csv

    echo "dereplicating co-assembly MAGs"
    eval "$(conda shell.bash hook)"
    conda activate instrain
	
    dRep dereplicate $dereplicated \
    -g ${genomes_checkm}/*.fa \
    --S_algorithm ANImf \
    --genomeInfo ${checkm_final}/checkm_out.csv \
    -comp 50 \
    -con 10 \
    -ms 10000 \
    -pa 0.9 \
    -sa 0.95 \
    -nc 0.30 \
    -cm larger \
    -p ${CORES}

    for i in $dereplicated/dereplicated_genomes/*.fa*
    do
        copy_genomes
    done
else
    for i in $original/*.fa*
    do
        copy_genomes
    done
fi
    
eval "$(conda shell.bash hook)"
conda activate prokka-env

for i in $(find $genomes/* -type f -name "*.fa*")
do 
    filename=$(basename $i)
    
    prokka --outdir $genomes/${filename} --force --prefix ${filename} --cpus 0 $i 
done

#confirm number of columns, create .genes files
csvtk dim --cols -t $genomes/*/*.gff >> $proka/columns.txt
awk '{$1=""}1' $genomes/*/columns.txt | awk '{$1=$1}1' > $proka/colunas.txt

for i in `cat $proka/colunas.txt`
do 
       
    echo "check if every file as 9 columns"
    echo "${i}"
    
    if [ "$i" -ne 9 ] 
    then
        echo "$i does no have the proper number of columns"
        echo "exiting script"
        exit 1
    else
        echo "the file $i  has the right number of columns"
    fi
done

for i in $genomes/*/*.gff
do    
        
    filename=$(basename $i .gff)
    dir_name=$(dirname $i)

    csvtk cut -f 1,3-5,7,9 --ignore-illegal-row -t $i > $proka/${filename}.genes
    csvtk rename -f 1-6 -t -n scaffold_id,gene_type,start,end,strand,gene_id $proka/${filename}.genes > $dir_name/${filename}.genes
done
 
#remove extra bins (from origial file information)
if [ "$metagenome" = "y" ]
then
    for i in $genomes/*/*.fa
    do
    	filename=$(basename $i)
    
    	echo "$filename" >> $midas_database/intermediated.txt
    done

awk 'FNR==NR {a[$1];next} $1 in a' $midas_database/intermediated.txt $midas_database/intermediate.map > $midas_database/intermediate.mapfile
fi

#create first column for .mapfiles
for i in $genomes/*/*.fa
do
    filename=$(basename $i)
    
    if [ "$metagenome" = "y" ]
    then

        if  grep -q ${filename} $midas_database/intermediate.mapfile
        then
            echo " Skipping ${filename%%.fa} for genome_id.txt and species_id.txt"
            continue
        else
            echo "creating ${filename} genome_id.txt"
            echo "${filename}" >> $midas_database/genome_id.txt
            echo "creating ${filename} species ID"
            grep -e ">" $i | sed "s/ //g" >> $midas_database/species_id.txt
        fi
    else 
        echo "creating genome_id.txt files"
        ls -1 $genomes > $midas_database/genome_id.txt
        echo "creating species_id.txt files"
        grep -e ">" $i |  sed 's/ //g' >> $midas_database/species_id.txt
    fi
done

#create third column of .mapfiles= print 1 so genomes is checked for snps
echo "create third column for genomes file"
sed 's/$/\t1/' $midas_database/species_id.txt > $midas_database/rep_genomes.txt

#merge the three files together
echo "merge columns to create final genomes.mapfile"
paste $midas_database/genome_id.txt $midas_database/rep_genomes.txt -d "\t" > $midas_database/genome.mapfile

if [ ! -s "$midas_database/genome.mapfile" ]
then
    echo "genome.mapfile is empty"
    exit 1  
fi 

#if metagenome file exists then apend it to the main file
if [ "$metagenome" = "y" ]
then
    echo "append MAGs to genome.mapfile"
    cat $midas_database/intermediate.mapfile >> $midas_database/genome.mapfile
fi
 
#add genome information to genomes.mapfile
echo "add colnames to genome.mapfile"
sed -i '1i\genome_id\tspecies_id\trep_genome' $midas_database/genome.mapfile 

awk "{print}" $midas_database/genome.mapfile | sed "s/>//g" > $midas_database/genomes.mapfile 
 
#create midas database
echo "##################################################"
echo "#              Start MIDAS run                   #"
echo "##################################################"

echo "##################################################"
echo "#            Creating MIDAS database             #"
echo "##################################################"

#build costum database
build_midas_db.py --threads $CORES $genomes $midas_database/genomes.mapfile $database

#run abundances of species
for i in $merged/*R1.fastq.gz
do 
   #run function fname 
    fname

    run_midas.py species $midas_output/${fil} -t $CORES -d $database -1 $i -2 $R2
done

#create string for species ids with all genomes to be used to count elleles
species=$(ls $database/rep_genomes | tr "\n" "," | sed "s/,$//")

for i in $merged/*R1.fastq.gz
do 
    #run function fname
    fname 

    run_midas.py snps $midas_output/${fil} --species_id ${species} -1 $i -2 $R2 -t $CORES  -d $database 
done

#create file with the spcies ids
ls -1 $database/rep_genomes > $midas_final/species.txt

#run merge snps, to actually make the snp call#run merge snps, to actually make the snp call
for i in `cat $midas_final/species.txt`
do
    echo $i
    merge_midas.py snps $midas_final -d $database --species_id ${i} -i $midas_output -t dir --allele_freq 0.05 --site_prev 0.50
done

#copy the frequencies of each Species SNPs in the samples to the final SNPs table
for i in `cat $midas_final/species.txt`
do
   
    paste $midas_final/$i/snps_freq.txt $midas_final/$i/snps_info.txt | cut --complement -f4 > $final_tables/${i}.txt
    
    if [ "${PIPESTATUS[0]}" = "0" ]
    then
        echo "SNPs frequencies of the $i genome were merged to the final table located at $final_tables"
    fi
done 2>/dev/null

##remove empty final tables
find $final_tables -type f -empty -print -delete
find $MIDAS -type d -empty -print -delete

##remove intermediate files
rm $midas_database/genome.mapfile
rm $midas_database/species_id.txt
rm $midas_database/rep_genomes.txt
rm $midas_database/genome_id.txt
rm $midas_database/intermediated.txt
rm $midas_database/intermediate.map 
