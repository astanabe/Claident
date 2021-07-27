use strict;
use File::Spec;
use Cwd 'getcwd';

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

# options
my %nacclist;
my $blastdb;
my $nacclist;
my $nodel;
my $blastoption;
my $numthreads = 1;
my $minlen = 50;
my $minalnlen = 50;
my $minalnpcov = 0.5;
my $minnseq = 500;

# input/output
my $inputfile;
my $outputfolder;

# commands
my $blastn;
my $makeblastdb;

# global variables
my $blastdbpath;
my $root = getcwd();
my %ignoreotulist;
my $ignoreotulist;
my $ignoreotuseq;

# file handles
my $filehandleinput1;
my $filehandleoutput1;
my $pipehandleinput1;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# read negative accession list file
	&readListFiles();
	# make output directory
	if (!-e $outputfolder && !mkdir($outputfolder)) {
		&errorMessage(__LINE__, 'Cannot make output folder.');
	}
	# retrieve similar sequences
	&retrieveSimilarSequences();
	# make BLASTDBs
	&makeBLASTDB();
	exit(0);
}

sub printStartupMessage {
	print(STDERR <<"_END");
clmakecachedb $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2021  Akifumi S. Tanabe

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

_END
	# display usage if command line options were not specified
	unless (@ARGV) {
		&helpMessage();
	}
}

sub getOptions {
	# get arguments
	$inputfile = $ARGV[-2];
	$outputfolder = $ARGV[-1];
	my $blastmode = 0;
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^end$/i) {
			$blastmode = 0;
		}
		elsif ($blastmode) {
			$blastoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^blastn?$/i) {
			$blastmode = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:blastdb|bdb)=(.+)$/i) {
			$blastdb = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?(?:acc|accession|seqid)list=(.+)$/i) {
			$nacclist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?(?:acc|accession|seqid)s?=(.+)$/i) {
			foreach my $nacc (split(/,/, $1)) {
				$nacclist{$nacc} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$ignoreotulist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)list=(.+)$/i) {
			$ignoreotulist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)seq=(.+)$/i) {
			$ignoreotuseq = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?len(?:gth)?=(\d+)$/i) {
			$minlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:aln|alignment)(?:len|length)=(\d+)$/i) {
			$minalnlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:aln|alignment)(?:r|rate|p|percentage)(?:cov|coverage)=(.+)$/i) {
			$minalnpcov = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?seq(?:uence)?s?=(\d+)$/i) {
			$minnseq = $1;
		}
		elsif ($ARGV[$i] =~ /^-+nodel$/i) {
			$nodel = 1;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if (!$inputfile) {
		&errorMessage(__LINE__, "Input file is not given.");
	}
	if (!-e $inputfile) {
		&errorMessage(__LINE__, "Input file does not exist.");
	}
	if ($minalnpcov < 0 || $minalnpcov > 1) {
		&errorMessage(__LINE__, "Minimum percentage of alignment length of center vs neighborhoods is invalid.");
	}
	if ($minalnpcov) {
		$minalnpcov *= 100;
	}
	if ($minnseq < 1) {
		&errorMessage(__LINE__, "The minimum number of sequences is too small.");
	}
	if ($blastoption =~ /\-(?:db|evalue|searchsp|gilist|negative_gilist|seqidlist|negative_seqidlist|taxids|negative_taxids|taxidlist|negative_taxidlist|entrez_query|query|out|outfmt|num_descriptions|num_alignments|num_threads|subject|subject_loc|max_hsps) /) {
		&errorMessage(__LINE__, "The options for blastn is invalid.");
	}
	else {
		$blastoption .= ' -max_hsps 1';
	}
	if ($blastoption !~ / \-task /) {
		$blastoption .= ' -task dc-megablast -template_type coding_and_optimal -template_length 16';
	}
	if ($blastoption !~ / \-word_size /) {
		$blastoption .= ' -word_size 11';
	}
	if ($blastoption !~ / \-max_target_seqs /) {
		$blastoption .= ' -max_target_seqs 10000';
	}
	# search blastn and makeblastdb
	{
		my $pathto;
		if ($ENV{'CLAIDENTHOME'}) {
			$pathto = $ENV{'CLAIDENTHOME'};
		}
		else {
			my $temp;
			if (-e '.claident') {
				$temp = '.claident';
			}
			elsif (-e $ENV{'HOME'} . '/.claident') {
				$temp = $ENV{'HOME'} . '/.claident';
			}
			elsif (-e '/etc/claident/.claident') {
				$temp = '/etc/claident/.claident';
			}
			if ($temp) {
				my $filehandle;
				unless (open($filehandle, "< $temp")) {
					&errorMessage(__LINE__, "Cannot read \"$temp\".");
				}
				while (<$filehandle>) {
					if (/^\s*CLAIDENTHOME\s*=\s*(\S[^\r\n]*)/) {
						$pathto = $1;
						$pathto =~ s/\s+$//;
						last;
					}
				}
				close($filehandle);
			}
		}
		if ($pathto) {
			$pathto =~ s/^"(.+)"$/$1/;
			$pathto =~ s/\/$//;
			$pathto .= '/bin';
			if (!-e $pathto) {
				&errorMessage(__LINE__, "Cannot find \"$pathto\".");
			}
			$blastn = "\"$pathto/blastn\"";
			$makeblastdb = "\"$pathto/makeblastdb\"";
		}
		else {
			$blastn = 'blastn';
			$makeblastdb = 'makeblastdb';
		}
	}
	# set BLASTDB path
	if ($ENV{'BLASTDB'}) {
		$blastdbpath = $ENV{'BLASTDB'};
		$blastdbpath =~ s/^"(.+)"$/$1/;
		$blastdbpath =~ s/\/$//;
	}
	foreach my $temp ('.claident', $ENV{'HOME'} . '/.claident', '/etc/claident/.claident', '.ncbirc', $ENV{'HOME'} . '/.ncbirc', $ENV{'NCBI'} . '/.ncbirc') {
		if (-e $temp) {
			my $pathto;
			my $filehandle;
			unless (open($filehandle, "< $temp")) {
				&errorMessage(__LINE__, "Cannot read \"$temp\".");
			}
			while (<$filehandle>) {
				if (/^\s*BLASTDB\s*=\s*(\S[^\r\n]*)/) {
					$pathto = $1;
					$pathto =~ s/\s+$//;
					last;
				}
			}
			close($filehandle);
			$pathto =~ s/^"(.+)"$/$1/;
			$pathto =~ s/\/$//;
			if ($blastdbpath) {
				if ($^O eq 'cygwin') {
					$blastdbpath .= ';' . $pathto;
				}
				else {
					$blastdbpath .= ':' . $pathto;
				}
			}
			else {
				$blastdbpath = $pathto;
			}
		}
	}
}

sub readListFiles {
	print(STDERR "Reading several lists...\n");
	if ($nacclist) {
		unless (open($filehandleinput1, "< $nacclist")) {
			&errorMessage(__LINE__, "Cannot open \"$nacclist\".");
		}
		while (<$filehandleinput1>) {
			if (/^\s*([A-Za-z0-9_]+)/) {
				$nacclist{$1} = 1;
			}
		}
		close($filehandleinput1);
	}
	if (%nacclist) {
		unless (open($filehandleoutput1, "> $outputfolder/nacclist.txt")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/nacclist.txt\".");
		}
		foreach my $nacc (sort(keys(%nacclist))) {
			print($filehandleoutput1 "$nacc\n");
		}
		close($filehandleoutput1);
		$nacclist = " -negative_seqidlist $outputfolder/nacclist.txt";
	}
	if ($ignoreotulist) {
		foreach my $ignoreotu (&readList($ignoreotulist)) {
			$ignoreotulist{$ignoreotu} = 1;
		}
	}
	if ($ignoreotuseq) {
		foreach my $ignoreotu (&readSeq($ignoreotuseq)) {
			$ignoreotulist{$ignoreotu} = 1;
		}
	}
	print(STDERR "done.\n\n");
}

sub readList {
	my $listfile = shift(@_);
	my @list;
	$filehandleinput1 = &readFile($listfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/\t.+//;
		push(@list, $_);
	}
	close($filehandleinput1);
	return(@list);
}

sub readSeq {
	my $seqfile = shift(@_);
	my @list;
	$filehandleinput1 = &readFile($seqfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		if (/^> *(.+)/) {
			my $seqname = $1;
			push(@list, $seqname);
		}
	}
	close($filehandleinput1);
	return(@list);
}

sub retrieveSimilarSequences {
	# count number of sequences
	unless (open($filehandleinput1, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
	}
	my $nseq = 0;
	while (<$filehandleinput1>) {
		if (/^>\s*(\S[^\r\n]*)\r?\n?$/) {
			my $query = $1;
			$query =~ s/\s+$//;
			$query =~ s/;+size=\d+;*//g;
			if (!exists($ignoreotulist{$query})) {
				$nseq ++;
			}
		}
	}
	close($filehandleinput1);
	my $nseqpersearch;
	# calculate nseqs of each file
	if ($nseq < $minnseq * 2) {
		$nseqpersearch = $nseq;
	}
	else {
		my $nsplit = int($nseq / $minnseq);
		$nseqpersearch = int($nseq / $nsplit) + 1;
	}
	# read input file
	print(STDERR "Searching similar sequences...\n");
	unless (open($filehandleinput1, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
	}
	{
		my $qnum = -1;
		local $/ = "\n>";
		my @queries;
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
				my $query = $1;
				my $sequence = $2;
				$query =~ s/\s+$//;
				$query =~ s/;+size=\d+;*//g;
				if (!exists($ignoreotulist{$query})) {
					$qnum ++;
					$sequence =~ s/[> \r\n]//g;
					push(@queries, $query);
					my @seq = $sequence =~ /\S/g;
					my $qlen = scalar(@seq);
					if ($qlen < $minlen) {
						next;
					}
					# output an entry
					unless (open($filehandleoutput1, ">> $outputfolder/tempquery.fasta")) {
						&errorMessage(__LINE__, "Cannot make \"$outputfolder/tempquery.fasta\".");
					}
					print($filehandleoutput1 ">query$qnum\n");
					print($filehandleoutput1 join('', @seq) . "\n");
					close($filehandleoutput1);
					# search similar sequences
					if (scalar(@queries) % $nseqpersearch == 0) {
						&runBLAST($nseqpersearch);
					}
				}
			}
		}
		if (-e "$outputfolder/tempquery.fasta") {
			&runBLAST(scalar(@queries) % $nseqpersearch);
		}
	}
	close($filehandleinput1);
	print(STDERR "done.\n\n");
}

sub runBLAST {
	my $tempnseq = shift(@_);
	print(STDERR "Searching similar sequences of $tempnseq sequences...\n");
	unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$nacclist -query $outputfolder/tempquery.fasta -db $blastdb -out - -evalue 1000000000 -outfmt \"6 qseqid sacc length qcovhsp sseq stitle\" -num_threads $numthreads -searchsp 9223372036854775807 |")) {
		&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$nacclist -query $outputfolder/tempquery.fasta -db $blastdb -out - -evalue 1000000000 -outfmt \"6 qseqid sacc length qcovhsp sseq stitle\" -num_threads $numthreads -searchsp 9223372036854775807\".");
	}
	local $/ = "\n";
	while (<$pipehandleinput1>) {
		s/\r?\n?//;
		if (/^\s*(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(.+)/ && $3 >= $minalnlen && $4 >= $minalnpcov) {
			my $prefix = $1;
			my $sacc = $2;
			my $seq = $5;
			my $title = $6;
			$seq =~ s/\-//g;
			unless (open($filehandleoutput1, ">> $outputfolder/$prefix.fasta")) {
				&errorMessage(__LINE__, "Cannot write \"$outputfolder/$prefix.fasta\".");
			}
			print($filehandleoutput1 ">$sacc $title\n$seq\n");
			close($filehandleoutput1);
		}
	}
	close($pipehandleinput1);
	#if ($?) {
	#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$nacclist -query $outputfolder/tempquery.fasta -db $blastdb -out - -evalue 1000000000 -outfmt \"6 qseqid sacc length qcovhsp sseq stitle\" -num_threads $numthreads -searchsp 9223372036854775807\".");
	#}
	unlink("$outputfolder/tempquery.fasta");
}

sub makeBLASTDB {
	print(STDERR "Constructing cache databases...\n");
	unless (chdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot change working directory.");
	}
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		while (glob("query*.fasta")) {
			if (my $pid = fork()) {
				$child ++;
				if ($child == $numthreads) {
					if (wait == -1) {
						$child = 0;
					} else {
						$child --;
					}
				}
				if ($?) {
					&errorMessage(__LINE__);
				}
				next;
			}
			else {
				my $tempfasta = $_;
				$tempfasta =~ /(query\d+)\.fasta/;
				my $prefix = $1;
				print(STDERR "Constructing cache database for $prefix...\n");
				if (system("BLASTDB=\"$blastdbpath\" $makeblastdb -in $tempfasta -input_type fasta -dbtype nucl -parse_seqids -hash_index -out $prefix -title $prefix 1> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $makeblastdb -in $tempfasta -input_type fasta -dbtype nucl -parse_seqids -hash_index -out $prefix -title $prefix\".");
				}
				unless ($nodel) {
					unlink($tempfasta);
				}
				exit;
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot run $makeblastdb correctly.');
		}
	}
	unless (chdir($root)) {
		&errorMessage(__LINE__, "Cannot change working directory.");
	}
	print(STDERR "done.\n\n");
}

sub readFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "gzip -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "bzip2 -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "xz -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	else {
		unless (open($filehandle, "< $filename")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	return($filehandle);
}

# error message
sub errorMessage {
	my $lineno = shift(@_);
	my $message = shift(@_);
	print(STDERR "ERROR!: line $lineno\n$message\n");
	print(STDERR "If you want to read help message, run this script without options.\n");
	exit(1);
}

sub helpMessage {
	print(STDERR <<"_END");
Usage
=====
clmakecachedb options inputfile outputfolder

Command line options
====================
blastn options end
  Specify commandline options for blastn.
(default: -task dc-megablast -word_size 11 -template_type coding_and_optimal
-template_length 16 -max_target_seqs 10000)

--bdb, --blastdb=BLASTDB(,BLASTDB)
  Specify name of BLAST database. (default: none)

--negativeacclist=FILENAME
  Specify file name of negative accession list. (default: none)

--negativeacc=accession(,accession..)
  Specify negative accessions.

--ignoreotu=SAMPLENAME,...,SAMPLENAME
  Specify ignoring otu names. (default: none)

--ignoreotulist=FILENAME
  Specify file name of ignoring otu list. (default: none)

--ignoreotuseq=FILENAME
  Specify file name of ignoring otu list. (default: none)

--minlen=INTEGER
  Specify minimum length of query sequence. (default: 50)

--minalnlen=INTEGER
  Specify minimum alignment length.
(default: 50)

--minalnpcov=DECIMAL
  Specify minimum percentage of alignment coverage.
(default: 0.5)

--minnseq=INTEGER
  Specify minimum number of sequences of each splitted search.
(default: 500)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

--nodel
  If this option is specified, all temporary files will not deleted.

Acceptable input file formats
=============================
FASTA
_END
	exit;
}
