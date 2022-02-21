use strict;
use File::Spec;
use Cwd 'getcwd';

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

# options
my $numthreads = 1;
my $vsearchoption = ' --fasta_width 0 --maxseqlength 50000 --minseqlength 32 --notrunclabels --sizein --xsize --sizeorder --clusterout_sort --qmask none --fulldp --cluster_size';
my $paddinglen = 0;
my $minovllen = 0;
my $tableformat = 'matrix';
my $nodel;

# input/output
my $outputfolder;
my @inputfiles;
my @otufiles;

# commands
my $vsearch;
my $vsearch5d;

# global variables
my $root = getcwd();
my %ignoreotulist;
my $ignoreotulist;
my $ignoreotuseq;
my %ignoreotumembers;
my %ignoreotuseq;

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
	# read negative seqids list file
	&readListFiles();
	# make concatenated files
	&makeConcatenatedFiles();
	# run assembling
	&runVSEARCH();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clclassseqv $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2022  Akifumi S. Tanabe

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
		elsif ($ARGV[$i] =~ /^-+padding(?:len|length)=(\d+)$/i) {
			$paddinglen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:overlap|ovl)(?:length|len)=(\d+)$/i) {
			$minovllen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+tableformat=(.+)$/i) {
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
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$ignoreotulist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)list=(.+)$/i) {
			$ignoreotulist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)seq=(.+)$/i) {
			$ignoreotuseq = $1;
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
		foreach my $inputfile (@inputfiles) {
			if (-d $inputfile) {
				my @temp = sort(glob("$inputfile/*.fasta"), glob("$inputfile/*.fasta.gz"), glob("$inputfile/*.fasta.bz2"), glob("$inputfile/*.fasta.xz"));
				for (my $i = 0; $i < scalar(@temp); $i ++) {
					if (-e $temp[$i]) {
						my $otufile = $temp[$i];
						$otufile =~ s/\.(?:fq|fastq|fa|fasta|fas)(?:\.gz|\.bz2|\.xz)?$/.otu.gz/;
						if (-e $otufile) {
							push(@newinputfiles, $temp[$i]);
							push(@otufiles, $otufile);
						}
					}
					else {
						&errorMessage(__LINE__, "The input files \"$temp[$i]\" is invalid.");
					}
				}
			}
			elsif (-e $inputfile) {
				my $otufile = $inputfile;
				$otufile =~ s/\.(?:fq|fastq|fa|fasta|fas)(?:\.gz|\.bz2|\.xz)?$/.otu.gz/;
				if (-e $otufile) {
					push(@newinputfiles, $inputfile);
					push(@otufiles, $otufile);
				}
			}
			else {
				&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
			}
		}
		@inputfiles = @newinputfiles;
	}
	if (scalar(@inputfiles) != scalar(@otufiles)) {
		&errorMessage(__LINE__, "The number of input files is different from the number of otu files.");
	}
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if (!mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
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

sub readListFiles {
	print(STDERR "Reading several lists...\n");
	if ($ignoreotulist) {
		foreach my $ignoreotu (&readList($ignoreotulist)) {
			$ignoreotulist{$ignoreotu} = 1;
		}
	}
	if ($ignoreotuseq) {
		foreach my $ignoreotu (&readSeq($ignoreotuseq)) {
			$ignoreotulist{$ignoreotu} = 1;
		}
	}
	print(STDERR "done.\n\n");
}

sub readList {
	my $listfile = shift(@_);
	my @list;
	$filehandleinput1 = &readFile($listfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/\t.+//;
		push(@list, $_);
	}
	close($filehandleinput1);
	return(@list);
}

sub readSeq {
	my $seqfile = shift(@_);
	my @list;
	$filehandleinput1 = &readFile($seqfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		if (/^> *(.+)/) {
			my $seqname = $1;
			push(@list, $seqname);
		}
	}
	close($filehandleinput1);
	return(@list);
}

sub makeConcatenatedFiles {
	$filehandleoutput1 = &writeFile("$outputfolder/concatenated.otu.gz");
	$filehandleoutput2 = &writeFile("$outputfolder/concatenated.fasta");
	my $num = 1;
	for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
		$filehandleinput1 = &readFile($otufiles[$i]);
		my %replace;
		my %otumembers;
		{
			my $otuname;
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				s/;size=\d+;*//g;
				if (/^>(.+)$/) {
					$otuname = $1;
					if (exists($ignoreotulist{$otuname})) {
						next;
					}
					else {
						s/$otuname/temp_$num/;
						$replace{$otuname} = "temp_$num";
						$num ++;
					}
				}
				elsif ($otuname && exists($ignoreotulist{$otuname}) && /^([^>].*)$/) {
					push(@{$ignoreotumembers{$otuname}}, $1);
				}
				elsif ($otuname && !exists($ignoreotulist{$otuname}) && /^([^>].*)$/) {
					push(@{$otumembers{$replace{$otuname}}}, $1);
				}
				else {
					&errorMessage(__LINE__, "\"$otufiles[$i]\" is invalid.");
				}
				if ($otuname && !exists($ignoreotulist{$otuname})) {
					print($filehandleoutput1 "$_\n");
				}
			}
		}
		close($filehandleinput1);
		$filehandleinput1 = &readFile($inputfiles[$i]);
		{
			my $otuname;
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				s/;size=\d+;*//g;
				if (/^>(.+)$/) {
					$otuname = $1;
					if (exists($ignoreotulist{$otuname})) {
						next;
					}
					elsif ($replace{$otuname} && @{$otumembers{$replace{$otuname}}}) {
						my $size = scalar(@{$otumembers{$replace{$otuname}}});
						s/$otuname/$replace{$otuname};size=$size;/;
					}
					else {
						&errorMessage(__LINE__, "\"$inputfiles[$i]\" is invalid.");
					}
				}
				elsif ($otuname && exists($ignoreotulist{$otuname}) && /^([^>].*)$/) {
					my $tempseq = $1;
					$tempseq =~ s/[^A-Za-z]//g;
					$ignoreotuseq{$otuname} .= $tempseq;
				}
				if ($otuname && !exists($ignoreotulist{$otuname})) {
					print($filehandleoutput2 "$_\n");
				}
			}
		}
		close($filehandleinput1);
	}
	close($filehandleoutput1);
	close($filehandleoutput2);
}

sub runVSEARCH {
	print(STDERR "Running clustering by VSEARCH...\n");
	my $tempminovllen;
	if ($minovllen == 0) {
		$tempminovllen = &getMinimumLength("$outputfolder/concatenated.fasta") - 10;
	}
	else {
		$tempminovllen = $minovllen;
	}
	if ($paddinglen > 0) {
		if (system("$vsearch5d$vsearchoption $outputfolder/concatenated.fasta --idoffset $paddinglen --threads $numthreads --centroids $outputfolder/temp.fasta --uc $outputfolder/temp.uc --mincols $tempminovllen 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch5d$vsearchoption $outputfolder/concatenated.fasta --idoffset $paddinglen --threads $numthreads --centroids $outputfolder/temp.fasta --uc $outputfolder/temp.uc --mincols $tempminovllen\".");
		}
	}
	else {
		if (system("$vsearch$vsearchoption $outputfolder/concatenated.fasta --threads $numthreads --centroids $outputfolder/temp.fasta --uc $outputfolder/temp.uc --mincols $tempminovllen 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption $outputfolder/concatenated.fasta --threads $numthreads --centroids $outputfolder/temp.fasta --uc $outputfolder/temp.uc --mincols $tempminovllen\".");
		}
	}
	&convertUCtoOTUMembers("$outputfolder/temp.fasta", "$outputfolder/temp.uc", "$outputfolder/clustered.fasta", "$outputfolder/clustered.otu.gz", "$outputfolder/concatenated.otu.gz");
	unless ($nodel) {
		unlink("$outputfolder/concatenated.fasta");
		unlink("$outputfolder/concatenated.otu.gz");
		unlink("$outputfolder/temp.fasta");
		unlink("$outputfolder/temp.uc");
	}
	print(STDERR "done.\n\n");
}

sub convertUCtoOTUMembers {
	my $tempfasta = shift(@_);
	my $tempuc = shift(@_);
	my $outfasta = shift(@_);
	my $outotufile = shift(@_);
	my %subotumembers;
	foreach my $subotufile (@_) {
		$filehandleinput1 = &readFile($subotufile);
		my $otuname;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;+size=\d+;*//g;
			if (/^>(.+)$/) {
				$otuname = $1;
			}
			elsif ($otuname && /^([^>].*)$/) {
				push(@{$subotumembers{$otuname}}, $1);
			}
			else {
				&errorMessage(__LINE__, "\"$subotufile\" is invalid.");
			}
		}
		close($filehandleinput1);
	}
	my %otumembers;
	$filehandleinput1 = &readFile($tempuc);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;+size=\d+;*//g;
		my @row = split(/\t/, $_);
		if ($row[0] eq 'S') {
			if (exists($subotumembers{$row[8]})) {
				foreach my $submember (@{$subotumembers{$row[8]}}) {
					push(@{$otumembers{$row[8]}}, $submember);
				}
			}
			else {
				push(@{$otumembers{$row[8]}}, $row[8]);
			}
		}
		elsif ($row[0] eq 'H') {
			if (exists($subotumembers{$row[8]})) {
				foreach my $submember (@{$subotumembers{$row[8]}}) {
					push(@{$otumembers{$row[9]}}, $submember);
				}
			}
			else {
				push(@{$otumembers{$row[9]}}, $row[8]);
			}
		}
	}
	close($filehandleinput1);
	my %table;
	my %samplenames;
	my %otunames;
	my %replace;
	$filehandleoutput1 = &writeFile($outotufile);
	if (%ignoreotumembers) {
		foreach my $otuname (sort({scalar(@{$ignoreotumembers{$b}}) <=> scalar(@{$ignoreotumembers{$a}}) || $a cmp $b} keys(%ignoreotumembers))) {
			print($filehandleoutput1 ">$otuname\n");
			foreach my $member (@{$ignoreotumembers{$otuname}}) {
				if ($member =~ / SN:(\S+)/) {
					my $samplename = $1;
					$table{$samplename}{$otuname} ++;
					$samplenames{$samplename} = 1;
				}
				print($filehandleoutput1 "$member\n");
			}
		}
	}
	{
		my @otumembers = sort({scalar(@{$otumembers{$b}}) <=> scalar(@{$otumembers{$a}}) || $a cmp $b} keys(%otumembers));
		my $notumembers = scalar(@otumembers);
		my $length = length($notumembers);
		my $num = 1;
		foreach my $centroid (@otumembers) {
			my $otuname = sprintf("otu_%0*d", $length, $num);
			$otunames{$otuname} = scalar(@{$otumembers{$centroid}});
			$replace{$centroid} = $otuname;
			print($filehandleoutput1 ">$otuname\n");
			foreach my $member (@{$otumembers{$centroid}}) {
				if ($member =~ / SN:(\S+)/) {
					my $samplename = $1;
					$table{$samplename}{$otuname} ++;
					$samplenames{$samplename} = 1;
				}
				print($filehandleoutput1 "$member\n");
			}
			$num ++;
		}
	}
	close($filehandleoutput1);
	$filehandleoutput1 = &writeFile($outfasta);
	if (%ignoreotuseq) {
		foreach my $otuname (sort({scalar(@{$ignoreotumembers{$b}}) <=> scalar(@{$ignoreotumembers{$a}}) || $a cmp $b} keys(%ignoreotuseq))) {
			print($filehandleoutput1 ">$otuname\n" . $ignoreotuseq{$otuname} . "\n");
		}
	}
	$filehandleinput1 = &readFile($tempfasta);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;size=\d+;*//g;
		if (/^>(.+)$/) {
			my $otuname = $1;
			if ($replace{$otuname}) {
				s/$otuname/$replace{$otuname}/;
			}
			else {
				&errorMessage(__LINE__, "\"$tempfasta\" is invalid.");
			}
		}
		print($filehandleoutput1 "$_\n");
	}
	close($filehandleinput1);
	close($filehandleoutput1);
	# save table
	{
		my @otunames = (sort({scalar(@{$ignoreotumembers{$b}}) <=> scalar(@{$ignoreotumembers{$a}}) || $a cmp $b} keys(%ignoreotumembers)), sort({$otunames{$b} <=> $otunames{$a} || $a cmp $b} keys(%otunames)));
		my @samplenames = sort({$a cmp $b} keys(%samplenames));
		unless (open($filehandleoutput1, "> $outputfolder/clustered.tsv")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/clustered.tsv\".");
		}
		if ($tableformat eq 'matrix') {
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
		elsif ($tableformat eq 'column') {
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

sub writeFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "| pigz -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "| lbzip2 -c > $filename 2> $devnull")) {
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
		unless (open($filehandle, "pigz -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "lbzip2 -dc $filename 2> $devnull |")) {
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
clclassseqv options inputfolder outputfolder
clclassseqv options inputfiles outputfolder

Command line options
====================
--minident=DECIMAL
  Specify the minimum identity threshold. (default: 0.97)

--strand=PLUS|BOTH
  Specify search strand option for VSEARCH. (default: PLUS)

--paddinglen=INTEGER
  Specify the length of padding. (default: 0)

--minovllen=INTEGER
  Specify minimum overlap length. 0 means automatic. (default: 0)

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: MATRIX)

--ignoreotu=SAMPLENAME,...,SAMPLENAME
  Specify ignoring otu names. (default: none)

--ignoreotulist=FILENAME
  Specify file name of ignoring otu list. (default: none)

--ignoreotuseq=FILENAME
  Specify file name of ignoring otu list. (default: none)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
