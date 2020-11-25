use strict;
use Fcntl ':flock';
use File::Spec;

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

my $makeblastdboption = ' -dbtype nucl -input_type fasta -hash_index -parse_seqids -max_file_sz 4G';

# options
my $numthreads = 1;
my $nacclist;
my %nacclist;
my $minlen = 0;
my $maxlen = 10000000000;

# input/output
my @inputfiles;
my $output;

# commands
my $makeblastdb;
my $blastdb_aliastool;

# global variables
my $maxsize = 10000000000;

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
	# read negative accessions list file
	&readNegativeAccessionList();
	# split input file and run makeblastdb
	&splitInputFile();
	# make nal
	&makeNal();
	exit(0);
}

sub printStartupMessage {
	print(STDERR <<"_END");
clmakeblastdb $buildno
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
	my %inputfiles;
	$output = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+n(?:egative)?(?:acc|accession|seqid)list=(.+)$/i) {
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
	print(STDERR "Minimum length: $minlen\nMaximum length: $maxlen\n");
	if ($minlen > $maxlen) {
		&errorMessage(__LINE__, "The minimum length threshold must be equal to or smaller than the maximum length threshold.");
	}
	if ($minlen > $maxsize) {
		&errorMessage(__LINE__, "The minimum length threshold must be equal to or smaller than $maxsize.");
	}
	if ($maxlen > $maxsize) {
		&errorMessage(__LINE__, "The maximum length threshold must be equal to or smaller than $maxsize.");
	}
	while (glob("$output.*.*")) {
		if (/^$output\..+\.fasta$/) {
			&errorMessage(__LINE__, "Temporary file already exists.");
		}
		elsif (/^$output\..+/) {
			&errorMessage(__LINE__, "Output file already exists.");
		}
	}
	if (scalar(@inputfiles) == 0) {
		&errorMessage(__LINE__, "Input file is not given.");
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
			$makeblastdb = "\"$pathto/makeblastdb\"";
			$blastdb_aliastool = "\"$pathto/blastdb_aliastool\"";
		}
		else {
			$makeblastdb = 'makeblastdb';
			$blastdb_aliastool = 'blastdb_aliastool';
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
	print(STDERR "Preparing files for makeblastdb...\n");
	# make splitted files
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		my $temptotal = 0;
		my $tempseq;
		my $tempseqlen = 0;
		my $tempnfile = 0;
		my $switch = 0;
		$filehandleoutput1 = &writeFile("$output." . sprintf("%02d", $tempnfile) . ".fasta");
		foreach my $inputfile (@inputfiles) {
			$filehandleinput1 = &readFile($inputfile);
			my $line = 0;
			while (<$filehandleinput1>) {
				$line ++;
				if (/^>\s*(\S+)\s*/) {
					my $seqid = $1;
					if (exists($nacclist{$seqid}) || $seqid =~ /(?:gb|emb|dbj|ref|pdb|tpd|tpe|tpg)\|([A-Za-z0-9_]+)/ && (exists($nacclist{$1})) || $seqid =~ /([A-Za-z0-9_]+)/ && (exists($nacclist{$1}))) {
						$switch = 0;
						next;
					}
					$switch = 1;
					if ($tempseq) {
						if (defined($minlen) && defined($maxlen) && $tempseqlen >= $minlen && $tempseqlen <= $maxlen) {
							print($filehandleoutput1 $tempseq);
							$temptotal += $tempseqlen;
						}
					}
					$tempseq = $_;
					$tempseqlen = 0;
					if ($temptotal >= $maxsize) {
						close($filehandleoutput1);
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
							$temptotal = 0;
							$tempnfile ++;
							$filehandleoutput1 = &writeFile("$output." . sprintf("%02d", $tempnfile) . ".fasta");
							next;
						}
						else {
							&runMakeblastdb($tempnfile);
							exit;
						}
					}
				}
				elsif ($switch) {
					$tempseqlen += length($_) - 1;
					$tempseq .= $_;
				}
			}
			close($filehandleinput1);
		}
		if ($tempseq) {
			if (defined($minlen) && defined($maxlen) && $tempseqlen >= $minlen && $tempseqlen <= $maxlen) {
				print($filehandleoutput1 $tempseq);
				$temptotal += $tempseqlen;
			}
			close($filehandleoutput1);
			if ($temptotal) {
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
					&runMakeblastdb($tempnfile);
					exit;
				}
			}
			else {
				unlink("$output." . sprintf("%02d", $tempnfile) . ".fasta");
			}
		}
		else {
			close($filehandleoutput1);
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot run makeblastdb correctly.');
		}
	}
	print(STDERR "done.\n\n");
}

sub runMakeblastdb {
	my $tempnfile = shift(@_);
	my $tempprefix = "$output." . sprintf("%02d", $tempnfile);
	print(STDERR "Running makeblastdb using $tempprefix.fasta...\n");
	system("$makeblastdb$makeblastdboption -in $tempprefix.fasta -out $tempprefix -title $tempprefix 1> $devnull 2> $devnull");
	if (!-e "$tempprefix.nsq" || -z "$tempprefix.nsq") {
		&errorMessage(__LINE__, "Cannot run makeblastdb correctly.");
	}
	unlink("$tempprefix.fasta");
}

sub makeNal {
	my @databases = glob("$output.*.nsq");
	if (scalar(@databases) > 1) {
		print(STDERR "Aggregating databases...\n");
		$filehandleoutput1 = &writeFile("$output.dblist");
		foreach (@databases) {
			s/\.nsq$//;
			print($filehandleoutput1 "$_\n");
		}
		close($filehandleoutput1);
		system("$blastdb_aliastool -dbtype nucl -dblist_file $output.dblist -out $output -title $output");
		unlink("$output.dblist");
		if (!-e "$output.nal" || -z "$output.nal") {
			&errorMessage(__LINE__, "Cannot run blastdb_aliastool correctly.");
		}
	}
	elsif (scalar(@databases) == 1) {
		print(STDERR "Renaming databases...\n");
		$databases[0] =~ s/\.nsq$//;
		rename("$databases[0].nhd", "$output.nhd");
		rename("$databases[0].nhi", "$output.nhi");
		rename("$databases[0].nhr", "$output.nhr");
		rename("$databases[0].nin", "$output.nin");
		rename("$databases[0].nnd", "$output.nnd");
		rename("$databases[0].nni", "$output.nni");
		rename("$databases[0].nog", "$output.nog");
		rename("$databases[0].nsd", "$output.nsd");
		rename("$databases[0].nsi", "$output.nsi");
		rename("$databases[0].nsq", "$output.nsq");
	}
	else {
		&errorMessage(__LINE__, "Cannot find constructed databases.");
	}
	print(STDERR "done.\n\n");
}

sub writeFile {
	my $filehandle;
	my $filename = shift(@_);
	unless (open($filehandle, "> $filename")) {
		&errorMessage(__LINE__, "Cannot open \"$filename\".");
	}
	unless (flock($filehandle, LOCK_EX)) {
		&errorMessage(__LINE__, "Cannot lock \"$filename\".");
	}
	if ($filename =~ /\.gz$/i) {
		unless ($filehandle = new IO::Compress::Gzip($filehandle)) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
		binmode($filehandle);
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless ($filehandle = new IO::Compress::Bzip2($filehandle)) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
		binmode($filehandle);
	}
	elsif ($filename =~ /\.xz$/i) {
		unless ($filehandle = new IO::Compress::Xz($filehandle)) {
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
		unless (open($filehandle, "pigz -dc $filename 2> $devnull |")) {
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
clmakeblastdb options inputfiles outputBLASTDB

Command line options
====================
--negativeacclist=FILENAME
  Specify file name of negative accession list. (default: none)

--negativeacc=accession(,accession..)
  Specify negative accessions.

--minlen=INTEGER
  Specify minimum length of sequence. (default: 0)

--maxlen=INTEGER
  Specify maximum length of sequence. (default: 10000000000)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA
_END
	exit;
}
