use strict;
use File::Spec;

my $buildno = '0.2.x';

# input/output
my $inputfile;
my $outputfolder;
my $contigmembers;
my $otufile;
my $referencedb;

# options
my $numthreads = 1;
my $vsearchoption;

# the other global variables
my $devnull = File::Spec->devnull();
my %members;
my $vsearch;

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
	# read contigmembers or otu file
	if (($contigmembers && -e $contigmembers) || ($otufile && -e $otufile)) {
		&readMembers();
	}
	# make output folder
	unless (mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make \"$outputfolder\".");
	}
	# delete chimeric sequences
	&runVSEARCH();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clrunuchime $buildno
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
	# get input file name
	$inputfile = $ARGV[-2];
	# get output file name
	$outputfolder = $ARGV[-1];
	# read command line options
	my $vsearchmode = 0;
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] eq 'end') {
			$vsearchmode = 0;
		}
		elsif ($vsearchmode) {
			$vsearchoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ 'vsearch' || $ARGV[$i] =~ 'uchime') {
			$vsearchmode = 1;
		}
		elsif ($ARGV[$i] =~ /^-+contigmembers?=(.+)$/i) {
			$contigmembers = $1;
		}
		elsif ($ARGV[$i] =~ /^-+otufile=(.+)$/i) {
			$otufile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+ref(?:erence)?(?:database|db)=(.+)$/i) {
			$referencedb = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
		}
	}
}

sub checkVariables {
	if (!$inputfile) {
		&errorMessage(__LINE__, "The input file name is not specified.");
	}
	if (!-e $inputfile) {
		&errorMessage(__LINE__, "The input file does not exist.");
	}
	if (!$outputfolder) {
		&errorMessage(__LINE__, "The output file name is not specified.");
	}
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "The output file already exists.");
	}
	if ($contigmembers && $referencedb) {
		&errorMessage(__LINE__, "Both contigmembers and referencedb were specified.");
	}
	if ($otufile && $referencedb) {
		&errorMessage(__LINE__, "Both OTU file and referencedb were specified.");
	}
	if ($contigmembers && $otufile) {
		&errorMessage(__LINE__, "Both contigmembers and OTU files were specified.");
	}
	if ($contigmembers && !-e $contigmembers) {
		&errorMessage(__LINE__, "The contigmembers file does not exist.");
	}
	if ($otufile && !-e $otufile) {
		&errorMessage(__LINE__, "The OTU file does not exist.");
	}
	if (!$otufile && !$contigmembers && !$referencedb) {
		my $prefix = $inputfile;
		$prefix =~ s/\.(?:gz|bz2|xz)$//i;
		$prefix =~ s/\.[^\.]+$//;
		if (-e "$prefix.otu.gz") {
			$otufile = "$prefix.otu.gz";
		}
		elsif (-e "$prefix.otu") {
			$otufile = "$prefix.otu";
		}
		elsif (-e "$prefix.contigmembers.gz") {
			$contigmembers = "$prefix.contigmembers.gz";
		}
		elsif (-e "$prefix.contigmembers.txt") {
			$contigmembers = "$prefix.contigmembers.txt";
		}
		elsif (-e "$prefix.contigmembers") {
			$contigmembers = "$prefix.contigmembers";
		}
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
	if ($vsearchoption =~ /-(?:chimeras|db|nonchimeras|uchime_denovo|uchime_ref|uchimealns|uchimeout|uchimeout5|centroids|cluster_fast|cluster_size|cluster_smallmem|clusters|consout|cons_truncate|derep_fulllength|sortbylength|sortbysize|output|allpairs_global|shuffle) /) {
		&errorMessage(__LINE__, "The option for vsearch is invalid.");
	}
	if (($contigmembers || $otufile) && $vsearchoption =~ /-threads /) {
		&errorMessage(__LINE__, "De novo chimera detection does not support multithreading.");
	}
	if ($referencedb && $vsearchoption !~ /-threads /) {
		$vsearchoption .= " --threads $numthreads";
	}
	if ($vsearchoption !~ /-fasta_width /) {
		$vsearchoption .= " --fasta_width 999999";
	}
	if ($vsearchoption !~ /-maxseqlength /) {
		$vsearchoption .= " --maxseqlength 50000";
	}
	if ($vsearchoption !~ /-minseqlength /) {
		$vsearchoption .= " --minseqlength 32";
	}
	if ($vsearchoption !~ /-notrunclabels/) {
		$vsearchoption .= " --notrunclabels";
	}
	if ($vsearchoption !~ /-abskew /) {
		$vsearchoption .= " --abskew 2.0";
	}
	if ($vsearchoption !~ /-dn /) {
		$vsearchoption .= " --dn 1.4";
	}
	if ($vsearchoption !~ /-mindiffs /) {
		$vsearchoption .= " --mindiffs 3";
	}
	if ($vsearchoption !~ /-mindiv /) {
		$vsearchoption .= " --mindiv 0.1";
	}
	if ($vsearchoption !~ /-minh /) {
		$vsearchoption .= " --minh 0.1";
	}
	if ($vsearchoption !~ /-xn /) {
		$vsearchoption .= " --xn 8.0";
	}
	if ($vsearchoption !~ /-strand /) {
		$vsearchoption .= " --strand plus";
	}
	print(STDERR "Command line options for vsearch :$vsearchoption\n\n");
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

sub readMembers {
	# read contig members
	if ($contigmembers) {
		$filehandleinput1 = &readFile($contigmembers);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			my @temp = split(/\t/, $_);
			if (scalar(@temp) > 2) {
				$members{$temp[0]} = scalar(@temp) - 1;
			}
			elsif (scalar(@temp) == 2) {
				$members{$temp[1]} = 1;
			}
			elsif (/.+/) {
				&errorMessage(__LINE__, "The contigmembers file is invalid.");
			}
		}
		close($filehandleinput1);
	}
	elsif ($otufile) {
		$filehandleinput1 = &readFile($otufile);
		my $centroid;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;?//g;
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
}

sub runVSEARCH {
	if ($contigmembers || $otufile) {
		$filehandleinput1 = &readFile($inputfile);
		unless (open($filehandleoutput1, "> $outputfolder/temp.fasta")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/temp.fasta\".");
		}
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
				my $seqname = $1;
				$seqname =~ s/;size=\d+;?//g;
				my $sequence = uc($2);
				$sequence =~ s/[^A-Z]//sg;
				if ($members{$seqname}) {
					print($filehandleoutput1 ">$seqname;size=$members{$seqname};\n$sequence\n");
				}
				elsif ($contigmembers) {
					&errorMessage(__LINE__, "There is no member information for \"$seqname\" in \"$contigmembers\".");
				}
				elsif ($otufile) {
					&errorMessage(__LINE__, "There is no member information for \"$seqname\" in \"$otufile\".");
				}
			}
		}
		close($filehandleoutput1);
		close($filehandleinput1);
		if (system("$vsearch$vsearchoption --uchime_denovo $outputfolder/temp.fasta --chimeras $outputfolder/chimeras.fasta --nonchimeras $outputfolder/nonchimeras.fasta --uchimeout $outputfolder/uchimeout.txt --uchimealns $outputfolder/uchimealns.txt")) {
			&errorMessage(__LINE__, "Cannot run vsearch correctly.");
		}
		if (system("perl -i.bak -npe 's/;size=\\d+;?//' $outputfolder/chimeras.fasta")) {
			&errorMessage(__LINE__, "Cannot modify \"$outputfolder/chimeras.fasta\".");
		}
		if (system("perl -i.bak -npe 's/;size=\\d+;?//' $outputfolder/nonchimeras.fasta")) {
			&errorMessage(__LINE__, "Cannot modify \"$outputfolder/nonchimeras.fasta\".");
		}
		unlink("$outputfolder/chimeras.fasta.bak");
		unlink("$outputfolder/nonchimeras.fasta.bak");
		unlink("$outputfolder/temp.fasta");
	}
	elsif ($referencedb) {
		if (system("$vsearch$vsearchoption --uchime_ref $inputfile --db $referencedb --chimeras $outputfolder/chimeras.fasta --nonchimeras $outputfolder/nonchimeras.fasta --uchimeout $outputfolder/uchimeout.txt --uchimealns $outputfolder/uchimealns.txt")) {
			&errorMessage(__LINE__, "Cannot run vsearch correctly.");
		}
	}
	else {
		if (system("$vsearch$vsearchoption --uchime_denovo $inputfile --chimeras $outputfolder/chimeras.fasta --nonchimeras $outputfolder/nonchimeras.fasta --uchimeout $outputfolder/uchimeout.txt --uchimealns $outputfolder/uchimealns.txt")) {
			&errorMessage(__LINE__, "Cannot run vsearch correctly.");
		}
		if (system("perl -i.bak -npe 's/;size=\\d+;?//' $outputfolder/chimeras.fasta")) {
			&errorMessage(__LINE__, "Cannot modify \"$outputfolder/chimeras.fasta\".");
		}
		if (system("perl -i.bak -npe 's/;size=\\d+;?//' $outputfolder/nonchimeras.fasta")) {
			&errorMessage(__LINE__, "Cannot modify \"$outputfolder/nonchimeras.fasta\".");
		}
		unlink("$outputfolder/chimeras.fasta.bak");
		unlink("$outputfolder/nonchimeras.fasta.bak");
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
clrunuchime options inputfile outputfolder

Command line options
====================
vsearch options end
  Specify commandline options for vsearch.
(default: --minh 0.1 --mindiv 0.1)

--contigmembers=FILENAME
  Specify file path to contigmembers file. (default: none)

--otufile=FILENAME
  Specify file path to otu file. (default: none)

--referencedb=FILENAME
  Specify file path to reference database (default: none)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, or bzip2-compressed)
_END
	exit;
}
