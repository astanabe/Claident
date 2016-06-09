use strict;
use Fcntl ':flock';
use File::Spec;

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
my $compress = 'gz';
my $append;
my $numthreads = 1;

# Input/Output
my $inputfile;
my $outputfolder;

# other variables
my @inputfiles;
my %in2out;

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
	# read input file
	&readInputFile();
	# process FASTQ files
	&processFASTQ();
}

sub printStartupMessage {
	print(STDERR <<"_END");
climportfastq $buildno
=======================================================================

Official web site of this script is
http://www.fifthdimension.jp/products/claident/ .
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
}

sub getOptions {
	$inputfile = $ARGV[-2];
	unless (-e $inputfile) {
		&errorMessage(__LINE__, "\"$inputfile\" does not exist.");
	}
	$outputfolder = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+compress=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:g|gz|gzip)$/i) {
				$compress = 'gz';
			}
			elsif ($value =~ /^(?:b|bz|bz2|bzip|bzip2)$/i) {
				$compress = 'bz2';
			}
			elsif ($value =~ /^(?:x|xz)$/i) {
				$compress = 'xz';
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$compress = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:a|append)$/i) {
			$append = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	if (!$append && -e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
}

sub readInputFile {
	print(STDERR "Reading input file...\n");
	my %tempin;
	my %tempout;
	unless (open($filehandleinput1, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
	}
	while (<$filehandleinput1>) {
		if (/^(\S+)\s+(\S+)/) {
			my $tempin = $1;
			my $tempout = $2;
			if ($tempout =~ /\//) {
				&errorMessage(__LINE__, "The output file name \"$tempout\" is invalid.");
			}
			{
				my @tempout = split(/__/, $tempout);
				if (scalar(@tempout) != 3) {
					&errorMessage(__LINE__, "The output file name \"$tempout\" is invalid.");
				}
			}
			if ($tempin{$tempin}) {
				&errorMessage(__LINE__, "The input file \"$tempin\" is doubly specified.");
			}
			else {
				$tempin{$tempin} = 1;
			}
			if ($tempout{$tempout}) {
				&errorMessage(__LINE__, "The output file \"$tempout\" is doubly specified.");
			}
			else {
				$tempout{$tempout} = 1;
			}
			$in2out{$tempin} = $tempout;
			push(@inputfiles, $tempin);
		}
	}
	close($filehandleinput1);
	print(STDERR "done.\n\n");
}

sub processFASTQ {
	print(STDERR "Processing FASTQs...\n");
	if (!-e $outputfolder && !mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
	}
	foreach my $tempin (@inputfiles) {
		print(STDERR "Processing \"$tempin\"...");
		{
			$filehandleinput1 = &readFile($tempin);
			my $tempnline = 1;
			my $seqname;
			my $nucseq;
			my $qualseq;
			my %child;
			my %pid;
			my $child = 0;
			$| = 1;
			$? = 0;
			# Processing FASTQ in parallel
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				if ($tempnline % 4 == 1 && /^\@(\S+)/) {
					$seqname = $1;
					if ($seqname =~ /__/) {
						&errorMessage(__LINE__, "\"$seqname\" is invalid name. Do not use \"__\" in sequence name.\nFile: $inputfiles[0]\nLine: $tempnline");
					}
				}
				elsif ($tempnline % 4 == 2) {
					s/[^a-zA-Z]//g;
					$nucseq = uc($_);
				}
				elsif ($tempnline % 4 == 3 && /^\+/) {
					$tempnline ++;
					next;
				}
				elsif ($tempnline % 4 == 0 && $seqname && $nucseq) {
					s/\s//g;
					$qualseq = $_;
					if (my $pid = fork()) {
						for (my $i = 0; $i < $numthreads * 2; $i ++) {
							if (!exists($child{$i})) {
								$child{$i} = 1;
								$pid{$pid} = $i;
								$child = $i;
								last;
							}
						}
						my @child = keys(%child);
						if (scalar(@child) == $numthreads * 2) {
							my $endpid = wait();
							if ($endpid == -1) {
								undef(%child);
								undef(%pid);
							}
							else {
								delete($child{$pid{$endpid}});
								delete($pid{$endpid});
							}
						}
						if ($?) {
							&errorMessage(__LINE__);
						}
						undef($seqname);
						undef($nucseq);
						undef($qualseq);
						$tempnline ++;
						next;
					}
					else {
						if (!-e "$outputfolder/$in2out{$tempin}") {
							mkdir("$outputfolder/$in2out{$tempin}");
						}
						unless (open($filehandleoutput1, ">> $outputfolder/$in2out{$tempin}/$child.fastq")) {
							&errorMessage(__LINE__, "Cannot write \"$outputfolder/$in2out{$tempin}/$child.fastq\".");
						}
						unless (flock($filehandleoutput1, LOCK_EX)) {
							&errorMessage(__LINE__, "Cannot lock \"$outputfolder/$in2out{$tempin}/$child.fastq\".");
						}
						unless (seek($filehandleoutput1, 0, 2)) {
							&errorMessage(__LINE__, "Cannot seek \"$outputfolder/$in2out{$tempin}/$child.fastq\".");
						}
						print($filehandleoutput1 "\@$seqname\__$in2out{$tempin}\n$nucseq\n+\n$qualseq\n");
						close($filehandleoutput1);
						exit;
					}
				}
				else {
					&errorMessage(__LINE__, "Invalid FASTQ.\nFile: $inputfiles[0]\nLine: $tempnline");
				}
				$tempnline ++;
			}
			close($filehandleinput1);
			# join processes
			while (wait != -1) {
				if ($?) {
					&errorMessage(__LINE__, 'Cannot split sequence file correctly.');
				}
			}
		}
		# join files
		{
			if ($compress) {
				$filehandleoutput1 = writeFile("$outputfolder/$in2out{$tempin}.fastq.$compress");
			}
			else {
				$filehandleoutput1 = writeFile("$outputfolder/$in2out{$tempin}.fastq");
			}
			foreach my $fastq (glob("$outputfolder/$in2out{$tempin}/*.fastq")) {
				unless (open($filehandleinput1, "< $fastq")) {
					&errorMessage(__LINE__, "Cannot open \"$fastq\".");
				}
				while (<$filehandleinput1>) {
					print($filehandleoutput1 $_);
				}
				close($filehandleinput1);
				unlink($fastq);
			}
			close($filehandleoutput1);
			rmdir("$outputfolder/$in2out{$tempin}");
		}
		print(STDERR "done.\n");
	}
	print(STDERR "done.\n\n");
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

sub writeFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "| gzip -c >> $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "| bzip2 -c >> $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "| xz -c >> $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	else {
		unless (open($filehandle, ">> $filename")) {
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
climportfastq options inputfile outputfolder

Command line options
====================
--compress=GZIP|BZIP2|XZ|DISABLE
  Specify compress output files or not. (default: GZIP)

-a, --append
  Specify outputfile append or not. (default: off)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
Tab-delimited text like below.

inputfilename	samplename

Note that samplename must be compliant with the following style.

RunID__TagID__PrimerID

Acceptable sequence file formats
================================
FASTQ (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
(Quality values must be encoded in Sanger format.)
_END
	exit;
}
