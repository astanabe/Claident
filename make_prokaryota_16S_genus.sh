#!/bin/sh
# Set number of processor cores used for computation
export NCPU=0; for n in `grep cpu.cores /proc/cpuinfo | grep -o -P '\d+' | sort -u`; do NCPU=$(($NCPU + n)); done
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND ((txid2[Organism:exp] OR txid2157[Organism:exp]) AND 150:1000000000000[Sequence Length] AND (16S[Title] AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT spacer[Title] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' prokaryota_16S1.txt || exit $?
# make taxonomy database
#clmaketaxdb --excluderefseq=enable --includetaxid=2,2157 taxonomy prokaryota.taxdb || exit $?
# search by keywords at taxdb
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=prokaryota.taxdb prokaryota_genus.txt || exit $?
# make BLAST database
cd blastdb || exit $?
clblastdbcmd --blastdb=`pwd`/nt --output=ACCESSION --numthreads=$NCPU ../prokaryota_genus.txt prokaryota_genus.txt
BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db nt -seqid_file_in prokaryota_genus.txt -seqid_title prokaryota_genus -seqid_file_out prokaryota_genus.bsl || exit $?
BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db nt -seqidlist prokaryota_genus.bsl -out prokaryota_genus -title prokaryota_genus || exit $?
cd .. || exit $?
# search by reference sequences
clblastseq blastn -db `pwd`/blastdb/prokaryota_genus -word_size 9 -evalue 1e-5 -strand plus -task blastn -max_target_seqs 10000000 end --output=ACCESSION --numthreads=$NCPU --hyperthreads=8 references_prokaryota_16S.fasta prokaryota_16S2.txt || exit $?
# eliminate duplicate entries
clelimdupacc prokaryota_16S1.txt prokaryota_16S2.txt prokaryota_16S.txt || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=prokaryota_16S.txt --taxdb=prokaryota.taxdb prokaryota_16S_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but prokaryota_all_genus-dependent
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_16S_genus.txt prokaryota_16S_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_16S_species_wsp.txt prokaryota_16S_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_16S_species.txt prokaryota_16S_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_16S_species_wosp.txt prokaryota_16S_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_16S_genus_man.txt prokaryota_16S_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_16S_species_wsp_man.txt prokaryota_16S_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_16S_species_man.txt prokaryota_16S_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../prokaryota_16S_species_wosp_man.txt prokaryota_16S_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_genus.txt -seqid_title prokaryota_16S_genus -seqid_file_out prokaryota_16S_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_genus.bsl -out prokaryota_16S_genus -title prokaryota_16S_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_species_wsp.txt -seqid_title prokaryota_16S_species_wsp -seqid_file_out prokaryota_16S_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_species_wsp.bsl -out prokaryota_16S_species_wsp -title prokaryota_16S_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_species.txt -seqid_title prokaryota_16S_species -seqid_file_out prokaryota_16S_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_species.bsl -out prokaryota_16S_species -title prokaryota_16S_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_species_wosp.txt -seqid_title prokaryota_16S_species_wosp -seqid_file_out prokaryota_16S_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_species_wosp.bsl -out prokaryota_16S_species_wosp -title prokaryota_16S_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_genus_man.txt -seqid_title prokaryota_16S_genus_man -seqid_file_out prokaryota_16S_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_genus_man.bsl -out prokaryota_16S_genus_man -title prokaryota_16S_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_species_wsp_man.txt -seqid_title prokaryota_16S_species_wsp_man -seqid_file_out prokaryota_16S_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_species_wsp_man.bsl -out prokaryota_16S_species_wsp_man -title prokaryota_16S_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_species_man.txt -seqid_title prokaryota_16S_species_man -seqid_file_out prokaryota_16S_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_species_man.bsl -out prokaryota_16S_species_man -title prokaryota_16S_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in prokaryota_16S_species_wosp_man.txt -seqid_title prokaryota_16S_species_wosp_man -seqid_file_out prokaryota_16S_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist prokaryota_16S_species_wosp_man.bsl -out prokaryota_16S_species_wosp_man -title prokaryota_16S_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/prokaryota_16S_genus.txt blastdb/prokaryota_16S_species_wsp.txt blastdb/prokaryota_16S_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/prokaryota_16S_genus.temp taxonomy prokaryota_16S_genus.taxdb
chmod 666 prokaryota_16S_genus.taxdb || exit $?
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_species_wsp.taxdb || exit $?
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_species.taxdb || exit $?
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_species_wosp.taxdb || exit $?
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_genus_man.taxdb || exit $?
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_species_wsp_man.taxdb || exit $?
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_species_man.taxdb || exit $?
ln -s prokaryota_16S_genus.taxdb prokaryota_16S_species_wosp_man.taxdb || exit $?
#rm prokaryota.taxdb || exit $?
