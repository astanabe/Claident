PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
PERL ?= $(filter /%,$(shell /bin/sh -c 'type perl'))
VERSION := 0.9.2022.03.15
PROGRAM := classigntax clblastdbcmd clblastprimer clblastseq clcalcfastqstatv clclassseqv clclusterstdv clconcatpair clconcatpairv clconvrefdb cldenoiseseqd clderepblastdb cldivseq clelimdupacc clextractdupacc clfillassign clfilterclass clfilterseq clfilterseqv clfiltersum clidentseq climportfastq clmakeblastdb clmakecachedb clmakeidentdb clmaketaxdb clmaketsv clmakeuchimedb clmakexml clmergeassign clplotwordcloud clrecoverseqv clremovechimev clremovecontam clretrieveacc clshrinkblastdb clsplitseq clsumclass clsumtaxa cltruncprimer

all: $(PROGRAM)

classigntax: classigntax.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clblastdbcmd: clblastdbcmd.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clblastprimer: clblastprimer.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clblastseq: clblastseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clcalcfastqstatv: clcalcfastqstatv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clclassseqv: clclassseqv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clclusterstdv: clclusterstdv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clconcatpair: clconcatpairv
	ln -s $< $@
	chmod 755 $@

clconcatpairv: clconcatpairv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clconvrefdb: clconvrefdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

cldenoiseseqd: cldenoiseseqd.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clderepblastdb: clderepblastdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

cldivseq: cldivseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clelimdupacc: clelimdupacc.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clextractdupacc: clextractdupacc.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clfillassign: clfillassign.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clfilterclass: clfilterclass.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clfilterseq: clfilterseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clfilterseqv: clfilterseqv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clfiltersum: clfiltersum.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clidentseq: clidentseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

climportfastq: climportfastq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakeblastdb: clmakeblastdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakecachedb: clmakecachedb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakeidentdb: clmakeidentdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clmaketaxdb: clmaketaxdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clmaketsv: clmaketsv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakeuchimedb: clmakeuchimedb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakexml: clmakexml.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clmergeassign: clmergeassign.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clplotwordcloud: clplotwordcloud.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clrecoverseqv: clrecoverseqv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clremovechimev: clremovechimev.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clremovecontam: clremovecontam.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clretrieveacc: clretrieveacc.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clshrinkblastdb: clshrinkblastdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clsplitseq: clsplitseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clsumclass: clsumclass.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

clsumtaxa: clsumtaxa.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

cltruncprimer: cltruncprimer.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/" $< >> $@

install: $(PROGRAM)
	chmod 755 $^
	mkdir -p $(BINDIR)
	cp $^ $(BINDIR)
	mkdir -p $(PREFIX)/share/claident
	mkdir -p $(PREFIX)/share/claident/taxdb
	mkdir -p $(PREFIX)/share/claident/blastdb
	mkdir -p $(PREFIX)/share/claident/uchimedb
	echo "CLAIDENTHOME=$(PREFIX)/share/claident" > $(PREFIX)/share/claident/.claident
	echo "TAXONOMYDB=$(PREFIX)/share/claident/taxdb" >> $(PREFIX)/share/claident/.claident
	echo "BLASTDB=$(PREFIX)/share/claident/blastdb" >> $(PREFIX)/share/claident/.claident
	echo "UCHIMEDB=$(PREFIX)/share/claident/uchimedb" >> $(PREFIX)/share/claident/.claident

clean:
	rm $(PROGRAM)
