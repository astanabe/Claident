use strict;
use File::Spec;
use File::Copy::Recursive ('fcopy', 'rcopy', 'dircopy');
use Cwd 'getcwd';

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
my $numthreads = 1;
my $vsearchoption = ' --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --qmask none --dbmask none --fulldp --usearch_global';
my $vsearchoption2 = ' --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --sizein --sizeout --sortbysize';
my $paddinglen = 0;
my $minovllen = 0;
my $nodel;

# input/output
my $outputfolder;
my @inputfiles;
my $centroidfile;

# commands
my $vsearch;
my $vsearch5d;

# global variables
my $root = getcwd();
my %members;

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
	# check input file format
	&checkInputFiles();
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
clrecoverseqv $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2019  Akifumi S. Tanabe

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
		elsif ($ARGV[$i] =~ /^-+(?:strand|s)=(forward|plus|single|both|double)$/i) {
			if ($1 =~ /^(?:forward|plus|single)$/i) {
				$vsearchoption = ' --strand plus' . $vsearchoption;
			}
			else {
				$vsearchoption = ' --strand both' . $vsearchoption;
			}
		}
		elsif ($ARGV[$i] =~ /^-+centroids?=(.+)$/i) {
			if (-e $1) {
				$centroidfile = $1;
			}
			else {
				&errorMessage(__LINE__, "The centroid sequence file does not exist.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+padding(?:len|length)=(\d+)$/i) {
			$paddinglen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:overlap|ovl)(?:length|len)=(\d+)$/i) {
			$minovllen = $1;
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
	if ($vsearchoption !~ /-+strand (plus|both)/i) {
		$vsearchoption = ' --strand plus' . $vsearchoption;
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
			$vsearch5d = "\"$pathto/vsearch5d\"";
		}
		else {
			$vsearch = 'vsearch';
			$vsearch5d = 'vsearch5d';
		}
	}
}

sub checkInputFiles {
	print(STDERR "Checking input files...\n");
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $inputfile (@inputfiles) {
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
				print(STDERR "Checking $inputfile...\n");
				if ($inputfile =~ /^.+__.+__.+/) {
					my $fileformat;
					my $lineno = 1;
					$filehandleinput1 = &readFile($inputfile);
					while (<$filehandleinput1>) {
						if (!$fileformat && $lineno == 1) {
							if (/^>/) {
								$fileformat = 'FASTA';
							}
							elsif (/^\@/) {
								$fileformat = 'FASTQ';
							}
							else {
								&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
							}
						}
						if ($fileformat eq 'FASTA' && /^>/ || $fileformat eq 'FASTQ' && $lineno % 4 == 1) {
							if ($_ =~ /.+__.+__.+__.+/ || $_ =~ /^\s*\r?\n?$/) {
								$lineno ++;
								next;
							}
							else {
								$_ = s/^[>\@](.+)\r?\n?$/$1/;
								&errorMessage(__LINE__, "The sequence name \"$_\" in \"$inputfile\" is invalid.");
							}
						}
						$lineno ++;
					}
					close($filehandleinput1);
				}
				exit;
			}
		}
	}
	print(STDERR "done.\n\n");
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
	print(STDERR "Running remapping by VSEARCH...\n");
	unless (fcopy("$root/$centroidfile", "clustered.fasta")) {
		&errorMessage(__LINE__, "Cannot copy \"$root/$centroidfile\" to \"clustered.fasta\".");
	}
	my $tempminovllen;
	if ($minovllen == 0) {
		$tempminovllen = &getMinimumLength("concatenated.fasta") - 10;
	}
	else {
		$tempminovllen = $minovllen;
	}
	# remap dereplicated reads to centroids
	if ($paddinglen > 0) {
		if (system("$vsearch5d$vsearchoption concatenated.fasta --db clustered.fasta --threads $numthreads --dbnotmatched nohit.fasta --uc clustered.uc --idoffset $paddinglen --mincols $tempminovllen 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch5d$vsearchoption concatenated.fasta --db clustered.fasta --threads $numthreads --dbnotmatched nohit.fasta --uc clustered.uc --idoffset $paddinglen --mincols $tempminovllen\".");
		}
	}
	else {
		if (system("$vsearch$vsearchoption concatenated.fasta --db clustered.fasta --threads $numthreads --dbnotmatched nohit.fasta --uc clustered.uc --mincols $tempminovllen 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption concatenated.fasta --db clustered.fasta --threads $numthreads --dbnotmatched nohit.fasta --uc clustered.uc --mincols $tempminovllen\".");
		}
	}
	&convertUCtoOTUMembers("clustered.uc", "clustered.otu.gz", "concatenated.otu.gz");
	unless ($nodel) {
		unlink("concatenated.fasta");
		unlink("concatenated.otu.gz");
	}
	if (-z "nohit.fasta") {
		unlink("nohit.fasta");
	}
	else {
		print(STDERR "WARNING!: Several centroid sequences did not match the input sequences.\nThis is weird.\nPlease check the input files and \"nohit.fasta\".\n");
		#if (system("gzip nohit.fasta")) {
		#	&errorMessage(__LINE__, "Cannot run \"gzip nohit.fasta\".");
		#}
	}
	# sort by abundance
	&readMembers("clustered.otu.gz");
	{
		$filehandleinput1 = &readFile("clustered.fasta");
		$filehandleoutput1 = &writeFile("temp.fasta");
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
				my $seqname = $1;
				my $sequence = uc($2);
				$seqname =~ s/;+size=\d+;*//g;
				$sequence =~ s/[^A-Z]//sg;
				if ($members{$seqname}) {
					print($filehandleoutput1 ">$seqname;size=$members{$seqname};\n$sequence\n");
				}
				else {
					&errorMessage(__LINE__, "Invalid result.");
				}
			}
		}
		close($filehandleoutput1);
		close($filehandleinput1);
	}
	if (system("$vsearch$vsearchoption2 temp.fasta --output clustered.fasta --threads $numthreads 1> $devnull")) {
		&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption2 temp.fasta --output clustered.fasta --threads $numthreads\".");
	}
	unless ($nodel) {
		unlink("temp.fasta");
	}
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
			s/;+size=\d+;*//g;
			if (/^>(.+)$/) {
				$centroid = $1;
			}
			elsif ($centroid && /^([^>].*)$/) {
				push(@{$subcluster{$centroid}}, $1);
			}
		}
		close($filehandleinput1);
	}
	my %cluster;
	$filehandleinput1 = &readFile($ucfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;+size=\d+;*//g;
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

sub getMinimumLength {
	my $filename = shift(@_);
	my $minlen;
	unless (open($filehandleinput1, "< $filename")) {
		&errorMessage(__LINE__, "Cannot read \"$filename\".");
	}
	my $templength = 0;
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/\s+//g;
		if (/^>/ && $templength > 0) {
			if (!defined($minlen) || $templength < $minlen) {
				$minlen = $templength;
			}
			$templength = 0;
		}
		else {
			$templength += length($_);
		}
	}
	close($filehandleinput1);
	if (!defined($minlen) || $templength < $minlen) {
		$minlen = $templength;
	}
	if ($minlen < 100) {
		$minlen = 100;
	}
	if ($minlen > 10000) {
		$minlen = 10000;
	}
	return($minlen);
}

sub readMembers {
	my $otufile = shift(@_);
	$filehandleinput1 = &readFile($otufile);
	my $centroid;
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;+size=\d+;*//g;
		if (/^>(.+)$/) {
			$centroid = $1;
			$members{$centroid} = 1;
		}
		elsif ($centroid && /^([^>].*)$/) {
			$members{$centroid} ++;
		}
		else {
			&errorMessage(__LINE__, "\"$otufile\" is invalid.");
		}
	}
	close($filehandleinput1);
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
clrecoverseqv options inputfiles outputfolder

Command line options
====================
--minident=DECIMAL
  Specify the minimum identity threshold. (default: 0.97)

--strand=PLUS|BOTH
  Specify search strand option for VSEARCH. (default: PLUS)

--centroid=FILENAME
  Specify the centroid sequence file. (default: none)

--paddinglen=INTEGER
  Specify the length of padding. (default: 0)

--minovllen=INTEGER
  Specify minimum overlap length. 0 means automatic. (default: 0)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
