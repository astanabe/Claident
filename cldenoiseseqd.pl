use strict;
use File::Spec;
use File::Copy::Recursive ('fcopy', 'rcopy', 'dircopy');

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# global variables
my @samplenames;

# options
my $pooling = 0;
my $seed = time^$$;
my $numthreads = 1;
my $nodel;

# input/output
my $outputfolder;
my @inputfiles;

# commands
my $Rscript;

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
	# prepare input files
	&extractInParallel();
	# run DADA2
	&runDADA2();
	# analyse DADA2 output
	&postDADA2();
}

sub printStartupMessage {
	print(STDERR <<"_END");
cldenoiseseqd $buildno
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
	$outputfolder = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:pool|pooling)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$pooling = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$pooling = 0;
			}
			elsif ($value =~ /^(?:pseudo|p)$/i) {
				$pooling = 'pseudo';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+seed=(\d+)$/i) {
			$seed = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+nodel$/i) {
			$nodel = 1;
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
					if (-f $temp[$i] || -l $temp[$i]) {
						push(@newinputfiles, $temp[$i]);
					}
					else {
						&errorMessage(__LINE__, "The input files \"$temp[0]\" and \"$temp[1]\" are invalid.");
					}
				}
			}
			elsif (-f $inputfile || -l $inputfile) {
				push(@newinputfiles, $inputfile);
			}
			else {
				&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
			}
		}
		@inputfiles = @newinputfiles;
	}
	{
		my %samplenames;
		foreach my $inputfile (@inputfiles) {
			if ($inputfile =~ /([^\/]+)(?:\.forward|\.reverse)?\.fastq/) {
				my $samplename = $1;
				my @samplename = split(/__/, $samplename);
				if (exists($samplenames{$samplename})) {
					&errorMessage(__LINE__, "The sample name \"$samplename\" is doubly used.");
				}
				elsif (scalar(@samplename) == 3) {
					$samplenames{$samplename} = 1;
					push(@samplenames, $samplename);
				}
				else {
					&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
				}
			}
			else {
				&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
			}
		}
		if (scalar(@inputfiles) != scalar(@samplenames)) {
			&errorMessage(__LINE__, "Unknown error.");
		}
	}
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if (!mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
	}
	# search R
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
			$Rscript = "\"$pathto/Rscript\"";
		}
		else {
			$Rscript = 'Rscript';
		}
	}
}

sub extractInParallel {
	print(STDERR "\nPreparing files for DADA2...\n");
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
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
				&extractcopyFile($inputfiles[$i], $outputfolder . '/' . $samplenames[$i] . '.fastq');
				exit;
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot extract/copy fastq files correctly.');
		}
	}
	print(STDERR "done.\n");
}

sub runDADA2 {
	print(STDERR "\nRunning DADA2...\n");
	$filehandleoutput1 = &writeFile("$outputfolder/runDADA2.R");
	print($filehandleoutput1 "ranseed <- $seed\n");
	print($filehandleoutput1 "numthreads <- $numthreads\n");
	print($filehandleoutput1 "outputfolder <- \"$outputfolder\"\n");
	if ($pooling == 1) {
		print($filehandleoutput1 "pooling <- T\n");
	}
	elsif ($pooling == 0) {
		print($filehandleoutput1 "pooling <- F\n");
	}
	elsif ($pooling eq 'pseudo') {
		print($filehandleoutput1 "pooling <- \"pseudo\"\n");
	}
	print($filehandleoutput1 <<'_END');
library(dada2)
set.seed(ranseed)
setDadaOpt(OMEGA_C=0)
fn1 <- sort(list.files(outputfolder, pattern="\\.fastq$", full.names=T))
extract.sample.names <- function (x) { sub("\\.fastq$", "", sub("^.*\\/", "", x)) }
names(fn1) <- sapply(fn1, extract.sample.names)
derep1 <- derepFastq(fn1, verbose=T, qualityType="FastqQuality")
err1 <- learnErrors(derep1, verbose=T, multithread=numthreads, qualityType="FastqQuality")
pdf(file=paste0(outputfolder, "/plotErrors.pdf"))
plotErrors(err1, obs=T, err_out=T, err_in=T, nominalQ=T)
dev.off()
dada1 <- dada(derep1, err=err1, verbose=T, multithread=numthreads, pool=pooling)
for (i in 1:length(fn1)) {
    write.table(derep1[[i]]$map, paste0(outputfolder, "/", names(fn1)[i], "_derepmap.txt"), sep="\t", col.names=F, row.names=F, quote=F)
    write.table(derep1[[i]]$uniques, paste0(outputfolder, "/", names(fn1)[i], "_uniques.txt"), sep="\t", col.names=F, row.names=T, quote=F)
    write.table(dada1[[i]]$map, paste0(outputfolder, "/", names(fn1)[i], "_dadamap.txt"), sep="\t", col.names=F, row.names=F, quote=F)
    write.table(dada1[[i]]$denoised, paste0(outputfolder, "/", names(fn1)[i], "_denoised.txt"), sep="\t", col.names=F, row.names=T, quote=F)
}
_END
	close($filehandleoutput1);
	if (system("$Rscript --vanilla $outputfolder/runDADA2.R")) {
		&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla $outputfolder/runDADA2.R\" correctly.");
	}
	print(STDERR "done.\n");
}

sub postDADA2 {
	print(STDERR "\nAnalyzing DADA2 output...\n");
	my %denoised;
	my %nseqdenoised;
	#my %uniques;
	foreach my $samplename (@samplenames) {
		my @denoised;
		#my @uniques;
		my @unique2denoised;
		my @rawread2unique;
		# read denoised sequence file and store seq2nseq and denoisednum2seq
		$filehandleinput1 = &readFile("$outputfolder/$samplename\_denoised.txt");
		while (<$filehandleinput1>) {
			if (/^([A-Z]+)\t(\d+)/) {
				$nseqdenoised{$1} += $2;
				push(@denoised, $1);
			}
			else {
				&errorMessage(__LINE__, "\"$outputfolder/$samplename\_denoised.txt\" is invalid.");
			}
		}
		close($filehandleinput1);
		unless ($nodel) {
			unlink("$outputfolder/$samplename\_denoised.txt");
		}
		# read dereplicated sequence file and store derepnum2seq
		#$filehandleinput1 = &readFile("$outputfolder/$samplename\_uniques.txt");
		#while (<$filehandleinput1>) {
		#	if (/^[A-Z]+/) {
		#		push(@uniques, $&);
		#	}
		#	else {
		#		&errorMessage(__LINE__, "\"$outputfolder/$samplename\_uniques.txt\" is invalid.");
		#	}
		#}
		#close($filehandleinput1);
		unless ($nodel) {
			unlink("$outputfolder/$samplename\_uniques.txt");
		}
		# read dadamap and store derepnum2denoisednum
		$filehandleinput1 = &readFile("$outputfolder/$samplename\_dadamap.txt");
		{
			my $lineno = 0;
			while (<$filehandleinput1>) {
				if (/^\d+/) {
					$unique2denoised[$lineno] = ($& - 1);
				}
				else {
					&errorMessage(__LINE__, "\"$outputfolder/$samplename\_dadamap.txt\" is invalid.");
				}
				$lineno ++;
			}
		}
		close($filehandleinput1);
		unless ($nodel) {
			unlink("$outputfolder/$samplename\_dadamap.txt");
		}
		# read derepmap and store rawnum2derepnum
		$filehandleinput1 = &readFile("$outputfolder/$samplename\_derepmap.txt");
		{
			my $lineno = 0;
			while (<$filehandleinput1>) {
				if (/^\d+/) {
					$rawread2unique[$lineno] = ($& - 1);
				}
				else {
					&errorMessage(__LINE__, "\"$outputfolder/$samplename\_derepmap.txt\" is invalid.");
				}
				$lineno ++;
			}
		}
		close($filehandleinput1);
		unless ($nodel) {
			unlink("$outputfolder/$samplename\_derepmap.txt");
		}
		# read fastq and store seqname to uniques and denoised
		$filehandleinput1 = &readFile("$outputfolder/$samplename.fastq");
		{
			my $lineno = 1;
			my $seqno = 0;
			while (<$filehandleinput1>) {
				if ($lineno % 4 == 1) {
					s/\r?\n?$//;
					if (/^\@(.+)/) {
						my $seqname = $1;
						#push(@{$uniques{$uniques[$rawread2unique[$seqno]]}}, $seqname);
						push(@{$denoised{$denoised[$unique2denoised[$rawread2unique[$seqno]]]}}, $seqname);
						$seqno ++;
					}
					else {
						&errorMessage(__LINE__, "\"$outputfolder/$samplename.fastq\" is invalid.");
					}
				}
				$lineno ++;
			}
		}
		close($filehandleinput1);
		unless ($nodel) {
			unlink("$outputfolder/$samplename.fastq");
		}
	}
	$filehandleoutput1 = &writeFile("$outputfolder/denoised.fasta");
	$filehandleoutput2 = &writeFile("$outputfolder/denoised.otu.gz");
	{
		my @denoised = sort({$nseqdenoised{$b} <=> $nseqdenoised{$a}} keys(%nseqdenoised));
		my $ndenoised = scalar(@denoised);
		my $length = length($ndenoised);
		my $num = 1;
		foreach my $seq (@denoised) {
			if ($nseqdenoised{$seq} == scalar(@{$denoised{$seq}})) {
				printf($filehandleoutput1 ">denoised_%0*d\n", $length, $num);
				print($filehandleoutput1 "$seq\n");
				printf($filehandleoutput2 ">denoised_%0*d\n", $length, $num);
				foreach my $member (@{$denoised{$seq}}) {
					print($filehandleoutput2 "$member\n");
				}
			}
			else {
				&errorMessage(__LINE__, "DADA2 output is invalid.");
			}
			$num ++;
		}
	}
	close($filehandleoutput2);
	close($filehandleoutput1);
	print(STDERR "done.\n");
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

sub extractcopyFile {
	my $filename = shift(@_);
	my $extractedfile = shift(@_);
	if ($filename =~ /\.gz$/i) {
		if (system("gzip -dc $filename > $extractedfile")) {
			&errorMessage(__LINE__, "Cannot run \"gzip -dc $filename > $extractedfile\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		if (system("bzip2 -dc $filename > $extractedfile")) {
			&errorMessage(__LINE__, "Cannot run \"bzip2 -dc $filename > $extractedfile\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		if (system("xz -dc $filename > $extractedfile")) {
			&errorMessage(__LINE__, "Cannot run \"xz -dc $filename > $extractedfile\".");
		}
	}
	else {
		unless (fcopy($filename, $extractedfile)) {
			&errorMessage(__LINE__, "Cannot copy \"$filename\" to \"$extractedfile\".");
		}
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
cldenoiseseqd options inputfolder outputfolder
cldenoiseseqd options inputfile1 inputfile2 ... inputfileN outputfolder

Command line options
====================
--pooling=ENABLE|DISABLE|PSEUDO
  Specify pooling mode for DADA2. (default: ENABLE)

--seed=INTEGER
  Specify the random number seed. (default: auto)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTQ (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}