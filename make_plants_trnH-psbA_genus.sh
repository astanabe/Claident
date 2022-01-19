#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid33090[Organism:exp] AND 200:10000[Sequence Length] AND ("trnH-psbA"[Title] OR ((trnH[Title] OR "tRNA-His"[Title]) AND psbA[Title])) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' plants_trnH-psbA1.txt || exit $?
cat plants_cpgenomes.txt >> plants_trnH-psbA1.txt || exit $?
# make taxonomy database
#clmaketaxdb --excluderefseq=enable --includetaxid=33090 taxonomy plants.taxdb || exit $?
# search by keywords at taxdb
#clretrieveacc --maxrank=genus --additional=enable --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=plants.taxdb plants_genus.txt || exit $?
# make BLAST database
#cd blastdb || exit $?
#clblastdbcmd --blastdb=./nt --output=ACCESSION --numthreads=16 ../plants_genus.txt plants_genus.txt
#BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db nt -seqid_file_in plants_genus.txt -seqid_title plants_genus -seqid_file_out plants_genus.bsl || exit $?
#BLASTDB=./ blastdb_aliastool -dbtype nucl -db nt -seqidlist plants_genus.bsl -out plants_genus -title plants_genus || exit $?
#cd .. || exit $?
# search by reference sequences
clblastseq blastn -db blastdb/plants_genus -word_size 11 -evalue 1e-15 -strand plus -task blastn -max_target_seqs 1000000000 end --output=ACCESSION --numthreads=16 --hyperthreads=8 references_plants_trnH-psbA.fasta plants_trnH-psbA2.txt || exit $?
# eliminate duplicate entries
clelimdupacc plants_trnH-psbA1.txt plants_trnH-psbA2.txt plants_trnH-psbA.txt || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --additional=enable --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_species_wosp.txt &
clretrieveacc --maxrank=genus --additional=enable --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --acclist=plants_trnH-psbA.txt --taxdb=plants.taxdb plants_trnH-psbA_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../plants_trnH-psbA_genus.txt plants_trnH-psbA_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_trnH-psbA_species_wsp.txt plants_trnH-psbA_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_trnH-psbA_species.txt plants_trnH-psbA_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_trnH-psbA_species_wosp.txt plants_trnH-psbA_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_trnH-psbA_genus_man.txt plants_trnH-psbA_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_trnH-psbA_species_wsp_man.txt plants_trnH-psbA_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_trnH-psbA_species_man.txt plants_trnH-psbA_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../plants_trnH-psbA_species_wosp_man.txt plants_trnH-psbA_species_wosp_man.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_trnH-psbA_genus.txt -seqid_title plants_trnH-psbA_genus -seqid_file_out plants_trnH-psbA_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_trnH-psbA_genus.bsl -out plants_trnH-psbA_genus -title plants_trnH-psbA_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_trnH-psbA_species_wsp.txt -seqid_title plants_trnH-psbA_species_wsp -seqid_file_out plants_trnH-psbA_species_wsp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_trnH-psbA_species_wsp.bsl -out plants_trnH-psbA_species_wsp -title plants_trnH-psbA_species_wsp" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_trnH-psbA_species.txt -seqid_title plants_trnH-psbA_species -seqid_file_out plants_trnH-psbA_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_trnH-psbA_species.bsl -out plants_trnH-psbA_species -title plants_trnH-psbA_species" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_trnH-psbA_species_wosp.txt -seqid_title plants_trnH-psbA_species_wosp -seqid_file_out plants_trnH-psbA_species_wosp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_trnH-psbA_species_wosp.bsl -out plants_trnH-psbA_species_wosp -title plants_trnH-psbA_species_wosp" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_trnH-psbA_genus_man.txt -seqid_title plants_trnH-psbA_genus_man -seqid_file_out plants_trnH-psbA_genus_man.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_trnH-psbA_genus_man.bsl -out plants_trnH-psbA_genus_man -title plants_trnH-psbA_genus_man" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_trnH-psbA_species_wsp_man.txt -seqid_title plants_trnH-psbA_species_wsp_man -seqid_file_out plants_trnH-psbA_species_wsp_man.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_trnH-psbA_species_wsp_man.bsl -out plants_trnH-psbA_species_wsp_man -title plants_trnH-psbA_species_wsp_man" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_trnH-psbA_species_man.txt -seqid_title plants_trnH-psbA_species_man -seqid_file_out plants_trnH-psbA_species_man.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_trnH-psbA_species_man.bsl -out plants_trnH-psbA_species_man -title plants_trnH-psbA_species_man" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in plants_trnH-psbA_species_wosp_man.txt -seqid_title plants_trnH-psbA_species_wosp_man -seqid_file_out plants_trnH-psbA_species_wosp_man.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist plants_trnH-psbA_species_wosp_man.bsl -out plants_trnH-psbA_species_wosp_man -title plants_trnH-psbA_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/plants_trnH-psbA_genus.txt blastdb/plants_trnH-psbA_species_wsp.txt blastdb/plants_trnH-psbA_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/plants_trnH-psbA_genus.temp taxonomy plants_trnH-psbA_genus.taxdb || exit $?
chmod 666 plants_trnH-psbA_genus.taxdb || exit $?
ln -s plants_trnH-psbA_genus.taxdb plants_trnH-psbA_species_wsp.taxdb || exit $?
ln -s plants_trnH-psbA_genus.taxdb plants_trnH-psbA_species.taxdb || exit $?
ln -s plants_trnH-psbA_genus.taxdb plants_trnH-psbA_species_wosp.taxdb || exit $?
ln -s plants_trnH-psbA_genus.taxdb plants_trnH-psbA_genus_man.taxdb || exit $?
ln -s plants_trnH-psbA_genus.taxdb plants_trnH-psbA_species_wsp_man.taxdb || exit $?
ln -s plants_trnH-psbA_genus.taxdb plants_trnH-psbA_species_man.taxdb || exit $?
ln -s plants_trnH-psbA_genus.taxdb plants_trnH-psbA_species_wosp_man.taxdb || exit $?
#rm plants.taxdb || exit $?
#rm blastdb/plants_genus.* || exit $?
