use strict;
use Fcntl ':flock';
use File::Spec;
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Compress::Bzip2 qw(bzip2 $Bzip2Error);
use IO::Compress::Xz qw(xz $XzError);

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

my $blastdbcmdoption = ' -dbtype nucl -target_only -ctrl_a -long_seqids';

# options
my $blastdb;
my $outputformat = 'FASTA';
my $numthreads = 1;
my $ngilist;
my $nseqidlist;
my %ngilist;
my %nseqidlist;
my $minlen;
my $maxlen;

# input/output
my $inputfile;
my $outputfile;

# commands
my $blastdbcmd;

# global variables
my $blastdbpath;
my $minnseq = 100000;

# file handles
my $filehandleinput1;
my $filehandleinput2;
my $filehandleoutput1;
my $pipehandleinput1;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# read negative seqids list file
	&readNegativeSeqIDList();
	# split input file and run blastdbcmd
	&splitInputFile();
	exit(0);
}

sub printStartupMessage {
	print(STDERR <<"_END");
clblastdbcmd $buildno
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
	$inputfile = $ARGV[-2];
	$outputfile = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:db|blastdb|bdb)=(.+)$/i) {
			$blastdb = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:o|output)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^FASTA$/i) {
				$outputformat = 'FASTA';
			}
			elsif ($value =~ /^(?:GI|GenBankID)$/i) {
				$outputformat = 'GI';
			}
			elsif ($value =~ /^(?:ACCESSION|ACC)$/i) {
				$outputformat = 'ACCESSION';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?gilist=(.+)$/i) {
			$ngilist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?seqidlist=(.+)$/i) {
			$nseqidlist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?gis?=(.+)$/i) {
			foreach my $ngi (split(/,/, $1)) {
				$ngilist{$ngi} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?seqids?=(.+)$/i) {
			foreach my $nseqid (split(/,/, $1)) {
				$nseqidlist{$nseqid} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?len(?:gth)?=(\d+)$/i) {
			$minlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?len(?:gth)?=(\d+)$/i) {
			$maxlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	if (-e $outputfile) {
		&errorMessage(__LINE__, "\"$outputfile\" already exists.");
	}
	while (glob("$outputfile.*.*")) {
		if (/^$outputfile\..+\.(?:txt|fasta)$/) {
			&errorMessage(__LINE__, "Temporary file already exists.");
		}
	}
	if (!$inputfile) {
		&errorMessage(__LINE__, "Input file is not given.");
	}
	if (!-e $inputfile) {
		&errorMessage(__LINE__, "Input file does not exist.");
	}
	if ($outputformat eq 'FASTA') {
		$outputformat = "'" . '%f' . "'";
	}
	elsif ($outputformat eq 'GI') {
		$outputformat = "'" . '%g' . "'";
	}
	elsif ($outputformat eq 'ACCESSION') {
		$outputformat = "'" . '%a' . "'";
	}
	# search blastn
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
			$blastdbcmd = "\"$pathto/blastdbcmd\"";
		}
		else {
			$blastdbcmd = 'blastdbcmd';
		}
	}
	# set BLASTDB path
	if ($ENV{'BLASTDB'}) {
		$blastdbpath = $ENV{'BLASTDB'};
		$blastdbpath =~ s/^"(.+)"$/$1/;
		$blastdbpath =~ s/\/$//;
	}
	foreach my $temp ('.claident', $ENV{'HOME'} . '/.claident', '/etc/claident/.claident', '.ncbirc', $ENV{'HOME'} . '/.ncbirc', $ENV{'NCBI'} . '/.ncbirc') {
		if (-e $temp) {
			my $pathto;
			my $filehandle;
			unless (open($filehandle, "< $temp")) {
				&errorMessage(__LINE__, "Cannot read \"$temp\".");
			}
			while (<$filehandle>) {
				if (/^\s*BLASTDB\s*=\s*(\S[^\r\n]*)/) {
					$pathto = $1;
					$pathto =~ s/\s+$//;
					last;
				}
			}
			close($filehandle);
			$pathto =~ s/^"(.+)"$/$1/;
			$pathto =~ s/\/$//;
			if ($blastdbpath) {
				if ($^O eq 'cygwin') {
					$blastdbpath .= ';' . $pathto;
				}
				else {
					$blastdbpath .= ':' . $pathto;
				}
			}
			else {
				$blastdbpath = $pathto;
			}
		}
	}
}

sub readNegativeSeqIDList {
	if ($ngilist) {
		$filehandleinput1 = &readFile($ngilist);
		while (<$filehandleinput1>) {
			if (/^\s*(\d+)/) {
				$ngilist{$1} = 1;
			}
		}
		close($filehandleinput1);
	}
	elsif ($nseqidlist) {
		$filehandleinput1 = &readFile($nseqidlist);
		while (<$filehandleinput1>) {
			if (/^\s*(\d+)/) {
				$nseqidlist{$1} = 1;
			}
		}
		close($filehandleinput1);
	}
}

sub splitInputFile {
	print(STDERR "Running blastdbcmd...\n");
	# make splitted files
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		my $tempnseq = 0;
		my $tempnfile = 0;
		my $tempseqs;
		$filehandleinput1 = &readFile($inputfile);
		while (<$filehandleinput1>) {
			if (/^\s*(\S+)\s*\r?\n?$/ && !exists($nseqidlist{$1}) && !exists($ngilist{$1})) {
				$tempseqs .= $1 . "\n";
				$tempnseq ++;
				if ($tempnseq == $minnseq) {
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
						undef($tempseqs);
						$tempnseq = 0;
						$tempnfile ++;
						next;
					}
					else {
						&runBlastdbcmd($tempnfile, $tempseqs);
						exit;
					}
				}
			}
		}
		close($filehandleinput1);
		if ($tempseqs) {
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
			}
			else {
				&runBlastdbcmd($tempnfile, $tempseqs);
				exit;
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot run blastdbcmd correctly.');
		}
	}
	print(STDERR "done.\n\n");
}

sub runBlastdbcmd {
	my $tempnfile = shift(@_);
	my $tempseqs = shift(@_);
	print(STDERR "Running blastdbcmd using $outputfile.$tempnfile.list...\n");
	unless (open($filehandleoutput1, "> $outputfile.$tempnfile.list")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfile.$tempnfile.list\".");
	}
	print($filehandleoutput1 "$tempseqs");
	close($filehandleoutput1);
	if ($minlen || $maxlen) {
		my $newseqids;
		unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastdbcmd$blastdbcmdoption -db $blastdb -entry_batch $outputfile.$tempnfile.list -out - -outfmt '%a %l' 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastdbcmd$blastdbcmdoption -db $blastdb -entry_batch $outputfile.$tempnfile.list -out - -outfmt '%a %l'\".");
		}
		while (<$pipehandleinput1>) {
			if (/\s*(\S+)\s+(\d+)/) {
				my $seqid = $1;
				my $length = $2;
				if ($minlen && $maxlen && $length >= $minlen && $length <= $maxlen || $minlen && $length >= $minlen || $maxlen && $length <= $maxlen) {
					$newseqids .= $seqid . "\n";
				}
			}
		}
		close($pipehandleinput1);
		unless (open($filehandleoutput1, "> $outputfile.$tempnfile.list")) {
			&errorMessage(__LINE__, "Cannot write \"$outputfile.$tempnfile.list\".");
		}
		print($filehandleoutput1 "$newseqids\n");
		close($filehandleoutput1);
	}
	if (-e "$outputfile.$tempnfile.list" && !-z "$outputfile.$tempnfile.list") {
		system("BLASTDB=\"$blastdbpath\" $blastdbcmd$blastdbcmdoption -db $blastdb -entry_batch $outputfile.$tempnfile.list -out $outputfile.$tempnfile.fasta -outfmt $outputformat 2> $devnull");
		if (!-e "$outputfile.$tempnfile.fasta") {
			&errorMessage(__LINE__, "Cannot run blastdbcmd correctly.");
		}
	}
	# save to output file
	if (-e "$outputfile.$tempnfile.fasta" && !-z "$outputfile.$tempnfile.fasta") {
		$filehandleoutput1 = &writeFileAppend($outputfile);
		unless (open($filehandleinput2, "< $outputfile.$tempnfile.fasta")) {
			&errorMessage(__LINE__, "Cannot read \"$outputfile.$tempnfile.fasta\".");
		}
		while (<$filehandleinput2>) {
			print($filehandleoutput1 $_);
		}
		close($filehandleinput2);
		close($filehandleoutput1);
	}
	unlink("$outputfile.$tempnfile.fasta");
	unlink("$outputfile.$tempnfile.list");
}

sub writeFileAppend {
	my $filehandle;
	my $filename = shift(@_);
	unless (open($filehandle, ">> $filename")) {
		&errorMessage(__LINE__, "Cannot open \"$filename\".");
	}
	unless (flock($filehandle, LOCK_EX)) {
		&errorMessage(__LINE__, "Cannot lock \"$filename\".");
	}
	unless (seek($filehandle, 0, 2)) {
		&errorMessage(__LINE__, "Cannot seek \"$filename\".");
	}
	if ($filename =~ /\.gz$/i) {
		unless ($filehandle = new IO::Compress::Gzip($filehandle, Append => 1)) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
		binmode($filehandle);
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless ($filehandle = new IO::Compress::Bzip2($filehandle, Append => 1)) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
		binmode($filehandle);
	}
	elsif ($filename =~ /\.xz$/i) {
		unless ($filehandle = new IO::Compress::Xz($filehandle, Append => 1)) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
		binmode($filehandle);
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
clblastdbcmd options inputfile outputfile

Command line options
====================
--blastdb=BLASTDB
  Specify name of BLAST database. (default: none)

-o, --output=FASTA|GI|ACCESSION
  Specify output format. (default: FASTA)

--negativegilist=FILENAME
  Specify file name of negative GI list. (default: none)

--negativegi=GI(,GI..)
  Specify negative GIs.

--negativeseqidlist=FILENAME
  Specify file name of negative SeqID list. (default: none)

--negativeseqid=SeqID(,SeqID..)
  Specify negative SeqIDs.

--minlen=INTEGER
  Specify minimum length of sequence. (default: none)

--maxlen=INTEGER
  Specify maximum length of sequence. (default: none)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
SeqID list (one sequence id per line)
_END
	exit;
}
