PREFIX ?= /usr/local
CONFIG ?= /etc/claident
BINDIR ?= $(PREFIX)/bin
PERL := $(filter /%,$(shell /bin/sh -c 'type perl'))
VERSION := 0.2.2016.04.15
PROGRAM := classigntax clblastprimer clblastseq clclassclass clclassseq clclassseqv clcleanseq clcleanseqv clderepblastdb cldivseq clelimdupgi clfillassign clfilterseq clfiltersum clidentseq climportillumina clmaketaxdb clmaketsv clmakeuchimedb clmakexml clmergeassign clreclassclass clrecoverseqv clretrievegi clrunuchime clshrinkblastdb clsplitseq clsumclass

all: $(PROGRAM)

classigntax: classigntax.pl
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

clderepblastdb: clderepblastdb.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

cldivseq: cldivseq.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.2\.x'/buildno = '$(VERSION)'/" $< >> $@

clelimdupgi: clelimdupgi.pl
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

climportillumina: climportillumina.pl
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
	mkdir -p $(CONFIG)
	echo "CLAIDENTHOME=$(PREFIX)/share/claident" > $(CONFIG)/.claident
	echo "TAXONOMYDB=$(PREFIX)/share/claident/taxdb" >> $(CONFIG)/.claident
	echo "BLASTDB=$(PREFIX)/share/claident/blastdb" >> $(CONFIG)/.claident
	echo "UCHIMEDB=$(PREFIX)/share/claident/uchimedb" >> $(CONFIG)/.claident

clean:
	rm $(PROGRAM)