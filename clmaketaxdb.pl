use strict;
use DBI;

my $buildno = '0.2.x';

print(STDERR <<"_END");
clmaketaxdb $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2016  Akifumi S. Tanabe

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
if (!-e "$inputfolder/gi_taxid_nucl.dmp") {
	&errorMessage(__LINE__, "\"$inputfolder/gi_taxid_nucl.dmp\" does not exist.");
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
my $gilist;
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
	elsif ($ARGV[$i] =~ /^-+gilist=(.+)$/i) {
		$gilist = $1;
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
if ($gilist && !-e $gilist) {
	&errorMessage(__LINE__, "\"$gilist\" does not exist.");
}
#if (!%includetaxa && !%excludetaxa && !%includetaxid && !%excludetaxid && !$gilist) {
#	&errorMessage(__LINE__, "Taxa, taxid, and GI list were not given.");
#} els
if ((%includetaxa || %excludetaxa || %includetaxid || %excludetaxid) && $gilist) {
	&errorMessage(__LINE__, "Taxa/taxid and GI list options are incompatible.");
}

# make new database and connect
my $dbhandle;
unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile", '', '')) {
	&errorMessage(__LINE__, "Cannot make database.");
}

if ($gilist) {
	my $gisdbhandle;
	# make new temporary database and connect
	if (-e "$outputfile.gisdb") {
		&errorMessage(__LINE__, "\"$outputfile.gisdb\" already exists.");
	}
	if ($workspace eq 'MEMORY') {
		unless ($gisdbhandle = DBI->connect("dbi:SQLite:dbname=:memory:", '', '')) {
			&errorMessage(__LINE__, "Cannot make database.");
		}
	}
	else {
		unless ($gisdbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile.gisdb", '', '')) {
			&errorMessage(__LINE__, "Cannot make database.");
		}
	}
	# make table
	unless ($gisdbhandle->do("CREATE TABLE gis (gi INTEGER NOT NULL PRIMARY KEY);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	# read GI list
	print(STDERR "Reading gilist file...");
	{
	# prepare SQL statement
		my $statement;
		unless ($statement = $gisdbhandle->prepare("REPLACE INTO gis (gi) VALUES (?);")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		# begin SQL transaction
		$gisdbhandle->do('BEGIN;');
		my $lineno = 1;
		my $inputhandle;
		unless (open($inputhandle, "< $gilist")) {
			&errorMessage(__LINE__, "Cannot read \"$gilist\".");
		}
		while (<$inputhandle>) {
			if (/^\d+/) {
				unless ($statement->execute($&)) {
					&errorMessage(__LINE__, "Cannot insert \"$&\".");
				}
				if ($lineno % 1000000 == 0) {
					print(STDERR '.');
					# commit SQL transaction
					$gisdbhandle->do('COMMIT;');
					# begin SQL transaction
					$gisdbhandle->do('BEGIN;');
				}
				$lineno ++;
			}
		}
		close($inputhandle);
		# commit SQL transaction
		$gisdbhandle->do('COMMIT;');
	}
	print(STDERR "done.\n\n");
	# make gi_taxid_nucl
	print(STDERR "Reading gi_taxid_nucl and making table for gi_taxid_nucl...");
	# make table
	unless ($dbhandle->do("CREATE TABLE gi_taxid_nucl (gi INTEGER NOT NULL PRIMARY KEY, taxid INTEGER NOT NULL);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	# prepare SQL statement
	my $statement;
	unless ($statement = $dbhandle->prepare("INSERT INTO gi_taxid_nucl (gi, taxid) VALUES (?, ?);")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	{
		# prepare SQL statement
		my $gisstatement;
		unless ($gisstatement = $gisdbhandle->prepare("SELECT gi FROM gis WHERE gi IN (?);")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		my $inputhandle;
		unless (open($inputhandle, "< $inputfolder/gi_taxid_nucl.dmp")) {
			&errorMessage(__LINE__, "Cannot read \"$inputfolder/gi_taxid_nucl.dmp\".");
		}
		# begin SQL transaction
		$dbhandle->do('BEGIN;');
		my $lineno = 1;
		while (<$inputhandle>) {
			my @columns = split(/\s+/, $_);
			unless ($gisstatement->execute($columns[0])) {
				&errorMessage(__LINE__, "Cannot execute SELECT.");
			}
			while (my @row = $gisstatement->fetchrow_array) {
				if ($row[0] == $columns[0]) {
					$includetaxid{$columns[1]} = 1;
					unless ($statement->execute($columns[0], $columns[1])) {
						&errorMessage(__LINE__, "Cannot execute INSERT.");
					}
				}
				last;
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
	print(STDERR "done.\n\n");
	# disconnect and delete gisdb
	$gisdbhandle->disconnect;
	unlink("$outputfile.gisdb");
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
if ($gilist) {
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

# make table for gi_taxid_nucl and add entries
# if ($gilist) {
# 	# make table
# 	unless ($dbhandle->do("CREATE TABLE gi_taxid_nucl (gi INTEGER NOT NULL PRIMARY KEY, taxid INTEGER NOT NULL);")) {
# 		&errorMessage(__LINE__, "Cannot make table.");
# 	}
# 	# prepare SQL statement
# 	my $statement;
# 	unless ($statement = $dbhandle->prepare("INSERT INTO gi_taxid_nucl (gi, taxid) VALUES (?, ?);")) {
# 		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
# 	}
# 	# prepare SQL statement
# 	my $includetaxidstatement;
# 	unless ($includetaxidstatement = $includetaxiddbhandle->prepare("SELECT gi FROM includetaxid WHERE taxid IN (?);")) {
# 		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
# 	}
# 	# begin SQL transaction
# 	$dbhandle->do('BEGIN;');
# 	# insert entry
# 	my $lineno = 1;
# 	my $nentries = 1;
# 	foreach my $includetaxid (keys(%includetaxid)) {
# 		unless ($includetaxidstatement->execute($includetaxid)) {
# 			&errorMessage(__LINE__, "Cannot execute SELECT.");
# 		}
# 		while (my @row = $includetaxidstatement->fetchrow_array) {
# 			unless ($statement->execute($row[0], $includetaxid)) {
# 				&errorMessage(__LINE__, "Cannot insert \"$row[0], $includetaxid\".");
# 			}
# 			if ($nentries % 1000000 == 0) {
# 				# commit SQL transaction
# 				$dbhandle->do('COMMIT;');
# 				# begin SQL transaction
# 				$dbhandle->do('BEGIN;');
# 			}
# 			$nentries ++;
# 		}
# 		if ($lineno % 1000000 == 0) {
# 			print(STDERR '.');
# 		}
# 		$lineno ++;
# 	}
# 	# commit SQL transaction
# 	$dbhandle->do('COMMIT;');
# 	# disconnect and delete includetaxiddb
# 	$includetaxiddbhandle->disconnect;
# 	unlink("$outputfile.includetaxiddb");
# 	print(STDERR '...');
# }
if (!$gilist) {
	print(STDERR "Making table for gi_taxid_nucl...");
	# make table
	unless ($dbhandle->do("CREATE TABLE gi_taxid_nucl (gi INTEGER NOT NULL PRIMARY KEY, taxid INTEGER NOT NULL);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	# open input file
	my $inputhandle;
	unless (open($inputhandle, "< $inputfolder/gi_taxid_nucl.dmp")) {
		&errorMessage(__LINE__, "Cannot read \"$inputfolder/gi_taxid_nucl.dmp\".");
	}
	# prepare SQL statement
	my $statement;
	unless ($statement = $dbhandle->prepare("INSERT INTO gi_taxid_nucl (gi, taxid) VALUES (?, ?);")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	# begin SQL transaction
	$dbhandle->do('BEGIN;');
	# insert entry
	my $lineno = 1;
	my $nentries = 1;
	while (<$inputhandle>) {
		my @columns = split(/\s+/, $_);
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
		if ($lineno % 1000000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	# commit SQL transaction
	$dbhandle->do('COMMIT;');
	# close input file
	close($inputhandle);
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
		my @columns = split(/\t\|\t/, $_);
		if ($includetaxid{$columns[0]} || !%includetaxid) {
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

--gilist=FILENAME
  Specify file name of GI list. (default: none)
_END
	exit;
}
