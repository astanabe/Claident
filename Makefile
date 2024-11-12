PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
PERL ?= $(filter /%,$(shell /bin/sh -c 'type perl'))
VERSION := 0.9.2024.11.12
YEAR := 2024
PROGRAM := classigntax clblastdbcmd clblastprimer clblastseq clcalcfastqstatv clclassseqv clclusterstdv clconcatpairv clconvrefdb cldenoiseseqd clderepblastdb cldivseq clelimdupacc clestimateconc clextractdupacc clextractuniqacc clfillassign clfilterclass clfilterseq clfilterseqv clfiltersum clidentseq climportfastq clmakeblastdb clmakecachedb clmakeidentdb clmaketaxdb clmaketsv clmakeuchimedb clmakexml clmergeassign clplotwordcloud clrarefysum clrecoverseqv clremovechimev clremovecontam clretrieveacc clshrinkblastdb clsplitseq clsumclass clsumtaxa cltruncprimer

all: $(PROGRAM)

%: %.pl
	echo '#!'$(PERL) > $@
	$(PERL) -npe "s/buildno = '0\.9\.x'/buildno = '$(VERSION)'/;s/ 2011-XXXX / 2011-$(YEAR) /" $< >> $@

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
