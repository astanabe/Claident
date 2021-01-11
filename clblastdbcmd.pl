use strict;
use Fcntl ':flock';
use File::Spec;

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

my $blastdbcmdoption = ' -dbtype nucl -target_only';

# options
my $blastdb;
my $outputformat = 'FASTA';
my $filejoin = 1;
my $numthreads = 1;
my $nacclist;
my %nacclist;
my $minlen;
my $maxlen;
my $compress = 'gz';

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
	# read negative accession list file
	&readNegativeAccessionList();
	# split input file
	&splitInputFile();
	# concatenate output files
	if ($filejoin) {
		&concatenateOutputFiles();
	}
}

sub printStartupMessage {
	print(STDERR <<"_END");
clblastdbcmd $buildno
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
	$inputfile = $ARGV[-2];
	$outputfile = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+compress=(.+)$/i) {
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
		elsif ($ARGV[$i] =~ /^-+(?:db|blastdb|bdb)=(.+)$/i) {
			$blastdb = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:o|output)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^FASTA$/i) {
				$outputformat = 'FASTA';
			}
			elsif ($value =~ /^(?:ACCTAXID|AccessionTAXID|AccessionTaxonomyID)$/i) {
				$outputformat = 'ACCTAXID';
			}
			elsif ($value =~ /^(?:ACC|Accession)$/i) {
				$outputformat = 'ACC';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+filejoin=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$filejoin = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$filejoin = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?acclist=(.+)$/i) {
			$nacclist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?(?:acc|accession|seqid)s?=(.+)$/i) {
			foreach my $nacc (split(/,/, $1)) {
				$nacclist{$nacc} = 1;
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
		if (/^$outputfile\.\d+(?:\.gz|\.bz2|\.xz|\.list)?$/) {
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
		$outputformat = "\">\%a \%t\n\%s\"";
	}
	elsif ($outputformat eq 'ACCTAXID') {
		$outputformat = "'" . '%a %T' . "'";
	}
	elsif ($outputformat eq 'ACC') {
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

sub readNegativeAccessionList {
	if ($nacclist) {
		$filehandleinput1 = &readFile($nacclist);
		while (<$filehandleinput1>) {
			if (/^\s*([A-Za-z0-9_]+)/) {
				$nacclist{$1} = 1;
			}
		}
		close($filehandleinput1);
	}
}

sub splitInputFile {
	print(STDERR "Preparing files for blastdbcmd...\n");
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
			if (/^\s*(\S+)\s*\r?\n?$/ && !exists($nacclist{$1})) {
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
						&makeTemporaryFiles($tempnfile, $tempseqs);
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
				&makeTemporaryFiles($tempnfile, $tempseqs);
				exit;
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot split input file correctly.');
		}
	}
	print(STDERR "done.\n\n");
}

sub makeTemporaryFiles {
	my $tempnfile = shift(@_);
	my $tempseqs = shift(@_);
	unless (open($filehandleoutput1, "> $outputfile.$tempnfile.list")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfile.$tempnfile.list\".");
	}
	print($filehandleoutput1 "$tempseqs");
	close($filehandleoutput1);
	if ($minlen || $maxlen) {
		my $newaccs;
		unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastdbcmd$blastdbcmdoption -db $blastdb -entry_batch $outputfile.$tempnfile.list -out - -outfmt '%a %l' 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastdbcmd$blastdbcmdoption -db $blastdb -entry_batch $outputfile.$tempnfile.list -out - -outfmt '%a %l'\".");
		}
		while (<$pipehandleinput1>) {
			if (/\s*(\S+)\s+(\d+)/) {
				my $acc = $1;
				my $length = $2;
				if ($minlen && $maxlen && $length >= $minlen && $length <= $maxlen || $minlen && $length >= $minlen || $maxlen && $length <= $maxlen) {
					$newaccs .= $acc . "\n";
				}
			}
		}
		close($pipehandleinput1);
		unless (open($filehandleoutput1, "> $outputfile.$tempnfile.list")) {
			&errorMessage(__LINE__, "Cannot write \"$outputfile.$tempnfile.list\".");
		}
		print($filehandleoutput1 "$newaccs\n");
		close($filehandleoutput1);
	}
	print(STDERR "Running blastdbcmd using $outputfile.$tempnfile.list...\n");
	if (-e "$outputfile.$tempnfile.list" && !-z "$outputfile.$tempnfile.list") {
		if ($compress) {
			$filehandleoutput1 = writeFile("$outputfile.$tempnfile.$compress");
		}
		else {
			$filehandleoutput1 = writeFile("$outputfile.$tempnfile");
		}
		unless (open($pipehandleinput1, "BLASTDB=\"$blastdbpath\" $blastdbcmd$blastdbcmdoption -db $blastdb -entry_batch $outputfile.$tempnfile.list -out - -outfmt $outputformat 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastdbcmd$blastdbcmdoption -db $blastdb -entry_batch $outputfile.$tempnfile.list -out - -outfmt $outputformat\".");
		}
		while (<$pipehandleinput1>) {
			print($filehandleoutput1 $_);
		}
		close($pipehandleinput1);
		close($filehandleoutput1);
	}
	unlink("$outputfile.$tempnfile.list");
}

sub concatenateOutputFiles {
	print(STDERR "Save to output file...\n");
	my $tempfilename;
	if ($compress) {
		$tempfilename = "$outputfile.*.$compress";
	}
	else {
		$tempfilename = "$outputfile.*";
	}
	$filehandleoutput1 = &writeFile($outputfile);
	while (my $tempfile = glob($tempfilename)) {
		if ($tempfile =~ /^$outputfile\.\d+/) {
			$filehandleinput1 = &readFile($tempfile);
			while (<$filehandleinput1>) {
				print($filehandleoutput1 $_);
			}
			close($filehandleinput1);
			unlink($tempfile);
		}
	}
	close($filehandleoutput1);
	print(STDERR "done.\n\n");
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

-o, --output=FASTA|ACCTAXID|ACCESSION
  Specify output format. (default: FASTA)

--compress=GZIP|BZIP2|XZ|DISABLE
  Specify compress temporary files or not. (default: DISABLE)

--filejoin=ENABLE|DISABLE
  Specify whether output file will be joined or not. (default: ENABLE)

--negativeacclist=FILENAME
  Specify file name of negative accession list. (default: none)

--negativeacc=accession(,accession..)
  Specify negative accessions.

--minlen=INTEGER
  Specify minimum length of sequence. (default: none)

--maxlen=INTEGER
  Specify maximum length of sequence. (default: none)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
Accession list (1 per line)
_END
	exit;
}
