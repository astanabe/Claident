#!/bin/sh
# Set number of processor cores used for computation
export NCPU=`grep -c processor /proc/cpuinfo`
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH

mkdir -p uchimedb
cd uchimedb

clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (mitochondrion[Filter] AND 13000:9999999[Sequence Length] NOT txid9606[Organism:exp])' mitochondrion.txt || exit $?
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (mitochondrion[Filter] AND 13000:9999999[Sequence Length] AND txid9606[Organism:exp])' mitochondrionHuman.txt || exit $?
shuf -n 1000 mitochondrionHuman.txt >> mitochondrion.txt || exit $?
pgretrieveseq --output=GenBank --database=nucleotide mitochondrion.txt mitochondrion.gb || exit $?

extractfeat -type CDS -tag "gene|product" -value "COX1|COI|COXI" -join mitochondrion.gb COX1.fasta &
extractfeat -type CDS -tag "gene|product" -value "CYTB|cytochrome*b" -join mitochondrion.gb CytB.fasta &
extractfeat -type rRNA -tag "gene|product" -value "12S*|s*RNA" -join mitochondrion.gb 12S.fasta &
extractfeat -type rRNA -tag "gene|product" -value "16S*|l*RNA" -join mitochondrion.gb 16S.fasta &
extractfeat -type D-loop -join mitochondrion.gb D-loop_temp1.fasta &
extractfeat -type misc_feature -tag note -value "*control*region*" -join mitochondrion.gb D-loop_temp2.fasta &
wait
cat D-loop_temp1.fasta D-loop_temp2.fasta > D-loop.fasta

# Cluster sequences
for locus in COX1 CytB 12S 16S D-loop
do vsearch --fasta_width 0 --notrunclabels --threads $NCPU --minseqlength 100 --strand both --derep_fulllength $locus.fasta --output $locus\_dereplicated.fasta
done

# Reverse-complement
for locus in COX1 CytB 12S 16S D-loop
do vsearch --fasta_width 0 --notrunclabels --threads $NCPU --label_suffix revcomp --fastx_revcomp $locus\_dereplicated.fasta --fastaout $locus\_dereplicated_revcomp.fasta
done

cat COX1_dereplicated.fasta COX1_dereplicated_revcomp.fasta > cducox1.fasta
cat CytB_dereplicated.fasta CytB_dereplicated_revcomp.fasta > cducytb.fasta
cat 12S_dereplicated.fasta 12S_dereplicated_revcomp.fasta > cdu12s.fasta
cat 16S_dereplicated.fasta 16S_dereplicated_revcomp.fasta > cdu16s.fasta
cat D-loop_dereplicated.fasta D-loop_dereplicated_revcomp.fasta > cdudloop.fasta

cd ..
