use strict;
use File::Copy::Recursive ('fcopy', 'rcopy', 'dircopy');

my $buildno = '0.2.2016.04.07';

# input/output
my $inputfile;
my $outputfile;

# options
my $numthreads = 1;
my $maxpchimera = 0;
my $maxnchimera;
my $vsearchoption;
my $addrevcomp = 1;

# file handles
my $filehandleinput1;
my $filehandleoutput1;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# delete chimeric sequences
	&deleteChimericSequences();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clmakeuchimedb $buildno
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
}

sub getOptions {
	# get input file name
	$inputfile = $ARGV[-2];
	# get output file name
	$outputfile = $ARGV[-1];
	# read command line options
	my $vsearchmode = 0;
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] eq 'end') {
			$vsearchmode = 0;
		}
		elsif ($vsearchmode) {
			$vsearchoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ 'vsearch') {
			$vsearchmode = 1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)chimeras?=(.+)$/i) {
			$maxpchimera = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?chimeras?=(\d+)$/i) {
			$maxnchimera = $1;
		}
		elsif ($ARGV[$i] =~ /^-+addrevcomp=(enable|disable|yes|no|true|false|E|D|Y|N|T|F)/i) {
			if ($1 =~ /^(?:enable|yes|true|E|Y|T)$/i) {
				$addrevcomp = 1;
			}
			elsif ($1 =~ /^(?:disable|no|false|D|N|F)$/i) {
				$addrevcomp = 0;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
		}
	}
}

sub checkVariables {
	if (!$inputfile) {
		&errorMessage(__LINE__, "The input file name is not specified.");
	}
	if (!-e $inputfile) {
		&errorMessage(__LINE__, "The input file does not exist.");
	}
	if (!$outputfile) {
		&errorMessage(__LINE__, "The output file name is not specified.");
	}
	if (-e $outputfile) {
		&errorMessage(__LINE__, "The output file already exists.");
	}
	my @temp = glob("$outputfile.*");
	if (@temp) {
		&errorMessage(__LINE__, "The temporary file already exists.");
	}
	if ($maxpchimera >= 1 || $maxpchimera < 0) {
		&errorMessage(__LINE__, "The maximum acceptable percentage of chimeras is invalid.");
	}
	if ($maxnchimera < 0) {
		&errorMessage(__LINE__, "The maximum acceptable number of chimeras is invalid.");
	}
	if ($numthreads < 1) {
		&errorMessage(__LINE__, "The number of threads is invalid.");
	}
	if ($vsearchoption =~ /-(?:chimeras|db|nonchimeras|uchime_denovo|uchime_ref|uchimealns|uchimeout|uchimeout5|centroids|cluster_fast|cluster_size|cluster_smallmem|clusters|consout|cons_truncate|derep_fulllength|sortbylength|sortbysize|output|allpairs_global|shuffle)/) {
		&errorMessage(__LINE__, "The option for vsearch is invalid.");
	}
	if ($vsearchoption !~ /-threads /) {
		$vsearchoption .= " --threads $numthreads";
	}
	if ($vsearchoption !~ /-fasta_width /) {
		$vsearchoption .= " --fasta_width 999999";
	}
	if ($vsearchoption !~ /-maxseqlength /) {
		$vsearchoption .= " --maxseqlength 50000";
	}
	if ($vsearchoption !~ /-minseqlength /) {
		$vsearchoption .= " --minseqlength 32";
	}
	if ($vsearchoption !~ /-notrunclabels/) {
		$vsearchoption .= " --notrunclabels";
	}
	if ($vsearchoption !~ /-self/) {
		$vsearchoption .= " --self";
	}
	if ($vsearchoption !~ /-selfid/) {
		$vsearchoption .= " --selfid";
	}
	if ($vsearchoption !~ /-abskew /) {
		$vsearchoption .= " --abskew 2.0";
	}
	if ($vsearchoption !~ /-dn /) {
		$vsearchoption .= " --dn 1.4";
	}
	if ($vsearchoption !~ /-mindiffs /) {
		$vsearchoption .= " --mindiffs 3";
	}
	if ($vsearchoption !~ /-mindiv /) {
		$vsearchoption .= " --mindiv 0.8";
	}
	if ($vsearchoption !~ /-minh /) {
		$vsearchoption .= " --minh 0.28";
	}
	if ($vsearchoption !~ /-xn /) {
		$vsearchoption .= " --xn 8.0";
	}
	print(STDERR "Command line options for vsearch :$vsearchoption\n\n");
}

sub deleteChimericSequences {
	my $niter = 1;
	my $continueflag = 1;
	while ($continueflag) {
		my $inputfasta;
		if ($niter == 1) {
			$inputfasta = $inputfile;
		}
		else {
			$inputfasta = $outputfile . '.' . ($niter - 1) . '.fasta';
		}
		if (system("vsearch$vsearchoption --uchime_ref $inputfasta --db $inputfasta --nonchimeras $outputfile.$niter.fasta --uchimeout $outputfile.$niter.txt")) {
			&errorMessage(__LINE__, "Cannot run vsearch correctly.");
		}
		unless (open($filehandleinput1, "< $outputfile.$niter.txt")) {
			&errorMessage(__LINE__, "Cannot read \"$outputfile.$niter.txt\".");
		}
		my $chimera = 0;
		my $nonchimera = 0;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if (/Y$/) {
				$chimera ++;
			}
			elsif (/N$/) {
				$nonchimera ++;
			}
		}
		close($filehandleinput1);
		if ((!defined($maxnchimera) || $chimera <= $maxnchimera) && ($chimera / ($chimera + $nonchimera)) <= $maxpchimera) {
			$continueflag = 0;
			last;
		}
		else {
			$niter ++;
		}
	}
	{
		my $inputfasta;
		if ($niter == 1) {
			$inputfasta = $inputfile;
		}
		else {
			$inputfasta = $outputfile . '.' . ($niter - 1) . '.fasta';
		}
		my $outputfasta = $outputfile;
		$outputfasta =~ s/\.(?:gz|bz2|xz)$//;
		unless (fcopy($inputfasta, $outputfasta)) {
			&errorMessage(__LINE__, "Cannot copy \"$inputfasta\" to \"$outputfasta\".");
		}
		if ($addrevcomp) {
			unless (open($filehandleinput1, "< $inputfasta")) {
				&errorMessage(__LINE__, "Cannot read \"$inputfasta\".");
			}
			unless (open($filehandleoutput1, ">> $outputfasta")) {
				&errorMessage(__LINE__, "Cannot write \"$outputfasta\".");
			}
			local $/ = "\n>";
			while (<$filehandleinput1>) {
				if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
					my $seqname = $1;
					my $sequence = $2;
					my @sequence = $sequence =~ /[a-zA-Z]/g;
					print($filehandleoutput1 ">$seqname\n" . join('', &reversecomplement(@sequence)) . "\n");
				}
			}
			close($filehandleoutput1);
			close($filehandleinput1);
		}
		if ($outputfasta ne $outputfile) {
			if ($outputfile =~ /\.gz$/) {
				if (system("gzip $outputfasta")) {
					&errorMessage(__LINE__, "Cannot run gzip.");
				}
			}
			elsif ($outputfile =~ /\.bz2$/) {
				if (system("bzip2 $outputfasta")) {
					&errorMessage(__LINE__, "Cannot run bzip2.");
				}
			}
			elsif ($outputfile =~ /\.xz$/) {
				if (system("xz $outputfasta")) {
					&errorMessage(__LINE__, "Cannot run xz.");
				}
			}
		}
	}
	for (my $i = 0; $i <= $niter; $i ++) {
		unlink("$outputfile.$i.fasta");
		unlink("$outputfile.$i.txt");
	}
}

sub reversecomplement {
	my @temp = @_;
	my @seq;
	foreach my $seq (reverse(@temp)) {
		$seq =~ tr/ACGTMRYKVHDBacgtmrykvhdb/TGCAKYRMBDHVtgcakyrmbdhv/;
		push(@seq, $seq);
	}
	return(@seq);
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
clmakeuchimedb options inputfile outputfile

Command line options
====================
vsearch options end
  Specify options for vsearch.

--maxpchimera=DECIMAL
  Specify maximum acceptable percentage of chimeras. (default: 0)

--maxnchimera=INTEGER
  Specify maximum acceptable number of chimeras. (default: Inf)

--addrevcomp=ENABLE|DISABLE
  Specify whether reverse-complement sequences should be added or not.
(default: ENABLE)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, or bzip2-compressed)
_END
	exit;
}
