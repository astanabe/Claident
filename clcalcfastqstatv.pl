use strict;
use File::Spec;
use Fcntl ':flock';

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

# global variable
my $vsearchoption = " --fastq_qmax 93";

# options
my $mode = 2;

# input/output
my $output;
my @inputfiles;

# commands
my $vsearch;

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
	# filter sequences
	&filterSequences();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clcalcfastqstatv $buildno
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
	# get arguments
	$output = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:mode|m)=(\d+)$/i) {
			$mode = $1;
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
	{
		my @newinputfiles;
		my @tempinputfiles;
		foreach my $inputfile (@inputfiles) {
			if (-d $inputfile) {
				my @temp = sort(glob("$inputfile/*.fastq"), glob("$inputfile/*.fastq.gz"), glob("$inputfile/*.fastq.bz2"), glob("$inputfile/*.fastq.xz"));
				for (my $i = 0; $i < scalar(@temp); $i ++) {
					if (-e $temp[$i]) {
						push(@newinputfiles, $temp[$i]);
					}
					else {
						&errorMessage(__LINE__, "The input files \"$temp[0]\" and \"$temp[1]\" are invalid.");
					}
				}
			}
			elsif (-e $inputfile) {
				push(@newinputfiles, $inputfile);
			}
			else {
				&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
			}
		}
		@inputfiles = @newinputfiles;
	}
	if (-e $output) {
		&errorMessage(__LINE__, "\"$output\" already exists.");
	}
	if ($mode < 0 || $mode > 2) {
		&errorMessage(__LINE__, "The mode \"$mode\" is invalid.");
	}
	# search vsearch
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
			$vsearch = "\"$pathto/vsearch\"";
		}
		else {
			$vsearch = 'vsearch';
		}
	}
	# initialize vsearch options
	if ($mode == 0) {
		$vsearchoption .= " --log $output --fastq_stats -";
	}
	elsif ($mode == 1) {
		$vsearchoption .= " --output $output --fastq_eestats -";
	}
	elsif ($mode == 2) {
		$vsearchoption .= " --output $output --fastq_eestats2 - --length_cutoffs \"5,*,5\"";
	}
}

sub filterSequences {
	print(STDERR "Calculating statistics using VSEARCH...\n");
	unless (open($pipehandleoutput1, "| $vsearch$vsearchoption")) {
		&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption\".");
	}
	for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
		$filehandleinput1 = &readFile($inputfiles[$i]);
		while (<$filehandleinput1>) {
			print($pipehandleoutput1 $_);
		}
	}
	close($pipehandleoutput1);
	&compressFileByName($output);
	print(STDERR "done.\n\n");
}

sub compressFileByName {
	my $outputfile = shift(@_);
	if ($outputfile =~ /\.gz$/) {
		my $temp = $outputfile;
		$temp =~ s/\.gz$//;
		unless (rename($outputfile, $temp)) {
			&errorMessage(__LINE__, "Cannot rename \"$outputfile\" to \"$temp\".");
		}
		if (system("gzip $temp")) {
			&errorMessage(__LINE__, "Cannot run \"gzip $temp\".");
		}
	}
	elsif ($outputfile =~ /\.bz2$/) {
		my $temp = $outputfile;
		$temp =~ s/\.bz2$//;
		unless (rename($outputfile, $temp)) {
			&errorMessage(__LINE__, "Cannot rename \"$outputfile\" to \"$temp\".");
		}
		if (system("bzip2 $temp")) {
			&errorMessage(__LINE__, "Cannot run \"bzip2 $temp\".");
		}
	}
	elsif ($outputfile =~ /\.xz$/) {
		my $temp = $outputfile;
		$temp =~ s/\.xz$//;
		unless (rename($outputfile, $temp)) {
			&errorMessage(__LINE__, "Cannot rename \"$outputfile\" to \"$temp\".");
		}
		if (system("xz $temp")) {
			&errorMessage(__LINE__, "Cannot run \"xz $temp\".");
		}
	}
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
clcalcfastqstatv options inputfolder outputfile
clcalcfastqstatv options inputfile1 inputfile2 ... inputfileN outputfile
clcalcfastqstatv options forwardread reverseread outputfile

Command line options
====================
-m, --mode=0|1|2
  Specify the statistics calculation mode. These number corresponds to
\"fastq_stats\", \"fastq_eestats\" and \"fastq_eestats2\", respectively.
(default: 2)

Acceptable input file formats
=============================
FASTQ (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
