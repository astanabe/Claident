use strict;
use File::Spec;

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
my %ngilist;
my %nseqidlist;
my $blastdb1;
my $blastdb2;
my $method = 'qc';
my $ngilist;
my $nseqidlist;
my $nodel;
my $ht;
my $minlen = 50;
my $minalnlen = 50;
my $minalnlennn = 100;
my $minalnlenb = 50;
my $minalnpcov = 0.5;
my $minalnpcovnn = 0.5;
my $minalnpcovb = 0.5;
my $minnnseq = 2;
my $blastoption;
my $numthreads = 1;

# input/output
my $inputfile;
my $outputfile1;
my $outputfile2;

# commands
my $blastn;

# global variables
my $blastdbpath;
my @queries;

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
	# read negative seqids list file
	&readNegativeSeqIDList();
	# search neighborhood sequences
	&searchNeighborhoods();
	# make output file
	&makeOutputFile();
	exit(0);
}

sub printStartupMessage {
	print(STDERR <<"_END");
clidentseq $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2018  Akifumi S. Tanabe

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
	($outputfile1, $outputfile2) = split(/,/, $ARGV[-1]);
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
			my @blastdb = split(/,/, $1);
			if (scalar(@blastdb) > 2) {
				&errorMessage(__LINE__, "Too many blastdbs were given.");
			}
			$blastdb1 = $blastdb[0];
			if ($blastdb[1]) {
				$blastdb2 = $blastdb[1];
			}
			else {
				$blastdb2 = $blastdb[0];
			}
		}
		elsif ($ARGV[$i] =~ /^-+method=(QC|QCENTRIC|QUERYCENTRIC|NNC|NNCENTRIC|NEARESTNEIGHBORCENTRIC|BOTH|NNC\+QC|QC\+NNC|\d+\%|\d+|\d+NN|\d+,\d+\%|\d+NN,\d+\%|\d+\%,\d+|\d+\%,\d+NN)$/i) {
			my $temp = $1;
			if ($temp =~ /^Q/i) {
				$method = 'qc';
			}
			elsif ($temp =~ /^N/i) {
				$method = 'nnc';
			}
			elsif ($temp =~ /^(\d+)(?:NN)?,(\d+\%)/i) {
				$method = "$1,$2";
			}
			elsif ($temp =~ /^(\d+\%),(\d+)(?:NN)?/i) {
				$method = "$2,$1";
			}
			elsif ($temp =~ /^(\d+\%)(?:NN)?/i) {
				$method = $1;
			}
			elsif ($temp =~ /^(\d+)(?:NN)?/i) {
				$method = $1;
			}
			else {
				$method = 'both';
			}
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
		elsif ($ARGV[$i] =~ /^-+(?:ht|hyperthreads?)=(\d+)$/i) {
			$ht = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?len(?:gth)?=(\d+)$/i) {
			$minlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:aln|alignment)(?:len|length)=(\d+)$/i) {
			$minalnlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:aln|alignment)(?:len|length)(?:nn|nearestneighbor)=(\d+)$/i) {
			$minalnlennn = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:aln|alignment)(?:len|length)(?:b|borderline)=(\d+)$/i) {
			$minalnlenb = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:aln|alignment)(?:r|rate|p|percentage)(?:cov|coverage)=(.+)$/i) {
			$minalnpcov = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:aln|alignment)(?:r|rate|p|percentage)(?:cov|coverage)(?:nn|nearestneighbor)=(.+)$/i) {
			$minalnpcovnn = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:aln|alignment)(?:r|rate|p|percentage)(?:cov|coverage)(?:b|borderline)=(.+)$/i) {
			$minalnpcovb = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?n(?:eighbor)?(?:hoods?)?seq(?:uence)?s?=(\d+)$/i) {
			$minnnseq = $1;
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
	if (-e $outputfile1) {
		&errorMessage(__LINE__, "\"$outputfile1\" already exists.");
	}
	if ($outputfile2 && -e $outputfile2) {
		&errorMessage(__LINE__, "\"$outputfile2\" already exists.");
	}
	if (!$inputfile) {
		&errorMessage(__LINE__, "Input file is not given.");
	}
	if (!-e $inputfile) {
		&errorMessage(__LINE__, "Input file does not exist.");
	}
	while (glob("$outputfile1.*.*")) {
		if (/^$outputfile1\..+\.temp$/) {
			&errorMessage(__LINE__, "Temporary folder already exists.");
		}
		elsif (/^$outputfile1\..+\.(?:ngilist|nseqidlist)$/) {
			&errorMessage(__LINE__, "Temporary file already exists.");
		}
	}
	if ($minalnpcov < 0 || $minalnpcov > 1) {
		&errorMessage(__LINE__, "Minimum percentage of alignment length of center vs neighborhoods is invalid.");
	}
	if ($minalnpcov) {
		$minalnpcov *= 100;
	}
	if ($minalnpcovnn < 0 || $minalnpcovnn > 1) {
		&errorMessage(__LINE__, "Minimum percentage of alignment length of query vs nearest-neighbor is invalid.");
	}
	if ($minalnpcovnn) {
		$minalnpcovnn *= 100;
	}
	if ($minalnpcovb < 0 || $minalnpcovb > 1) {
		&errorMessage(__LINE__, "Minimum percentage of alignment length of query/neighborhoods vs borderline is invalid.");
	}
	if ($minalnpcovb) {
		$minalnpcovb *= 100;
	}
	if ($method eq 'both' && !$outputfile2) {
		&errorMessage(__LINE__, "Secondary output file was not specified though both NNC and QC method were enabled.");
	}
	elsif ($method ne 'both' && $outputfile2) {
		&errorMessage(__LINE__, "Secondary output file was specified though both NNC and QC method were not enabled.");
	}
	elsif ($method =~ /^\d+/ && $outputfile2) {
		&errorMessage(__LINE__, "Secondary output file was specified though both NNC and QC method were not enabled.");
	}
	elsif ($method =~ /^\d+/ && $blastdb1 ne $blastdb2) {
		&errorMessage(__LINE__, "Cannot use multiple BLASTDBs in this method.");
	}
	if (-d $blastdb1 && $blastdb1 ne $blastdb2) {
		&errorMessage(__LINE__, "Cannot use multiple BLASTDBs and cache DB simultaneously.");
	}
	if ($method =~ /^(\d+)$/ || $method =~ /^(\d+),\d+\%/i) {
		$minnnseq = $1;
		print(STDERR "$minnnseq-nearest-neighbor method was specified. The minimum number of neighborhoods is overridden.\n");
	}
	elsif ($method =~ /^(\d+)\%/ && ($1 > 100 || $1 < 50)) {
		&errorMessage(__LINE__, "Percent threshold is invalid.");
	}
	elsif ($method =~ /^\d+\%/) {
		$minnnseq = 0;
	}
	if ($ht) {
		if ($numthreads % $ht != 0) {
			&errorMessage(__LINE__, "Multithreading with hyperthreading requires integral multiple numthreads of hyperthreads.");
		}
		else {
			$numthreads /= $ht;
		}
	}
	else {
		$ht = 1;
	}
	if ($blastoption =~ /\-(?:db|evalue|max_target_seqs|searchsp|gilist|negative_gilist|seqidlist|entrez_query|query|out|outfmt|num_descriptions|num_alignments|num_threads|subject|subject_loc|max_hsps) /) {
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
	# search blastn
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
		}
		else {
			$blastn = 'blastn';
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

sub readNegativeSeqIDList {
	if ($ngilist) {
		$filehandleinput1 = &readFile($ngilist);
		while (<$filehandleinput1>) {
			if (/^\s*(\d+)/) {
				$ngilist{$1} = 1;
			}
		}
		close($filehandleinput1);
	}
	elsif ($nseqidlist) {
		$filehandleinput1 = &readFile($nseqidlist);
		while (<$filehandleinput1>) {
			if (/^\s*(\d+)/) {
				$nseqidlist{$1} = 1;
			}
		}
		close($filehandleinput1);
	}
	if (%ngilist) {
		unless (open($filehandleoutput1, "> $outputfile1.ngilist")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfile1.ngilist\".");
		}
		foreach my $ngi (sort({$a <=> $b} keys(%ngilist))) {
			print($filehandleoutput1 "$ngi\n");
		}
		close($filehandleoutput1);
		$ngilist = " -negative_gilist \"$outputfile1.ngilist\"";
	}
	elsif (%nseqidlist) {
		unless (open($filehandleoutput1, "> $outputfile1.nseqidlist")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfile1.nseqidlist\".");
		}
		foreach my $nseqid (keys(%nseqidlist)) {
			print($filehandleoutput1 "$nseqid\n");
		}
		close($filehandleoutput1);
		$nseqidlist = " -negative_seqidlist \"$outputfile1.nseqidlist\"";
	}
}

sub searchNeighborhoods {
	# read input file
	print(STDERR "Searching neighborhoods...\n");
	$filehandleinput1 = &readFile($inputfile);
	{
		my $qnum = -1;
		my $child = 0;
		$| = 1;
		$? = 0;
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
				my $query = $1;
				my $sequence = $2;
				$query =~ s/\s+$//;
				$query =~ s/;+size=\d+;*//g;
				$qnum ++;
				$sequence =~ s/[> \r\n]//g;
				push(@queries, $query);
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
					print(STDERR "Searching neighborhoods of sequence $qnum...\n");
					local $/ = "\n";
					if (-d $blastdb1 && $blastdb1 eq $blastdb2) {
						if (-e "$blastdb1/query$qnum.nsq") {
							$blastdb1 = "$blastdb1/query$qnum";
							$blastdb2 = "$blastdb2/query$qnum";
						}
						else {
							exit;
						}
					}
					my $qlen;
					{
						my @seq = $sequence =~ /\S/g;
						$qlen = scalar(@seq);
						if ($qlen < $minlen) {
							exit;
						}
						unless (mkdir("$outputfile1.$qnum.temp")) {
							&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.temp\".");
						}
						# output an entry
						unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/query.fasta")) {
							&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.temp/query.fasta\".");
						}
						print($filehandleoutput1 ">query$qnum\n");
						print($filehandleoutput1 join('', @seq) . "\n");
						close($filehandleoutput1);
					}
					# search nearest-neighbor
					my $nne = 1e-140;
					my $nnscore;
					if ($method =~ /^\d+,(\d+)\%$/) {
						my $perc_identity = $1;
						my $tempnseq = $minnnseq + 100;
						unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807 |")) {
							&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807\".");
						}
						my $tempscore;
						my %neighborhoods;
						my @tempneighborhoods;
						while (<$pipehandleinput1>) {
							if (!$tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $3 >= $minalnlen && $4 >= $minalnpcov) {
								$neighborhoods{$1} = 1;
								@tempneighborhoods = keys(%neighborhoods);
								if (scalar(@tempneighborhoods) >= $minnnseq) {
									$tempscore = $2;
								}
							}
							elsif ($tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $tempscore && $3 >= $minalnlen && $4 >= $minalnpcov) {
								$neighborhoods{$1} = 1;
							}
							elsif ($tempscore && /^\s*(\d+)\s+(\d+)\s+\d+/ && !exists($neighborhoods{$1}) && $2 < $tempscore) {
								last;
							}
						}
						close($pipehandleinput1);
						#if ($?) {
						#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs $tempnseq -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807\".");
						#}
						unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/fblasthit.txt")) {
							&errorMessage(__LINE__, "Cannot write \"$outputfile1.$qnum.temp/fblasthit.txt\".");
						}
						foreach my $neighborhood (sort({$a <=> $b} keys(%neighborhoods))) {
							print($filehandleoutput1 "$neighborhood\n");
						}
						close($filehandleoutput1);
					}
					elsif ($method =~ /^\d+/) {
						my %neighborhoods;
						if ($method =~ /^(\d+)\%$/) {
							my $perc_identity = $1;
							unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807 |")) {
								&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807\".");
							}
							while (<$pipehandleinput1>) {
								if (/^\s*(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $minalnlen && $3 >= $minalnpcov) {
									$neighborhoods{$1} = 1;
								}
							}
							close($pipehandleinput1);
							#if ($?) {
							#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi length\" -show_gis -max_target_seqs 1000000000 -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807\".");
							#}
						}
						my @tempneighborhoods = keys(%neighborhoods);
						if ($method =~ /^\d+$/ || scalar(@tempneighborhoods) < $minnnseq) {
							my $tempnseq = $minnnseq + 100;
							unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807 |")) {
								&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
							}
							my $tempscore;
							undef(%neighborhoods);
							while (<$pipehandleinput1>) {
								if (!$tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $3 >= $minalnlen && $4 >= $minalnpcov) {
									$neighborhoods{$1} = 1;
									@tempneighborhoods = keys(%neighborhoods);
									if (scalar(@tempneighborhoods) >= $minnnseq) {
										$tempscore = $2;
									}
								}
								elsif ($tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $tempscore && $3 >= $minalnlen && $4 >= $minalnpcov) {
									$neighborhoods{$1} = 1;
								}
								elsif ($tempscore && /^\s*(\d+)\s+(\d+)\s+\d+/ && !exists($neighborhoods{$1}) && $2 < $tempscore) {
									last;
								}
							}
							close($pipehandleinput1);
							#if ($?) {
							#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
							#}
						}
						unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/fblasthit.txt")) {
							&errorMessage(__LINE__, "Cannot write \"$outputfile1.$qnum.temp/fblasthit.txt\".");
						}
						foreach my $neighborhood (sort({$a <=> $b} keys(%neighborhoods))) {
							print($filehandleoutput1 "$neighborhood\n");
						}
						close($filehandleoutput1);
					}
					else {
						my %nnseq;
						unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi evalue score sseq qcovhsp\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807 |")) {
							&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi evalue score sseq qcovhsp\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807\".");
						}
						while (<$pipehandleinput1>) {
							if (!$nnscore && /^\s*(\d+)\s+(\S+)\s+(\d+)\s+(\S+)/) {
								$nnseq{$4} = $1;
								my $evalue = $2;
								$nnscore = $3;
								if ($evalue =~ /^(\d+\.\d+e[\+\-]?\d+)$/ || $evalue =~ /^(\d+e[\+\-]?\d+)$/ || $evalue =~ /^(\d+\.\d+)$/ || $evalue =~ /^(\d+)$/) {
									my $tempnne = eval($1);
									if ($tempnne > $nne) {
										$nne = $tempnne;
									}
								}
							}
							elsif ($nnscore && /^\s*(\d+)\s+(\S+)\s+(\d+)\s+(\S+)/ && $3 == $nnscore) {
								$nnseq{$4} = $1;
							}
						}
						close($pipehandleinput1);
						#if ($?) {
						#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi evalue score sseq\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807\".");
						#}
						foreach my $tempseq (keys(%nnseq)) {
							if (length($tempseq) < $minalnlennn || ($minalnpcovnn && (length($tempseq) / $qlen) * 100 < $minalnpcovnn)) {
								delete($nnseq{$tempseq});
							}
						}
						if (!%nnseq) {
							exit;
						}
						unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/nn.fasta")) {
							&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.temp/nn.fasta\".");
						}
						foreach my $tempseq (sort({$nnseq{$a} <=> $nnseq{$b}} keys(%nnseq))) {
							my $tempseq2 = $tempseq;
							$tempseq2 =~ s/\-//g;
							print($filehandleoutput1 ">query$qnum.nn.$nnseq{$tempseq}\n$tempseq2\n");
						}
						close($filehandleoutput1);
						# search borderline
						{
							my @borderlinegi;
							my $borderlinescore;
							# rake neighborhoods of nearest-neighbors
							{
								my $iterno = 0;
								while (!@borderlinegi && $iterno < 5) {
									if ($nne < 1e-100) {
										$nne *= 1e+32;
									}
									elsif ($nne < 1e-50 && $nne >= 1e-100) {
										$nne *= 1e+16;
									}
									elsif ($nne < 1e-25 && $nne >= 1e-50) {
										$nne *= 1e+8;
									}
									elsif ($nne < 1 && $nne >= 1e-25) {
										$nne *= 1e+4;
									}
									elsif ($nne >= 1) {
										$nne *= 1e+2;
									}
									my $tempeval = sprintf("%.2e", $nne);
									unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb1 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807 |")) {
										&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb1 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
									}
									while (<$pipehandleinput1>) {
										if (/^\s*(\d+)\s+(\d+)/ && !exists($ngilist{$1}) && $2 >= $nnscore) {
											$ngilist{$1} = 1;
										}
										elsif (!$borderlinescore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($ngilist{$1}) && $2 < $nnscore && $3 >= $minalnlenb && $4 >= $minalnpcovb) {
											push(@borderlinegi, $1);
											$borderlinescore = $2;
										}
										elsif ($borderlinescore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($ngilist{$1}) && $2 == $borderlinescore && $3 >= $minalnlenb && $4 >= $minalnpcovb) {
											push(@borderlinegi, $1);
										}
										elsif ($borderlinescore && /^\s*(\d+)\s+(\d+)/ && !exists($ngilist{$1}) && $2 < $borderlinescore) {
											last;
										}
									}
									close($pipehandleinput1);
									#if ($?) {
									#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb1 -out - -evalue $tempeval -outfmt \"6 sgi score length\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
									#}
									$iterno ++;
								}
							}
							# make negative GI list and search borderline
							if (!@borderlinegi) {
								unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/ngilist.txt")) {
									&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.temp/ngilist.txt\".");
								}
								foreach my $ngi (sort({$a <=> $b} keys(%ngilist))) {
									print($filehandleoutput1 "$ngi\n");
								}
								close($filehandleoutput1);
								unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption -negative_gilist \"$outputfile1.$qnum.temp/ngilist.txt\" -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807 |")) {
									&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -negative_gilist \"$outputfile1.$qnum.temp/ngilist.txt\" -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807\".");
								}
								my %borderlines;
								while (<$pipehandleinput1>) {
									if (!$borderlinescore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($borderlines{$1}) && $2 < $nnscore && $3 >= $minalnlenb && $4 >= $minalnpcovb) {
										$borderlines{$1} = 1;
										push(@borderlinegi, $1);
										$borderlinescore = $2;
									}
									elsif ($borderlinescore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($borderlines{$1}) && $2 == $borderlinescore && $3 >= $minalnlenb && $4 >= $minalnpcovb) {
										$borderlines{$1} = 1;
										push(@borderlinegi, $1);
									}
									elsif ($borderlinescore && /^\s*(\d+)\s+(\d+)/ && !exists($borderlines{$1}) && $2 < $borderlinescore) {
										last;
									}
								}
								close($pipehandleinput1);
								#if ($?) {
								#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -negative_gilist \"$outputfile1.$qnum.temp/ngilist.txt\" -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807\".");
								#}
							}
							if (@borderlinegi) {
								unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/borderline.txt")) {
									&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.temp/borderline.txt\".");
								}
								foreach my $borderlinegi (@borderlinegi) {
									print($filehandleoutput1 "$borderlinegi\n");
								}
								close($filehandleoutput1);
							}
							else {
								print(STDERR "WARNING!: Cannot find borderline for $query.");
								exit;
							}
							if ($method eq 'nnc' || $method eq 'both') {
								my $tempeval = sprintf("%.2e", $nne);
								unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807 |")) {
									&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
								}
								my %neighborhoods;
								while (<$pipehandleinput1>) {
									if (/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $borderlinescore && $3 >= $minalnlen && $4 >= $minalnpcov) {
										$neighborhoods{$1} = 1;
									}
									elsif (/^\s*(\d+)\s+(\d+)/ && !exists($neighborhoods{$1}) && $2 < $borderlinescore) {
										last;
									}
								}
								close($pipehandleinput1);
								#if ($?) {
								#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
								#}
								my @tempneighborhoods = keys(%neighborhoods);
								if (scalar(@tempneighborhoods) < $minnnseq) {
									my $tempnseq = $minnnseq + 100;
									unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807 |")) {
										&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
									}
									unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/nnblasthit.txt")) {
										&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.temp/nnblasthit.txt\".");
									}
									undef(%neighborhoods);
									my $tempscore;
									while (<$pipehandleinput1>) {
										if (!$tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $3 >= $minalnlen && $4 >= $minalnpcov) {
											$neighborhoods{$1} = 1;
											print($filehandleoutput1 "$1\n");
											@tempneighborhoods = keys(%neighborhoods);
											if (scalar(@tempneighborhoods) >= $minnnseq) {
												$tempscore = $2;
											}
										}
										elsif ($tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $tempscore && $3 >= $minalnlen && $4 >= $minalnpcov) {
											$neighborhoods{$1} = 1;
											print($filehandleoutput1 "$1\n");
										}
										elsif ($tempscore && /^\s*(\d+)\s+(\d+)/ && !exists($neighborhoods{$1}) && $2 < $tempscore) {
											last;
										}
									}
									close($filehandleoutput1);
									close($pipehandleinput1);
									#if ($?) {
									#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/nn.fasta\" -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
									#}
								}
								else {
									unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/nnblasthit.txt")) {
										&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.temp/nnblasthit.txt\".");
									}
									foreach my $neighborhood (sort({$a <=> $b} keys(%neighborhoods))) {
										print($filehandleoutput1 "$neighborhood\n");
									}
									close($filehandleoutput1);
								}
							}
						}
						if ($method eq 'nnc') {
							exit;
						}
						# calculate borderline score
						my @borderlinegi;
						my $borderlinee = 1e-140;
						my $borderlinescore;
						{
							unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -gilist \"$outputfile1.$qnum.temp/borderline.txt\" -out - -evalue 1000000000 -outfmt \"6 sgi evalue score length qcovhsp\" -show_gis -max_target_seqs 100 -searchsp 9223372036854775807 |")) {
								&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -gilist \"$outputfile1.$qnum.temp/borderline.txt\" -out - -evalue 1000000000 -outfmt \"6 sgi evalue score length qcovhsp\" -show_gis -max_target_seqs 100 -searchsp 9223372036854775807\".");
							}
							my %borderlines;
							while (<$pipehandleinput1>) {
								if (!$borderlinescore && (/^\s*(\d+)\s+(\d+\.\d+e[\+\-]?\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+e[\+\-]?\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+\.\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/) && !exists($borderlines{$1}) && $4 >= $minalnlenb && $5 >= $minalnpcovb) {
									$borderlines{$1} = 1;
									push(@borderlinegi, $1);
									my $tempborderlinee = eval($2);
									if ($tempborderlinee > $borderlinee) {
										$borderlinee = $tempborderlinee;
									}
									$borderlinescore = $3;
								}
								elsif ($borderlinescore && (/^\s*(\d+)\s+(\d+\.\d+e[\+\-]?\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+e[\+\-]?\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+\.\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/) && !exists($borderlines{$1}) && $3 == $borderlinescore && $4 >= $minalnlenb && $5 >= $minalnpcovb) {
									$borderlines{$1} = 1;
									push(@borderlinegi, $1);
								}
								elsif ($borderlinescore && (/^\s*(\d+)\s+(\d+\.\d+e[\+\-]?\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+e[\+\-]?\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+\.\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ || /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/) && !exists($borderlines{$1}) && $3 < $borderlinescore && $4 >= $minalnlenb && $5 >= $minalnpcovb) {
									last;
								}
							}
							close($pipehandleinput1);
							#if ($?) {
							#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb1 -gilist \"$outputfile1.$qnum.temp/borderline.txt\" -out - -evalue 1000000000 -outfmt \"6 sgi evalue score length\" -show_gis -max_target_seqs 100 -searchsp 9223372036854775807\".");
							#}
							if (!$borderlinescore) {
								print(STDERR "WARNING!: Cannot calculate borderline score for $query.");
								exit;
							}
						}
						# rake neighborhoods
						{
							my %neighborhoods;
							my $iterno = 0;
							my $borderlinefound;
							while (!$borderlinefound && $iterno < 5) {
								if ($borderlinee < 1e-100) {
									$borderlinee *= 1e+32;
								}
								elsif ($borderlinee < 1e-50 && $borderlinee >= 1e-100) {
									$borderlinee *= 1e+16;
								}
								elsif ($borderlinee < 1e-25 && $borderlinee >= 1e-50) {
									$borderlinee *= 1e+8;
								}
								elsif ($borderlinee < 1 && $borderlinee >= 1e-25) {
									$borderlinee *= 1e+4;
								}
								elsif ($borderlinee >= 1) {
									$borderlinee *= 1e+2;
								}
								my $tempeval = sprintf("%.2e", $borderlinee);
								unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807 |")) {
									&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
								}
								undef(%neighborhoods);
								while (<$pipehandleinput1>) {
									if (/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 > $borderlinescore && $3 >= $minalnlen && $4 >= $minalnpcov) {
										$neighborhoods{$1} = 1;
									}
									elsif (/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 == $borderlinescore) {
										if ($3 >= $minalnlen && $4 >= $minalnpcov) {
											$neighborhoods{$1} = 1;
										}
										$borderlinefound = 1;
									}
									elsif (/^\s*(\d+)\s+(\d+)/ && !exists($neighborhoods{$1}) && $2 < $borderlinescore) {
										$borderlinefound = 1;
										last;
									}
								}
								close($pipehandleinput1);
								#if ($?) {
								#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
								#}
								$iterno ++;
							}
							if (!$borderlinefound) {
								foreach my $borderlinegi (@borderlinegi) {
									$neighborhoods{$borderlinegi} = 1;
								}
							}
							my @tempneighborhoods = keys(%neighborhoods);
							if (scalar(@tempneighborhoods) < $minnnseq) {
								my $tempnseq = $minnnseq + 100;
								unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807 |")) {
									&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
								}
								unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/qblasthit.txt")) {
									&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.temp/qblasthit.txt\".");
								}
								undef(%neighborhoods);
								my $tempscore;
								while (<$pipehandleinput1>) {
									if (!$tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $3 >= $minalnlen && $4 >= $minalnpcov) {
										$neighborhoods{$1} = 1;
										print($filehandleoutput1 "$1\n");
										@tempneighborhoods = keys(%neighborhoods);
										if (scalar(@tempneighborhoods) >= $minnnseq) {
											$tempscore = $2;
										}
									}
									elsif ($tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $tempscore && $3 >= $minalnlen && $4 >= $minalnpcov) {
										$neighborhoods{$1} = 1;
										print($filehandleoutput1 "$1\n");
									}
									elsif ($tempscore && /^\s*(\d+)\s+(\d+)/ && !exists($neighborhoods{$1}) && $2 < $tempscore) {
										last;
									}
								}
								close($filehandleoutput1);
								close($pipehandleinput1);
								#if ($?) {
								#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query \"$outputfile1.$qnum.temp/query.fasta\" -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
								#}
							}
							else {
								unless (open($filehandleoutput1, "> $outputfile1.$qnum.temp/qblasthit.txt")) {
									&errorMessage(__LINE__, "Cannot write \"$outputfile1.$qnum.temp/qblasthit.txt\".");
								}
								foreach my $neighborhood (sort({$a <=> $b} keys(%neighborhoods))) {
									print($filehandleoutput1 "$neighborhood\n");
								}
								close($filehandleoutput1);
							}
						}
					}
					exit;
				}
			}
		}
	}
	close($filehandleinput1);
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot run BLAST search correctly.');
		}
	}
	print(STDERR "done.\n\n");
	unlink("$outputfile1.ngilist");
	unlink("$outputfile1.nseqidlist");
}

sub makeOutputFile {
	print(STDERR "Reading blastn results and save to output file...");
	if ($method =~ /^\d+/) {
		&outputFile('fblasthit.txt', $outputfile1);
	}
	else {
		if ($method eq 'nnc' || $method eq 'both') {
			&outputFile('nnblasthit.txt', $outputfile1);
		}
		if ($method eq 'both') {
			print(STDERR "done.\n\n");
			print(STDERR "Reading blastn results and save to output file...");
			&outputFile('qblasthit.txt', $outputfile2);
		}
		elsif ($method eq 'qc') {
			&outputFile('qblasthit.txt', $outputfile1);
		}
	}
	print(STDERR "done.\n\n");
	unless ($nodel) {
		for (my $i = 0; $i < scalar(@queries); $i ++) {
			unlink("$outputfile1.$i.temp/query.fasta");
			unlink("$outputfile1.$i.temp/nn.fasta");
			unlink("$outputfile1.$i.temp/ngilist.txt");
			unlink("$outputfile1.$i.temp/nseqidlist.txt");
			unlink("$outputfile1.$i.temp/borderline.txt");
			unlink("$outputfile1.$i.temp/fblasthit.txt");
			unlink("$outputfile1.$i.temp/nnblasthit.txt");
			unlink("$outputfile1.$i.temp/qblasthit.txt");
			rmdir("$outputfile1.$i.temp");
		}
	}
}

sub outputFile {
	my $listfile = shift(@_);
	my $outputfile = shift(@_);
	my %tempgis;
	# retrieve blast results
	for (my $i = 0; $i < scalar(@queries); $i ++) {
		if (-e "$outputfile1.$i.temp/$listfile") {
			unless (open($filehandleinput1, "< $outputfile1.$i.temp/$listfile")) {
				&errorMessage(__LINE__, "Cannot read \"$outputfile1.$i.temp/$listfile\".");
			}
			while (<$filehandleinput1>) {
				if (/^\s*(\d+)/) {
					$tempgis{$queries[$i]}{$1} = 1;
				}
			}
			close($filehandleinput1);
		}
	}
	# save results to output file
	$filehandleoutput1 = &writeFile($outputfile);
	foreach my $query (@queries) {
		if ($tempgis{$query}) {
			print($filehandleoutput1 "$query\t" . join("\t", sort({$a <=> $b} keys(%{$tempgis{$query}}))) . "\n");
		}
		else {
			print($filehandleoutput1 "$query\t0\n");
		}
	}
	close($filehandleoutput1);
}

sub writeFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "| gzip -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "| bzip2 -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "| xz -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	else {
		unless (open($filehandle, "> $filename")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	return($filehandle);
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
clidentseq options inputfile outputfile(,outputfile)

Command line options
====================
blastn options end
  Specify commandline options for blastn.
(default: -task dc-megablast -word_size 11 -template_type coding_and_optimal
-template_length 16)

--bdb, --blastdb=BLASTDB(,BLASTDB)
  Specify name of BLAST database or cache database. (default: none)

--method=QC|NNC|NNC+QC|INTEGER|INTEGER\%|INTEGER,INTEGER\%
  Specify identification method. (default: QC)

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
  Specify minimum alignment length of center vs neighborhoods.
(default: 50)

--minalnlennn=INTEGER
  Specify minimum alignment length of query vs nearest-neighbor.
(default: 100)

--minalnlenb=INTEGER
  Specify minimum alignment length of query/nearest-neighbor vs borderline.
(default: 50)

--minalnpcov=DECIMAL
  Specify minimum percentage of alignment coverage of center vs neighborhoods.
(default: 0.5)

--minalnpcovnn=DECIMAL
  Specify minimum percentage of alignment coverage of query vs nearest-neighbor.
(default: 0.5)

--minalnpcovb=DECIMAL
  Specify minimum percentage of alignment coverage of query/nearest-neighbor vs
borderline. (default: 0.5)

--minnneighborhoodseq=INTEGER
  Specify minimum number of neighborhood sequences. (default: 2)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

--ht, --hyperthreads=INTEGER
  Specify the number of threads of each process. (default: 1)

--nodel
  If this option is specified, all temporary files will not deleted.

Acceptable input file formats
=============================
FASTA
_END
	exit;
}
