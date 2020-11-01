export PATH=/usr/local/share/claident/bin:$PATH

clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (plastid[Filter] AND 100000:9999999[Sequence Length])' plastid.txt || exit $?
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (txid1117[Organism:exp] AND "complete genome"[Title])' cyanobacteria.txt || exit $?
pgretrieveseq --output=GenBank --database=nucleotide plastid.txt plastid.gb || exit $?
pgretrieveseq --output=GenBank --database=nucleotide cyanobacteria.txt cyanobacteria.gb || exit $?

extractfeat -type CDS -tag "gene|product" -value "psbA" -join -before 300 -after -50 plastid.gb trnH-psbA.fasta &
extractfeat -type CDS -tag "gene|product" -value "matK" -join plastid.gb matK.fasta &
extractfeat -type CDS -tag "gene|product" -value "rbcL" -join plastid.gb rbcL_temp1.fasta &
extractfeat -type CDS -tag "gene|product" -value "rbcL" -join cyanobacteria.gb rbcL_temp2.fasta &
extractfeat -type CDS -tag "gene|product" -value "ribulose*large*subunit" -join cyanobacteria.gb rbcL_temp3.fasta &
wait
cat rbcL_temp1.fasta rbcL_temp2.fasta rbcL_temp3.fasta > rbcL.fasta

vsearch --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp trnH-psbA.fasta --fastaout trnH-psbArc.fasta
cat trnH-psbA.fasta trnH-psbArc.fasta > cdutrnhpsba.fasta

vsearch --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp matK.fasta --fastaout matKrc.fasta
cat matK.fasta matKrc.fasta > cdumatk.fasta

vsearch --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp rbcL.fasta --fastaout rbcLrc.fasta
cat rbcL.fasta rbcLrc.fasta > cdurbcl.fasta
