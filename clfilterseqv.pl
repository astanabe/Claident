use strict;
use File::Spec;

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

# global variable
my $vsearchoption = " --fastq_qmax 93";

# options
my $folder = 0;
my $paired;
my $maxnee;
my $minlen = 0;
my $maxlen = 99999;
my $minqual = 0;
my $maxqual = 93;
my $ovlen = 'truncate';
my $maxnNs = 0;
my $compress = 'gz';
my $numthreads = 1;
my $append;

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
clfilterseqv $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2021  Akifumi S. Tanabe

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
		if ($ARGV[$i] =~ /^-+folder$/i) {
			$folder = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:o|output)=(?:folder|dir|directory)$/i) {
			$folder = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:a|append)$/i) {
			$append = 1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?qual(?:ity)?=(\d+)$/i) {
			$minqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?qual(?:ity)?=(\d+)$/i) {
			$maxqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?len(?:gth)?=(\d+)$/i) {
			$minlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?len(?:gth)?=(\d+)$/i) {
			$maxlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?Ns?=(\d+)$/i) {
			$maxnNs = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?ee=(\d+(?:\.\d+)?)$/i) {
			$maxnee = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:overflow|over|ov)(?:len|length)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:elim|eliminate)$/i) {
				$ovlen = 'eliminate';
			}
			elsif ($value =~ /^(?:trunc|truncate)$/i) {
				$ovlen = 'truncate';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
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
						if (-e $temp[$i] && -e $temp[($i + 1)]) {
							if ($temp[$i] =~ /\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$/ && $temp[($i + 1)] =~ /\.reverse\.fastq(?:\.gz|\.bz2|\.xz)?$/) {
								if (defined($paired) && $paired == 0) {
									&errorMessage(__LINE__, "The input files are invalid. Paired-end and single-end sequences cannot be mixed.");
								}
								push(@newinputfiles, $temp[$i], $temp[($i + 1)]);
								$paired = 1;
							}
							else {
								if ($paired) {
									&errorMessage(__LINE__, "The input files are invalid. Paired-end and single-end sequences cannot be mixed.");
								}
								push(@newinputfiles, $temp[$i], $temp[($i + 1)]);
								$paired = 0;
							}
						}
						else {
							&errorMessage(__LINE__, "The input files \"$temp[$i]\" and \"" . $temp[($i + 1)] . "\" are invalid.");
						}
					}
				}
				else {
					if ($paired) {
						&errorMessage(__LINE__, "The input files are invalid. Paired-end and single-end sequences cannot be mixed.");
					}
					for (my $i = 0; $i < scalar(@temp); $i ++) {
						push(@newinputfiles, $temp[$i]);
					}
					$paired = 0;
				}
			}
			elsif (-e $inputfile) {
				push(@tempinputfiles, $inputfile);
			}
			else {
				&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
			}
		}
		if (scalar(@tempinputfiles) % 2 == 0) {
			for (my $i = 0; $i < scalar(@tempinputfiles); $i += 2) {
				if (-e $tempinputfiles[$i] && -e $tempinputfiles[($i + 1)]) {
					if ($tempinputfiles[$i] =~ /\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$/ && $tempinputfiles[($i + 1)] =~ /\.reverse\.fastq(?:\.gz|\.bz2|\.xz)?$/) {
						if (defined($paired) && $paired == 0) {
							&errorMessage(__LINE__, "The input files are invalid. Paired-end and single-end sequences cannot be mixed.");
						}
						push(@newinputfiles, $tempinputfiles[$i], $tempinputfiles[($i + 1)]);
						$paired = 1;
					}
					else {
						if ($paired) {
							&errorMessage(__LINE__, "The input files are invalid. Paired-end and single-end sequences cannot be mixed.");
						}
						push(@newinputfiles, $tempinputfiles[$i], $tempinputfiles[($i + 1)]);
						$paired = 0;
					}
				}
				else {
					&errorMessage(__LINE__, "The input files \"$tempinputfiles[$i]\" and \"" . $tempinputfiles[($i + 1)] . "\" are invalid.");
				}
			}
		}
		elsif ($paired) {
			&errorMessage(__LINE__, "The input files are invalid. Paired-end and single-end sequences cannot be mixed.");
		}
		if (@newinputfiles) {
			@inputfiles = @newinputfiles;
		}
		elsif (@tempinputfiles) {
			@inputfiles = @tempinputfiles;
		}
		else {
			&errorMessage(__LINE__, "The input files are invalid.");
		}
		if (scalar(@inputfiles) > 1) {
			$folder = 1;
		}
	}
	if ($paired) {
		print(STDERR "The input files will be treated as paired-end sequences.\n");
	}
	else {
		print(STDERR "The input files will be treated as single-end sequences.\n");
	}
	if (-e $output && !$append) {
		&errorMessage(__LINE__, "\"$output\" already exists.");
	}
	elsif (!$append && $folder && !mkdir($output)) {
		&errorMessage(__LINE__, 'Cannot make output folder.');
	}
	$minqual --;
	if ($minqual < 0) {
		$minqual = 0;
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
	if ($minqual) {
		$vsearchoption .= " --fastq_truncqual $minqual";
	}
	if ($minlen) {
		$vsearchoption .= " --fastq_minlen $minlen";
	}
	if ($maxqual == 93) {
		undef($maxqual);
	}
	elsif ($maxqual > 93) {
		&errorMessage(__LINE__, "The maximum quality value is invalid.");
	}
	if ($maxlen) {
		if ($ovlen eq 'truncate') {
			$vsearchoption .= " --fastq_trunclen_keep $maxlen";
		}
		elsif ($ovlen eq 'eliminate') {
			$vsearchoption .= " --fastq_maxlen $maxlen";
		}
	}
	if ($maxnee) {
		$vsearchoption .= " --fastq_maxee $maxnee";
	}
	if (defined($maxnNs)) {
		$vsearchoption .= " --fastq_maxns $maxnNs";
	}
}

sub filterSequences {
	print(STDERR "Processing sequences...\n");
	if (!$paired && !$folder) {
		print(STDERR "Filtering \"$inputfiles[0]\" using VSEARCH...\n");
		my $tempfile;
		if ($inputfiles[0] =~ /\.xz$/) {
			if (system("xz -dk " . $inputfiles[0])) {
				&errorMessage(__LINE__, "Cannot run \"xz -dk " . $inputfiles[0] . "\".");
			}
			$inputfiles[0] =~ s/\.xz$//;
			$tempfile = $inputfiles[0];
		}
		if (system("$vsearch$vsearchoption --fastq_filter $inputfiles[0] --fastqout $output 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption --fastq_filter $inputfiles[0] --fastqout $output\".");
		}
		if ($tempfile) {
			unlink($tempfile);
		}
		if (-e $output && !-z $output) {
			if ($maxqual) {
				unless (rename($output, "$output.temp")) {
					&errorMessage(__LINE__, "Cannot rename \"$output\" to \"$output.temp\".");
				}
				if (system("$vsearch --fastq_convert $output.temp --fastq_qmax 93 --fastq_qmaxout $maxqual --fastqout $output 1> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$vsearch --fastq_convert $output.temp --fastq_qmax 93 --fastq_qmaxout $maxqual --fastqout $output\".");
				}
				unlink("$output.temp");
			}
			&compressFileByName($output);
		}
		elsif (-e $output) {
			unlink($output);
			print(STDERR "Filtering has been correctly finished. But there is no passed sequence (all sequences have been filtered out).\n");
		}
	}
	elsif (!$paired && $folder) {
		my @outputfastq;
		for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
			my $prefix = $inputfiles[$i];
			if ($prefix =~ /\//) {
				$prefix =~ s/^.+\///;
			}
			$prefix =~ s/\.fastq(?:\.gz|\.bz2|\.xz)?$//;
			if ($prefix !~ /(?:__undetermined|__incompleteUMI)/) {
				print(STDERR "Filtering \"$inputfiles[$i]\" using VSEARCH...\n");
				my $tempfile;
				if ($inputfiles[$i] =~ /\.xz$/) {
					if (system("xz -dk " . $inputfiles[$i])) {
						&errorMessage(__LINE__, "Cannot run \"xz -dk " . $inputfiles[$i] . "\".");
					}
					$inputfiles[$i] =~ s/\.xz$//;
					$tempfile = $inputfiles[$i];
				}
				if (system("$vsearch$vsearchoption --fastq_filter $inputfiles[$i] --fastqout $output/$prefix.fastq 1> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption --fastq_filter $inputfiles[$i] --fastqout $output/$prefix.fastq\".");
				}
				if ($tempfile) {
					unlink($tempfile);
				}
				if (-e "$output/$prefix.fastq" && !-z "$output/$prefix.fastq") {
					if ($maxqual) {
						unless (rename("$output/$prefix.fastq", "$output/$prefix.temp")) {
							&errorMessage(__LINE__, "Cannot rename \"$output/$prefix.fastq\" to \"$output/$prefix.temp\".");
						}
						if (system("$vsearch --fastq_convert $output/$prefix.temp --fastq_qmax 93 --fastq_qmaxout $maxqual --fastqout $output/$prefix.fastq 1> $devnull")) {
							&errorMessage(__LINE__, "Cannot run \"$vsearch --fastq_convert $output/$prefix.temp --fastq_qmax 93 --fastq_qmaxout $maxqual --fastqout $output/$prefix.fastq\".");
						}
						unlink("$output/$prefix.temp");
					}
					push(@outputfastq, "$output/$prefix.fastq");
				}
				elsif (-e "$output/$prefix.fastq") {
					unlink("$output/$prefix.fastq");
				}
			}
		}
		if ($compress) {
			&compressInParallel(@outputfastq);
		}
	}
	elsif ($paired && $folder) {
		my @outputfastq;
		for (my $i = 0; $i < scalar(@inputfiles); $i += 2) {
			my $forwardprefix = $inputfiles[$i];
			if ($forwardprefix =~ /\//) {
				$forwardprefix =~ s/^.+\///;
			}
			$forwardprefix =~ s/\.fastq(?:\.gz|\.bz2|\.xz)?$//;
			my $reverseprefix = $inputfiles[$i];
			if ($reverseprefix =~ /\//) {
				$reverseprefix =~ s/^.+\///;
			}
			$reverseprefix =~ s/\.fastq(?:\.gz|\.bz2|\.xz)?$//;
			if ($forwardprefix !~ /(?:__undetermined|__incompleteUMI)/ && $reverseprefix !~ /(?:__undetermined|__incompleteUMI)/) {
				print(STDERR "Filtering \"$inputfiles[$i]\" and \"" . $inputfiles[($i + 1)] . "\" using VSEARCH...\n");
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
				if (system("$vsearch$vsearchoption --fastq_filter $inputfiles[$i] --reverse " . $inputfiles[($i + 1)] . " --fastqout $output/$forwardprefix.fastq --fastqout_rev $output/$reverseprefix.fastq 1> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption --fastq_filter $inputfiles[$i] --reverse " . $inputfiles[($i + 1)] . " --fastqout $output/$forwardprefix.fastq --fastqout_rev $output/$reverseprefix.fastq\".");
				}
				foreach my $tempfile (@tempfiles) {
					unlink($tempfile);
				}
				if (-e "$output/$forwardprefix.fastq" && !-z "$output/$forwardprefix.fastq" && -e "$output/$reverseprefix.fastq" && !-z "$output/$reverseprefix.fastq") {
					if ($maxqual) {
						unless (rename("$output/$forwardprefix.fastq", "$output/$forwardprefix.temp")) {
							&errorMessage(__LINE__, "Cannot rename \"$output/$forwardprefix.fastq\" to \"$output/$forwardprefix.temp\".");
						}
						if (system("$vsearch --fastq_convert $output/$forwardprefix.temp --fastq_qmax 93 --fastq_qmaxout $maxqual --fastqout $output/$forwardprefix.fastq 1> $devnull")) {
							&errorMessage(__LINE__, "Cannot run \"$vsearch --fastq_convert $output/$forwardprefix.temp --fastq_qmax 93 --fastq_qmaxout $maxqual --fastqout $output/$forwardprefix.fastq\".");
						}
						unlink("$output/$forwardprefix.temp");
						unless (rename("$output/$reverseprefix.fastq", "$output/$reverseprefix.temp")) {
							&errorMessage(__LINE__, "Cannot rename \"$output/$reverseprefix.fastq\" to \"$output/$reverseprefix.temp\".");
						}
						if (system("$vsearch --fastq_convert $output/$reverseprefix.temp --fastq_qmax 93 --fastq_qmaxout $maxqual --fastqout $output/$reverseprefix.fastq 1> $devnull")) {
							&errorMessage(__LINE__, "Cannot run \"$vsearch --fastq_convert $output/$reverseprefix.temp --fastq_qmax 93 --fastq_qmaxout $maxqual --fastqout $output/$reverseprefix.fastq\".");
						}
						unlink("$output/$reverseprefix.temp");
					}
					push(@outputfastq, "$output/$forwardprefix.fastq", "$output/$reverseprefix.fastq");
				}
				elsif (-e "$output/$forwardprefix.fastq" && -e "$output/$reverseprefix.fastq") {
					unlink("$output/$forwardprefix.fastq");
					unlink("$output/$reverseprefix.fastq");
				}
			}
		}
		if ($compress) {
			&compressInParallel(@outputfastq);
		}
	}
	print(STDERR "done.\n\n");
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
clfilterseqv options inputfolder outputfolder
clfilterseqv options inputfile1 inputfile2 ... inputfileN outputfolder
clfilterseqv options forwardread reverseread outputfolder

Command line options
====================
-o, --output=FILE|DIRECTORY
  Specify output format. (default: DIRECTORY)

--maxnee=DECIMAL
  Specify the maximum number of expected errors. (default: none)

--minqual=INTEGER
  Specify the minimum quality value for 3'-tail trimming. (default: 0)

--maxqual=INTEGER
  Specify the maximum quality value. (default: 93)

--minlen=INTEGER
  Specify the minimum length after trimming. (default: 0)

--maxlen=INTEGER
  Specify the maximum length after trimming. (default: 99999)

--ovlen=ELIMINATE|TRUNCATE
  Specify whether 1 whole sequence is eliminated or overflow is truncated if
sequence length is longer than maxlen. (default: TRUNCATE)

--maxnNs=INTEGER
  Specify the maximum number of Ns. (default: 0)

-a, --append
  Specify outputfile append or not. (default: off)

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
