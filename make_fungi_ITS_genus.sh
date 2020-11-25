#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid4751[Organism:exp] AND 200:10000[Sequence Length] AND (ITS1[Title] OR ITS2[Title] OR "internal transcribed spacer"[Title] OR "internal transcribed spacers"[Title]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' fungi_ITS1.txt || exit $?
# make taxonomy database
clmaketaxdb --includetaxid=4751 taxonomy fungi.taxdb || exit $?
# search by keywords at taxdb
clretrieveacc --maxrank=genus --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --taxdb=fungi.taxdb fungi_genus.txt || exit $?
# make BLAST database
cd blastdb || exit $?
clblastdbcmd --blastdb=./nt --output=ACCESSION --numthreads=16 ../fungi_genus.txt fungi_genus.txt
BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db nt -seqid_file_in fungi_genus.txt -seqid_title fungi_genus -seqid_file_out fungi_genus.bsl || exit $?
BLASTDB=./ blastdb_aliastool -dbtype nucl -db nt -seqidlist fungi_genus.bsl -out fungi_genus -title fungi_genus || exit $?
cd .. || exit $?
# search by primer sequences
clblastprimer blastn -db blastdb/fungi_genus -word_size 9 -evalue 1e-1 -perc_identity 90 -strand plus -task blastn-short -ungapped -dust no -max_target_seqs 1000000000 end --numthreads=16 --hyperthreads=16 primers_fungi_ITS.fasta fungi_ITS2.txt || exit $?
# eliminate duplicate entries
clelimdupacc fungi_ITS1.txt fungi_ITS2.txt fungi_ITS.txt || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_genus.txt &
clretrieveacc --maxrank=species --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=fungi_ITS.txt --taxdb=fungi.taxdb fungi_ITS_species_wosp.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_genus.txt fungi_ITS_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species_wsp.txt fungi_ITS_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species.txt fungi_ITS_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../fungi_ITS_species_wosp.txt fungi_ITS_species_wosp.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_genus.txt -seqid_title fungi_ITS_genus -seqid_file_out fungi_ITS_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_genus.bsl -out fungi_ITS_genus -title fungi_ITS_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species_wsp.txt -seqid_title fungi_ITS_species_wsp -seqid_file_out fungi_ITS_species_wsp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species_wsp.bsl -out fungi_ITS_species_wsp -title fungi_ITS_species_wsp" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species.txt -seqid_title fungi_ITS_species -seqid_file_out fungi_ITS_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species.bsl -out fungi_ITS_species -title fungi_ITS_species" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in fungi_ITS_species_wosp.txt -seqid_title fungi_ITS_species_wosp -seqid_file_out fungi_ITS_species_wosp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist fungi_ITS_species_wosp.bsl -out fungi_ITS_species_wosp -title fungi_ITS_species_wosp" &
wait
cd .. || exit $?
# minimize taxdb
clmaketaxdb --acclist=blastdb/fungi_ITS_genus.txt taxonomy fungi_ITS_genus.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species_wsp.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species.taxdb || exit $?
ln -s fungi_ITS_genus.taxdb fungi_ITS_species_wosp.taxdb || exit $?
rm fungi.taxdb || exit $?
rm blastdb/fungi_genus.* || exit $?
