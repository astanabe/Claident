use strict;
use File::Spec;

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
my %ngilist;
my %nseqidlist;
my $blastdb;
my $ngilist;
my $nseqidlist;
my $nodel;
my $blastoption;
my $numthreads = 1;
my $minlen = 50;
my $minalnlen = 50;
my $minalnpcov = 0.5;

# input/output
my $inputfile;
my $outputfolder;

# commands
my $blastn;
my $blastdb_aliastool;

# global variables
my $blastdbpath;

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
	# read replicate list file
	&readNegativeSeqIDList();
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

Copyright (C) 2011-2016  Akifumi S. Tanabe

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
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?gilist=(.+)$/i) {
			$ngilist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?seqidlist=(.+)$/i) {
			$nseqidlist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?gis?=(.+)$/i) {
			foreach my $ngi (split(/,/, $1)) {
				$ngilist{$ngi} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?seqids?=(.+)$/i) {
			foreach my $nseqid (split(/,/, $1)) {
				$nseqidlist{$nseqid} = 1;
			}
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
	if ($blastoption =~ /\-(?:db|evalue|searchsp|gilist|negative_gilist|seqidlist|entrez_query|query|out|outfmt|num_descriptions|num_alignments|num_threads|subject|subject_loc|max_hsps) /) {
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
	# search blastn and blastdb_aliastool
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
			$blastdb_aliastool = "\"$pathto/blastdb_aliastool\"";
		}
		else {
			$blastn = 'blastn';
			$blastdb_aliastool = 'blastdb_aliastool';
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
				$blastdbpath .= ':' . $pathto;
			}
			else {
				$blastdbpath = $pathto;
			}
		}
	}
}

sub readNegativeSeqIDList {
	if ($ngilist) {
		unless (open($filehandleinput1, "< $ngilist")) {
			&errorMessage(__LINE__, "Cannot open \"$ngilist\".");
		}
		while (<$filehandleinput1>) {
			if (/^\s*(\d+)/) {
				$ngilist{$1} = 1;
			}
		}
		close($filehandleinput1);
	}
	elsif ($nseqidlist) {
		unless (open($filehandleinput1, "< $nseqidlist")) {
			&errorMessage(__LINE__, "Cannot open \"$nseqidlist\".");
		}
		while (<$filehandleinput1>) {
			if (/^\s*(\d+)/) {
				$nseqidlist{$1} = 1;
			}
		}
		close($filehandleinput1);
	}
	if (%ngilist) {
		unless (open($filehandleoutput1, "> $outputfolder/ngilist.txt")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/ngilist.txt\".");
		}
		foreach my $ngi (sort({$a <=> $b} keys(%ngilist))) {
			print($filehandleoutput1 "$ngi\n");
		}
		close($filehandleoutput1);
		$ngilist = " -negative_gilist $outputfolder/ngilist.txt";
	}
	elsif (%nseqidlist) {
		unless (open($filehandleoutput1, "> $outputfolder/nseqidlist.txt")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/nseqidlist.txt\".");
		}
		foreach my $nseqid (keys(%nseqidlist)) {
			print($filehandleoutput1 "$nseqid\n");
		}
		close($filehandleoutput1);
		$nseqidlist = " -negative_seqidlist $outputfolder/nseqidlist.txt";
	}
}

sub retrieveSimilarSequences {
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
				$query =~ s/;size=\d+;?//g;
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
				if (scalar(@queries) % ($numthreads * 100) == 0) {
					&runBLAST($numthreads * 100);
				}
			}
		}
		if (-e "$outputfolder/tempquery.fasta") {
			&runBLAST(scalar(@queries) % ($numthreads * 100));
		}
	}
	close($filehandleinput1);
	print(STDERR "done.\n\n");
}

sub runBLAST {
	my $tempnseq = shift(@_);
	print(STDERR "Searching similar sequences of $tempnseq sequences...\n");
	unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist$nseqidlist -query $outputfolder/tempquery.fasta -db $blastdb -out - -evalue 1000000000 -outfmt \"6 qseqid sgi length qcovhsp\" -num_threads $numthreads -searchsp 9223372036854775807 |")) {
		&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist$nseqidlist -query $outputfolder/tempquery.fasta -db $blastdb -out - -evalue 1000000000 -outfmt \"6 qseqid sgi length qcovhsp\" -num_threads $numthreads -searchsp 9223372036854775807\".");
	}
	local $/ = "\n";
	while (<$pipehandleinput1>) {
		if (/^\s*(\S+)\s+(\d+)\s+(\d+)\s+(\S+)/ && $3 >= $minalnlen && $4 >= $minalnpcov) {
			unless (open($filehandleoutput1, ">> $outputfolder/$1.txt")) {
				&errorMessage(__LINE__, "Cannot write \"$outputfolder/$1.txt\".");
			}
			print($filehandleoutput1 "$2\n");
			close($filehandleoutput1);
		}
	}
	close($pipehandleinput1);
	#if ($?) {
	#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist$nseqidlist -query $outputfolder/tempquery.fasta -db $blastdb -out - -evalue 1000000000 -outfmt \"6 qseqid sgi length qcovhsp\" -num_threads $numthreads -searchsp 9223372036854775807\".");
	#}
	unlink("$outputfolder/tempquery.fasta");
}

sub makeBLASTDB {
	while (glob("$outputfolder/query*.txt")) {
		my $gilist = $_;
		$gilist =~ /(query\d+)\.txt/;
		my $prefix = $1;
		if (system("BLASTDB=\"$blastdbpath\" $blastdb_aliastool -dbtype nucl -db $blastdb -gilist $gilist -out $outputfolder/$prefix -title $prefix 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot make cachedb \"$outputfolder/$prefix\".");
		}
		unless ($nodel) {
			unlink($gilist);
		}
	}
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

--negativegilist=FILENAME
  Specify file name of negative GI list. (default: none)

--negativegi=GI(,GI..)
  Specify negative GIs.

--negativeseqidlist=FILENAME
  Specify file name of negative SeqID list. (default: none)

--negativeseqid=SeqID(,SeqID..)
  Specify negative SeqIDs.

--minlen=INTEGER
  Specify minimum length of query sequence. (default: 50)

--minalnlen=INTEGER
  Specify minimum alignment length.
(default: 50)

--minalnpcov=DECIMAL
  Specify minimum percentage of alignment coverage.
(default: 0.5)

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
