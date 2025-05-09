use strict;
use File::Spec;

my $devnull = File::Spec->devnull();

my $buildno = '0.9.x';

#input/output
my $inputfile;
my $outputfile;

# options
my $runname;
my $tableformat = 'matrix';

# global variables
my %table;
my @otunames;
my @samplenames;

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
	# read otu file
	&readMembers();
	# save summary
	&saveSummary();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clsumclass $buildno
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
		if ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$runname = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:o|output|tableformat)=(.+)$/i) {
			if ($1 =~ /^matrix$/i) {
				$tableformat = 'matrix';
			}
			elsif ($1 =~ /^column$/i) {
				$tableformat = 'column';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
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

sub readMembers {
	# read input file
	$filehandleinput1 = &readFile($inputfile);
	my $otuname;
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;+size=\d+;*//g;
		if (/^>(.+)$/) {
			$otuname = $1;
			push(@otunames, $otuname);
		}
		elsif ($otuname && / SN:(\S+)/) {
			my $samplename = $1;
			my @temp = split(/__/, $samplename);
			if (scalar(@temp) == 3) {
				my ($temprunname, $tag, $primer) = @temp;
				if ($runname) {
					$temprunname = $runname;
				}
				$table{"$temprunname\__$tag\__$primer"}{$otuname} ++;
			}
			else {
				&errorMessage(__LINE__, "\"$_\" is invalid name.");
			}
		}
		else {
			&errorMessage(__LINE__, "\"$inputfile\" is invalid.");
		}
	}
	close($filehandleinput1);
}

sub saveSummary {
	@otunames = sort({$a cmp $b} @otunames);
	@samplenames = sort({$a cmp $b} keys(%table));
	# save output file
	unless (open($filehandleoutput1, "> $outputfile")) {
		&errorMessage(__LINE__, "Cannot make \"$outputfile\".");
	}
	if ($tableformat eq 'matrix') {
		print($filehandleoutput1 "samplename\t" . join("\t", @otunames) . "\n");
		foreach my $samplename (@samplenames) {
			print($filehandleoutput1 $samplename);
			foreach my $otuname (@otunames) {
				if ($table{$samplename}{$otuname}) {
					print($filehandleoutput1 "\t$table{$samplename}{$otuname}");
				}
				else {
					print($filehandleoutput1 "\t0");
				}
			}
			print($filehandleoutput1 "\n");
		}
	}
	elsif ($tableformat eq 'column') {
		print($filehandleoutput1 "samplename\totuname\tnreads\n");
		foreach my $samplename (@samplenames) {
			foreach my $otuname (@otunames) {
				if ($table{$samplename}{$otuname}) {
					print($filehandleoutput1 "$samplename\t$otuname\t$table{$samplename}{$otuname}\n");
				}
			}
		}
	}
	close($filehandleoutput1);
}

sub readFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "pigz -p 8 -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "pbzip2 -p8 -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "xz -T 8 -dc $filename 2> $devnull |")) {
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
clsumclass options inputfile outputfile

Command line options
====================
--tableformat=COLUMN|MATRIX
  Specify output table format. (default: MATRIX)

--runname=RUNNAME
  Specify run name for replacing run name.
(default: given by sequence name)

Acceptable input file formats
=============================
otu.gz
_END
	exit;
}
