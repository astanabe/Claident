clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (plastid[Filter] AND 100000:9999999[Sequence Length])' plastid.txt
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid1117[Organism:exp] AND "complete genome"[Title])' cyanobacteria.txt
pgretrieveseq --output=GenBank --database=nucleotide plastid.txt plastid.gb
pgretrieveseq --output=GenBank --database=nucleotide cyanobacteria.txt cyanobacteria.gb

extractfeat -type CDS -tag gene -value "psbA" -before 300 -after -50 plastid.gb trnH-psbA.fasta
vsearch --id 0.99 --qmask none --strand both --threads 8 --notrunclabels --cluster_fast trnH-psbA.fasta --centroids trnH-psbAnr99.fasta
vsearch --threads 8 --notrunclabels --label_suffix revcomp --fastx_revcomp trnH-psbAnr99.fasta --fastaout trnH-psbAnr99rc.fasta
cat trnH-psbAnr99.fasta trnH-psbAnr99rc.fasta > cdutrnhpsba.fasta

extractfeat -type CDS -tag gene -value "matK" plastid.gb matK.fasta
vsearch --id 0.99 --qmask none --strand both --threads 8 --notrunclabels --cluster_fast matK.fasta --centroids matKnr99.fasta
vsearch --threads 8 --notrunclabels --label_suffix revcomp --fastx_revcomp matKnr99.fasta --fastaout matKnr99rc.fasta
cat matKnr99.fasta matKnr99rc.fasta > cdumatk.fasta

extractfeat -type CDS -tag gene -value "rbcL" plastid.gb rbcL.fasta
extractfeat -type CDS -tag gene -value "rbcL" cyanobacteria.gb stdout >> rbcL.fasta
extractfeat -type CDS -tag product -value "ribulose*large*subunit" cyanobacteria.gb stdout >> rbcL.fasta
vsearch --id 0.99 --qmask none --strand both --threads 8 --notrunclabels --cluster_fast rbcL.fasta --centroids rbcLnr99.fasta
vsearch --threads 8 --notrunclabels --label_suffix revcomp --fastx_revcomp rbcLnr99.fasta --fastaout rbcLnr99rc.fasta
cat rbcLnr99.fasta rbcLnr99rc.fasta > cdurbcl.fasta
