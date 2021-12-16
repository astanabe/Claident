use strict;
use DBI;
use File::Spec;
use File::Copy::Recursive ('fcopy', 'rcopy', 'dircopy');
use Cwd 'getcwd';

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

my $makeblastdboption = ' -dbtype nucl -input_type fasta -hash_index -parse_seqids -max_file_sz 2G';

# options
my $blastdb;
my $taxdb;
my $format;
my $separator = ';';
my $accprefix = 'ZZ';
my $nodel;

# input/output
my $inputfile;
my $output;

# commands
my $makeblastdb;
my $blastdb_aliastool;

# global variables
my $root = getcwd();
my @format;
my $prefix;
my $blastdbpath;
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'subphylum', 'superclass', 'class', 'subclass', 'infraclass', 'cohort', 'subcohort', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'section', 'subsection', 'series', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma', 'forma specialis', 'strain', 'isolate');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}

# file handles
my $filehandleinput1;
my $filehandleoutput1;
my $pipehandleinput1;
my $dbhandle;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# read FASTA file and make TaxDB
	&readFASTAmakeTaxDB();
	# make BLASTDB
	&makeBLASTDB();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clconvrefdb $buildno
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
	$output = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:db|blastdb|bdb)=(.+)$/i) {
			$blastdb = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:taxdb|tdb)=(.+)$/i) {
			$taxdb = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:format|f)=(.+)$/i) {
			$format = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:separator|s)=(.+)$/i) {
			$separator = $1;
		}
		elsif ($ARGV[$i] =~ /^-+accprefix=(.+)$/i) {
			$accprefix = $1;
		}
		elsif ($ARGV[$i] =~ /^-+nodel$/i) {
			$nodel = 1;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	if ($accprefix !~ /^[A-Z][A-Z]$/) {
		&errorMessage(__LINE__, "Accession prefix must be 2 uppercase letters.");
	}
	if ($taxdb && !$blastdb) {
		&errorMessage(__LINE__, "Taxonomy DB was given but BLAST DB was not given.");
	}
	elsif ($blastdb && !$taxdb) {
		&errorMessage(__LINE__, "BLAST DB was given but taxonomy DB was not given.");
	}
	while (glob("$output.*")) {
		if (/^$output\..+/) {
			&errorMessage(__LINE__, "Output file already exists.");
		}
	}
	# define prefix
	$prefix = $output;
	$prefix =~ s/^.+[\\\/]//;
	if ($prefix eq '') {
		&errorMessage(__LINE__, "Output is invalid.");
	}
	# recognize format
	if ($format) {
		$format =~ s/^\"(.+)\"$/$1/;
		my @words = split(/${separator}/, $format);
		for (my $i = 0; $i < scalar(@words); $i ++) {
			$words[$i] =~ s/^\"(.+)\"$/$1/;
			if ($taxrank{$words[$i]}) {
				$format[$i] = $words[$i];
			}
			else {
				&errorMessage(__LINE__, "Specified format is invalid.");
			}
		}
	}
	# search taxdb
	if ($taxdb) {
		if (-e "$taxdb.taxdb") {
			$taxdb = "$taxdb.taxdb";
		}
		else {
			my $pathto;
			if ($ENV{'TAXONOMYDB'}) {
				$pathto = $ENV{'TAXONOMYDB'};
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
						if (/^\s*TAXONOMYDB\s*=\s*(\S[^\r\n]*)/) {
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
			if ($pathto && -e "$pathto/$taxdb") {
				$taxdb = "$pathto/$taxdb";
			}
			elsif ($pathto && -e "$pathto/$taxdb.taxdb") {
				$taxdb = "$pathto/$taxdb.taxdb";
			}
			else {
				&errorMessage(__LINE__, "Both \"$taxdb\" and \"$pathto/$taxdb\" do not exist.");
			}
		}
	}
	# search makeblastdb and blastdb_aliastool
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

sub readFASTAmakeTaxDB {
	my $temptaxid = 9999999;
	my $tempacc = 0;
	if ($taxdb) {
		unless (fcopy($taxdb, "$output.taxdb")) {
			&errorMessage(__LINE__, "Cannot copy \"$taxdb\" to \"$output.taxdb\".");
		}
		print(STDERR "Reading taxonomy database...");
		# connect taxdb
		unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$output.taxdb", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 0, AutoInactiveDestroy => 1})) {
			&errorMessage(__LINE__, "Cannot connect database.");
		}
		{
			my $statement;
			unless ($statement = $dbhandle->prepare('SELECT taxid FROM acc_taxid')) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
			unless ($statement->execute) {
				&errorMessage(__LINE__, "Cannot execute SELECT.");
			}
			my $lineno = 1;
			while (my @row = $statement->fetchrow_array) {
				if ($row[0] > $temptaxid) {
					$temptaxid = $row[0];
				}
				if ($lineno % 10000 == 0) {
					print(STDERR '.');
				}
				$lineno ++;
			}
		}
		# disconnect
		$dbhandle->disconnect;
		print(STDERR "done.\n\n");
	}
	else {
		$temptaxid = 1;
	}
	# read input FASTA file
	print(STDERR "Reading input file...");
	my %taxon2taxid;
	my %acc2taxid;
	unless (open($filehandleoutput1, "> $output.fasta")) {
		&errorMessage(__LINE__, "Cannot write \"$output.fasta\".");
	}
	unless (open($filehandleinput1, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
	}
	{
		my $lineno = 1;
		$| = 1;
		$? = 0;
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.*)/s) {
				my $seqname = $1;
				my $sequence = $2;
				$seqname =~ s/${separator}?\s*$//;
				$sequence =~ s/[>\s\r\n]//g;
				if ($sequence) {
					$tempacc ++;
					my $acc = $accprefix . &convNumber2Accession($tempacc);
					print($filehandleoutput1 ">gb|$acc $seqname\n$sequence\n");
					if ($seqname !~ /${separator}/ && $seqname =~ /^ta?xid[:=](\d+)$/i) {
						$acc2taxid{$acc} = $1;
					}
					elsif ($taxon2taxid{$seqname}) {
						$acc2taxid{$acc} = $taxon2taxid{$seqname};
					}
					else {
						$temptaxid ++;
						$taxon2taxid{$seqname} = $temptaxid;
						$acc2taxid{$acc} = $temptaxid;
					}
				}
			}
			if ($lineno % 10000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
	}
	close($filehandleinput1);
	close($filehandleoutput1);
	print(STDERR "done.\n\n");
	# make taxonomic hierarchy
	print(STDERR "Formatting taxonomic hierarchy...");
	my %parents;
	{
		my $lineno = 1;
		my @taxon = sort({$taxon2taxid{$a} <=> $taxon2taxid{$b}} keys(%taxon2taxid));
		foreach my $taxon (@taxon) {
			while ($taxon =~ /${separator}/) {
				my $highertaxon = $taxon;
				$highertaxon =~ s/${separator}[^${separator}]+$//;
				if ($highertaxon !~ /${separator}/ && $highertaxon =~ /^ta?xid[:=](\d+)$/i) {
					$parents{$taxon2taxid{$taxon}} = $1;
					last;
				}
				elsif ($taxon2taxid{$highertaxon}) {
					$parents{$taxon2taxid{$taxon}} = $taxon2taxid{$highertaxon};
					last;
				}
				else {
					$temptaxid ++;
					$taxon2taxid{$highertaxon} = $temptaxid;
					$parents{$taxon2taxid{$taxon}} = $temptaxid;
				}
				$taxon = $highertaxon;
			}
			if ($lineno % 10000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
		@taxon = sort({$taxon2taxid{$a} <=> $taxon2taxid{$b}} keys(%taxon2taxid));
		foreach my $taxon (@taxon) {
			my @hierarchy = split(/${separator}/, $taxon);
			my $tail = scalar(@hierarchy) - 1;
			if ($hierarchy[0] =~ /^ta?xid[:=](\d+)/i) {
				$tail --;
			}
			if (@format) {
				if ($format[$tail]) {
					$hierarchy[-1] =~ /^"?(.+)"?$/;
					my $name = $1;
					$taxon2taxid{"$format[$tail]:$name"} = $taxon2taxid{$taxon};
					delete($taxon2taxid{$taxon});
				}
				else {
					&errorMessage(__LINE__, "\"$taxon\" is invalid.");
				}
			}
			else {
				if ($hierarchy[-1] =~ /^"?(.+?)"?[:=]"?(.+)"?$/) {
					my $taxrank = $1;
					my $name = $2;
					if ($taxrank{$taxrank}) {
						$taxon2taxid{"$taxrank:$name"} = $taxon2taxid{$taxon};
						delete($taxon2taxid{$taxon});
					}
					else {
						&errorMessage(__LINE__, "\"$taxon\" is invalid.");
					}
				}
				else {
					&errorMessage(__LINE__, "\"$taxon\" is invalid.");
				}
			}
			
			if ($lineno % 10000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
	}
	print(STDERR "done.\n\n");
	# make taxdb
	unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$output.taxdb", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 0, AutoInactiveDestroy => 1})) {
		&errorMessage(__LINE__, "Cannot make database.");
	}
	print(STDERR "Making table for acc_taxid...");
	# make table
	unless ($taxdb) {
		unless ($dbhandle->do("CREATE TABLE acc_taxid (acc TEXT NOT NULL PRIMARY KEY, taxid INTEGER NOT NULL);")) {
			&errorMessage(__LINE__, "Cannot make table.");
		}
	}
	{
		# prepare SQL statement
		my $statement;
		unless ($statement = $dbhandle->prepare("INSERT INTO acc_taxid (acc, taxid) VALUES (?, ?);")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		# begin SQL transaction
		$dbhandle->do('BEGIN;');
		# insert entry
		{
			my $lineno = 1;
			my $nentries = 1;
			foreach my $acc (sort(keys(%acc2taxid))) {
				unless ($statement->execute($acc, $acc2taxid{$acc})) {
					&errorMessage(__LINE__, "Cannot insert \"$acc, $acc2taxid{$acc}\".");
				}
				if ($nentries % 1000000 == 0) {
					# commit SQL transaction
					$dbhandle->do('COMMIT;');
					# begin SQL transaction
					$dbhandle->do('BEGIN;');
				}
				$nentries ++;
				if ($lineno % 1000000 == 0) {
					print(STDERR '.');
				}
				$lineno ++;
			}
		}
		# commit SQL transaction
		$dbhandle->do('COMMIT;');
	}
	print(STDERR "done.\n\n");
	print(STDERR "Making table for names...");
	# make table
	unless ($taxdb) {
		unless ($dbhandle->do("CREATE TABLE names (taxid INTEGER NOT NULL, name TEXT NOT NULL, nameclass TEXT);")) {
			&errorMessage(__LINE__, "Cannot make table.");
		}
	}
	{
		# prepare SQL statement
		my $statement;
		unless ($statement = $dbhandle->prepare("INSERT INTO names (taxid, name, nameclass) VALUES (?, ?, ?);")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		# begin SQL transaction
		$dbhandle->do('BEGIN;');
		{
			my $lineno = 1;
			my $nentries = 1;
			foreach my $taxon (sort({$taxon2taxid{$a} <=> $taxon2taxid{$b}} keys(%taxon2taxid))) {
				if ($taxon =~ /^"?(.+?)"?[:=]"?(.+)"?$/) {
					my $taxrank = $1;
					my $name = $2;
					if ($taxrank{$taxrank}) {
						unless ($statement->execute($taxon2taxid{$taxon}, $name, 'scientific name')) {
							&errorMessage(__LINE__, "Cannot insert \"$taxon2taxid{$taxon}, $name, scientific name\".");
						}
					}
					else {
						&errorMessage(__LINE__, "\"$taxon\" is invalid.");
					}
				}
				else {
					&errorMessage(__LINE__, "\"$taxon\" is invalid.");
				}
				if ($nentries % 1000000 == 0) {
					# commit SQL transaction
					$dbhandle->do('COMMIT;');
					# begin SQL transaction
					$dbhandle->do('BEGIN;');
				}
				$nentries ++;
				if ($lineno % 10000 == 0) {
					print(STDERR '.');
				}
				$lineno ++;
			}
		}
		# commit SQL transaction
		$dbhandle->do('COMMIT;');
		# delete root
		unless ($dbhandle->do("DELETE FROM names WHERE name='all';") || $dbhandle->do("DELETE FROM names WHERE name='root';") || $dbhandle->do("DELETE FROM names WHERE name='Root';")) {
			&errorMessage(__LINE__, "Cannot delete root.");
		}
	}
	print(STDERR "done.\n\n");
	print(STDERR "Making table for nodes...");
	# make table
	unless ($taxdb) {
		unless ($dbhandle->do("CREATE TABLE nodes (taxid INTEGER NOT NULL PRIMARY KEY, parent INTEGER NOT NULL, rank TEXT NOT NULL);")) {
			&errorMessage(__LINE__, "Cannot make table.");
		}
	}
	{
		# prepare SQL statement
		my $statement;
		unless ($statement = $dbhandle->prepare("INSERT INTO nodes (taxid, parent, rank) VALUES (?, ?, ?);")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		# begin SQL transaction
		$dbhandle->do('BEGIN;');
		{
			my $lineno = 1;
			my $nentries = 1;
			foreach my $taxon (sort({$taxon2taxid{$a} <=> $taxon2taxid{$b}} keys(%taxon2taxid))) {
				if ($taxon =~ /^"?(.+?)"?[:=]"?(.+)"?$/) {
					my $taxrank = $1;
					my $name = $2;
					if ($taxrank{$taxrank}) {
						if ($parents{$taxon2taxid{$taxon}}) {
							unless ($statement->execute($taxon2taxid{$taxon}, $parents{$taxon2taxid{$taxon}}, $taxrank)) {
								&errorMessage(__LINE__, "Cannot insert \"$taxon2taxid{$taxon}, $parents{$taxon2taxid{$taxon}}, $taxrank\".");
							}
						}
						else {
							unless ($statement->execute($taxon2taxid{$taxon}, 1, $taxrank)) {
								&errorMessage(__LINE__, "Cannot insert \"$taxon2taxid{$taxon}, 1, $taxrank\".");
							}
						}
					}
					else {
						&errorMessage(__LINE__, "\"$taxon\" is invalid.");
					}
				}
				else {
					&errorMessage(__LINE__, "\"$taxon\" is invalid.");
				}
				if ($nentries % 1000000 == 0) {
					# commit SQL transaction
					$dbhandle->do('COMMIT;');
					# begin SQL transaction
					$dbhandle->do('BEGIN;');
				}
				$nentries ++;
				if ($lineno % 10000 == 0) {
					print(STDERR '.');
				}
				$lineno ++;
			}
		}
		# commit SQL transaction
		$dbhandle->do('COMMIT;');
	}
	print(STDERR "done.\n\n");
	# disconnect
	$dbhandle->disconnect;
}

sub makeBLASTDB {
	print(STDERR "Running makeblastdb using $output.fasta...\n");
	if ($blastdb) {
		system("BLASTDB=\"$blastdbpath\" $makeblastdb$makeblastdboption -in $output.fasta -out $output.sub -title $output.sub 1> $devnull 2> $devnull");
		if ((!-e "$output.sub.nsq" || -z "$output.sub.nsq") && (!-e "$output.sub.nal" || -z "$output.sub.nal")) {
			&errorMessage(__LINE__, "Cannot run makeblastdb correctly.");
		}
	}
	else {
		system("BLASTDB=\"$blastdbpath\" $makeblastdb$makeblastdboption -in $output.fasta -out $output -title $output 1> $devnull 2> $devnull");
		if ((!-e "$output.nsq" || -z "$output.nsq") && (!-e "$output.nal" || -z "$output.nal")) {
			&errorMessage(__LINE__, "Cannot run makeblastdb correctly.");
		}
	}
	unless ($nodel) {
		unlink("$output.fasta");
	}
	print(STDERR "done.\n\n");
	if ($blastdb) {
		system("BLASTDB=\"$blastdbpath\" $blastdb_aliastool -dbtype nucl -dblist \"$blastdb $output.sub\" -out $output -title $output");
		if (!-e "$output.nal" || -z "$output.nal") {
			&errorMessage(__LINE__, "Cannot run blastdb_aliastool correctly.");
		}
	}
}

sub convNumber2Accession {
	my $num = shift(@_);
	my $acc;
	if ($num < 100000000) {
		$acc = 'AA' . sprintf("%08d", $num);
	}
	else {
		my $prefix = int($num / 99999999);
		if ($prefix < 26) {
			$acc = 'A' . pack('C', ($prefix + 65)) . sprintf("%08d", ($num % 99999999));
		}
		else {
			my $prefix2 = int($prefix / 26);
			if ($prefix2 < 26) {
				$prefix = $prefix % 26;
				$acc = pack('C', ($prefix2 + 65)) . pack('C', ($prefix + 65)) . sprintf("%08d", ($num % 99999999));
			}
			else {
				&errorMessage(__LINE__, "Too many sequence.");
			}
		}
	}
	return($acc);
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
clconvrefdb options inputfile outputprefix

Command line options
====================
--tdb, --taxdb=FILENAME
  Specify filename of taxonomy database. (default: none)

--bdb, --blastdb=BLASTDBNAME
  Specify filename of BLAST database. (default: none)

-f, --format=FORMAT
  Specify defline format. (default: none)

-s, --separator=SEPARATOR
  Specify defline separator. (default: ;)

--accprefix=PREFIX
  Specify prefix for fake accessions. (default: ZZ)

Defline format
==============
In FASTA input file, taxonomy rank is required like below.

>kingdom:Metazoa;phylum:Chordata;class:Mammalia;order:Primates;family:Hominidae;genus:Homo;species:Homo sapiens

Alternatively, you can use --format option.
If you specify this option like below,

--format=\"kingdom;phylum;class;order;family;genus;species\"

you can use the following defline format.

>Metazoa;Chordata;Mammalia;Primates;Hominidae;Homo;Homo sapiens

Additionally, you can add your own sequences to existing database based on the
following format.

>taxid:9605;species:Homo foobar
>taxid:9606

Acceptable input file formats
=============================
FASTA
_END
	exit;
}
