use strict;
use File::Spec;

my $buildno = '0.2.x';

# input/output
my @inputfiles;
my @otufiles;
my $outputfolder;
my $referencedb;

# options
my $mode = 'both';
my $uchimedenovo = 3;
my $vsearchoption = " --fasta_width 0 --notrunclabels --sizein --xsize";
my $elimborder = 1;
my $numthreads = 1;
my $nodel;

# the other global variables
my $devnull = File::Spec->devnull();
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
	# make concatenated files
	&makeTemporaryFile();
	# run VSEARCH
	&runVSEARCH();
	# remove chimeras
	&postVSEARCH();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clremovechimev $buildno
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
	my $vsearchmode = 0;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] eq 'end') {
			$vsearchmode = 0;
		}
		elsif ($vsearchmode) {
			$vsearchoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] eq 'vsearch' || $ARGV[$i] eq 'uchime') {
			$vsearchmode = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:elim|eliminate|del|delete)(?:border|borderline)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$elimborder = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$elimborder = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:mode|m)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:both|b)$/i) {
				$mode = 'both';
			}
			elsif ($value =~ /^(?:denovo|d)$/i) {
				$mode = 'denovo';
			}
			elsif ($value =~ /^(?:ref|r)$/i) {
				$mode = 'ref';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+uchimedenovo=(\d+)$/i) {
			$uchimedenovo = $1;
		}
		elsif ($ARGV[$i] =~ /^-+ref(?:erence)?(?:database|db)=(.+)$/i) {
			$referencedb = $1;
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
	if (scalar(@inputfiles) > 1) {
		&errorMessage(__LINE__, "Too many inputs were given.");
	}
	if (($mode eq 'both' || $mode eq 'ref') && !$referencedb) {
		&errorMessage(__LINE__, "\"uchime_ref\" is enabled but reference db is not given.");
	}
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if (!mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
	}
	if ($uchimedenovo < 1 || $uchimedenovo > 3) {
		&errorMessage(__LINE__, "Invalid value for version of UCHIME de novo.");
	}
	if ($uchimedenovo == 1) {
		$uchimedenovo = '';
	}
	# search referencedb
	if ($referencedb) {
		if (!-e $referencedb) {
			if (-e "$referencedb.fasta") {
				$referencedb = "$referencedb.fasta";
			}
			else {
				my $pathto;
				if ($ENV{'UCHIMEDB'}) {
					$pathto = $ENV{'UCHIMEDB'};
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
							if (/^\s*UCHIMEDB\s*=\s*(\S[^\r\n]*)/) {
								$pathto = $1;
								$pathto =~ s/\s+$//;
								last;
							}
						}
						close($filehandle);
					}
				}
				$pathto =~ s/^"(.+)"$/$1/;
				$pathto =~ s/\/$//;
				if ($pathto && -e "$pathto/$referencedb") {
					$referencedb = "$pathto/$referencedb";
				}
				elsif ($pathto && -e "$pathto/$referencedb.fasta") {
					$referencedb = "$pathto/$referencedb.fasta";
				}
				else {
					&errorMessage(__LINE__, "Both \"$referencedb\" and \"$pathto/$referencedb\" do not exist.");
				}
			}
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
	if ($vsearchoption =~ /-(?:chimeras|db|nonchimeras|uchime_denovo|uchime2_denovo|uchime3_denovo|uchime_ref|uchimealns|uchimeout|uchimeout5|centroids|cluster_fast|cluster_size|cluster_smallmem|clusters|consout|cons_truncate|derep_fulllength|sortbylength|sortbysize|output|allpairs_global|shuffle) /) {
		&errorMessage(__LINE__, "The option for vsearch is invalid.");
	}
	print(STDERR "Command line options for vsearch :$vsearchoption\n\n");
}

sub makeTemporaryFile {
	$filehandleinput1 = &readFile($otufiles[0]);
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
				&errorMessage(__LINE__, "\"$otufiles[0]\" is invalid.");
			}
		}
	}
	close($filehandleinput1);
	$filehandleoutput1 = &writeFile("$outputfolder/temp.fasta");
	$filehandleinput1 = &readFile($inputfiles[0]);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;size=\d+;*//g;
		if (/^>(.+)$/) {
			my $otuname = $1;
			if (@{$otumembers{$otuname}}) {
				my $size = scalar(@{$otumembers{$otuname}});
				s/$otuname/$otuname;size=$size;/;
			}
			else {
				&errorMessage(__LINE__, "\"$inputfiles[0]\" is invalid.");
			}
		}
		print($filehandleoutput1 "$_\n");
	}
	close($filehandleinput1);
	close($filehandleoutput1);
}

sub runVSEARCH {
	print(STDERR "Running chimera detection by VSEARCH...\n");
	if ($mode eq 'both' || $mode eq 'denovo') {
		if (system("$vsearch$vsearchoption --uchime$uchimedenovo\_denovo $outputfolder/temp.fasta --chimeras $outputfolder/denovo_chimeras.fasta --nonchimeras $outputfolder/denovo_nonchimeras.fasta --borderline $outputfolder/denovo_borderline.fasta --uchimeout $outputfolder/denovo_uchimeout.txt --uchimealns $outputfolder/denovo_uchimealns.txt 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption --uchime$uchimedenovo\_denovo $outputfolder/temp.fasta --sizein --xsize --chimeras $outputfolder/denovo_chimeras.fasta --nonchimeras $outputfolder/denovo_nonchimeras.fasta --borderline $outputfolder/denovo_borderline.fasta --uchimeout $outputfolder/denovo_uchimeout.txt --uchimealns $outputfolder/denovo_uchimealns.txt\" correctly.");
		}
		print(STDERR "\n");
	}
	if ($mode eq 'both' || $mode eq 'ref') {
		if (system("$vsearch$vsearchoption --uchime_ref $outputfolder/temp.fasta --db $referencedb --chimeras $outputfolder/ref_chimeras.fasta --nonchimeras $outputfolder/ref_nonchimeras.fasta --borderline $outputfolder/ref_borderline.fasta --uchimeout $outputfolder/ref_uchimeout.txt --uchimealns $outputfolder/ref_uchimealns.txt 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearchoption --uchime_ref $outputfolder/temp.fasta --db $referencedb --chimeras $outputfolder/ref_chimeras.fasta --nonchimeras $outputfolder/ref_nonchimeras.fasta --borderline $outputfolder/ref_borderline.fasta --uchimeout $outputfolder/ref_uchimeout.txt --uchimealns $outputfolder/ref_uchimealns.txt\" correctly.");
		}
	}
	print(STDERR "done.\n\n");
}

sub postVSEARCH {
	print(STDERR "Analyzing VSEARCH output and save results...\n");
	my %chimeras;
	if ($mode eq 'both' || $mode eq 'denovo') {
		$filehandleinput1 = &readFile("$outputfolder/denovo_chimeras.fasta");
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;+size=\d+;*//g;
			if (/^>(.+)$/) {
				$chimeras{$1} = 1;
			}
		}
		close($filehandleinput1);
		if ($elimborder) {
			$filehandleinput1 = &readFile("$outputfolder/denovo_borderline.fasta");
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				s/;+size=\d+;*//g;
				if (/^>(.+)$/) {
					$chimeras{$1} = 1;
				}
			}
			close($filehandleinput1);
		}
	}
	if ($mode eq 'both' || $mode eq 'ref') {
		$filehandleinput1 = &readFile("$outputfolder/ref_chimeras.fasta");
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;+size=\d+;*//g;
			if (/^>(.+)$/) {
				$chimeras{$1} = 1;
			}
		}
		close($filehandleinput1);
		if ($elimborder) {
			$filehandleinput1 = &readFile("$outputfolder/ref_borderline.fasta");
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				s/;+size=\d+;*//g;
				if (/^>(.+)$/) {
					$chimeras{$1} = 1;
				}
			}
			close($filehandleinput1);
		}
	}
	$filehandleoutput1 = &writeFile("$outputfolder/nonchimeras.fasta");
	$filehandleinput1 = &readFile($inputfiles[0]);
	{
		my $switch = 0;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;+size=\d+;*//g;
			if (/^>(.+)$/) {
				if ($chimeras{$1}) {
					$switch = 0;
				}
				else {
					$switch = 1;
				}
			}
			if ($switch) {
				print($filehandleoutput1 "$_\n");
			}
		}
	}
	close($filehandleinput1);
	close($filehandleoutput1);
	$filehandleoutput1 = &writeFile("$outputfolder/nonchimeras.otu.gz");
	$filehandleinput1 = &readFile($otufiles[0]);
	{
		my $switch = 0;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;+size=\d+;*//g;
			if (/^>(.+)$/) {
				if ($chimeras{$1}) {
					$switch = 0;
				}
				else {
					$switch = 1;
				}
			}
			if ($switch) {
				print($filehandleoutput1 "$_\n");
			}
		}
	}
	close($filehandleinput1);
	close($filehandleoutput1);
	unless ($nodel) {
		unlink("$outputfolder/temp.fasta");
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

# error message
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
clremovechimev options inputfolder outputfolder
clremovechimev options inputfile outputfolder

Command line options
====================
vsearch options end
  Specify commandline options for vsearch.
(default: none)

--mode=BOTH|DENOVO|REF
  Specify run mode. (default: REF)

--uchimedenovo=1|2|3
  Specify version of UCHIME de novo. (default: 3)

--referencedb=FILENAME
  Specify file path to reference database (default: none)

--elimborder=ENABLE|DISABLE
  Specify whether borderline sequences must be eliminated or not.
(default: ENABLE)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, or bzip2-compressed)
_END
	exit;
}