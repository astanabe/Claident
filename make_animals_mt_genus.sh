#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid33208[Organism:exp] AND (mitochondrion[Filter] OR mitochondrial[Filter]) NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' animals_mt.txt || exit $?
# make taxonomy database
#clmaketaxdb --includetaxid=33208 taxonomy animals.taxdb || exit $?
# extract genus-level identified sequences
clretrieveacc --includetaxa=genus,.+ --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_genus.txt || exit $?
# extract species-level identified sequences
clretrieveacc --includetaxa=genus,.+,species,.+ --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=animals_mt.txt --taxdb=animals.taxdb animals_mt_species.txt || exit $?
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_underclass.txt ../animals_mt_genus.txt animals_mt_genus.txt &
clextractdupacc --workspace=disk overall_underclass.txt ../animals_mt_species.txt animals_mt_species.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_genus.txt -seqid_title animals_mt_genus -seqid_file_out animals_mt_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_genus.bsl -out animals_mt_genus -title animals_mt_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in animals_mt_species.txt -seqid_title animals_mt_species -seqid_file_out animals_mt_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist animals_mt_species.bsl -out animals_mt_species -title animals_mt_species" &
wait
cd .. || exit $?
# minimize taxdb
clmaketaxdb --acclist=blastdb/animals_mt_genus.txt taxonomy animals_mt_genus.taxdb || exit $?
ln -s animals_mt_genus.taxdb animals_mt_species.taxdb || exit $?
#rm animals.taxdb || exit $?
#rm blastdb/animals_genus.* || exit $?
