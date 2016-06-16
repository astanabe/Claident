use strict;
use File::Spec;
use Cwd 'getcwd';

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
my $numthreads = 1;
my $vsearchoption = ' --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --strand plus --sizein --sizeout --qmask none --fulldp --cluster_size';
my $nodel;

# input/output
my $outputfolder;
my @inputfiles;

# commands
my $vsearch;

# global variables
my $root = getcwd();

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
	# make output directory
	if (!-e $outputfolder && !mkdir($outputfolder)) {
		&errorMessage(__LINE__, 'Cannot make output folder.');
	}
	# change working directory
	unless (chdir($outputfolder)) {
		&errorMessage(__LINE__, 'Cannot change working directory.');
	}
	# make concatenated files
	&makeConcatenatedFiles();
	# run assembling
	&runVSEARCH();
	# change working directory
	unless (chdir($root)) {
		&errorMessage(__LINE__, 'Cannot change working directory.');
	}
}

sub printStartupMessage {
	print(STDERR <<"_END");
clclassseqv $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
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
	# get arguments
	$outputfolder = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:min(?:imum)?ident(?:ity|ities)?|m)=(.+)$/i) {
			if (($1 > 0.8 && $1 <= 1) || $1 == 0) {
				$vsearchoption = " --id $1" . $vsearchoption;
			}
			else {
				&errorMessage(__LINE__, "The minimum identity threshold is invalid.");
			}
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
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if (!@inputfiles) {
		&errorMessage(__LINE__, "No input file was specified.");
	}
	if ($vsearchoption !~ / -+id \d+/) {
		$vsearchoption = " --id 0.97" . $vsearchoption;
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

sub makeConcatenatedFiles {
	$filehandleoutput1 = writeFile("concatenated.fasta");
	$filehandleoutput2 = writeFile("concatenated.otu.gz");
	foreach my $inputfile (@inputfiles) {
		my $filename = $inputfile;
		$filename =~ s/^.+(?:\/|\\)//;
		$filename =~ s/\.(?:gz|bz2|xz)$//;
		$filename =~ s/\.[^\.]+$//;
		my $tempinputfile;
		{
			my $inputpath;
			if ($inputfile =~ /^\//) {
				$inputpath = $inputfile;
			}
			else {
				$inputpath = "$root/$inputfile";
			}
			if ($inputfile =~ /\.(?:fq|fastq)(?:\.gz|\.bz2|\.xz)?$/) {
				&convertFASTQtoFASTA($inputpath, "$filename.fasta");
				$tempinputfile = "$filename.fasta";
			}
			elsif ($inputfile =~ /\.xz$/) {
				if (system("xz -dc $inputpath > $filename.fasta")) {
					&errorMessage(__LINE__, "Cannot run \"xz -dc $inputpath > $filename.fasta\".");
				}
				$tempinputfile = "$filename.fasta";
			}
			else {
				$tempinputfile = $inputpath;
			}
		}
		$filehandleinput1 = &readFile($tempinputfile);
		while (<$filehandleinput1>) {
			print($filehandleoutput1 $_);
		}
		close($filehandleinput1);
		my $otufile = $inputfile;
		$otufile =~ s/\.(?:fq|fastq|fa|fasta|fas)(?:\.gz|\.bz2|\.xz)?$/.otu.gz/;
		if ($otufile !~ /^\//) {
			$otufile = "$root/$otufile";
		}
		if (-e $otufile) {
			$filehandleinput1 = &readFile($otufile);
			while (<$filehandleinput1>) {
				print($filehandleoutput2 $_);
			}
			close($filehandleinput1);
		}
		else {
			$filehandleinput1 = &readFile($tempinputfile);
			while (<$filehandleinput1>) {
				if (/^>/) {
					print($filehandleoutput2 $_);
				}
			}
			close($filehandleinput1);
		}
	}
	close($filehandleoutput1);
	close($filehandleoutput2);
}

sub runVSEARCH {
	print(STDERR "Running clustering by VSEARCH...\n");
	if (system("$vsearch$vsearchoption concatenated.fasta --threads $numthreads --centroids clustered.fasta --uc clustered.uc 1> $devnull")) {
		&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption concatenated.fasta --threads $numthreads --centroids clustered.fasta --uc clustered.uc\".");
	}
	&convertUCtoOTUMembers("clustered.uc", "clustered.otu.gz", "concatenated.otu.gz");
	unlink("concatenated.fasta");
	unlink("concatenated.otu.gz");
	#if (system("perl -i.bak -npe 's/;size=\d+;?//' clustered.fasta")) {
	#	&errorMessage(__LINE__, "Cannot run \"perl -i.bak -npe 's/;size=\\d+;?//' clustered.fasta\".");
	#}
	#unlink("clustered.fasta.bak");
	#if (system("gzip clustered.fasta")) {
	#	&errorMessage(__LINE__, "Cannot run \"gzip clustered.fasta\".");
	#}
	print(STDERR "done.\n\n");
}

sub convertUCtoOTUMembers {
	my @subotufile = @_;
	my $ucfile = shift(@subotufile);
	my $otufile = shift(@subotufile);
	my %subcluster;
	foreach my $subotufile (@subotufile) {
		$filehandleinput1 = &readFile($subotufile);
		my $centroid;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;?//g;
			if (/^>(.+)$/) {
				$centroid = $1;
			}
			elsif ($centroid && /^([^>].*)$/) {
				push(@{$subcluster{$centroid}}, $1);
			}
		}
		close($filehandleinput1);
		unless ($centroid) {
			&errorMessage(__LINE__, "\"$subotufile\" is invalid.");
		}
	}
	my %cluster;
	$filehandleinput1 = &readFile($ucfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;size=\d+;?//g;
		my @row = split(/\t/, $_);
		if ($row[0] eq 'S') {
			push(@{$cluster{$row[8]}}, $row[8]);
			if (exists($subcluster{$row[8]})) {
				foreach my $submember (@{$subcluster{$row[8]}}) {
					if ($submember ne $row[8]) {
						push(@{$cluster{$row[8]}}, $submember);
					}
					else {
						&errorMessage(__LINE__, "\"$ucfile\" is invalid.");
					}
				}
			}
		}
		elsif ($row[0] eq 'H') {
			push(@{$cluster{$row[9]}}, $row[8]);
			if (exists($subcluster{$row[8]})) {
				foreach my $submember (@{$subcluster{$row[8]}}) {
					if ($submember ne $row[8] && $submember ne $row[9]) {
						push(@{$cluster{$row[9]}}, $submember);
					}
					else {
						&errorMessage(__LINE__, "\"$ucfile\" is invalid.");
					}
				}
			}
		}
	}
	close($filehandleinput1);
	unless ($nodel) {
		unlink($ucfile);
	}
	$filehandleoutput1 = &writeFile($otufile);
	foreach my $centroid (keys(%cluster)) {
		print($filehandleoutput1 ">$centroid\n");
		foreach my $member (@{$cluster{$centroid}}) {
			if ($member ne $centroid) {
				print($filehandleoutput1 "$member\n");
			}
		}
	}
	close($filehandleoutput1);
}

sub writeFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "| gzip -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "| bzip2 -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "| xz -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	else {
		unless (open($filehandle, "> $filename")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	return($filehandle);
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

sub convertFASTQtoFASTA {
	my $fastqfile = shift(@_);
	my $fastafile = shift(@_);
	$filehandleinput3 = &readFile($fastqfile);
	$filehandleoutput3 = &writeFile($fastafile);
	while (<$filehandleinput3>) {
		my $nameline = $_;
		my $seqline = <$filehandleinput3>;
		my $sepline = <$filehandleinput3>;
		my $qualline = <$filehandleinput3>;
		if (substr($nameline, 0, 1) ne '@') {
			&errorMessage(__LINE__, "\"$fastqfile\" is invalid.");
		}
		if (substr($sepline, 0, 1) ne '+') {
			&errorMessage(__LINE__, "\"$fastqfile\" is invalid.");
		}
		print($filehandleoutput3 '>' . substr($nameline, 1));
		print($filehandleoutput3 $seqline);
	}
	close($filehandleoutput3);
	close($filehandleinput3);
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
clclassseqv options inputfiles outputfolder

Command line options
====================
--minident=DECIMAL
  Specify the minimum identity threshold. (default: 0.97)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
