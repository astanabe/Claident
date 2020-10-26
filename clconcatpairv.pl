use strict;
use File::Spec;
use Fcntl ':flock';

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# global variable
my $vsearch5doption = " --fastq_qmax 93 --fastq_qmaxout 93 --fastq_allowmergestagger";

# options
my $folder = 0;
my $maxnmismatch = 99999;
my $maxpmismatch = 0.5;
my $minovllen = 10;
my $minlen = 1;
my $minqual = 0;
my $compress = 'gz';
my $mode = 'ovl';
my $padding = 'ACGTACGTACGTACGT';
my $numthreads = 1;
my $nodel;
my $append;

# input/output
my $output;
my @inputfiles;

# commands
my $vsearch5d;

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
	# concatenate sequences
	&concatenateSequences();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clconcatpairv $buildno
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
		if ($ARGV[$i] =~ /^-+(?:mode|m)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:ovl|non)$/i) {
				$mode = lc($value);
			}
			else {
				&errorMessage(__LINE__, "The concatenation mode is invalid.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?mismatch=(\d+)$/i) {
			$maxnmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)mismatch=(.+)$/i) {
			$maxpmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?qual(?:ity)?=(\d+)$/i) {
			$minqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?len(?:gth)?=(\d+)$/i) {
			$minlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:overlap|ovl)(?:length|len)=(\d+)$/i) {
			$minovllen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:padding|p)=(.+)$/i) {
			if ($1 =~ /^[ACGT]+$/i) {
				$padding = uc($1);
			}
			else {
				&errorMessage(__LINE__, "The padding sequence is invalid.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:o|output)=(?:folder|dir|directory)$/i) {
			$folder = 1;
		}
		elsif ($ARGV[$i] =~ /^-+compress=(.+)$/i) {
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
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
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
				if (scalar(@temp) % 2 == 0) {
					for (my $i = 0; $i < scalar(@temp); $i += 2) {
						if ((-f $temp[$i] || -l $temp[$i]) && (-f $temp[($i + 1)] || -l $temp[($i + 1)])) {
							if ($temp[$i] =~ /\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$/ && $temp[($i + 1)] =~ /\.reverse\.fastq(?:\.gz|\.bz2|\.xz)?$/) {
								push(@newinputfiles, $temp[$i], $temp[($i + 1)]);
							}
							else {
								&errorMessage(__LINE__, "The input files are not paried-end sequences.");
							}
						}
						else {
							&errorMessage(__LINE__, "The input files \"$temp[$i]\" and \"" . $temp[($i + 1)] . "\" are invalid.");
						}
					}
				}
				else {
					&errorMessage(__LINE__, "The input files are not paried-end sequences.");
				}
			}
			elsif (-f $inputfile || -l $inputfile) {
				push(@tempinputfiles, $inputfile);
			}
			else {
				&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
			}
		}
		if (scalar(@tempinputfiles) % 2 == 0) {
			for (my $i = 0; $i < scalar(@tempinputfiles); $i += 2) {
				if ((-f $tempinputfiles[$i] || -l $tempinputfiles[$i]) && (-f $tempinputfiles[($i + 1)] || -l $tempinputfiles[($i + 1)])) {
					if ($tempinputfiles[$i] =~ /\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$/ && $tempinputfiles[($i + 1)] =~ /\.reverse\.fastq(?:\.gz|\.bz2|\.xz)?$/) {
						push(@newinputfiles, $tempinputfiles[$i], $tempinputfiles[($i + 1)]);
					}
					else {
						&errorMessage(__LINE__, "The input files are not paried-end sequences.");
					}
				}
				else {
					&errorMessage(__LINE__, "The input files \"$tempinputfiles[$i]\" and \"" . $tempinputfiles[($i + 1)] . "\" are invalid.");
				}
			}
		}
		else {
			&errorMessage(__LINE__, "The input files are not paried-end sequences.");
		}
		@inputfiles = @newinputfiles;
		if (scalar(@inputfiles) > 2) {
			$folder = 1;
		}
	}
	if (-e $output && !$append) {
		&errorMessage(__LINE__, "\"$output\" already exists.");
	}
	elsif ($folder && !mkdir($output)) {
		&errorMessage(__LINE__, 'Cannot make output folder.');
	}
	if ($maxpmismatch > 1) {
		&errorMessage(__LINE__, "The maximum percentage of mismatches is invalid.");
	}
	$maxpmismatch *= 100;
	$minqual --;
	if ($minqual < 0) {
		$minqual = 0;
	}
	# search vsearch5d
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
			$vsearch5d = "\"$pathto/vsearch5d\"";
		}
		else {
			$vsearch5d = 'vsearch5d';
		}
	}
	# initialize vsearch5d options
	if ($numthreads) {
		$vsearch5doption .= " --threads $numthreads";
	}
	if ($mode eq 'ovl') {
		if ($minqual) {
			$vsearch5doption .= " --fastq_truncqual $minqual";
		}
		if ($minlen) {
			$vsearch5doption .= " --fastq_minlen $minlen";
		}
		if ($minovllen) {
			$vsearch5doption .= " --fastq_minovlen $minovllen";
		}
		if ($maxnmismatch) {
			$vsearch5doption .= " --fastq_maxdiffs $maxnmismatch";
		}
		if ($maxpmismatch) {
			$vsearch5doption .= " --fastq_maxdiffpct $maxpmismatch";
		}
		$vsearch5doption .= " --fastq_mergepairs";
	}
	elsif ($mode eq 'non') {
		$vsearch5doption .= " --join_padgap $padding";
		my $padqual = $padding;
		$padqual =~ s/[ACGT]/I/g;
		$vsearch5doption .= " --join_padgapq $padqual";
		$vsearch5doption .= " --fastq_join2";
	}
}

sub concatenateSequences {
	print(STDERR "\nProcessing sequences...\n");
	if (scalar(@inputfiles) == 2 && !$folder) {
		my $i = 0;
		print(STDERR "Concatenating \"$inputfiles[$i]\" and \"" . $inputfiles[($i + 1)] . "\" using VSEARCH5D...\n");
		my @tempfiles;
		if ($inputfiles[$i] =~ /\.xz$/) {
			if (system("xz -dk " . $inputfiles[$i])) {
				&errorMessage(__LINE__, "Cannot run \"xz -dk " . $inputfiles[$i] . "\".");
			}
			$inputfiles[$i] =~ s/\.xz$//;
			push(@tempfiles, $inputfiles[$i]);
		}
		if ($inputfiles[($i + 1)] =~ /\.xz$/) {
			if (system("xz -dk " . $inputfiles[($i + 1)])) {
				&errorMessage(__LINE__, "Cannot run \"xz -dk " . $inputfiles[($i + 1)] . "\".");
			}
			$inputfiles[($i + 1)] =~ s/\.xz$//;
			push(@tempfiles, $inputfiles[($i + 1)]);
		}
		if (system("$vsearch5d$vsearch5doption $inputfiles[$i] --reverse " . $inputfiles[($i + 1)] . " --fastqout $output 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch5d$vsearch5doption $inputfiles[$i] --reverse " . $inputfiles[($i + 1)] . " --fastqout $output\".");
		}
		foreach my $tempfile (@tempfiles) {
			unlink($tempfile);
		}
		&compressFileByName($output);
	}
	else {
		my @outputfastq;
		for (my $i = 0; $i < scalar(@inputfiles); $i += 2) {
			my $prefix = $inputfiles[$i];
			if ($prefix =~ /\//) {
				$prefix =~ s/^.+\///;
			}
			$prefix =~ s/\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$//;
			if ($prefix !~ /__undetermined$/) {
				print(STDERR "Concatenating \"$inputfiles[$i]\" and \"" . $inputfiles[($i + 1)] . "\" using VSEARCH5D...\n");
				my @tempfiles;
				if ($inputfiles[$i] =~ /\.xz$/) {
					if (system("xz -dk " . $inputfiles[$i])) {
						&errorMessage(__LINE__, "Cannot run \"xz -dk " . $inputfiles[$i] . "\".");
					}
					$inputfiles[$i] =~ s/\.xz$//;
					push(@tempfiles, $inputfiles[$i]);
				}
				if ($inputfiles[($i + 1)] =~ /\.xz$/) {
					if (system("xz -dk " . $inputfiles[($i + 1)])) {
						&errorMessage(__LINE__, "Cannot run \"xz -dk " . $inputfiles[($i + 1)] . "\".");
					}
					$inputfiles[($i + 1)] =~ s/\.xz$//;
					push(@tempfiles, $inputfiles[($i + 1)]);
				}
				if (system("$vsearch5d$vsearch5doption $inputfiles[$i] --reverse " . $inputfiles[($i + 1)] . " --fastqout $output/$prefix.fastq 1> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$vsearch5d$vsearch5doption $inputfiles[$i] --reverse " . $inputfiles[($i + 1)] . " --fastqout $output/$prefix.fastq\".");
				}
				push(@outputfastq, "$output/$prefix.fastq");
				foreach my $tempfile (@tempfiles) {
					unlink($tempfile);
				}
			}
		}
		if ($compress) {
			&compressInParallel(@outputfastq);
		}
	}
	print(STDERR "done.\n");
}

sub compressInParallel {
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $fastq (@_) {
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
				print(STDERR "Compressing $fastq...\n");
				&compressFileBySetting($fastq);
				exit;
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot split sequence file correctly.');
		}
	}
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

sub compressFileBySetting {
	my $outputfile = shift(@_);
	if ($compress eq 'gz') {
		if (system("gzip $outputfile")) {
			&errorMessage(__LINE__, "Cannot run \"gzip $outputfile\".");
		}
	}
	elsif ($compress eq 'bz2') {
		if (system("bzip2 $outputfile")) {
			&errorMessage(__LINE__, "Cannot run \"bzip2 $outputfile\".");
		}
	}
	elsif ($compress eq 'xz') {
		if (system("xz $outputfile")) {
			&errorMessage(__LINE__, "Cannot run \"xz $outputfile\".");
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
clconcatpairv options inputfolder outputfolder
clconcatpairv options inputfile1 inputfile2 ... inputfileN outputfolder
clconcatpairv options forwardread reverseread outputfile (or outputfolder)

Command line options
====================
-o, --output=FILE|DIRECTORY
  Specify output format. (default: DIRECTORY)

-m, --mode=OVL|NON
  Specify the concatenation mode. (default: OVL)

--maxnmismatch=INTEGER
  Specify the maximum number of mismatches. (default: 9999)

--maxpmismatch=DECIMAL
  Specify the maximum percentage of mismatches. (default: 0.5)

--minqual=INTEGER
  Specify the minimum quality value for 3'-tail trimming. (default: 0)

--minlen=INTEGER
  Specify the minimum length after trimming. (default: 1)

--minovllen=INTEGER
  Specify the minimum length of overlap. (default: 10)

-p, --padding=SEQUENCE
  Specify the padding sequence for non-overlapped paired-end mode.
(default: ACGTACGTACGTACGT)

--compress=GZIP|BZIP2|XZ|DISABLE
  Specify compress output files or not. (default: GZIP)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTQ (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
