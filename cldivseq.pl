use strict;

my $buildno = '0.2.x';

print(STDERR <<"_END");
cldivseq $buildno
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

# initialize variables
my $outputfile2 = $ARGV[-1];
if (-e $outputfile2) {
	&errorMessage(__LINE__, "\"$outputfile2\" already exists.");
}
my $outputfile1 = $ARGV[-2];
if (-e $outputfile1) {
	&errorMessage(__LINE__, "\"$outputfile1\" already exists.");
}
my $inputfile = $ARGV[-3];
unless (-e $inputfile) {
	&errorMessage(__LINE__, "\"$inputfile\" does not exist.");
}
my $qualfile;
my $border = 'both';
my %query;
my $queryfile;
my $reversecomplement;
my $maxpmismatch = 0.15;
my $maxnmismatch;
my $makedummy;
my $goscore = -10;
my $gescore = -1;
my $mmscore = -4;
my $mscore = 5;
my $endgap = 'nobody';
for (my $i = 0; $i < scalar(@ARGV) - 3; $i ++) {
	if ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)mismatch=(.+)$/i) {
		$maxpmismatch = $1;
	}
	elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?mismatch=(.+)$/i) {
		$maxnmismatch = $1;
	}
	elsif ($ARGV[$i] =~ /^-+(?:query|q)=(.+)$/i) {
		my $query = uc($1);
		$query =~ s/[^A-Z]//sg;
		$query{$query} = 'query';
	}
	elsif ($ARGV[$i] =~ /^-+queryfile=(.+)$/i) {
		$queryfile = $1;
	}
	elsif ($ARGV[$i] =~ /^-+(?:qual|qualfile|q)=(.+)$/i) {
		$qualfile = $1;
	}
	elsif ($ARGV[$i] =~ /^-+(?:reversecomplement|revcomp)$/i) {
		$reversecomplement = 1;
	}
	elsif ($ARGV[$i] =~ /^-+border=(start|end|both)$/i) {
		$border = lc($1);
	}
	elsif ($ARGV[$i] =~ /^-+g(?:ap)?o(?:pen)?(?:score)?=(-?\d+)$/i) {
		$goscore = $1;
	}
	elsif ($ARGV[$i] =~ /^-+g(?:ap)?e(?:xtension)?(?:score)?=(-?\d+)$/i) {
		$gescore = $1;
	}
	elsif ($ARGV[$i] =~ /^-+m(?:is)?m(?:atch)?(?:score)?=(-?\d+)$/i) {
		$mmscore = $1;
	}
	elsif ($ARGV[$i] =~ /^-+m(?:atch)?(?:score)?=(-?\d+)$/i) {
		$mscore = $1;
	}
	elsif ($ARGV[$i] =~ /^-+endgap=(nobody|match|mismatch|gap)$/i) {
		$endgap = lc($1);
	}
	elsif ($ARGV[$i] =~ /^-+makedummy$/i) {
		$makedummy = 1;
	}
	else {
		&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
	}
}
if (!%query && !$queryfile) {
	&errorMessage(__LINE__, "Query was not specified.");
}
elsif ($queryfile && !-e $queryfile) {
	&errorMessage(__LINE__, "\"$queryfile\" does not exist.");
}
unless ($qualfile) {
	$qualfile = "$inputfile.qual";
}

if ($queryfile) {
	my $queryfilehandle;
	unless (open($queryfilehandle, "< $queryfile")) {
		&errorMessage(__LINE__, "Cannot open \"$queryfile\".");
	}
	local $/ = "\n>";
	while (<$queryfilehandle>) {
		if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
			my $name = $1;
			my $query = uc($2);
			$name =~ s/\s+$//;
			$query =~ s/[> \r\n]//g;
			$query{$query} = $name;
		}
	}
	close($queryfilehandle);
	print(STDERR "Queries\n");
	foreach (keys(%query)) {
		print(STDERR "$query{$_}: $_\n");
	}
}
print(STDERR "\n");

if ($reversecomplement) {
	my %newquery;
	foreach my $query (keys(%query)) {
		my $revcomp = &reversecomplement($query);
		$newquery{$revcomp} = $query{$query};
	}
	undef(%query);
	%query = %newquery;
}

# read input file
my $inputhandle;
unless (open($inputhandle, "< $inputfile")) {
	&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
}
my $outputhandle1;
unless (open($outputhandle1, "> $outputfile1")) {
	&errorMessage(__LINE__, "Cannot write \"$outputfile1\".");
}
my $outputhandle2;
unless (open($outputhandle2, "> $outputfile2")) {
	&errorMessage(__LINE__, "Cannot write \"$outputfile2\".");
}
my $qualhandle;
my $outqualhandle1;
my $outqualhandle2;
if (-e $qualfile) {
	unless (open($qualhandle, "< $qualfile")) {
		&errorMessage(__LINE__, "Cannot open \"$qualfile\".");
	}
	unless (open($outqualhandle1, "> $outputfile1.qual")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfile1.qual\".");
	}
	unless (open($outqualhandle2, "> $outputfile2.qual")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfile2.qual\".");
	}
}
{
	local $/ = "\n>";
	while (<$inputhandle>) {
		if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
			my $taxon = $1;
			my $sequence = $2;
			$taxon =~ s/\s+$//;
			$sequence =~ s/[> \r\n]//g;
			my @qual;
			if (-e $qualfile) {
				local $/ = "\n>";
				my $qualline = readline($qualhandle);
				if ($qualline =~ /^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
					my $temp = $1;
					my $qual = $2;
					$temp =~ s/\s+$//;
					if ($temp eq $taxon) {
						@qual = $qual =~ /\d+/g;
					}
				}
				else {
					&errorMessage(__LINE__, "The quality file is invalid.");
				}
			}
			my @seq = $sequence =~ /\S/g;
			my $seq = join('', @seq);
			my @borderpos;
			foreach my $query (keys(%query)) {
				my ($start, $end, $pmismatch, $nmismatch) = &searchQuery($query, $seq);
				if ((!defined($maxnmismatch) || $nmismatch <= $maxnmismatch) && $pmismatch <= $maxpmismatch) {
					if ($border eq 'start') {
						push(@borderpos, $start);
					}
					elsif ($border eq 'end') {
						push(@borderpos, ($end + 1));
					}
					else {
						push(@borderpos, $start);
						push(@borderpos, ($end + 1));
					}
					last;
				}
			}
			# output an entry
			my $formerseq;
			my $formerqual;
			my $latterseq;
			my $latterqual;
			if (scalar(@borderpos) == 1) {
				$latterseq = join('', splice(@seq, $borderpos[0]));
				if (@qual) {
					$latterqual = join(' ', splice(@qual, $borderpos[0]));
				}
			}
			elsif (scalar(@borderpos) == 2) {
				$latterseq = join('', splice(@seq, $borderpos[1]));
				splice(@seq, $borderpos[0]);
				if (@qual) {
					$latterqual = join(' ', splice(@qual, $borderpos[1]));
					splice(@qual, $borderpos[0])
				}
			}
			$formerseq = join('', @seq);
			if (@qual) {
				$formerqual = join(' ', @qual);
			}
			if ($makedummy) {
				if (!$formerseq) {
					$formerseq = 'A';
				}
				elsif (!$latterseq) {
					$latterseq = 'A';
				}
				if (@qual) {
					if (!$formerqual) {
						$formerqual = 20;
					}
					elsif (!$latterqual) {
						$latterqual = 20;
					}
				}
			}
			print($outputhandle1 ">$taxon\n");
			print($outputhandle1 "$formerseq\n");
			if (@qual) {
				print($outqualhandle1 ">$taxon\n");
				print($outqualhandle1 "$formerqual\n");
			}
			print($outputhandle2 ">$taxon\n");
			print($outputhandle2 "$latterseq\n");
			if (@qual) {
				print($outqualhandle2 ">$taxon\n");
				print($outqualhandle2 "$latterqual\n");
			}
		}
	}
}
close($inputhandle);
close($outputhandle1);
close($outputhandle2);
if (-e $qualfile) {
	close($qualhandle);
	close($outqualhandle1);
	close($outqualhandle2);
}

sub searchQuery {
	my $subject = $_[1];
	my ($newquery, $newsubject) = alignTwoSequences($_[0], $_[1]);
	my $subquery = $newquery;
	my $front = $subquery =~ s/^-+//;
	my $rear = $subquery =~ s/-+$//;
	my $start = rindex($newquery, $subquery);
	my $end;
	my $sublength = length($subquery);
	my $subsubject = substr($newsubject, $start, $sublength);
	my $nmismatch = $sublength;
	for (my $i = 0; $i < $sublength; $i ++) {
		if (&testCompatibility(substr($subquery, $i, 1), substr($subsubject, $i, 1))) {
			$nmismatch --;
		}
	}
	my $pmismatch = $nmismatch / $sublength;
	$subsubject =~ s/-+//g;
	if (!$front) {
		$start = 0;
	}
	else {
		$start = rindex($subject, $subsubject);
	}
	if ($start == -1) {
		$end = -1;
	}
	else {
		$end = $start + length($subsubject) - 1;
	}
	return($start, $end, $pmismatch, $nmismatch);
}

sub alignTwoSequences {
	my @query = split(//, $_[0]);
	my @subject = split(//, $_[1]);
	# align sequences by Needleman-Wunsch algorithm
	{
		my $querylength = scalar(@query);
		my $subjectlength = scalar(@subject);
		# make alignment matrix, gap matrix, route matrix
		my @amatrix;
		my @rmatrix;
		$rmatrix[0][0] = 0;
		$rmatrix[0][1] = 1;
		for (my $i = 2; $i <= $querylength; $i ++) {
			$rmatrix[0][$i] = 1;
		}
		$rmatrix[1][0] = 2;
		for (my $i = 2; $i <= $subjectlength; $i ++) {
			$rmatrix[$i][0] = 2;
		}
		$amatrix[0][0] = 0;
		if ($endgap eq 'gap') {
			$amatrix[0][1] = $goscore;
			for (my $i = 2; $i <= $querylength; $i ++) {
				$amatrix[0][$i] += $amatrix[0][($i - 1)] + $gescore;
			}
			$amatrix[1][0] = $goscore;
			for (my $i = 2; $i <= $subjectlength; $i ++) {
				$amatrix[$i][0] += $amatrix[($i - 1)][0] + $gescore;
			}
		}
		elsif ($endgap eq 'mismatch') {
			$amatrix[0][1] = $mmscore;
			for (my $i = 2; $i <= $querylength; $i ++) {
				$amatrix[0][$i] += $amatrix[0][($i - 1)] + $mmscore;
			}
			$amatrix[1][0] = $mmscore;
			for (my $i = 2; $i <= $subjectlength; $i ++) {
				$amatrix[$i][0] += $amatrix[($i - 1)][0] + $mmscore;
			}
		}
		elsif ($endgap eq 'match') {
			$amatrix[0][1] = $mscore;
			for (my $i = 2; $i <= $querylength; $i ++) {
				$amatrix[0][$i] += $amatrix[0][($i - 1)] + $mscore;
			}
			$amatrix[1][0] = $mscore;
			for (my $i = 2; $i <= $subjectlength; $i ++) {
				$amatrix[$i][0] += $amatrix[($i - 1)][0] + $mscore;
			}
		}
		elsif ($endgap eq 'nobody') {
			$amatrix[0][1] = 0;
			for (my $i = 2; $i <= $querylength; $i ++) {
				$amatrix[0][$i] = 0;
			}
			$amatrix[1][0] = 0;
			for (my $i = 2; $i <= $subjectlength; $i ++) {
				$amatrix[$i][0] = 0;
			}
		}
		# fill matrix
		for (my $i = 1; $i <= $subjectlength; $i ++) {
			for (my $j = 1; $j <= $querylength; $j ++) {
				my @score;
				if (&testCompatibility($query[($j * (-1))], $subject[($i * (-1))])) {
					push(@score, $amatrix[($i - 1)][($j - 1)] + $mscore);
				}
				else {
					push(@score, $amatrix[($i - 1)][($j - 1)] + $mmscore);
				}
				if ($endgap ne 'gap' && ($i == $subjectlength || $j == $querylength)) {
					if ($endgap eq 'mismatch') {
						push(@score, $amatrix[$i][($j - 1)] + $mmscore);
						push(@score, $amatrix[($i - 1)][$j] + $mmscore);
					}
					elsif ($endgap eq 'match') {
						push(@score, $amatrix[$i][($j - 1)] + $mscore);
						push(@score, $amatrix[($i - 1)][$j] + $mscore);
					}
					elsif ($endgap eq 'nobody') {
						push(@score, $amatrix[$i][($j - 1)]);
						push(@score, $amatrix[($i - 1)][$j]);
					}
				}
				else {
					if ($rmatrix[$i][($j - 1)] == 1) {
						push(@score, $amatrix[$i][($j - 1)] + $gescore);
					}
					else {
						push(@score, $amatrix[$i][($j - 1)] + $goscore);
					}
					if ($rmatrix[($i - 1)][$j] == 2) {
						push(@score, $amatrix[($i - 1)][$j] + $gescore);
					}
					else {
						push(@score, $amatrix[($i - 1)][$j] + $goscore);
					}
				}
				if (($score[1] > $score[0] || $score[1] == $score[0] && $i == $subjectlength) && $score[1] > $score[2]) {
					$amatrix[$i][$j] = $score[1];
					$rmatrix[$i][$j] = 1;
				}
				elsif (($score[2] > $score[0] || $score[2] == $score[0] && $j == $querylength) && $score[2] >= $score[1]) {
					$amatrix[$i][$j] = $score[2];
					$rmatrix[$i][$j] = 2;
				}
				else {
					$amatrix[$i][$j] = $score[0];
					$rmatrix[$i][$j] = 0;
				}
			}
		}
		my @newquery;
		my @newsubject;
		my ($ipos, $jpos) = ($subjectlength, $querylength);
		while ($ipos != 0 && $jpos != 0) {
			if ($rmatrix[$ipos][$jpos] == 1) {
				push(@newquery, shift(@query));
				push(@newsubject, '-');
				$jpos --;
			}
			elsif ($rmatrix[$ipos][$jpos] == 2) {
				push(@newquery, '-');
				push(@newsubject, shift(@subject));
				$ipos --;
			}
			else {
				push(@newquery, shift(@query));
				push(@newsubject, shift(@subject));
				$ipos --;
				$jpos --;
			}
		}
		if (@query) {
			while (@query) {
				push(@newquery, shift(@query));
				push(@newsubject, '-');
			}
		}
		elsif (@subject) {
			while (@subject) {
				push(@newquery, '-');
				push(@newsubject, shift(@subject));
			}
		}
		return(join('', @newquery), join('', @newsubject));
	}
}

sub testCompatibility {
	# 0: incompatible
	# 1: compatible
	my ($seq1, $seq2) = @_;
	my $compatibility = 1;
	if ($seq1 ne $seq2) {
		if ($seq1 eq '-' && $seq2 ne '-' ||
			$seq1 ne '-' && $seq2 eq '-' ||
			$seq1 eq 'A' && $seq2 =~ /^[CGTUSYKB]$/ ||
			$seq1 eq 'C' && $seq2 =~ /^[AGTURWKD]$/ ||
			$seq1 eq 'G' && $seq2 =~ /^[ACTUMWYH]$/ ||
			$seq1 =~ /^[TU]$/ && $seq2 =~ /^[ACGMRSV]$/ ||
			$seq1 eq 'M' && $seq2 =~ /^[KGT]$/ ||
			$seq1 eq 'R' && $seq2 =~ /^[YCT]$/ ||
			$seq1 eq 'W' && $seq2 =~ /^[SCG]$/ ||
			$seq1 eq 'S' && $seq2 =~ /^[WAT]$/ ||
			$seq1 eq 'Y' && $seq2 =~ /^[RAG]$/ ||
			$seq1 eq 'K' && $seq2 =~ /^[MAC]$/ ||
			$seq1 eq 'B' && $seq2 eq 'A' ||
			$seq1 eq 'D' && $seq2 eq 'C' ||
			$seq1 eq 'H' && $seq2 eq 'G' ||
			$seq1 eq 'V' && $seq2 =~ /^[TU]$/) {
			$compatibility = 0;
		}
	}
	return($compatibility);
}

sub reversecomplement {
	my @seq = split(/ */, $_[0]);
	@seq = reverse(@seq);
	my $seq = join('', @seq);
	$seq =~ tr/ACGTMRYKVHDBacgtmrykvhdb/TGCAKYRMBDHVtgcakyrmbdhv/;
	return($seq);
}

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
cldivseq options inputfile outputfile1 outputfile2

Command line options
====================
-q, --query=DNA|AA sequence
  Specify a query sequence.

--queryfile=FILENAME
  Specify query sequence list file name. (default: none)

--reversecomplement
  If this option is specified, reverse-complement of query sequence will be
searched. (default: off)

--border=START|END|BOTH
  Specify split border position. (default: both)

--maxpmismatch=DECIMAL
  Specify maximum acceptable mismatch percentage for queries. (default: 0.15)

--maxnmismatch=INTEGER
  Specify maximum acceptable mismatch number for queries.
(default: Inf)

-q, --qualfile=FILENAME
  Specify .qual file name. (default: inputfile.qual)

--makedummy
  If this option is specified, dummy sequence will be output to latter
file when query sequence does not been found.

--gapopenscore=INTEGER
  Specify gap open score for alignment of queries. (default: -10)

--gapextensionscore=INTEGER
  Specify gap extension score for alignment of queries. (default: -1)

--mismatchscore=INTEGER
  Specify mismatch score for alignment of queries. (default: -4)

--matchscore=INTEGER
  Specify match score for alignment of queries. (default: 5)

--endgap=NOBODY|MATCH|MISMATCH|GAP
  Specify end gap treatment. (default: nobody)

Acceptable input file formats
=============================
FASTA (+.qual)
_END
	exit;
}
