use strict;
use File::Spec;
use DBI;

my $buildno = '0.9.x';

# options
my $append;
my $difference = 'stop';
my $prefer = 'small';

# input/output
my @inputfiles;
my $outputfile;
my $lockdir;

# other variables
my $devnull = File::Spec->devnull();
my %replace;

# file handles
my $filehandleinput1;
my $dbhandle;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# make output file
	&makeIdentDB();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clmakeidentdb $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-XXXX  Akifumi S. Tanabe

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
	$outputfile = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:a|append)$/i) {
			$append = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:diff|difference)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^stop$/i) {
				$difference = 'stop';
			}
			elsif ($value =~ /^(?:con|continue)$/i) {
				$difference = 'continue';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+prefer=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:small|s)$/i) {
				$prefer = 'small';
			}
			elsif ($value =~ /^(?:large|l)$/i) {
				$prefer = 'large';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
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
	if (-e $outputfile && !$append) {
		&errorMessage(__LINE__, "Output file already exists.");
	}
	$lockdir = "$outputfile.lock";
}

sub makeIdentDB {
	print(STDERR "Reading input file and register to the database...\n");
	while (!mkdir($lockdir)) {
		print(STDERR "Lock directory was found. Sleep 10 seconds.\n");
		sleep(10);
	}
	$SIG{'TERM'} = $SIG{'PIPE'} = $SIG{'HUP'} = "sigexit";
	sub sigexit {
		rmdir($lockdir);
		exit(1);
	}
	print(STDERR "Lock directory has been correctly made.\n");
	my $switch = 0;
	if (-e $outputfile && $append) {
		my $nadd = 0;
		if (-e $outputfile) {
			unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
				&errorMessage(__LINE__, "Cannot connect database.");
			}
		}
		else {
			&errorMessage(__LINE__, "Database file does not exist.");
		}
		# check duplication
		my $ndiff = 0;
		my $stop;
		foreach my $inputfile (@inputfiles) {
			print(STDERR "Checking \"$inputfile\"...\n");
			$filehandleinput1 = &readFile($inputfile);
			local $/ = "\n>";
			while (<$filehandleinput1>) {
				if (/^>?\s*(\S[^\r\n]*)\r?\n(.*)/s) {
					my $query = $1;
					my $accs = $2;
					$accs =~ s/[> \t]//g;
					$accs =~ s/\s+\r?\n?$//;
					$query =~ /;base62=([A-Za-z0-9]+)/;
					my $tempseq = $1;
					my @accs = split(/\r?\n/, $accs);
					if ($tempseq) {
						my $statement;
						unless ($statement = $dbhandle->prepare("SELECT acc FROM base62_acc WHERE base62 IN ('" . $tempseq . "')")) {
							&errorMessage(__LINE__, "Cannot prepare SQL statement.");
						}
						unless ($statement->execute) {
							&errorMessage(__LINE__, "Cannot execute SELECT.");
						}
						my $existref = $statement->fetchall_arrayref([0]);
						my $nhit = scalar(@{$existref});
						if ($nhit != 0) {
							@accs = sort(@accs);
							my @existaccs;
							foreach my $temp (@{$existref}) {
								push(@existaccs, $temp->[0]);
							}
							@existaccs = sort(@existaccs);
							if ($nhit == scalar(@accs)) {
								for (my $i = 0; $i < scalar(@accs); $i ++) {
									if ($accs[$i] ne $existaccs[$i]) {
										$ndiff ++;
										$stop = 1;
										print(STDERR "Duplicate sequence $tempseq is detected, but accessions are not identical.\nInsert will abort.\nExisting: @existaccs\nNew: @accs\n");
									}
								}
							}
							else {
								if ($nhit != 1 || scalar(@accs) != 0 || $existref->[0]->[0] ne '0') {
									$ndiff ++;
									if ($prefer eq 'small' && scalar(@accs) < scalar(@existaccs) || $prefer eq 'large' && scalar(@accs) > scalar(@existaccs)) {
										$replace{$tempseq} = 1;
									}
									else {
										$replace{$tempseq} = 0;
									}
									print(STDERR "Duplicate sequence $tempseq is detected, but accessions are not identical.\nExisting: @existaccs\nNew: @accs\n");
								}
							}
						}
						else {
							$nadd ++;
						}
					}
				}
			}
			close($filehandleinput1);
		}
		if ($ndiff) {
			if ($difference eq 'stop' || $stop) {
				&errorMessage(__LINE__, "$ndiff sequence(s) are duplicated and do not have identical accessions.");
			}
			else {
				print(STDERR "$ndiff sequence(s) are duplicated and do not have identical accessions.\n");
				if ($prefer eq 'small') {
					print(STDERR "The smaller number of accessions are preferred.\n");
				}
				else {
					print(STDERR "The larger number of accessions are preferred.\n");
				}
			}
		}
		if ($nadd) {
			$switch = 1;
		}
	}
	else {
		if (-e $outputfile) {
			&errorMessage(__LINE__, "Output file already exists.");
		}
		else {
			unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
				&errorMessage(__LINE__, "Cannot make database.");
			}
			unless ($dbhandle->do("CREATE TABLE base62_acc (base62 TEXT NOT NULL, acc TEXT NOT NULL);")) {
				&errorMessage(__LINE__, "Cannot make table.");
			}
			$dbhandle->do("CREATE INDEX base62index ON base62_acc (base62);");
		}
		$switch = 1;
	}
	# register to database
	if ($switch) {
		foreach my $inputfile (@inputfiles) {
			print(STDERR "Inserting entry from \"$inputfile\"...\n");
			$filehandleinput1 = &readFile($inputfile);
			local $/ = "\n>";
			while (<$filehandleinput1>) {
				if (/^>?\s*(\S[^\r\n]*)\r?\n(.*)/s) {
					my $query = $1;
					my $accs = $2;
					$accs =~ s/[> \t]//g;
					$accs =~ s/\s+\r?\n?$//;
					$query =~ /;base62=([A-Za-z0-9]+)/;
					my $tempseq = $1;
					my @accs = split(/\r?\n/, $accs);
					if ($tempseq && (!exists($replace{$tempseq}) || $replace{$tempseq} == 1)) {
						my $statement;
						unless ($statement = $dbhandle->prepare("SELECT acc FROM base62_acc WHERE base62 IN ('" . $tempseq . "')")) {
							&errorMessage(__LINE__, "Cannot prepare SQL statement.");
						}
						unless ($statement->execute) {
							&errorMessage(__LINE__, "Cannot execute SELECT.");
						}
						my $existref = $statement->fetchall_arrayref([0]);
						my $nhit = scalar(@{$existref});
						# delete existing data
						if ($nhit && $replace{$tempseq} == 1) {
							unless ($statement = $dbhandle->prepare("DELETE FROM base62_acc WHERE base62 IN ('" . $tempseq . "')")) {
								&errorMessage(__LINE__, "Cannot prepare SQL statement.");
							}
							unless ($statement->execute) {
								&errorMessage(__LINE__, "Cannot execute DELETE.");
							}
						}
						# insert new data
						if ($nhit == 0 || $nhit && $replace{$tempseq} == 1) {
							unless ($statement = $dbhandle->prepare("INSERT INTO base62_acc (base62, acc) VALUES (?, ?);")) {
								&errorMessage(__LINE__, "Cannot prepare SQL statement.");
							}
							# begin SQL transaction
							$dbhandle->do('BEGIN;');
							if (@accs) {
								my $nentries = 1;
								foreach my $acc (@accs) {
									unless ($statement->execute($tempseq, $acc)) {
										&errorMessage(__LINE__, "Cannot execute INSERT.");
									}
									if ($nentries % 1000 == 0) {
										# commit SQL transaction
										$dbhandle->do('COMMIT;');
										# begin SQL transaction
										$dbhandle->do('BEGIN;');
									}
									$nentries ++;
								}
							}
							else {
								unless ($statement->execute($tempseq, 0)) {
									&errorMessage(__LINE__, "Cannot execute INSERT.");
								}
							}
							# commit SQL transaction
							$dbhandle->do('COMMIT;');
						}
					}
				}
			}
			close($filehandleinput1);
		}
	}
	$dbhandle->disconnect;
	while (!rmdir($lockdir)) {
		print(STDERR "Lock directory cannot be removed. Sleep 10 seconds.\n");
		sleep(10);
	}
	print(STDERR "Lock directory has been correctly removed.\n");
	print(STDERR "done.\n\n");
}

sub readFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "pigz -p 8 -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "pbzip2 -p8 -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "xz -T 8 -dc $filename 2> $devnull |")) {
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
	if ($lockdir =~ /\.lock$/ && -d $lockdir) {
		while (!rmdir($lockdir)) {
			print(STDERR "Lock directory cannot be removed. Sleep 10 seconds.\n");
			sleep(10);
		}
		print(STDERR "Lock directory has been correctly removed.\n");
	}
	exit(1);
}

sub helpMessage {
	print(STDERR <<"_END");
Usage
=====
clmakeidentdb options inputfile outputfile

Command line options
====================
-a, --append
  Specify outputfile append or not. (default: off)

--difference=STOP|CONTINUE
  Specify difference handling. (default: STOP)

--prefer=SMALL|LARGE
  Specify preferred. (default: SMALL)

Acceptable input file formats
=============================
Output of clidentseq
(FASTA-like accession list)
_END
	exit;
}
