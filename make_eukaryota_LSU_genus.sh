#!/bin/sh
# Set PREFIX
if test -z $PREFIX; then
PREFIX=/usr/local || exit $?
fi
# Set PATH
export PATH=$PREFIX/bin:$PREFIX/share/claident/bin:$PATH
# search by keywords at INSD
clretrieveacc --keywords='"ddbj embl genbank"[Filter] AND (txid2759[Organism:exp] AND 150:1000000000000[Sequence Length] AND ((25S[Title] OR 26S[Title] OR 27S[Title] OR 28S[Title] OR "large subunit"[Title] OR LSU[Title]) AND ("ribosomal RNA"[Title] OR rRNA[Title] OR "ribosomal DNA"[Title] OR rDNA[Title])) NOT spacer[Title] NOT environmental[Title] NOT uncultured[Title] NOT unclassified[Title] NOT unidentified[Title] NOT metagenome[Title] NOT metagenomic[Title])' eukaryota_LSU.txt || exit $?
# make taxonomy database
clmaketaxdb --acclist=eukaryota_LSU.txt taxonomy eukaryota_LSU_temp.taxdb || exit $?
# extract identified sequences
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_genus.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_species_wsp.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_species.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_species_wosp.txt &
clretrieveacc --maxrank=genus --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_genus_man.txt &
clretrieveacc --maxrank=species --ngword='^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_species_wsp_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.$,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_species_man.txt &
clretrieveacc --maxrank=species --ngword='species, sp\.,^x , x ,environmental,uncultured,unclassified,unidentified,metagenome,metagenomic' --includetaxa=genus,.+ --taxdb=eukaryota_LSU_temp.taxdb eukaryota_LSU_species_wosp_man.txt &
wait
# make BLAST database
cd blastdb || exit $?
# NT-independent, but overall_class-dependent
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_LSU_genus.txt eukaryota_LSU_genus.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_LSU_species_wsp.txt eukaryota_LSU_species_wsp.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_LSU_species.txt eukaryota_LSU_species.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_LSU_species_wosp.txt eukaryota_LSU_species_wosp.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_LSU_genus_man.txt eukaryota_LSU_genus_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_LSU_species_wsp_man.txt eukaryota_LSU_species_wsp_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_LSU_species_man.txt eukaryota_LSU_species_man.txt &
clextractdupacc --workspace=disk overall_class.txt ../eukaryota_LSU_species_wosp_man.txt eukaryota_LSU_species_wosp_man.txt &
wait
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_LSU_genus.txt -seqid_title eukaryota_LSU_genus -seqid_file_out eukaryota_LSU_genus.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_LSU_genus.bsl -out eukaryota_LSU_genus -title eukaryota_LSU_genus" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_LSU_species_wsp.txt -seqid_title eukaryota_LSU_species_wsp -seqid_file_out eukaryota_LSU_species_wsp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_LSU_species_wsp.bsl -out eukaryota_LSU_species_wsp -title eukaryota_LSU_species_wsp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_LSU_species.txt -seqid_title eukaryota_LSU_species -seqid_file_out eukaryota_LSU_species.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_LSU_species.bsl -out eukaryota_LSU_species -title eukaryota_LSU_species" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_LSU_species_wosp.txt -seqid_title eukaryota_LSU_species_wosp -seqid_file_out eukaryota_LSU_species_wosp.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_LSU_species_wosp.bsl -out eukaryota_LSU_species_wosp -title eukaryota_LSU_species_wosp" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_LSU_genus_man.txt -seqid_title eukaryota_LSU_genus_man -seqid_file_out eukaryota_LSU_genus_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_LSU_genus_man.bsl -out eukaryota_LSU_genus_man -title eukaryota_LSU_genus_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_LSU_species_wsp_man.txt -seqid_title eukaryota_LSU_species_wsp_man -seqid_file_out eukaryota_LSU_species_wsp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_LSU_species_wsp_man.bsl -out eukaryota_LSU_species_wsp_man -title eukaryota_LSU_species_wsp_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_LSU_species_man.txt -seqid_title eukaryota_LSU_species_man -seqid_file_out eukaryota_LSU_species_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_LSU_species_man.bsl -out eukaryota_LSU_species_man -title eukaryota_LSU_species_man" &
sh -c "BLASTDB=`pwd` blastdb_aliastool -seqid_dbtype nucl -seqid_db overall_class -seqid_file_in eukaryota_LSU_species_wosp_man.txt -seqid_title eukaryota_LSU_species_wosp_man -seqid_file_out eukaryota_LSU_species_wosp_man.bsl; BLASTDB=`pwd` blastdb_aliastool -dbtype nucl -db overall_class -seqidlist eukaryota_LSU_species_wosp_man.bsl -out eukaryota_LSU_species_wosp_man -title eukaryota_LSU_species_wosp_man" &
wait
cd .. || exit $?
# minimize taxdb
clelimdupacc blastdb/eukaryota_LSU_genus.txt blastdb/eukaryota_LSU_species_wsp.txt blastdb/eukaryota_LSU_genus.temp || exit $?
clmaketaxdb --acclist=blastdb/eukaryota_LSU_genus.temp taxonomy eukaryota_LSU_genus.taxdb || exit $?
chmod 666 eukaryota_LSU_genus.taxdb || exit $?
ln -s eukaryota_LSU_genus.taxdb eukaryota_LSU_species_wsp.taxdb || exit $?
ln -s eukaryota_LSU_genus.taxdb eukaryota_LSU_species.taxdb || exit $?
ln -s eukaryota_LSU_genus.taxdb eukaryota_LSU_species_wosp.taxdb || exit $?
ln -s eukaryota_LSU_genus.taxdb eukaryota_LSU_genus_man.taxdb || exit $?
ln -s eukaryota_LSU_genus.taxdb eukaryota_LSU_species_wsp_man.taxdb || exit $?
ln -s eukaryota_LSU_genus.taxdb eukaryota_LSU_species_man.taxdb || exit $?
ln -s eukaryota_LSU_genus.taxdb eukaryota_LSU_species_wosp_man.taxdb || exit $?
rm eukaryota_LSU_temp.taxdb || exit $?
