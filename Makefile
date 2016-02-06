PREFIX ?= /usr/local
CONFIG ?= /etc/claident
BINDIR ?= $(PREFIX)/bin
PERL := $(filter /%,$(shell /bin/sh -c 'type perl'))
PYTHON := $(filter /%,$(shell /bin/sh -c 'type python'))
PROGRAM := classigntax clblastprimer clblastseq clclassclass clclassseq clclassseqv clcleanseq clcleanseqv clderepblastdb cldivseq clelimdupgi clfillassign clfilterseq clfiltersum clidentseq climportillumina clmaketaxdb clmaketsv clmakeuchimedb clmakexml clmergeassign clreclassclass clrecoverseqv clretrievegi clrunuchime clshrinkblastdb clsplitseq clsumclass sff_extract

all: $(PROGRAM)

classigntax: classigntax.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clblastprimer: clblastprimer.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clblastseq: clblastseq.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clclassclass: clclassclass.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clclassseq: clclassseq.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clclassseqv: clclassseqv.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clcleanseq: clcleanseq.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clcleanseqv: clcleanseqv.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clderepblastdb: clderepblastdb.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

cldivseq: cldivseq.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clelimdupgi: clelimdupgi.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clfillassign: clfillassign.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clfilterseq: clfilterseq.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clfiltersum: clfiltersum.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clidentseq: clidentseq.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

climportillumina: climportillumina.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clmaketaxdb: clmaketaxdb.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clmaketsv: clmaketsv.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clmakeuchimedb: clmakeuchimedb.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clmakexml: clmakexml.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clmergeassign: clmergeassign.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clreclassclass: clreclassclass.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clrecoverseqv: clrecoverseqv.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clretrievegi: clretrievegi.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clrunuchime: clrunuchime.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clshrinkblastdb: clshrinkblastdb.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clsplitseq: clsplitseq.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

clsumclass: clsumclass.pl
	echo '#!'$(PERL) > $@
	cat $< >> $@

sff_extract: sff_extract.py
	echo '#!'$(PYTHON) > $@
	cat $< >> $@

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
