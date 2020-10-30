use strict;

my $buildno = '0.2.x';

# options
my $unit = 0;
my $topN;

# Input/Output
my $inputfile;
my $outputfile;
my $taxonomyfile;

# other variables
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'superclass', 'class', 'subclass', 'infraclass', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}

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
	# read taxonomy file
	&readTaxonomyFile();
	# read input file
	&readInputFile();
	# make output file
	&saveSummary();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clsumtaxa $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2020  Akifumi S. Tanabe

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
	$inputfile = $ARGV[-2];
	$outputfile = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:unit|rank|taxrank|level|taxlevel)=(.+)$/i) {
			my $taxrank = $1;
			if ($taxrank{$taxrank}) {
				$unit = $taxrank{$taxrank};
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+topN=(\d+)$/i) {
			$topN = $1;
		}
		elsif ($ARGV[$i] =~ /^-+taxonomyfile?=(.+)$/i) {
			if (-e $1) {
				$taxonomyfile = $1;
			}
			else {
				&errorMessage(__LINE__, "The taxonomy file does not exist.");
			}
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	unless (-e $inputfile) {
		&errorMessage(__LINE__, "\"$inputfile\" does not exist.");
	}
	if (-e $outputfile) {
		&errorMessage(__LINE__, "Output file already exists.");
	}
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
clrecoverseqv options inputfiles outputfolder

Command line options
====================
--minident=DECIMAL
  Specify the minimum identity threshold. (default: 0.97)

--strand=PLUS|BOTH
  Specify search strand option for VSEARCH. (default: PLUS)

--centroid=FILENAME
  Specify the centroid sequence file. (default: none)

--paddinglen=INTEGER
  Specify the length of padding. (default: 0)

--minovllen=INTEGER
  Specify minimum overlap length. 0 means automatic. (default: 0)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
