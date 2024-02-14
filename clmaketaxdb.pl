use strict;
use DBI;

my $buildno = '0.9.x';

print(STDERR <<"_END");
clmaketaxdb $buildno
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

# get input folder name
my $inputfolder = $ARGV[-2];
# check input folder and input files
if (!-e $inputfolder) {
	&errorMessage(__LINE__, "Input folder does not exist.");
}
if (!-e "$inputfolder/names.dmp") {
	&errorMessage(__LINE__, "\"$inputfolder/names.dmp\" does not exist.");
}
if (!-e "$inputfolder/nodes.dmp") {
	&errorMessage(__LINE__, "\"$inputfolder/nodes.dmp\" does not exist.");
}
if (!-e "$inputfolder/acc_taxid.dmp") {
	&errorMessage(__LINE__, "\"$inputfolder/acc_taxid.dmp\" does not exist.");
}

# get output file name
my $outputfile = $ARGV[-1];
# check output file
if (-e $outputfile) {
	&errorMessage(__LINE__, "Output file already exists.");
}

my %includetaxa;
my %excludetaxa;
my %includetaxid;
my %excludetaxid;
my $excluderefseq = 1;
my $acclist;
my $workspace = 'MEMORY';
# get other arguments
for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
	if ($ARGV[$i] =~ /^-+in(?:clude)?tax(?:on|a)?=(.+)$/i) {
		foreach my $word (split(/,/, $1)) {
			$includetaxa{lc($word)} = 1;
		}
	}
	elsif ($ARGV[$i] =~ /^-+ex(?:clude)?tax(?:on|a)?=(.+)$/i) {
		foreach my $word (split(/,/, $1)) {
			$excludetaxa{lc($word)} = 1;
		}
	}
	elsif ($ARGV[$i] =~ /^-+in(?:clude)?tax(?:on|a)?id=(.+)$/i) {
		foreach my $taxid (split(/,/, $1)) {
			$includetaxid{$taxid} = 1;
		}
	}
	elsif ($ARGV[$i] =~ /^-+ex(?:clude)?tax(?:on|a)?id=(.+)$/i) {
		foreach my $taxid (split(/,/, $1)) {
			$excludetaxid{$taxid} = 1;
		}
	}
	elsif ($ARGV[$i] =~ /^-+excluderefseq=(.+)$/i) {
		my $value = $1;
		if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
			$excluderefseq = 1;
		}
		elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
			$excluderefseq = 0;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
		}
	}
	elsif ($ARGV[$i] =~ /^-+(?:acc|accession|seqid)list=(.+)$/i) {
		$acclist = $1;
	}
	elsif ($ARGV[$i] =~ /^\-+workspace=(.+)$/i) {
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
		&errorMessage(__LINE__, "Invalid option.");
	}
}

# check variables
if ($acclist && !-e $acclist) {
	&errorMessage(__LINE__, "\"$acclist\" does not exist.");
}
#if (!%includetaxa && !%excludetaxa && !%includetaxid && !%excludetaxid && !$acclist) {
#	&errorMessage(__LINE__, "Taxa, taxid, and accession list were not given.");
#} els
if ((%includetaxa || %excludetaxa || %includetaxid || %excludetaxid) && $acclist) {
	&errorMessage(__LINE__, "Taxa/taxid and accession list options are incompatible.");
}

# make new database and connect
my $dbhandle;
unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
	&errorMessage(__LINE__, "Cannot make database.");
}

if ($acclist) {
	my $accsdbhandle;
	# make new temporary database and connect
	if (-e "$outputfile.accsdb") {
		&errorMessage(__LINE__, "\"$outputfile.accsdb\" already exists.");
	}
	if ($workspace eq 'MEMORY') {
		unless ($accsdbhandle = DBI->connect("dbi:SQLite:dbname=:memory:", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
			&errorMessage(__LINE__, "Cannot make database.");
		}
	}
	else {
		unless ($accsdbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile.accsdb", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
			&errorMessage(__LINE__, "Cannot make database.");
		}
	}
	# make table
	unless ($accsdbhandle->do("CREATE TABLE accs (acc TEXT NOT NULL PRIMARY KEY);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	$accsdbhandle->do("CREATE INDEX accindex ON accs (acc);");
	# read accession list
	print(STDERR "Reading accession list file...");
	{
	# prepare SQL statement
		my $statement;
		unless ($statement = $accsdbhandle->prepare("REPLACE INTO accs (acc) VALUES (?);")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		# begin SQL transaction
		$accsdbhandle->do('BEGIN;');
		my $lineno = 1;
		my $inputhandle;
		unless (open($inputhandle, "< $acclist")) {
			&errorMessage(__LINE__, "Cannot read \"$acclist\".");
		}
		while (<$inputhandle>) {
			if (/^[A-Za-z0-9_]+/) {
				unless ($statement->execute($&)) {
					&errorMessage(__LINE__, "Cannot insert \"$&\".");
				}
				if ($lineno % 1000000 == 0) {
					print(STDERR '.');
					# commit SQL transaction
					$accsdbhandle->do('COMMIT;');
					# begin SQL transaction
					$accsdbhandle->do('BEGIN;');
				}
				$lineno ++;
			}
		}
		close($inputhandle);
		# commit SQL transaction
		$accsdbhandle->do('COMMIT;');
	}
	print(STDERR "done.\n\n");
	# make acc_taxid
	print(STDERR "Reading acc_taxid and making table for acc_taxid...");
	# make table
	unless ($dbhandle->do("CREATE TABLE acc_taxid (acc TEXT NOT NULL PRIMARY KEY, taxid INTEGER NOT NULL);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	# prepare SQL statement
	my $statement;
	unless ($statement = $dbhandle->prepare("INSERT INTO acc_taxid (acc, taxid) VALUES (?, ?);")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	{
		# prepare SQL statement
		my $accsstatement;
		unless ($accsstatement = $accsdbhandle->prepare("SELECT acc FROM accs WHERE acc IN (?);")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		my $inputhandle;
		unless (open($inputhandle, "< $inputfolder/acc_taxid.dmp")) {
			&errorMessage(__LINE__, "Cannot read \"$inputfolder/acc_taxid.dmp\".");
		}
		# begin SQL transaction
		$dbhandle->do('BEGIN;');
		my $lineno = 1;
		while (<$inputhandle>) {
			my @columns = split(/\s+/, $_);
			$columns[0] =~ s/\.\d+$//;
			if (!$excluderefseq || $columns[0] !~ /_/) {
				unless ($accsstatement->execute($columns[0])) {
					&errorMessage(__LINE__, "Cannot execute SELECT.");
				}
				while (my @row = $accsstatement->fetchrow_array) {
					if ($row[0] == $columns[0]) {
						$includetaxid{$columns[1]} = 1;
						unless ($statement->execute($columns[0], $columns[1])) {
							&errorMessage(__LINE__, "Cannot execute INSERT.");
						}
					}
					last;
				}
			}
			if ($lineno % 1000000 == 0) {
				print(STDERR '.');
				# commit SQL transaction
				$dbhandle->do('COMMIT;');
				# begin SQL transaction
				$dbhandle->do('BEGIN;');
			}
			$lineno ++;
		}
		close($inputhandle);
		# commit SQL transaction
		$dbhandle->do('COMMIT;');
	}
	$dbhandle->do("CREATE INDEX accindex ON acc_taxid (acc);");
	print(STDERR "done.\n\n");
	# disconnect and delete accsdb
	$accsdbhandle->disconnect;
	unlink("$outputfile.accsdb");
}
elsif (%includetaxa || %excludetaxa) {
	# read names
	print(STDERR "Reading names file...");
	{
		# open input file
		my $inputhandle;
		unless (open($inputhandle, "< $inputfolder/names.dmp")) {
			&errorMessage(__LINE__, "Cannot read \"$inputfolder/names.dmp\".");
		}
		# store entries
		my $lineno = 1;
		while (<$inputhandle>) {
			s/\r?\n?$//;
			s/\t?\|?$//;
			my @columns = split(/\t\|\t/, lc($_));
			foreach my $word (keys(%includetaxa)) {
				if ($columns[1] =~ /$word/) {
					$includetaxid{$columns[0]} = 1;
				}
			}
			foreach my $word (keys(%excludetaxa)) {
				if ($columns[1] =~ /$word/) {
					$excludetaxid{$columns[0]} = 1;
				}
			}
			if ($lineno % 10000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
		# close input file
		close($inputhandle);
	}
	undef(%includetaxa);
	undef(%excludetaxa);
	print(STDERR "done.\n\n");
}

my %daughters;
my %parents;
if ($acclist) {
	# read nodes
	print(STDERR "Reading nodes file...");
	{
		# open input file
		my $inputhandle;
		unless (open($inputhandle, "< $inputfolder/nodes.dmp")) {
			&errorMessage(__LINE__, "Cannot read \"$inputfolder/nodes.dmp\".");
		}
		# store entries
		my $lineno = 1;
		while (<$inputhandle>) {
			s/\r?\n?$//;
			s/\t?\|?$//;
			my @columns = split(/\t\|\t/, $_);
			if ($parents{$columns[0]}) {
				&errorMessage(__LINE__, "Parent of \"$columns[0]\" is doubly specified.");
			}
			else {
				$parents{$columns[0]} = $columns[1];
			}
			if ($lineno % 10000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
		# close input file
		close($inputhandle);
	}
	print(STDERR "done.\n\n");
	# get all taxid to include subset database from nodes
	print(STDERR "Getting all taxonomic IDs...");
	foreach my $daughterid (keys(%includetaxid)) {
		&getParents($daughterid);
	}
	print(STDERR "done.\n\n");
	undef(%parents);
}
elsif (%includetaxid || %excludetaxid) {
	# read nodes
	print(STDERR "Reading nodes file...");
	{
		# open input file
		my $inputhandle;
		unless (open($inputhandle, "< $inputfolder/nodes.dmp")) {
			&errorMessage(__LINE__, "Cannot read \"$inputfolder/nodes.dmp\".");
		}
		# store entries
		my $lineno = 1;
		while (<$inputhandle>) {
			s/\r?\n?$//;
			s/\t?\|?$//;
			my @columns = split(/\t\|\t/, $_);
			push(@{$daughters{$columns[1]}}, $columns[0]);
			if ($lineno % 10000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
		# close input file
		close($inputhandle);
	}
	print(STDERR "done.\n\n");
	# get all taxid to include subset database from nodes
	print(STDERR "Getting all taxonomic IDs...");
	if (%includetaxid) {
		foreach my $parentid (keys(%includetaxid)) {
			&getDaughters($parentid);
		}
	}
	else {
		# open input file
		my $inputhandle;
		unless (open($inputhandle, "< $inputfolder/names.dmp")) {
			&errorMessage(__LINE__, "Cannot read \"$inputfolder/names.dmp\".");
		}
		# store entries
		my $lineno = 1;
		while (<$inputhandle>) {
			s/\r?\n?$//;
			s/\t?\|?$//;
			my @columns = split(/\t\|\t/, lc($_));
			$includetaxid{$columns[0]} = 1;
			if ($lineno % 10000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
		# close input file
		close($inputhandle);
	}
	if (%excludetaxid) {
		foreach my $parentid (keys(%excludetaxid)) {
			delete($includetaxid{$parentid});
			delete($excludetaxid{$parentid});
			&deleteDaughters($parentid);
		}
	}
	print(STDERR "done.\n\n");
	undef(%daughters);
}

if (!$acclist) {
	print(STDERR "Making table for acc_taxid...");
	# make table
	unless ($dbhandle->do("CREATE TABLE acc_taxid (acc TEXT NOT NULL PRIMARY KEY, taxid INTEGER NOT NULL);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	# open input file
	my $inputhandle;
	unless (open($inputhandle, "< $inputfolder/acc_taxid.dmp")) {
		&errorMessage(__LINE__, "Cannot read \"$inputfolder/acc_taxid.dmp\".");
	}
	# prepare SQL statement
	my $statement;
	unless ($statement = $dbhandle->prepare("INSERT INTO acc_taxid (acc, taxid) VALUES (?, ?);")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	# begin SQL transaction
	$dbhandle->do('BEGIN;');
	# insert entry
	my $lineno = 1;
	my $nentries = 1;
	while (<$inputhandle>) {
		my @columns = split(/\s+/, $_);
		$columns[0] =~ s/\.\d+$//;
		if (!$excluderefseq || $columns[0] !~ /_/) {
			if ($includetaxid{$columns[1]} || !%includetaxid) {
				unless ($statement->execute($columns[0], $columns[1])) {
					&errorMessage(__LINE__, "Cannot insert \"$columns[0], $columns[1]\".");
				}
				if ($nentries % 1000000 == 0) {
					# commit SQL transaction
					$dbhandle->do('COMMIT;');
					# begin SQL transaction
					$dbhandle->do('BEGIN;');
				}
				$nentries ++;
			}
		}
		if ($lineno % 1000000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	# commit SQL transaction
	$dbhandle->do('COMMIT;');
	# close input file
	close($inputhandle);
	$dbhandle->do("CREATE INDEX accindex ON acc_taxid (acc);");
	print(STDERR "done.\n\n");
}

# make table for names and add entries
print(STDERR "Making table for names...");
{
	# make table
	unless ($dbhandle->do("CREATE TABLE names (taxid INTEGER NOT NULL, name TEXT NOT NULL, nameclass TEXT);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	# open input file
	my $inputhandle;
	unless (open($inputhandle, "< $inputfolder/names.dmp")) {
		&errorMessage(__LINE__, "Cannot read \"$inputfolder/names.dmp\".");
	}
	# prepare SQL statement
	my $statement;
	unless ($statement = $dbhandle->prepare("INSERT INTO names (taxid, name, nameclass) VALUES (?, ?, ?);")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	# begin SQL transaction
	$dbhandle->do('BEGIN;');
	# insert entry
	my $lineno = 1;
	my $nentries = 1;
	while (<$inputhandle>) {
		s/\r?\n?$//;
		s/\t?\|?$//;
		my @columns = split(/\t\|\t/, $_);
		if ($includetaxid{$columns[0]} || !%includetaxid) {
			unless ($statement->execute($columns[0], $columns[1], $columns[3])) {
				&errorMessage(__LINE__, "Cannot insert \"$columns[0], $columns[1], $columns[3]\".");
			}
			if ($nentries % 1000000 == 0) {
				# commit SQL transaction
				$dbhandle->do('COMMIT;');
				# begin SQL transaction
				$dbhandle->do('BEGIN;');
			}
			$nentries ++;
		}
		if ($lineno % 10000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	# commit SQL transaction
	$dbhandle->do('COMMIT;');
	# close input file
	close($inputhandle);
	# delete root
	unless ($dbhandle->do("DELETE FROM names WHERE name='all';") || $dbhandle->do("DELETE FROM names WHERE name='root';")) {
		&errorMessage(__LINE__, "Cannot delete root.");
	}
}
print(STDERR "done.\n\n");

# make table for nodes and add entries
print(STDERR "Making table for nodes...");
{
	# make table
	unless ($dbhandle->do("CREATE TABLE nodes (taxid INTEGER NOT NULL PRIMARY KEY, parent INTEGER NOT NULL, rank TEXT NOT NULL);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	# open input file
	my $inputhandle;
	unless (open($inputhandle, "< $inputfolder/nodes.dmp")) {
		&errorMessage(__LINE__, "Cannot read \"$inputfolder/nodes.dmp\".");
	}
	# prepare SQL statement
	my $statement;
	unless ($statement = $dbhandle->prepare("INSERT INTO nodes (taxid, parent, rank) VALUES (?, ?, ?);")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	# begin SQL transaction
	$dbhandle->do('BEGIN;');
	# insert entry
	my $lineno = 1;
	my $nentries = 1;
	while (<$inputhandle>) {
		s/\r?\n?$//;
		s/\t?\|?$//;
		my @columns = split(/\t\|\t/, $_);
		if ($includetaxid{$columns[0]} || !%includetaxid) {
			$columns[2] =~ s/^(?:morph|subvariety||pathogroup|serogroup)$/subspecies/;
			$columns[2] =~ s/^(?:biotype|genotype|serotype)$/varietas/;
			$columns[2] =~ s/^clade$/no rank/;
			unless ($statement->execute($columns[0], $columns[1], $columns[2])) {
				&errorMessage(__LINE__, "Cannot insert \"$columns[0], $columns[1], $columns[2]\".");
			}
			if ($nentries % 1000000 == 0) {
				# commit SQL transaction
				$dbhandle->do('COMMIT;');
				# begin SQL transaction
				$dbhandle->do('BEGIN;');
			}
			$nentries ++;
		}
		if ($lineno % 10000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	# commit SQL transaction
	$dbhandle->do('COMMIT;');
	# close input file
	close($inputhandle);
	# delete root
	unless ($dbhandle->do("DELETE FROM nodes WHERE taxid=1;")) {
		&errorMessage(__LINE__, "Cannot delete root.");
	}
}
print(STDERR "done.\n\n");

# disconnect
$dbhandle->disconnect;

sub getDaughters {
	my $parentid = shift(@_);
	if ($daughters{$parentid}) {
		foreach my $daughterid (@{$daughters{$parentid}}) {
			$includetaxid{$daughterid} = 1;
			&getDaughters($daughterid);
		}
	}
}

sub deleteDaughters {
	my $parentid = shift(@_);
	if ($daughters{$parentid}) {
		foreach my $daughterid (@{$daughters{$parentid}}) {
			delete($includetaxid{$daughterid});
			&deleteDaughters($daughterid);
		}
	}
}

sub getParents {
	my $daughterid = shift(@_);
	if ($parents{$daughterid} && !exists($includetaxid{$parents{$daughterid}})) {
		$includetaxid{$parents{$daughterid}} = 1;
		&getParents($parents{$daughterid});
	}
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
clmaketaxdb options inputfolder outputfile

Command line options
====================
--includetaxa=NAME(,NAME..)
  Specify include taxa by name. (default: none)

--excludetaxa=NAME(,NAME..)
  Specify exclude taxa by name. (default: none)

--includetaxid=ID(,ID..)
  Specify include taxa by NCBI taxonomy ID. (default: none)

--excludetaxid=ID(,ID..)
  Specify exclude taxa by NCBI taxonomy ID. (default: none)

--excluderefseq=ENABLE|DISABLE
  Specify whether RefSeq accession exclusion will be applied or not.
(default: ENABLE)

--acclist=FILENAME
  Specify file name of accession list. (default: none)
_END
	exit;
}
