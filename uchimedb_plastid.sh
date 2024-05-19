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

clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (plastid[Filter] AND 100000:9999999[Sequence Length])' plastid.txt || exit $?
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid1117[Organism:exp] AND "complete genome"[Title])' cyanobacteria.txt || exit $?
pgretrieveseq --output=GenBank --database=nucleotide plastid.txt plastid.gb || exit $?
pgretrieveseq --output=GenBank --database=nucleotide cyanobacteria.txt cyanobacteria.gb || exit $?

extractfeat -type CDS -tag "gene|product" -value "psbA" -join -before 300 -after -50 plastid.gb trnH-psbA.fasta &
extractfeat -type CDS -tag "gene|product" -value "matK" -join plastid.gb matK.fasta &
extractfeat -type CDS -tag "gene|product" -value "rbcL" -join plastid.gb rbcL_temp1.fasta &
extractfeat -type CDS -tag "gene|product" -value "rbcL" -join cyanobacteria.gb rbcL_temp2.fasta &
extractfeat -type CDS -tag "gene|product" -value "ribulose*large*subunit" -join cyanobacteria.gb rbcL_temp3.fasta &
wait
cat rbcL_temp1.fasta rbcL_temp2.fasta rbcL_temp3.fasta > rbcL.fasta

# Cluster sequences
for locus in matK rbcL trnH-psbA
do vsearch --fasta_width 0 --notrunclabels --threads $NCPU --minseqlength 100 --strand both --derep_fulllength $locus.fasta --output $locus\_dereplicated.fasta
done

# Reverse-complement
for locus in matK rbcL trnH-psbA
do vsearch --fasta_width 0 --notrunclabels --threads $NCPU --label_suffix revcomp --fastx_revcomp $locus\_dereplicated.fasta --fastaout $locus\_dereplicated_revcomp.fasta
done

cat matK_dereplicated.fasta matK_dereplicated_revcomp.fasta > cdumatk.fasta
cat rbcL_dereplicated.fasta rbcL_dereplicated_revcomp.fasta > cdurbcl.fasta
cat trnH-psbA_dereplicated.fasta trnH-psbA_dereplicated_revcomp.fasta > cdutrnhpsba.fasta

cd ..
