use strict;
use File::Spec;

my $buildno = '0.9.x';

# input/output
my @inputfiles;
my @otufiles;
my $outputfolder;

# options
my $mode = 'eliminate';
my $tagfile;
my $reversetagfile;
my $reversecomplement;
my $siglevel = 0.05;
my $tagjump = 'half';
my $tableformat = 'matrix';

# the other global variables
my $devnull = File::Spec->devnull();
my %table;
my %tag;
my $taglength;
my %reversetag;
my $reversetaglength;
my %blanklist;
my %ignorelist;
my $blanklist;
my $ignorelist;
my %samplenames;
my %sample2blank;
my %blanksamples;
my %otunames;

# file handles
my $filehandleinput1;
my $filehandleinput2;
my $filehandleinput3;
my $filehandleoutput1;
my $filehandleoutput2;
my $filehandleoutput3;
my $pipehandleinput1;
my $pipehandleinput2;
my $pipehandleoutput1;
my $pipehandleoutput2;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clfilterclass $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2023  Akifumi S. Tanabe

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
	$outputfolder = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+tableformat=(.+)$/i) {
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
			my @temp = glob($ARGV[$i]);
			if (scalar(@temp) > 0) {
				foreach (@temp) {
					if (!exists($inputfiles{$_})) {
						$inputfiles{$_} = 1;
						push(@inputfiles, $_);
					}
					else {
						&errorMessage(__LINE__, "\"$_\" is doubly specified.");
					}
				}
			}
			else {
				&errorMessage(__LINE__, "Input file does not exist.");
			}
		}
	}
}

sub checkVariables {
	if (!@inputfiles) {
		&errorMessage(__LINE__, "No input file was specified.");
	}
	&errorMessage(__LINE__, "This command is under construction.");
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
clfilterclass options inputfolder outputfolder
clfilterclass options inputfile outputfolder

Command line options
====================
--taxfile=FILENAME
  Specify output of classigntax. (default: none)

--includetaxa=NAME(,NAME..)
  Specify include taxa by scientific name. (default: none)

--excludetaxa=NAME(,NAME..)
  Specify exclude taxa by scientific name. (default: none)

--otu=OTUNAME,...,OTUNAME
  Specify output OTU names. The unspecified OTUs will be deleted.

--negativeotu=OTUNAME,...,OTUNAME
  Specify delete OTU names. The specified OTUs will be deleted.

--sample=SAMPLENAME,...,SAMPLENAME
  Specify output sample names. The unspecified samples will be deleted.

--negativesample=SAMPLENAME,...,SAMPLENAME
  Specify delete sample names. The specified samples will be deleted.

--otulist=FILENAME
  Specify output OTU list file name. The file must contain 1 OTU name
at a line.

--negativeotulist=FILENAME
  Specify delete OTU list file name. The file must contain 1 OTU name
at a line.

--otuseq=FILENAME
  Specify output OTU sequence file name. The file must contain 1 OTU
name at a line.

--negativeotuseq=FILENAME
  Specify delete OTU sequence file name. The file must contain 1 OTU
name at a line.

--samplelist=FILENAME
  Specify output sample list file name. The file must contain 1 sample
name at a line.

--negativesamplelist=FILENAME
  Specify delete sample list file name. The file must contain 1 sample
name at a line.

--minnseqotu=INTEGER
  Specify minimum number of sequences of OTU. If the number of
sequences of a OTU is smaller than this value at all samples, the
OTU will be omitted. (default: 0)

--minnseqsample=INTEGER
  Specify minimum number of sequences of sample. If the number of
sequences of a sample is smaller than this value at all OTUs, the
sample will be omitted. (default: 0)

--minntotalseqotu=INTEGER
  Specify minimum total number of sequences of OTU. If the total
number of sequences of a OTU is smaller than this value, the OTU
will be omitted. (default: 0)

--minntotalseqsample=INTEGER
  Specify minimum total number of sequences of sample. If the total
number of sequences of a sample is smaller than this value, the sample
will be omitted. (default: 0)

--minpseqotu=DECIMAL
  Specify minimum percentage of sequences of OTU. If the number of
sequences of a OTU / the total number of sequences of a OTU is
smaller than this value at all samples, the OTU will be omitted.
(default: 0)

--minpseqsample=DECIMAL
  Specify minimum percentage of sequences of sample. If the number of
sequences of a sample / the total number of sequences of a sample is
smaller than this value at all OTUs, the sample will be omitted.
(default: 0)

--replicatelist=FILENAME
  Specify the list file of PCR replicates. (default: none)

--minnreplicate=INTEGER
  Specify the minimum number of \"presense\" replicates required for clean
and nonchimeric OTUs. (default: 2)

--minpreplicate=DECIMAL
  Specify the minimum percentage of \"presense\" replicates per sample
required for clean and nonchimeric OTUs. (default: 1)

--minnpositive=INTEGER
  The OTU that consists of this number of reads will be treated as true
positive in noise/chimera detection. (default: 1)

--minppositive=DECIMAL
  The OTU that consists of this proportion of reads will be treated as true
positive in noise/chimera detection. (default: 0)

--runname=RUNNAME
  Specify run name for replacing run name.
(default: given by sequence name)

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: MATRIX)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, or bzip2-compressed)
_END
	exit;
}
