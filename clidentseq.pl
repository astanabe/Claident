use strict;
use File::Spec;

my $buildno = '0.2.x';

print(STDERR <<"_END");
clidentseq $buildno
=======================================================================

Official web site of this script is
http://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2015  Akifumi S. Tanabe

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

# initialize variables
my $devnull = File::Spec->devnull();
my $numthreads = 1;

# get input file name
my $inputfile = $ARGV[-2];
# check input file
if (!-e $inputfile) {
	&errorMessage(__LINE__, "Input file does not exist.");
}

# get output file name
my ($outputfile1, $outputfile2) = split(/,/, $ARGV[-1]);
# check output file
if (-e $outputfile1) {
	&errorMessage(__LINE__, "\"$outputfile1\" already exists.");
}
if ($outputfile2 && -e $outputfile2) {
	&errorMessage(__LINE__, "\"$outputfile2\" already exists.");
}
while (glob("$outputfile1.*.*")) {
	if (/^$outputfile1\..+\.(?:query|nn|ngilist|borderline|nnblast|qblast|fblast)$/) {
		&errorMessage(__LINE__, "Temporary file already exists.");
	}
}

# get other arguments
my %ngilist;
my $blastdb1;
my $blastdb2;
my $method = 'qc';
my $ngilist;
my $ngis;
my $nodel;
my $ht;
my $minlen = 50;
my $minalnlen = 50;
my $minalnlennn = 100;
my $minalnlenb = 50;
my $minalnpcov = 0;
my $minalnpcovnn = 0;
my $minalnpcovb = 0;
my $minnnseq = 2;
my $blastoption;
{
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
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?gis?=(.+)$/i) {
			foreach my $ngi (split(/,/, $1)) {
				$ngilist{$ngi} = 1;
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
if ($blastoption =~ /\-(?:db|evalue|max_target_seqs|searchsp|gilist|negative_gilist|query|out|outfmt|num_descriptions|num_alignments|num_threads|subject|subject_loc) /) {
	&errorMessage(__LINE__, "The options for blastn is invalid.");
}
if ($blastoption !~ / \-task /) {
	$blastoption .= ' -task blastn';
}
if ($blastoption !~ / \-max_hsps /) {
	$blastoption .= ' -max_hsps 1';
}
if ($blastoption !~ / \-word_size /) {
	$blastoption .= ' -word_size 9';
}

my $blastn;
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

my $blastdbpath;
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

my $inputhandle;
if ($ngilist) {
	unless (open($inputhandle, "< $ngilist")) {
		&errorMessage(__LINE__, "Cannot open \"$ngilist\".");
	}
	while (<$inputhandle>) {
		if (/^\s*(\d+)/) {
			$ngilist{$1} = 1;
		}
	}
	close($inputhandle);
}

if (%ngilist) {
	my $outputhandle;
	unless (open($outputhandle, "> $outputfile1.ngilist")) {
		&errorMessage(__LINE__, "Cannot make \"$outputfile1.ngilist\".");
	}
	foreach my $ngi (sort({$a <=> $b} keys(%ngilist))) {
		print($outputhandle "$ngi\n");
	}
	close($outputhandle);
	$ngilist = " -negative_gilist $outputfile1.ngilist";
}

# read input file
print(STDERR "Searching neighborhoods...\n");
my @queries;
unless (open($inputhandle, "< $inputfile")) {
	&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
}
{
	my $qnum = -1;
	my $child = 0;
	$| = 1;
	$? = 0;
	local $/ = "\n>";
	while (<$inputhandle>) {
		if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
			my $query = $1;
			my $sequence = $2;
			$query =~ s/\s+$//;
			$query =~ s/;size=\d+;?//g;
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
				my $outputhandle;
				my $qlen;
				{
					my @seq = $sequence =~ /\S/g;
					$qlen = scalar(@seq);
					if ($qlen < $minlen) {
						exit;
					}
					# output an entry
					unless (open($outputhandle, "> $outputfile1.$qnum.query")) {
						&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.query\".");
					}
					print($outputhandle ">query$qnum\n");
					print($outputhandle join('', @seq) . "\n");
					close($outputhandle);
				}
				# search nearest-neighbor
				my $nne = 1e-140;
				my $nnscore;
				my $temphandle;
				if ($method =~ /^\d+,(\d+)\%$/) {
					my $perc_identity = $1;
					my $tempnseq = $minnnseq + 100;
					unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807 |")) {
						&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807\".");
					}
					my $tempscore;
					my %neighborhoods;
					my @tempneighborhoods;
					while (<$temphandle>) {
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
					close($temphandle);
					#if ($?) {
					#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs $tempnseq -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807\".");
					#}
					unless (open($outputhandle, "> $outputfile1.$qnum.fblast")) {
						&errorMessage(__LINE__, "Cannot write \"$outputfile1.$qnum.fblast\".");
					}
					foreach my $neighborhood (sort({$a <=> $b} keys(%neighborhoods))) {
						print($outputhandle "$neighborhood\n");
					}
					close($outputhandle);
				}
				elsif ($method =~ /^\d+/) {
					my %neighborhoods;
					if ($method =~ /^(\d+)\%$/) {
						my $perc_identity = $1;
						unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807 |")) {
							&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807\".");
						}
						while (<$temphandle>) {
							if (/^\s*(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $minalnlen && $3 >= $minalnpcov) {
								$neighborhoods{$1} = 1;
							}
						}
						close($temphandle);
						#if ($?) {
						#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi length\" -show_gis -max_target_seqs 1000000000 -perc_identity $perc_identity -num_threads $ht -searchsp 9223372036854775807\".");
						#}
					}
					my @tempneighborhoods = keys(%neighborhoods);
					if ($method =~ /^\d+$/ || scalar(@tempneighborhoods) < $minnnseq) {
						my $tempnseq = $minnnseq + 100;
						unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807 |")) {
							&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
						}
						my $tempscore;
						undef(%neighborhoods);
						while (<$temphandle>) {
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
						close($temphandle);
						#if ($?) {
						#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
						#}
					}
					unless (open($outputhandle, "> $outputfile1.$qnum.fblast")) {
						&errorMessage(__LINE__, "Cannot write \"$outputfile1.$qnum.fblast\".");
					}
					foreach my $neighborhood (sort({$a <=> $b} keys(%neighborhoods))) {
						print($outputhandle "$neighborhood\n");
					}
					close($outputhandle);
				}
				else {
					my %nnseq;
					unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi evalue score sseq qcovhsp\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807 |")) {
						&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi evalue score sseq qcovhsp\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807\".");
					}
					while (<$temphandle>) {
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
					close($temphandle);
					#if ($?) {
					#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi evalue score sseq\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807\".");
					#}
					foreach my $tempseq (keys(%nnseq)) {
						if (length($tempseq) < $minalnlennn || ($minalnpcovnn && (length($tempseq) / $qlen) * 100 < $minalnpcovnn)) {
							delete($nnseq{$tempseq});
						}
					}
					if (!%nnseq) {
						exit;
					}
					unless (open($outputhandle, "> $outputfile1.$qnum.nn")) {
						&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.nn\".");
					}
					foreach my $tempseq (sort({$nnseq{$a} <=> $nnseq{$b}} keys(%nnseq))) {
						my $tempseq2 = $tempseq;
						$tempseq2 =~ s/\-//g;
						print($outputhandle ">query$qnum.nn.$nnseq{$tempseq}\n$tempseq2\n");
					}
					close($outputhandle);
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
								unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption -query $outputfile1.$qnum.nn -db $blastdb1 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807 |")) {
									&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query $outputfile1.$qnum.nn -db $blastdb1 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
								}
								while (<$temphandle>) {
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
								close($temphandle);
								#if ($?) {
								#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query $outputfile1.$qnum.nn -db $blastdb1 -out - -evalue $tempeval -outfmt \"6 sgi score length\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
								#}
								$iterno ++;
							}
						}
						# make negative GI list and search borderline
						if (!@borderlinegi) {
							unless (open($outputhandle, "> $outputfile1.$qnum.ngilist")) {
								&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.ngilist\".");
							}
							foreach my $ngi (sort({$a <=> $b} keys(%ngilist))) {
								print($outputhandle "$ngi\n");
							}
							close($outputhandle);
							unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption -negative_gilist $outputfile1.$qnum.ngilist -query $outputfile1.$qnum.nn -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807 |")) {
								&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -negative_gilist $outputfile1.$qnum.ngilist -query $outputfile1.$qnum.nn -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807\".");
							}
							my %borderlines;
							while (<$temphandle>) {
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
							close($temphandle);
							#if ($?) {
							#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -negative_gilist $outputfile1.$qnum.ngilist -query $outputfile1.$qnum.nn -db $blastdb1 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs 100 -num_threads $ht -searchsp 9223372036854775807\".");
							#}
						}
						if (@borderlinegi) {
							unless (open($outputhandle, "> $outputfile1.$qnum.borderline")) {
								&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.borderline\".");
							}
							foreach my $borderlinegi (@borderlinegi) {
								print($outputhandle "$borderlinegi\n");
							}
							close($outputhandle);
						}
						else {
							exit;
						}
						if ($method eq 'nnc' || $method eq 'both') {
							my $tempeval = sprintf("%.2e", $nne);
							unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.nn -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807 |")) {
								&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.nn -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
							}
							my %neighborhoods;
							while (<$temphandle>) {
								if (/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $borderlinescore && $3 >= $minalnlen && $4 >= $minalnpcov) {
									$neighborhoods{$1} = 1;
								}
								elsif (/^\s*(\d+)\s+(\d+)/ && !exists($neighborhoods{$1}) && $2 < $borderlinescore) {
									last;
								}
							}
							close($temphandle);
							#if ($?) {
							#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.nn -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
							#}
							my @tempneighborhoods = keys(%neighborhoods);
							if (scalar(@tempneighborhoods) < $minnnseq) {
								my $tempnseq = $minnnseq + 100;
								unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.nn -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807 |")) {
									&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.nn -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
								}
								unless (open($outputhandle, "> $outputfile1.$qnum.nnblast")) {
									&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.nnblast\".");
								}
								undef(%neighborhoods);
								my $tempscore;
								while (<$temphandle>) {
									if (!$tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $3 >= $minalnlen && $4 >= $minalnpcov) {
										$neighborhoods{$1} = 1;
										print($outputhandle "$1\n");
										@tempneighborhoods = keys(%neighborhoods);
										if (scalar(@tempneighborhoods) >= $minnnseq) {
											$tempscore = $2;
										}
									}
									elsif ($tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $tempscore && $3 >= $minalnlen && $4 >= $minalnpcov) {
										$neighborhoods{$1} = 1;
										print($outputhandle "$1\n");
									}
									elsif ($tempscore && /^\s*(\d+)\s+(\d+)/ && !exists($neighborhoods{$1}) && $2 < $tempscore) {
										last;
									}
								}
								close($outputhandle);
								close($temphandle);
								#if ($?) {
								#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.nn -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
								#}
							}
							else {
								unless (open($outputhandle, "> $outputfile1.$qnum.nnblast")) {
									&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.nnblast\".");
								}
								foreach my $neighborhood (sort({$a <=> $b} keys(%neighborhoods))) {
									print($outputhandle "$neighborhood\n");
								}
								close($outputhandle);
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
						unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption -query $outputfile1.$qnum.query -db $blastdb1 -gilist $outputfile1.$qnum.borderline -out - -evalue 1000000000 -outfmt \"6 sgi evalue score length qcovhsp\" -show_gis -max_target_seqs 100 -searchsp 9223372036854775807 |")) {
							&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query $outputfile1.$qnum.query -db $blastdb1 -gilist $outputfile1.$qnum.borderline -out - -evalue 1000000000 -outfmt \"6 sgi evalue score length qcovhsp\" -show_gis -max_target_seqs 100 -searchsp 9223372036854775807\".");
						}
						my %borderlines;
						while (<$temphandle>) {
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
						close($temphandle);
						#if ($?) {
						#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query $outputfile1.$qnum.query -db $blastdb1 -gilist $outputfile1.$qnum.borderline -out - -evalue 1000000000 -outfmt \"6 sgi evalue score length\" -show_gis -max_target_seqs 100 -searchsp 9223372036854775807\".");
						#}
						if (!$borderlinescore) {
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
							unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807 |")) {
								&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
							}
							undef(%neighborhoods);
							while (<$temphandle>) {
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
							close($temphandle);
							#if ($?) {
							#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb2 -out - -evalue $tempeval -outfmt \"6 sgi score length\" -show_gis -max_target_seqs 1000000000 -num_threads $ht -searchsp 9223372036854775807\".");
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
							unless (open($temphandle, "BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807 |")) {
								&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length qcovhsp stitle\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
							}
							unless (open($outputhandle, "> $outputfile1.$qnum.qblast")) {
								&errorMessage(__LINE__, "Cannot make \"$outputfile1.$qnum.qblast\".");
							}
							undef(%neighborhoods);
							my $tempscore;
							while (<$temphandle>) {
								if (!$tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $3 >= $minalnlen && $4 >= $minalnpcov) {
									$neighborhoods{$1} = 1;
									print($outputhandle "$1\n");
									@tempneighborhoods = keys(%neighborhoods);
									if (scalar(@tempneighborhoods) >= $minnnseq) {
										$tempscore = $2;
									}
								}
								elsif ($tempscore && /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)/ && !exists($neighborhoods{$1}) && $2 >= $tempscore && $3 >= $minalnlen && $4 >= $minalnpcov) {
									$neighborhoods{$1} = 1;
									print($outputhandle "$1\n");
								}
								elsif ($tempscore && /^\s*(\d+)\s+(\d+)/ && !exists($neighborhoods{$1}) && $2 < $tempscore) {
									last;
								}
							}
							close($outputhandle);
							close($temphandle);
							#if ($?) {
							#	&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption$ngilist -query $outputfile1.$qnum.query -db $blastdb2 -out - -evalue 1000000000 -outfmt \"6 sgi score length\" -show_gis -max_target_seqs $tempnseq -num_threads $ht -searchsp 9223372036854775807\".");
							#}
						}
						else {
							unless (open($outputhandle, "> $outputfile1.$qnum.qblast")) {
								&errorMessage(__LINE__, "Cannot write \"$outputfile1.$qnum.qblast\".");
							}
							foreach my $neighborhood (sort({$a <=> $b} keys(%neighborhoods))) {
								print($outputhandle "$neighborhood\n");
							}
							close($outputhandle);
						}
					}
				}
				exit;
			}
		}
	}
}
close($inputhandle);

# join
while (wait != -1) {
	if ($?) {
		&errorMessage(__LINE__, 'Cannot run BLAST search correctly.');
	}
}
print(STDERR "done.\n\n");

unlink("$outputfile1.ngilist");

print(STDERR "Reading blastn results and save to output file...");
if ($method =~ /^\d+/) {
	&outputFile('fblast', $outputfile1);
}
else {
	if ($method eq 'nnc' || $method eq 'both') {
		&outputFile('nnblast', $outputfile1);
	}
	if ($method eq 'both') {
		print(STDERR "done.\n\n");
		print(STDERR "Reading blastn results and save to output file...");
		&outputFile('qblast', $outputfile2);
	}
	elsif ($method eq 'qc') {
		&outputFile('qblast', $outputfile1);
	}
}
print(STDERR "done.\n\n");

unless ($nodel) {
	for (my $i = 0; $i < scalar(@queries); $i ++) {
		unlink("$outputfile1.$i.query");
		unlink("$outputfile1.$i.nn");
		unlink("$outputfile1.$i.ngilist");
		unlink("$outputfile1.$i.borderline");
		unlink("$outputfile1.$i.fblast");
		unlink("$outputfile1.$i.nnblast");
		unlink("$outputfile1.$i.qblast");
	}
}

sub outputFile {
	my $extension = shift(@_);
	my $outputfile = shift(@_);
	my %tempgis;
	# retrieve blast results
	for (my $i = 0; $i < scalar(@queries); $i ++) {
		if (-e "$outputfile1.$i.$extension") {
			unless (open($inputhandle, "< $outputfile1.$i.$extension")) {
				&errorMessage(__LINE__, "Cannot read \"$outputfile1.$i.$extension\".");
			}
			while (<$inputhandle>) {
				if (/^\s*(\d+)/) {
					$tempgis{$queries[$i]}{$1} = 1;
				}
			}
			close($inputhandle);
		}
	}
	# save results to output file
	my $outputhandle;
	unless (open($outputhandle, "> $outputfile")) {
		&errorMessage(__LINE__, "Cannot make \"$outputfile\".");
	}
	foreach my $query (@queries) {
		if ($tempgis{$query}) {
			print($outputhandle "$query\t" . join("\t", sort({$a <=> $b} keys(%{$tempgis{$query}}))) . "\n");
		}
		else {
			print($outputhandle "$query\t0\n");
		}
	}
	close($outputhandle);
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
(default: -task blastn -word_size 9)

--bdb, --blastdb=BLASTDB(,BLASTDB)
  Specify name of BLAST database. (default: none)

--method=QC|NNC|NNC+QC|INTEGER|INTEGER\%|INTEGER,INTEGER\%
  Specify identification method. (default: QC)

--negativegilist=FILENAME
  Specify file name of negative GI list. (default: none)

--negativegi=GI(,GI..)
  Specify negative GIs.

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
(default: 0)

--minalnpcovnn=DECIMAL
  Specify minimum percentage of alignment coverage of query vs nearest-neighbor.
(default: 0)

--minalnpcovb=DECIMAL
  Specify minimum percentage of alignment coverage of query/nearest-neighbor vs
borderline. (default: 0)

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
