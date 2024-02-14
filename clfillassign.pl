use strict;

my $buildno = '0.9.x';

# input/output
my $inputfile;
my $outputfile;

# options
my $fullfill = 0;

# global variables
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'subphylum', 'superclass', 'class', 'subclass', 'infraclass', 'cohort', 'subcohort', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'section', 'subsection', 'series', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma', 'forma specialis', 'strain', 'isolate');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}
my @outheader = @taxrank;
shift(@outheader);

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
	# fill in the blanks
	&fillBlanks();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clfillassign $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-XXXX  Akifumi S. Tanabe

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
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:fill|full|fullfill)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$fullfill = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$fullfill = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	# check input file
	if (!-e $inputfile) {
		&errorMessage(__LINE__, "Input file does not exist.");
	}
	# check output file
	if (-e $outputfile) {
		&errorMessage(__LINE__, "Output file already exists.");
	}
}

sub fillBlanks {
	unless (open($filehandleinput1, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot read \"$inputfile\".");
	}
	unless (open($filehandleoutput1, "> $outputfile")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfile\".");
	}
	my $lineno = 1;
	my @inheader;
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		if ($lineno == 1) {
			if (/\t/) {
				@inheader = split(/\t/, $_, -1);
			}
			else {
				&errorMessage(__LINE__, "");
			}
			if ($fullfill) {
				print($filehandleoutput1 "query\t" . join("\t", @outheader) . "\n");
			}
			else {
				print($filehandleoutput1 join("\t", @inheader) . "\n");
			}
		}
		elsif ($lineno > 1 && /\t/) {
			my @cell = split(/\t/, $_, -1);
			if ($fullfill) {
				my @temp;
				$temp[0] = $cell[0];
				for (my $i = 1; $i < scalar(@cell); $i ++) {
					$temp[$taxrank{$inheader[$i]}] = $cell[$i];
				}
				if (scalar(@temp) < scalar(@taxrank)) {
					$temp[scalar(@outheader)] = '';
				}
				@cell = @temp;
			}
			my $taxon;
			# fill upward
			for (my $i = -1; $i * (-1) < scalar(@cell); $i --) {
				if ($taxon && $cell[$i] eq '') {
					$cell[$i] = $taxon;
				}
				elsif ($cell[$i]) {
					$taxon = $cell[$i];
				}
			}
			undef($taxon);
			# fill downward
			for (my $i = 1; $i < scalar(@cell); $i ++) {
				if ($taxon && $cell[$i] eq '') {
					$cell[$i] = "unidentified $taxon";
				}
				elsif ($cell[$i]) {
					$taxon = $cell[$i];
				}
			}
			print($filehandleoutput1 join("\t", @cell) . "\n");
		}
		else {
			print($filehandleoutput1 $_);
		}
		$lineno ++;
	}
	close($filehandleoutput1);
	close($filehandleinput1);
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
clfillassign inputfile outputfile

Command line options
====================
--fullfill=ENABLE|DISABLE
  Specify whether all taxonomic ranks need to be filled or not.
(default: DISABLE)

Acceptable input file formats
=============================
Output of classigntax
(Tab-delimited texts)
_END
	exit;
}

