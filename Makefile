PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
PERL := $(filter /%,$(shell /bin/sh -c 'type perl'))
VERSION := 0.2.2019.07.03
PROGRAM := classigntax clblastdbcmd clblastprimer clblastseq clclassclass clclassseq clclassseqv clcleanseq clcleanseqv clconcatpair clderepblastdb cldivseq clelimdupgi clextractdupgi clfillassign clfilterseq clfiltersum clidentseq climportfastq climportillumina clmakeblastdb clmakecachedb clmaketaxdb clmaketsv clmakeuchimedb clmakexml clmergeassign clreclassclass clrecoverseqv clretrievegi clrunuchime clshrinkblastdb clsplitseq clsumclass

all: $(PROGRAM)

classigntax: classigntax.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clblastdbcmd: clblastdbcmd.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clblastprimer: clblastprimer.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clblastseq: clblastseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clclassclass: clclassclass.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clclassseq: clclassseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clclassseqv: clclassseqv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clcleanseq: clcleanseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clcleanseqv: clcleanseqv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clconcatpair: clconcatpair.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clderepblastdb: clderepblastdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

cldivseq: cldivseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clelimdupgi: clelimdupgi.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clextractdupgi: clextractdupgi.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clfillassign: clfillassign.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clfilterseq: clfilterseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clfiltersum: clfiltersum.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clidentseq: clidentseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

climportfastq: climportfastq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

climportillumina: climportillumina.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakeblastdb: clmakeblastdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakecachedb: clmakecachedb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clmaketaxdb: clmaketaxdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clmaketsv: clmaketsv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakeuchimedb: clmakeuchimedb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clmakexml: clmakexml.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clmergeassign: clmergeassign.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clreclassclass: clreclassclass.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clrecoverseqv: clrecoverseqv.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clretrievegi: clretrievegi.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clrunuchime: clrunuchime.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clshrinkblastdb: clshrinkblastdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clsplitseq: clsplitseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clsumclass: clsumclass.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

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
