use strict;
use File::Spec;
use Fcntl ':flock';

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
my $folder = 0;
my $maxnmismatch = 20;
my $minovllen = 20;
my $compress = 'gz';
my $mode = 'ovl';
my $padding = 'ACGTACGTACGTACGT';
my $numthreads = 1;
my $nodel;

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
	# concatenate sequences
	&concatenateSequences();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clconcatpair $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2018  Akifumi S. Tanabe

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
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?mismatch=(.+)$/i) {
			$maxnmismatch = $1;
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
		elsif ($ARGV[$i] =~ /^-+output=(?:folder|dir|directory)$/i) {
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
	if (-e $output) {
		&errorMessage(__LINE__, "\"$output\" already exists.");
	}
	if (!@inputfiles) {
		&errorMessage(__LINE__, "No input file was specified.");
	}
	if (scalar(@inputfiles) > 2) {
		if (scalar(@inputfiles) % 2 == 0) {
			@inputfiles = sort(@inputfiles);
			for (my $i = 0; $i < scalar(@inputfiles); $i += 2) {
				if (-f $inputfiles[0] && !-z $inputfiles[0] && -f $inputfiles[1] && !-z $inputfiles[1] && $inputfiles[0] =~ /\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$/ && $inputfiles[1] =~ /\.reverse\.fastq(?:\.gz|\.bz2|\.xz)?$/) {
					next;
				}
				else {
					&errorMessage(__LINE__, "The input file names \"$inputfiles[0]\" and \"$inputfiles[1]\" are invalid.");
				}
			}
			$folder = 1;
		}
		else {
			&errorMessage(__LINE__, "The number of input files is not even number.");
		}
	}
	elsif (scalar(@inputfiles) == 1) {
		if (-d $inputfiles[0]) {
			my @tempinputfiles;
			my @temp = glob("$inputfiles[0]/*.forward.*");
			if (scalar(@temp) > 0) {
				foreach my $forward (@temp) {
					my $reverse = $forward;
					$reverse =~ s/\.forward\./.reverse./;
					if (-f $forward && !-z $forward && -f $reverse && !-z $reverse && $forward =~ /\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$/ && $reverse =~ /\.reverse\.fastq(?:\.gz|\.bz2|\.xz)?$/) {
						push(@tempinputfiles, $forward);
						push(@tempinputfiles, $reverse);
					}
				}
			}
			else {
				&errorMessage(__LINE__, "Input file does not exist.");
			}
			@inputfiles = @tempinputfiles;
			$folder = 1;
		}
		else {
			&errorMessage(__LINE__, "Input is not a directory.");
		}
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
}

sub concatenateSequences {
	print(STDERR "\nProcessing sequences...\n");
	if ($mode eq 'ovl') {
		if (scalar(@inputfiles) == 2 && !$folder) {
			print(STDERR "Concatenating $inputfiles[0] and $inputfiles[1] using VSEARCH...\n");
			if (system("$vsearch --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --fastq_qmax 99 --fastq_mergepairs $inputfiles[0] --reverse $inputfiles[1] --fastq_minovlen $minovllen --fastq_maxdiffs $maxnmismatch --fastq_allowmergestagger --fastqout $output --threads $numthreads 1> $devnull")) {
				&errorMessage(__LINE__, "Cannot run \"$vsearch --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --fastq_qmax 99 --fastq_mergepairs $inputfiles[0] --reverse $inputfiles[1] --fastq_minovlen $minovllen --fastq_maxdiffs $maxnmismatch --fastq_allowmergestagger --fastqout $output --threads $numthreads\".");
			}
			&compressFileByName($output);
		}
		else {
			# make output directory
			if (!-e $output && !mkdir($output)) {
				&errorMessage(__LINE__, 'Cannot make output folder.');
			}
			my @outputfastq;
			for (my $i = 0; $i < scalar(@inputfiles); $i += 2) {
				my $prefix = $inputfiles[$i];
				if ($prefix =~ /\//) {
					$prefix =~ s/^.+\///;
				}
				$prefix =~ s/\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$//;
				print(STDERR "Concatenating $inputfiles[$i] and " . $inputfiles[($i + 1)] . " using VSEARCH...\n");
				if (system("$vsearch --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --fastq_qmax 99 --fastq_mergepairs $inputfiles[$i] --reverse " . $inputfiles[($i + 1)] . " --fastq_minovlen $minovllen --fastq_maxdiffs $maxnmismatch --fastq_allowmergestagger --fastqout $output/$prefix.fastq --threads $numthreads 1> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$vsearch --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --fastq_qmax 99 --fastq_mergepairs $inputfiles[$i] --reverse " . $inputfiles[($i + 1)] . " --fastq_minovlen $minovllen --fastq_maxdiffs $maxnmismatch --fastq_allowmergestagger --fastqout $output/$prefix.fastq --threads $numthreads\".");
				}
				push(@outputfastq, "$output/$prefix.fastq");
			}
			if ($compress) {
				&compressInParallel(@outputfastq);
			}
		}
	}
	elsif ($mode eq 'non') {
		if (scalar(@inputfiles) == 2 && !$folder) {
			print(STDERR "Concatenating $inputfiles[0] and $inputfiles[1]...\n");
			&concatenateNonoverlappedPair($inputfiles[0], $inputfiles[1], $output);
			&concatenateFiles($output);
		}
		else {
			# make output directory
			if (!-e $output && !mkdir($output)) {
				&errorMessage(__LINE__, 'Cannot make output folder.');
			}
			my @outputfastq;
			for (my $i = 0; $i < scalar(@inputfiles); $i += 2) {
				my $prefix = $inputfiles[$i];
				if ($prefix =~ /\//) {
					$prefix =~ s/^.+\///;
				}
				$prefix =~ s/\.forward\.fastq(?:\.gz|\.bz2|\.xz)?$//;
				print(STDERR "Concatenating $inputfiles[$i] and " . $inputfiles[($i + 1)] . "...\n");
				&concatenateNonoverlappedPair($inputfiles[$i], $inputfiles[($i + 1)], "$output/$prefix.fastq");
				push(@outputfastq, "$output/$prefix.fastq");
			}
			&concatenateFiles(@outputfastq);
		}
	}
	print(STDERR "done.\n");
}

sub concatenateNonoverlappedPair {
	my $forwardread = shift(@_);
	my $reverseread = shift(@_);
	my $outputfile = shift(@_);
	$filehandleinput1 = &readFile($forwardread);
	$filehandleinput2 = &readFile($reverseread);
	# concatenate
	{
		my $tempnline = 1;
		my $seqname;
		my $nucseq1;
		my $qualseq1;
		my $nucseq2;
		my $qualseq2;
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
				readline($filehandleinput2);
			}
			elsif ($tempnline % 4 == 2) {
				s/[^a-zA-Z]//g;
				$nucseq1 = uc($_);
				$nucseq2 = readline($filehandleinput2);
				$nucseq2 =~ s/\r?\n?$//;
				$nucseq2 =~ s/[^a-zA-Z]//g;
				$nucseq2 = uc($nucseq2);
			}
			elsif ($tempnline % 4 == 3 && /^\+/) {
				$tempnline ++;
				readline($filehandleinput2);
				next;
			}
			elsif ($tempnline % 4 == 0 && $seqname && $nucseq1) {
				s/\s//g;
				$qualseq1 = $_;
				$qualseq2 = readline($filehandleinput2);
				$qualseq2 =~ s/\r?\n?$//;
				$qualseq2 =~ s/\s//g;
				$qualseq2 = $qualseq2;
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
					undef($nucseq1);
					undef($qualseq1);
					undef($nucseq2);
					undef($qualseq2);
					$tempnline ++;
					next;
				}
				else {
					# reverse-complement reverse sequence
					$nucseq2 = &reversecomplement($nucseq2);
					{
						my @tempqual = split('', $qualseq2);
						$qualseq2 = join('', reverse(@tempqual));
					}
					# make quality padding
					my $qualpadding = $padding;
					$qualpadding =~ s/./V/g;
					# save to file
					unless (open($filehandleoutput1, ">> $outputfile.$child")) {
						&errorMessage(__LINE__, "Cannot write \"$outputfile.$child\".");
					}
					unless (flock($filehandleoutput1, LOCK_EX)) {
						&errorMessage(__LINE__, "Cannot lock \"$outputfile.$child\".");
					}
					unless (seek($filehandleoutput1, 0, 2)) {
						&errorMessage(__LINE__, "Cannot seek \"$outputfile.$child\".");
					}
					print($filehandleoutput1 "\@$seqname\n" . $nucseq2 . $padding . $nucseq1 . "\n+\n" . $qualseq2 . $qualpadding . $qualseq1 . "\n");
					close($filehandleoutput1);
					exit;
				}
			}
			else {
				&errorMessage(__LINE__, "Invalid FASTQ.\nFile: $forwardread\nLine: $tempnline");
			}
			$tempnline ++;
		}
		# join
		while (wait != -1) {
			if ($?) {
				&errorMessage(__LINE__, 'Cannot concatenate sequences correctly.');
			}
		}
	}
	close($filehandleinput1);
	close($filehandleinput2);
}

sub concatenateFiles {
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $outputfile (@_) {
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
				my @seqfiles = glob("$outputfile.*");
				if (scalar(@seqfiles) == $numthreads * 2) {
					if ($folder && $compress) {
						$filehandleoutput1 = writeFile("$outputfile.$compress");
					}
					else {
						$filehandleoutput1 = writeFile("$outputfile");
					}
					foreach my $seqfile (@seqfiles) {
						unless (open($filehandleinput1, "< $seqfile")) {
							&errorMessage(__LINE__, "Cannot open \"$seqfile\".");
						}
						while (<$filehandleinput1>) {
							print($filehandleoutput1 $_);
						}
						close($filehandleinput1);
						unlink($seqfile);
					}
					close($filehandleoutput1);
				}
				else {
					&errorMessage(__LINE__, "Invalid results.");
				}
				exit;
			}
		}
		# join
		while (wait != -1) {
			if ($?) {
				&errorMessage(__LINE__, 'Cannot concatenate sequence file correctly.');
			}
		}
	}
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

sub reversecomplement {
	my @temp = split('', $_[0]);
	my @seq;
	foreach my $seq (reverse(@temp)) {
		$seq =~ tr/ACGTMRYKVHDBacgtmrykvhdb/TGCAKYRMBDHVtgcakyrmbdhv/;
		push(@seq, $seq);
	}
	return(join('', @seq));
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
clconcatpair options inputfolder outputfolder
clconcatpair options inputfile1 inputfile2 ... inputfileN outputfolder
clconcatpair options forwardread reverseread outputfile (or outputfolder)

Command line options
====================
-o, --output=FILE|DIRECTORY
  Specify output format. (default: DIRECTORY)

-m, --mode=OVL|NON
  Specify the concatenation mode. (default: OVL)

--maxnmismatch=INTEGER
  Specify the maximum number of mismatches. (default: 20)

--minovllen=INTEGER
  Specify the minimum length of overlap. (default: 20)

-p, --padding=SEQUENCE
  Specify the padding sequence for non-overlapped paired-end mode.
(default: ACGTACGTACGTACGT)

--compress=GZIP|BZIP2|XZ|DISABLE
  Specify compress output files or not. (default: GZIP)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTQ (uncompressed, gzip-compressed, or bzip2-compressed)
_END
	exit;
}
