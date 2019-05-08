export PATH=/usr/local/share/claident/bin:$PATH

clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (mitochondrion[Filter] AND 13000:9999999[Sequence Length] NOT txid9606[Organism:exp])' mitochondrion.txt || exit $?
clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (mitochondrion[Filter] AND 13000:9999999[Sequence Length] AND txid9606[Organism:exp])' mitochondrionHuman.txt || exit $?
shuf -n 1000 mitochondrionHuman.txt >> mitochondrion.txt || exit $?
pgretrieveseq --output=GenBank --database=nucleotide mitochondrion.txt mitochondrion.gb || exit $?

extractfeat -type CDS -tag gene -value "COX1|COI" mitochondrion.gb COX1.fasta &
extractfeat -type CDS -tag gene -value "cytochrome*b|cyt*b" mitochondrion.gb CytB.fasta &
extractfeat -type rRNA -tag product -value "12S*RNA|s*RNA" mitochondrion.gb 12S.fasta &
extractfeat -type rRNA -tag product -value "16S*RNA|l*RNA" mitochondrion.gb 16S.fasta &
extractfeat -type D-loop mitochondrion.gb D-loop_temp1.fasta &
extractfeat -type misc_feature -tag note -calue "*control*region*" mitochondrion.gb D-loop_temp2.fasta &
wait
cat D-loop_temp1.fasta D-loop_temp2.fasta > D-loop.fasta

vsearch --threads 8 --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp COX1.fasta --fastaout COX1rc.fasta
cat COX1.fasta COX1rc.fasta > cducox1.fasta

vsearch --threads 8 --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp CytB.fasta --fastaout CytBrc.fasta
cat CytB.fasta CytBrc.fasta > cducytb.fasta

vsearch --threads 8 --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp 12S.fasta --fastaout 12Src.fasta
cat 12S.fasta 12Src.fasta > cdu12s.fasta

vsearch --threads 8 --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp 16S.fasta --fastaout 16Src.fasta
cat 16S.fasta 16Src.fasta > cdu16s.fasta

vsearch --threads 8 --fasta_width 0 --notrunclabels --label_suffix revcomp --fastx_revcomp D-loop.fasta --fastaout D-looprc.fasta
cat D-loop.fasta D-looprc.fasta > cdudloop.fasta
