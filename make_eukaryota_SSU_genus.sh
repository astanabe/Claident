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
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid2759[Organism:exp] AND 150:1000000000000[Sequence Length] AND ((18S[Title] OR "small subunit"[Title] OR SSU[Title]) AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT spacer[Title] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' eukaryota_SSU1.txt || exit $?
# make taxonomy database
#clmaketaxdb --excluderefseq=enable --includetaxid=2759 taxonomy eukaryota.taxdb || exit $?
# search by keywords at taxdb
#clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=eukaryota.taxdb eukaryota_genus.txt || exit $?
# make BLAST database
#cd blastdb || exit $?
#clblastdbcmd --blastdb=`pwd`/nt --output=ACCESSION --numthreads=$NCPU ../eukaryota_genus.txt eukaryota_genus.txt
#BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db nt -seqid_file_in eukaryota_genus.txt -seqid_title eukaryota_genus -seqid_file_out eukaryota_genus.bsl || exit $?
#BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db nt -seqidlist eukaryota_genus.bsl -out eukaryota_genus -title eukaryota_genus || exit $?
#cd .. || exit $?
# search by reference sequences
clblastseq blastn -db `pwd`/blastdb/eukaryota_genus -word_size 9 -evalue 1e-5 -strand plus -task blastn -max_target_seqs 10000000 end --output=ACCESSION --numthreads=$NCPU --hyperthreads=16 references_eukaryota_SSU.fasta eukaryota_SSU2.txt || exit $?
# eliminate duplicate entries
clelimdupacc eukaryota_SSU1.txt eukaryota_SSU2.txt eukaryota_SSU.txt || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=eukaryota_SSU.txt --taxdb=eukaryota.taxdb eukaryota_SSU_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=eukaryota_SSU.txt --taxdb=eukaryota.taxdb eukaryota_SSU_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=eukaryota_SSU.txt --taxdb=eukaryota.taxdb eukaryota_SSU_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=eukaryota_SSU.txt --taxdb=eukaryota.taxdb eukaryota_SSU_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=eukaryota_SSU.txt --taxdb=eukaryota.taxdb eukaryota_SSU_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=eukaryota_SSU.txt --taxdb=eukaryota.taxdb eukaryota_SSU_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=eukaryota_SSU.txt --taxdb=eukaryota.taxdb eukaryota_SSU_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=eukaryota_SSU.txt --taxdb=eukaryota.taxdb eukaryota_SSU_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_genus.txt eukaryota_SSU_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species_wsp.txt eukaryota_SSU_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species.txt eukaryota_SSU_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species_wosp.txt eukaryota_SSU_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_genus_man.txt eukaryota_SSU_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species_wsp_man.txt eukaryota_SSU_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species_man.txt eukaryota_SSU_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species_wosp_man.txt eukaryota_SSU_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_genus.txt -seqid_title eukaryota_SSU_genus -seqid_file_out eukaryota_SSU_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_genus.bsl -out eukaryota_SSU_genus -title eukaryota_SSU_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species_wsp.txt -seqid_title eukaryota_SSU_species_wsp -seqid_file_out eukaryota_SSU_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species_wsp.bsl -out eukaryota_SSU_species_wsp -title eukaryota_SSU_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species.txt -seqid_title eukaryota_SSU_species -seqid_file_out eukaryota_SSU_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species.bsl -out eukaryota_SSU_species -title eukaryota_SSU_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species_wosp.txt -seqid_title eukaryota_SSU_species_wosp -seqid_file_out eukaryota_SSU_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species_wosp.bsl -out eukaryota_SSU_species_wosp -title eukaryota_SSU_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_genus_man.txt -seqid_title eukaryota_SSU_genus_man -seqid_file_out eukaryota_SSU_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_genus_man.bsl -out eukaryota_SSU_genus_man -title eukaryota_SSU_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species_wsp_man.txt -seqid_title eukaryota_SSU_species_wsp_man -seqid_file_out eukaryota_SSU_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species_wsp_man.bsl -out eukaryota_SSU_species_wsp_man -title eukaryota_SSU_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species_man.txt -seqid_title eukaryota_SSU_species_man -seqid_file_out eukaryota_SSU_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species_man.bsl -out eukaryota_SSU_species_man -title eukaryota_SSU_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species_wosp_man.txt -seqid_title eukaryota_SSU_species_wosp_man -seqid_file_out eukaryota_SSU_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species_wosp_man.bsl -out eukaryota_SSU_species_wosp_man -title eukaryota_SSU_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/eukaryota_SSU_genus.txt blastdb/eukaryota_SSU_species_wsp.txt blastdb/eukaryota_SSU_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/eukaryota_SSU_genus.temp taxonomy eukaryota_SSU_genus.taxdb || exit $?
chmod 666 eukaryota_SSU_genus.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species_wsp.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species_wosp.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_genus_man.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species_wsp_man.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species_man.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species_wosp_man.taxdb || exit $?
