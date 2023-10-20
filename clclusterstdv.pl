use strict;
use File::Spec;
use Cwd 'getcwd';

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

# options
my $numthreads = 1;
my $hthreads;
my $vsearchoption = ' --fasta_width 0 --maxseqlength 50000 --minseqlength 32 --notrunclabels --qmask none --dbmask none --fulldp --maxaccepts 0 --maxrejects 0 --uc_allhits --usearch_global';
my $paddinglen = 0;
my $minovllen = 0;
my $tableformat = 'matrix';
my $nodel;
my $minident = 0.9;

# input/output
my $outputfolder;
my @inputfiles;
my @otufiles;
my $stdseq;

# commands
my $vsearch;
my $vsearch5d;

# global variables
my $root = getcwd();
my @stdlist;

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
	# read sequence files
	&readSequenceFiles();
	# make concatenated files
	&makeConcatenatedFiles();
	# run assembling
	&runVSEARCH();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clclusterstdv $buildno
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
				$minident = $1;
				$vsearchoption = " --id " . ($minident - 0.2) . $vsearchoption;
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
		elsif ($ARGV[$i] =~ /^-+(?:std|stdseq|standard|standardseq|stdotu|stdotuseq|standardotu|standardotuseq)=(.+)$/i) {
			$stdseq = $1;
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
	if (!$stdseq) {
		&errorMessage(__LINE__, "No standard sequence was specified.");
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
	if (scalar(@inputfiles) > 1) {
		&errorMessage(__LINE__, "This command accepts only 1 input file.");
	}
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if (!mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
	}
	if ($vsearchoption !~ / -+id \d+/) {
		$vsearchoption = " --id 0.7" . $vsearchoption;
	}
	if ($vsearchoption !~ /-+strand (plus|both)/i) {
		$vsearchoption = ' --strand plus' . $vsearchoption;
	}
	$hthreads = int($numthreads / 2);
	if ($hthreads < 1) {
		$hthreads = 1;
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

sub readSequenceFiles {
	if ($stdseq) {
		@stdlist = &readSeq($stdseq);
	}
}

sub makeConcatenatedFiles {
	$filehandleoutput1 = &writeFile("$outputfolder/concatenated.otu.gz");
	$filehandleoutput2 = &writeFile("$outputfolder/concatenated.fasta");
	for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
		$filehandleinput1 = &readFile($otufiles[$i]);
		my %otumembers;
		{
			my $otuname;
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				s/;size=\d+;*//g;
				if (/^>(.+)$/) {
					$otuname = $1;
				}
				elsif ($otuname && /^([^>].*)$/) {
					push(@{$otumembers{$otuname}}, $1);
				}
				else {
					&errorMessage(__LINE__, "\"$otufiles[$i]\" is invalid.");
				}
				print($filehandleoutput1 "$_\n");
			}
		}
		close($filehandleinput1);
		$filehandleinput1 = &readFile($inputfiles[$i]);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;*//g;
			if (/^>(.+)$/) {
				my $otuname = $1;
				unless (exists($otumembers{$otuname})) {
					&errorMessage(__LINE__, "\"$inputfiles[$i]\" is invalid.");
				}
			}
			print($filehandleoutput2 "$_\n");
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
		if (system("$vsearch5d$vsearchoption $stdseq --db $outputfolder/concatenated.fasta --idoffset $paddinglen --threads $numthreads --notmatched $outputfolder/notmatched.fasta --uc $outputfolder/matched.uc --mincols $tempminovllen 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch5d$vsearchoption $stdseq --db $outputfolder/concatenated.fasta --idoffset $paddinglen --threads $numthreads --notmatched $outputfolder/notmatched.fasta --uc $outputfolder/matched.uc --mincols $tempminovllen\".");
		}
	}
	else {
		if (system("$vsearch$vsearchoption $stdseq --db $outputfolder/concatenated.fasta --threads $numthreads --notmatched $outputfolder/notmatched.fasta --uc $outputfolder/matched.uc --mincols $tempminovllen 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption $stdseq --db $outputfolder/concatenated.fasta --threads $numthreads --notmatched $outputfolder/notmatched.fasta --uc $outputfolder/matched.uc --mincols $tempminovllen\".");
		}
	}
	if (-e "$outputfolder/notmatched.fasta" && !-z "$outputfolder/notmatched.fasta") {
		print(STDERR "WARNING!: There are unmatched internal standard. This is weird. Please check standard sequence and data.\n");
	}
	&convertUCtoOTUMembers("$outputfolder/concatenated.fasta", "$outputfolder/matched.uc", "$outputfolder/stdclustered.fasta", "$outputfolder/stdclustered.otu.gz", "$outputfolder/stdvariations.fasta", "$outputfolder/concatenated.otu.gz");
	unless ($nodel) {
		unlink("$outputfolder/concatenated.fasta");
		unlink("$outputfolder/concatenated.otu.gz");
		unlink("$outputfolder/notmatched.fasta");
		unlink("$outputfolder/matched.uc");
	}
	print(STDERR "done.\n\n");
}

sub convertUCtoOTUMembers {
	my $tempfasta = shift(@_);
	my $tempuc = shift(@_);
	my $outfasta = shift(@_);
	my $outotufile = shift(@_);
	my $varfasta = shift(@_);
	my %otumembers;
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
				push(@{$otumembers{$otuname}}, $1);
			}
			else {
				&errorMessage(__LINE__, "\"$subotufile\" is invalid.");
			}
		}
		close($filehandleinput1);
	}
	$filehandleinput1 = &readFile($tempuc);
	{
		my %replace;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;+size=\d+;*//g;
			my @row = split(/\t/, $_);
			if ($row[0] eq 'H') {
				if (exists($otumembers{$row[9]})) {
					my $alnlen = 0;
					my $diff = 0;
					if ($row[7] eq '=') {
						$alnlen = $row[2];
						$diff = 0;
					}
					else {
						my @temp = $row[7] =~ /\d*[MDI]/g;
						my @compaln;
						my @compalc;
						for (my $i = 0; $i < scalar(@temp); $i ++) {
							$compaln[$i] = $temp[$i];
							$compaln[$i] =~ s/[MDI]$//;
							if ($compaln[$i] eq '') {
								$compaln[$i] = 1;
							}
							$compalc[$i] = $temp[$i];
							$compalc[$i] =~ s/^\d*//;
						}
						foreach (@compaln) {
							$alnlen += $_;
						}
						$diff = int(($alnlen * (1 - ($row[3] / 100))) + 0.5);
						for (my $i = 0; $i < scalar(@compalc); $i ++) {
							if ($compalc[$i] eq 'D' || $compalc[$i] eq 'I') {
								$diff = $diff - $compaln[$i] + 1;
							}
						}
					}
					my $pident = (($alnlen - $diff) / $alnlen);
					if ($pident >= $minident) {
						$replace{$row[9]}{$row[8]} = $pident;
					}
				}
				else {
					&errorMessage(__LINE__, "\"$tempuc\" is invalid.");
				}
			}
			elsif ($row[0] eq 'N') {
				next;
			}
			else {
				&errorMessage(__LINE__, "\"$tempuc\" is invalid.");
			}
		}
		foreach my $from (keys(%replace)) {
			foreach my $to (sort({$replace{$from}{$b} <=> $replace{$from}{$a}} keys(%{$replace{$from}}))) {
				if (exists($otumembers{$from})) {
					foreach my $member (@{$otumembers{$from}}) {
						push(@{$otumembers{$to}}, $member);
					}
					delete($otumembers{$from});
					last;
				}
			}
		}
	}
	close($filehandleinput1);
	my %table;
	my %samplenames;
	my %otunames;
	$filehandleoutput1 = &writeFile($outotufile);
	{
		my @otumembers = sort({scalar(@{$otumembers{$b}}) <=> scalar(@{$otumembers{$a}}) || $a cmp $b} keys(%otumembers));
		my $notumembers = scalar(@otumembers);
		my $length = length($notumembers);
		foreach my $centroid (@otumembers) {
			$otunames{$centroid} = 1;
			print($filehandleoutput1 ">$centroid\n");
			foreach my $member (@{$otumembers{$centroid}}) {
				if ($member =~ / SN:(\S+)/) {
					my $samplename = $1;
					$table{$samplename}{$centroid} ++;
					$samplenames{$samplename} = 1;
				}
				print($filehandleoutput1 "$member\n");
			}
		}
	}
	close($filehandleoutput1);
	$filehandleoutput1 = &writeFile($outfasta);
	$filehandleinput1 = &readFile($stdseq);
	{
		my $otuname;
		my $switch = 0;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if (/^>(.+)$/) {
				my $otuname = $1;
				if (exists($otumembers{$otuname})) {
					$switch = 1;
				}
				else {
					$switch = 0;
				}
			}
			if ($switch) {
				print($filehandleoutput1 "$_\n");
			}
		}
	}
	close($filehandleinput1);
	$filehandleinput1 = &readFile($tempfasta);
	$filehandleoutput2 = &writeFile($varfasta);
	{
		my $otuname;
		my $switch = 0;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if (/^>(.+)$/) {
				my $otuname = $1;
				if (exists($otumembers{$otuname})) {
					$switch = 1;
				}
				else {
					$switch = 0;
				}
			}
			if ($switch) {
				print($filehandleoutput1 "$_\n");
			}
			else {
				print($filehandleoutput2 "$_\n");
			}
		}
	}
	close($filehandleoutput2);
	close($filehandleinput1);
	close($filehandleoutput1);
	# save table
	{
		my @otunames = @stdlist;
		foreach my $std (@stdlist) {
			delete($otunames{$std});
		}
		push(@otunames, sort({$a cmp $b} keys(%otunames)));
		my @samplenames = sort({$a cmp $b} keys(%samplenames));
		unless (open($filehandleoutput1, "> $outputfolder/stdclustered.tsv")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/stdclustered.tsv\".");
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

sub readSeq {
	my $seqfile = shift(@_);
	my @list;
	$filehandleinput1 = &readFile($seqfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		if (/^> *(.+)/) {
			my $seqname = $1;
			$seqname =~ s/;+size=\d+;*//g;
			push(@list, $seqname);
		}
	}
	close($filehandleinput1);
	return(@list);
}

sub writeFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "| pigz -p $hthreads -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "| lbzip2 -n $hthreads -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "| xz -T $hthreads -c > $filename 2> $devnull")) {
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
		unless (open($filehandle, "pigz -p $hthreads -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "lbzip2 -n $hthreads -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "xz -T $hthreads -dc $filename 2> $devnull |")) {
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
clclusterstdv options inputfolder outputfolder
clclusterstdv options inputfiles outputfolder

Command line options
====================
--standardseq=FILENAME
  Specify FASTA sequence file of internal standard. (default: none)

--minident=DECIMAL
  Specify the minimum identity threshold. (default: 0.90)

--strand=PLUS|BOTH
  Specify search strand option for VSEARCH. (default: PLUS)

--paddinglen=INTEGER
  Specify the length of padding. (default: 0)

--minovllen=INTEGER
  Specify minimum overlap length. 0 means automatic. (default: 0)

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: MATRIX)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
