#!/bin/sh
export PATH=/usr/local/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid2759[Organism:exp] AND 200:10000[Sequence Length] AND ((18S[Title] OR "small subunit"[Title] OR SSU[Title]) AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT spacer[Title] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' eukaryota_SSU.txt || exit $?
# make taxonomy database
clmaketaxdb --acclist=eukaryota_SSU.txt taxonomy eukaryota_SSU_temp.taxdb || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --acclist=eukaryota_SSU.txt --taxdb=eukaryota_SSU_temp.taxdb eukaryota_SSU_genus.txt &
clretrieveacc --maxrank=species --ngword=environmental,uncultured,unclassified,unidentified,metagenome,metagenomic --acclist=eukaryota_SSU.txt --taxdb=eukaryota_SSU_temp.taxdb eukaryota_SSU_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=eukaryota_SSU.txt --taxdb=eukaryota_SSU_temp.taxdb eukaryota_SSU_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --acclist=eukaryota_SSU.txt --taxdb=eukaryota_SSU_temp.taxdb eukaryota_SSU_species_wosp.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_genus.txt eukaryota_SSU_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species_wsp.txt eukaryota_SSU_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species.txt eukaryota_SSU_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_SSU_species_wosp.txt eukaryota_SSU_species_wosp.txt &
wait
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_genus.txt -seqid_title eukaryota_SSU_genus -seqid_file_out eukaryota_SSU_genus.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_genus.bsl -out eukaryota_SSU_genus -title eukaryota_SSU_genus" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species_wsp.txt -seqid_title eukaryota_SSU_species_wsp -seqid_file_out eukaryota_SSU_species_wsp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species_wsp.bsl -out eukaryota_SSU_species_wsp -title eukaryota_SSU_species_wsp" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species.txt -seqid_title eukaryota_SSU_species -seqid_file_out eukaryota_SSU_species.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species.bsl -out eukaryota_SSU_species -title eukaryota_SSU_species" &
sh -c "BLASTDB=./ blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_SSU_species_wosp.txt -seqid_title eukaryota_SSU_species_wosp -seqid_file_out eukaryota_SSU_species_wosp.bsl; BLASTDB=./ blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_SSU_species_wosp.bsl -out eukaryota_SSU_species_wosp -title eukaryota_SSU_species_wosp" &
wait
cd .. || exit $?
# minimize taxdb
clmaketaxdb --acclist=blastdb/eukaryota_SSU_genus.txt taxonomy eukaryota_SSU_genus.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species_wsp.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species.taxdb || exit $?
ln -s eukaryota_SSU_genus.taxdb eukaryota_SSU_species_wosp.taxdb || exit $?
rm eukaryota_SSU_temp.taxdb || exit $?
