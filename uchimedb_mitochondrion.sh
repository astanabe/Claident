# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH

clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (mitochondrion[Filter] AND 13000:9999999[Sequence Length] NOT txid9606[Organism:exp])' mitochondrion.txt || exit $?
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (mitochondrion[Filter] AND 13000:9999999[Sequence Length] AND txid9606[Organism:exp])' mitochondrionHuman.txt || exit $?
shuf -n 1000 mitochondrionHuman.txt >> mitochondrion.txt || exit $?
pgretrieveseq --output=GenBank --database=nucleotide mitochondrion.txt mitochondrion.gb || exit $?

extractfeat -type CDS -tag "gene|product" -value "COX1|COI|COXI" -join mitochondrion.gb COX1.fasta &
extractfeat -type CDS -tag "gene|product" -value "CYTB|cytochrome*b" -join mitochondrion.gb CytB.fasta &
extractfeat -type rRNA -tag product -value "12S*|s*RNA" mitochondrion.gb 12S.fasta &
extractfeat -type rRNA -tag product -value "16S*|l*RNA" mitochondrion.gb 16S.fasta &
extractfeat -type D-loop mitochondrion.gb D-loop_temp1.fasta &
extractfeat -type misc_feature -tag note -value "*control*region*" mitochondrion.gb D-loop_temp2.fasta &
wait
cat D-loop_temp1.fasta D-loop_temp2.fasta > D-loop.fasta

vsearch --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp COX1.fasta --fastaout COX1rc.fasta
cat COX1.fasta COX1rc.fasta > cducox1.fasta

vsearch --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp CytB.fasta --fastaout CytBrc.fasta
cat CytB.fasta CytBrc.fasta > cducytb.fasta

vsearch --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp 12S.fasta --fastaout 12Src.fasta
cat 12S.fasta 12Src.fasta > cdu12s.fasta

vsearch --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp 16S.fasta --fastaout 16Src.fasta
cat 16S.fasta 16Src.fasta > cdu16s.fasta

vsearch --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp D-loop.fasta --fastaout D-looprc.fasta
cat D-loop.fasta D-looprc.fasta > cdudloop.fasta
