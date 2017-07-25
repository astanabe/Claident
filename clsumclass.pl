use strict;
use File::Spec;

my $devnull = File::Spec->devnull();

my $buildno = '0.2.x';

#input/output
my $inputfile;
my $outputfile;

# options
my $runname;
my $outformat = 'Matrix';

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
	# read contigmembers or otu file
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

Copyright (C) 2011-2017  Akifumi S. Tanabe

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
		elsif ($ARGV[$i] =~ /^-+(?:o|output)=(.+)$/i) {
			if ($1 =~ /^Matrix$/i) {
				$outformat = 'Matrix';
			}
			elsif ($1 =~ /^Column$/i) {
				$outformat = 'Column';
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
	my $format;
	# read input file
	$filehandleinput1 = &readFile($inputfile);
	while (<$filehandleinput1>) {
		if (/\t/) {
			$format = 'contigmembers';
			last;
		}
		elsif (/^>/) {
			$format = 'otu';
			last;
		}
		else {
			&errorMessage(__LINE__, "The input file is unknown format.");
		}
	}
	close($filehandleinput1);
	# read input file again
	$filehandleinput1 = &readFile($inputfile);
	# if input file is contigmembers
	if ($format eq 'contigmembers') {
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if (my @row = split(/\t/)) {
				if (scalar(@row) > 2) {
					my $otuname = shift(@row);
					push(@otunames, $otuname);
					foreach my $contigmember (@row) {
						my @temp = split(/__/, $contigmember);
						if (scalar(@temp) == 3) {
							my ($temp, $temprunname, $primer) = @temp;
							if ($runname) {
								$temprunname = $runname;
							}
							$table{"$temprunname\__$primer"}{$otuname} ++;
						}
						elsif (scalar(@temp) == 4) {
							my ($temp, $temprunname, $tag, $primer) = @temp;
							if ($runname) {
								$temprunname = $runname;
							}
							$table{"$temprunname\__$tag\__$primer"}{$otuname} ++;
						}
						else {
							&errorMessage(__LINE__, "\"$contigmember\" is invalid name.");
						}
					}
				}
				elsif (scalar(@row) == 2) {
					push(@otunames, $row[1]);
					my @temp = split(/__/, $row[1]);
					if (scalar(@temp) == 3) {
						my ($temp, $temprunname, $primer) = @temp;
						if ($runname) {
							$temprunname = $runname;
						}
						$table{"$temprunname\__$primer"}{$row[1]} ++;
					}
					elsif (scalar(@temp) == 4) {
						my ($temp, $temprunname, $tag, $primer) = @temp;
						if ($runname) {
							$temprunname = $runname;
						}
						$table{"$temprunname\__$tag\__$primer"}{$row[1]} ++;
					}
					else {
						&errorMessage(__LINE__, "\"$row[1]\" is invalid name.");
					}
				}
				else {
					&errorMessage(__LINE__, "Invalid assemble results.\nInput file: $inputfile\nContig: $row[0]\n");
				}
			}
		}
	}
	elsif ($format eq 'otu') {
		my $otuname;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;?//g;
			if (/^>(.+)$/) {
				$otuname = $1;
				push(@otunames, $otuname);
				my @temp = split(/__/, $otuname);
				if (scalar(@temp) == 3) {
					my ($temp, $temprunname, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$primer"}{$otuname} ++;
				}
				elsif (scalar(@temp) == 4) {
					my ($temp, $temprunname, $tag, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$tag\__$primer"}{$otuname} ++;
				}
				else {
					&errorMessage(__LINE__, "\"$otuname\" is invalid name.");
				}
			}
			elsif ($otuname && /^([^>].*)$/) {
				my $otumember = $1;
				my @temp = split(/__/, $otumember);
				if (scalar(@temp) == 3) {
					my ($temp, $temprunname, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$primer"}{$otuname} ++;
				}
				elsif (scalar(@temp) == 4) {
					my ($temp, $temprunname, $tag, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$tag\__$primer"}{$otuname} ++;
				}
				else {
					&errorMessage(__LINE__, "\"$otumember\" is invalid name.");
				}
			}
			else {
				&errorMessage(__LINE__, "\"$inputfile\" is invalid.");
			}
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
	if ($outformat eq 'Matrix') {
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
	elsif ($outformat eq 'Column') {
		print($filehandleoutput1 "samplename\totuname\tnreads\n");
		foreach my $samplename (@samplenames) {
			foreach my $otuname (@otunames) {
				if ($table{$samplename}{$otuname}) {
					print($filehandleoutput1 "$samplename\t$otuname\t$table{$samplename}{$otuname}\n");
				}
				else {
					print($filehandleoutput1 "$samplename\t$otuname\t0\n");
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
clsumclass options inputfile outputfile

Command line options
====================
--output=COLUMN|MATRIX
  Specify output format. (default: MATRIX)

--runname=RUNNAME
  Specify run name for replacing run name.
(default: given by sequence name)

Acceptable input file formats
=============================
contigmembers.txt
contigmembers.gz
otu.gz
_END
	exit;
}
