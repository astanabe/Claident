use strict;
use DBI;

my $buildno = '0.9.x';

print(STDERR <<"_END");
clextractuniqacc $buildno
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

# get output file name
my $outputfile = $ARGV[-1];
# check output file
if (-e $outputfile) {
	&errorMessage(__LINE__, "Output file already exists.");
}

my $workspace = 'MEMORY';
my %inputfiles;
for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
	if ($ARGV[$i] =~ /^\-+workspace=(.+)$/i) {
		if ($1 =~ /^(?:memory|ram)$/i) {
			$workspace = 'MEMORY';
		}
		elsif ($1 =~ /^(?:disk|hdd|ssd|storage)$/i) {
			$workspace = 'DISK';
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
	else {
		my @temp = glob($ARGV[$i]);
		if (scalar(@temp) > 0) {
			foreach (@temp) {
				if (!-e $_) {
					&errorMessage(__LINE__, "\"$_\" does not exist.");
				}
				elsif (!exists($inputfiles{$_})) {
					$inputfiles{$_} = 1;
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

my @inputfiles = sort(keys(%inputfiles));

# make new temporary database and connect
my $tempdbhandle;
if ($workspace eq 'MEMORY') {
	unless ($tempdbhandle = DBI->connect("dbi:SQLite:dbname=:memory:", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
		&errorMessage(__LINE__, "Cannot make database.");
	}
}
else {
	if (-e "$outputfile.tempdb") {
		&errorMessage(__LINE__, "\"$outputfile.tempdb\" already exists.");
	}
	unless ($tempdbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile.tempdb", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
		&errorMessage(__LINE__, "Cannot make database.");
	}
}
# make table
unless ($tempdbhandle->do("CREATE TABLE accs (acc TEXT NOT NULL PRIMARY KEY);")) {
	&errorMessage(__LINE__, "Cannot make table.");
}
print(STDERR "Extracting unique accessions of first input file...");
# read first input file
{
	# prepare SQL statement
	my $statement;
	unless ($statement = $tempdbhandle->prepare("REPLACE INTO accs (acc) VALUES (?);")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	# begin SQL transaction
	$tempdbhandle->do('BEGIN;');
	my $lineno = 1;
	my $firstinputfile = shift(@inputfiles);
	my $inputhandle;
	unless (open($inputhandle, "< $firstinputfile")) {
		&errorMessage(__LINE__, "Cannot open \"$firstinputfile\".");
	}
	while (<$inputhandle>) {
		if (/[A-Za-z0-9_]+/) {
			unless ($statement->execute($&)) {
				&errorMessage(__LINE__, "Cannot insert \"$&\".");
			}
			if ($lineno % 1000000 == 0) {
				print(STDERR '.');
				# commit SQL transaction
				$tempdbhandle->do('COMMIT;');
				# begin SQL transaction
				$tempdbhandle->do('BEGIN;');
			}
			$lineno ++;
		}
	}
	close($inputhandle);
	# commit SQL transaction
	$tempdbhandle->do('COMMIT;');
}
# delete accs of the other input files
{
	# begin SQL transaction
	$tempdbhandle->do('BEGIN;');
	my $lineno = 1;
	foreach my $inputfile (@inputfiles) {
		my $inputhandle;
		unless (open($inputhandle, "< $inputfile")) {
			&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
		}
		while (<$inputhandle>) {
			if (/[A-Za-z0-9_]+/) {
				# prepare SQL statement
				my $statement;
				unless ($statement = $tempdbhandle->prepare("DELETE FROM accs WHERE acc IN ('" . $& . "');")) {
					&errorMessage(__LINE__, "Cannot prepare SQL statement.");
				}
				$statement->execute;
				if ($lineno % 1000000 == 0) {
					print(STDERR '.');
					# commit SQL transaction
					$tempdbhandle->do('COMMIT;');
					# begin SQL transaction
					$tempdbhandle->do('BEGIN;');
				}
				$lineno ++;
			}
		}
		close($inputhandle);
	}
	# commit SQL transaction
	$tempdbhandle->do('COMMIT;');
}
print(STDERR "done.\n\n");

print(STDERR "Saving accessions...");
{
	my $statement;
	unless ($statement = $tempdbhandle->prepare('SELECT acc FROM accs')) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	unless ($statement->execute) {
		&errorMessage(__LINE__, "Cannot execute SELECT.");
	}
	my $outputhandle;
	unless (open($outputhandle, "> $outputfile")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfile\"");
	}
	my $lineno = 1;
	while (my @row = $statement->fetchrow_array) {
		print($outputhandle "$row[0]\n");
		if ($lineno % 1000000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	close($outputhandle);
}
print(STDERR "done.\n\n");

# disconnect
$tempdbhandle->disconnect;
if ($workspace eq 'DISK') {
	unlink("$outputfile.tempdb");
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
clextractuniqacc inputfiles outputfile

Acceptable input file formats
=============================
accession list (1 per line)
_END
	exit;
}
