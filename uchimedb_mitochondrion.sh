clretrievegi --keywords='"ddbj embl genbank"[Filter] AND (mitochondrion[Filter] AND 13000:9999999[Sequence Length])' mitochondrion.txt
pgretrieveseq --output=GenBank --database=nucleotide mitochondrion.txt mitochondrion.gb

extractfeat -type CDS -tag gene -value "COX1|COI" mitochondrion.gb COX1.fasta
vsearch --id 0.99 --qmask none --strand both --threads 8 --notrunclabels --cluster_fast COX1.fasta --centroids COX1nr99.fasta
vsearch --threads 8 --notrunclabels --label_suffix revcomp --fastx_revcomp COX1nr99.fasta --fastaout COX1nr99rc.fasta
cat COX1nr99.fasta COX1nr99rc.fasta > cducox1.fasta

extractfeat -type CDS -tag gene -value "cytochrome*b|cyt*b" mitochondrion.gb CytB.fasta
vsearch --id 0.99 --qmask none --strand both --threads 8 --notrunclabels --cluster_fast CytB.fasta --centroids CytBnr99.fasta
vsearch --threads 8 --notrunclabels --label_suffix revcomp --fastx_revcomp CytBnr99.fasta --fastaout CytBnr99rc.fasta
cat CytBnr99.fasta CytBnr99rc.fasta > cducytb.fasta

extractfeat -type rRNA -tag product -value "12S*RNA|s*RNA" mitochondrion.gb 12S.fasta
vsearch --id 0.99 --qmask none --strand both --threads 8 --notrunclabels --cluster_fast 12S.fasta --centroids 12Snr99.fasta
vsearch --threads 8 --notrunclabels --label_suffix revcomp --fastx_revcomp 12Snr99.fasta --fastaout 12Snr99rc.fasta
cat 12Snr99.fasta 12Snr99rc.fasta > cdu12s.fasta
