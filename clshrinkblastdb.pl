use strict;
use DBI;
use File::Spec;

my $buildno = '0.2.x';

# input/output
my $inputfile;
my $outputfile;

# options
my $numthreads = 1;
my $minlen = 100;
my $maxlen = 20000;
my $threshold = 100000;
my $dellongseq = 0;
my $taxdb;
my $targetrank = 'class';

# global variables
my $devnull = File::Spec->devnull();
my @taxa;
my %daughters;
my %includetaxid;
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
	# construct temporary sequence database
	&constructSeqDB();
	# retrieve taxids
	&retrieveTaxa();
	# cluster sequences and save results
	&clusterSequences();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clshrinkblastdb $buildno
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
	# get input file name
	$inputfile = $ARGV[-2];
	# get output file name
	$outputfile = $ARGV[-1];
	# read command line options
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:taxdb|tdb)=(.+)$/i) {
			$taxdb = $1;
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
		elsif ($ARGV[$i] =~ /^-+(?:del|delete)(?:longer|long)(?:sequence|seq)s?=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$dellongseq = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$dellongseq = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
		}
	}
}

sub checkVariables {
	if (!$taxdb) {
		&errorMessage(__LINE__, "Taxdb was not given.");
	}
	elsif (!-e $taxdb) {
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
	if ($minlen < 1) {
		&errorMessage(__LINE__, "The minimum length threshold for sequences is invalid.");
	}
	if ($maxlen < 1) {
		&errorMessage(__LINE__, "The maximum length threshold for sequences is invalid.");
	}
	if ($minlen > $maxlen) {
		&errorMessage(__LINE__, "The minimum length threshold for sequences is larger than the maximum length threshold.");
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
}

sub constructSeqDB {
	print(STDERR "Constructing temporary sequence database...");
	# connect to database
	my $seqdbhandle;
	unless ($seqdbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile.seqdb", '', '')) {
		&errorMessage(__LINE__, "Cannot connect database.");
	}
	# make table
	unless ($seqdbhandle->do("CREATE TABLE seq (acc TEXT NOT NULL PRIMARY KEY, seq TEXT NOT NULL, seqname TEXT);")) {
		&errorMessage(__LINE__, "Cannot make table.");
	}
	# prepare SQL statement
	my $statement;
	unless ($statement = $seqdbhandle->prepare("INSERT INTO seq (acc, seq, seqname) VALUES (?, ?, ?);")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	# begin SQL transaction
	$seqdbhandle->do('BEGIN;');
	# open input file
	$filehandleinput1 = &readFile($inputfile);
	local $/ = "\n>";
	# insert entry
	my $seqno = 1;
	my $nentries = 1;
	while (<$filehandleinput1>) {
		if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
			my $seqname = $1;
			my $seq = uc($2);
			$seq =~ s/[> \r\n]//g;
			$seqname =~ /\|*(?:gb|emb|dbj)\|([A-Za-z0-9]+)[\| ]/;
			my $acc = $1;
			my $seqlen = length($seq);
			if ($seqlen >= $minlen && $seqlen <= $maxlen) {
				unless ($statement->execute($acc, $seq, $seqname)) {
					&errorMessage(__LINE__, "Cannot insert \"$acc, $seq, $seqname\".");
				}
				if ($nentries % 100000 == 0) {
					# commit SQL transaction
					$seqdbhandle->do('COMMIT;');
					# begin SQL transaction
					$seqdbhandle->do('BEGIN;');
				}
				$nentries ++;
			}
			elsif ($dellongseq == 0 && $seqlen > $maxlen) {
				$filehandleoutput1 = &writeFile($outputfile);
				print($filehandleoutput1 ">$seqname\n$seq\n");
				close($filehandleoutput1);
			}
		}
		if ($seqno % 100000 == 0) {
			print(STDERR '.');
		}
		$seqno ++;
	}
	# commit SQL transaction
	$seqdbhandle->do('COMMIT;');
	# close input file
	close($filehandleinput1);
	# disconnect
	$seqdbhandle->disconnect;
	print(STDERR "done.\n\n");
}

sub retrieveTaxa {
	print(STDERR "Reading nodes table...");
	# connect to database
	my $taxdbhandle;
	unless ($taxdbhandle = DBI->connect("dbi:SQLite:dbname=$taxdb", '', '')) {
		&errorMessage(__LINE__, "Cannot connect database.");
	}
	my $statement;
	unless ($statement = $taxdbhandle->prepare('SELECT taxid, parent, rank FROM nodes')) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	unless ($statement->execute) {
		&errorMessage(__LINE__, "Cannot execute SELECT.");
	}
	my $lineno = 1;
	while (my @row = $statement->fetchrow_array) {
		push(@{$daughters{$row[1]}}, $row[0]);
		if ($row[2] eq $targetrank) {
			push(@taxa, $row[0]);
		}
		if ($lineno % 10000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	# disconnect
	$taxdbhandle->disconnect;
	print(STDERR "done.\n\n");
}

sub clusterSequences {
	print(STDERR "Clustering sequences...\n");
	$filehandleoutput1 = &writeFile("$outputfile.temp.fasta");
	# connect to database
	my $taxdbhandle;
	unless ($taxdbhandle = DBI->connect("dbi:SQLite:dbname=$taxdb", '', '')) {
		&errorMessage(__LINE__, "Cannot connect database.");
	}
	# connect to database
	my $seqdbhandle;
	unless ($seqdbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile.seqdb", '', '')) {
		&errorMessage(__LINE__, "Cannot connect database.");
	}
	my $nentries = 0;
	# retrieve sequences of each taxon
	foreach my $taxon (@taxa) {
		undef(%includetaxid);
		$includetaxid{$taxon} = 1;
		&getDaughters($taxon);
		my $statement1;
		my $statement2;
		unless ($statement1 = $taxdbhandle->prepare("SELECT DISTINCT acc FROM acc_taxid WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ")")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		unless ($statement1->execute) {
			&errorMessage(__LINE__, "Cannot execute SELECT.");
		}
		my @acc;
		while (my @row1 = $statement1->fetchrow_array) {
			push(@acc, $row1[0]);
			if (scalar(@acc) >= $threshold) {
				unless ($statement2 = $seqdbhandle->prepare('SELECT acc, seq FROM seq WHERE acc IN (' . join(', ', @acc) . ')')) {
					&errorMessage(__LINE__, "Cannot prepare SQL statement.");
				}
				unless ($statement2->execute) {
					&errorMessage(__LINE__, "Cannot execute SELECT.");
				}
				while (my @row2 = $statement2->fetchrow_array) {
					print($filehandleoutput1 ">$row2[0]\n$row2[1]\n");
					$nentries ++;
				}
				undef(@acc);
			}
		}
		undef(%includetaxid);
		# if retrieved sequences exceeds threshold, run clustering
		if ($nentries >= $threshold) {
			close($filehandleoutput1);
			&executeVSEARCH();
			&readVSEARCHResults();
			unlink("$outputfile.temp.fasta");
			$filehandleoutput1 = &writeFile("$outputfile.temp.fasta");
			$nentries = 0;
		}
	}
	# disconnect
	$seqdbhandle->disconnect;
	# disconnect
	$taxdbhandle->disconnect;
	close($filehandleoutput1);
	# run clustering if sequence file exists
	if ($nentries) {
		&executeVSEARCH();
		&readVSEARCHResults();
	}
	unlink("$outputfile.temp.fasta");
	# retrieve sequences which does not have specified-level taxonomic information
	{
		undef(%includetaxid);
		foreach my $taxon (@taxa) {
			$includetaxid{$taxon} = 1;
			&getDaughters($taxon);
		}
		$filehandleoutput1 = &writeFile("$outputfile.temp.fasta");
		$nentries = 0;
		# connect to database
		my $taxdbhandle;
		unless ($taxdbhandle = DBI->connect("dbi:SQLite:dbname=$taxdb", '', '')) {
			&errorMessage(__LINE__, "Cannot connect database.");
		}
		# connect to database
		my $seqdbhandle;
		unless ($seqdbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile.seqdb", '', '')) {
			&errorMessage(__LINE__, "Cannot connect database.");
		}
		my $statement1;
		my $statement2;
		unless ($statement1 = $taxdbhandle->prepare("SELECT DISTINCT acc FROM acc_taxid WHERE taxid NOT IN (" . join(', ', keys(%includetaxid)) . ")")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		unless ($statement1->execute) {
			&errorMessage(__LINE__, "Cannot execute SELECT.");
		}
		my @acc;
		while (my @row1 = $statement1->fetchrow_array) {
			push(@acc, $row1[0]);
			if (scalar(@acc) >= $threshold) {
				unless ($statement2 = $seqdbhandle->prepare('SELECT acc, seq FROM seq WHERE acc IN (' . join(', ', @acc) . ')')) {
					&errorMessage(__LINE__, "Cannot prepare SQL statement.");
				}
				unless ($statement2->execute) {
					&errorMessage(__LINE__, "Cannot execute SELECT.");
				}
				while (my @row2 = $statement2->fetchrow_array) {
					print($filehandleoutput1 ">$row2[0]\n$row2[1]\n");
					$nentries ++;
				}
				undef(@acc);
			}
		}
		# disconnect
		$taxdbhandle->disconnect;
		# disconnect
		$seqdbhandle->disconnect;
		undef(%includetaxid);
		close($filehandleoutput1);
		# run clustering
		if ($nentries) {
			&executeVSEARCH();
			&readVSEARCHResults();
		}
		unlink("$outputfile.temp.fasta");
	}
	unlink("$outputfile.seqdb");
	print(STDERR "done.\n\n");
	sub getDaughters {
		my $parentid = shift(@_);
		if ($daughters{$parentid}) {
			foreach my $daughterid (@{$daughters{$parentid}}) {
				$includetaxid{$daughterid} = 1;
				&getDaughters($daughterid);
			}
		}
	}
}

sub executeCDHITEST {
	if (system("cd-hit-est -M 0 -d 0 -T $numthreads -n 12 -l $minlen -i $outputfile.temp.fasta -o $outputfile.clustered.fasta -c 1.0 -aS 1.0 -AS 0 -B 0 -p 0 -g 0 -r 0")) {
		&errorMessage(__LINE__, "Cannot run CD-HIT-EST correctly.");
	}
	unlink("$outputfile.clustered.fasta");
}

sub readCDHITESTResults {
	# read clustering results and store
	my @cluster;
	my $ncluster;
	$filehandleinput1 = &readFile("$outputfile.clustered.fasta.clstr");
	while (<$filehandleinput1>) {
		if (defined($ncluster) && /^\d+\s+(\d+)nt, >(\S+?)\.\.\. /) {
			$cluster[$ncluster]{$2} = $1;
		}
		elsif (/^>Cluster (\d+)/) {
			$ncluster = $1;
		}
	}
	close($filehandleinput1);
	unlink("$outputfile.clustered.fasta.clstr");
	&outputResults(@cluster);
}

sub executeVSEARCH {
	if (system("$vsearch --fasta_width 0 --maxseqlength $maxlen --minseqlength $minlen --notrunclabels --threads $numthreads --cluster_fast $outputfile.temp.fasta --wordlength 15 --id 1 --query_cov 1 --qmask none --uc $outputfile.uc.txt")) {
		&errorMessage(__LINE__, "Cannot run VSEARCH correctly.");
	}
}

sub readVSEARCHResults {
	# read clustering results and store
	my @cluster;
	$filehandleinput1 = &readFile("$outputfile.uc.txt");
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		my @row = split(/\t/, $_);
		if ($row[0] eq 'S' || $row[0] eq 'H') {
			$cluster[$row[1]]{$row[8]} = $row[2];
		}
	}
	close($filehandleinput1);
	unlink("$outputfile.uc.txt");
	&outputResults(@cluster);
}

sub outputResults {
	my @cluster = @_;
	# connect to database
	my $taxdbhandle;
	unless ($taxdbhandle = DBI->connect("dbi:SQLite:dbname=$taxdb", '', '')) {
		&errorMessage(__LINE__, "Cannot connect database.");
	}
	# connect to database
	my $seqdbhandle;
	unless ($seqdbhandle = DBI->connect("dbi:SQLite:dbname=$outputfile.seqdb", '', '')) {
		&errorMessage(__LINE__, "Cannot connect database.");
	}
	# check taxid and split different taxid sequences to different clusters
	$filehandleoutput1 = &writeFile($outputfile);
	foreach my $cluster (@cluster) {
		my %subcluster;
		my $statement;
		unless ($statement = $taxdbhandle->prepare('SELECT acc, taxid FROM acc_taxid WHERE acc IN (' . join(', ', keys(%{$cluster})) . ')')) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		unless ($statement->execute) {
			&errorMessage(__LINE__, "Cannot execute SELECT.");
		}
		while (my @row = $statement->fetchrow_array) {
			push(@{$subcluster{$row[1]}}, $row[0]);
		}
		foreach my $taxid (keys(%subcluster)) {
			my $centroid;
			foreach my $acc (sort({$cluster->{$b} <=> $cluster->{$a}} @{$subcluster{$taxid}})) {
				$centroid = $acc;
				last;
			}
			my @seqname;
			my $sequence;
			unless ($statement = $seqdbhandle->prepare('SELECT acc, seqname, seq FROM seq WHERE acc IN (' . join(', ', @{$subcluster{$taxid}}) . ')')) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
			unless ($statement->execute) {
				&errorMessage(__LINE__, "Cannot execute SELECT.");
			}
			while (my @row = $statement->fetchrow_array) {
				push(@seqname, $row[1]);
				if (!$sequence && $row[0] eq $centroid) {
					$sequence = $row[2];
				}
			}
			print($filehandleoutput1 '>' . join("\x01", @seqname) . "\n$sequence\n");
		}
	}
	close($filehandleoutput1);
	# disconnect
	$seqdbhandle->disconnect;
	# disconnect
	$taxdbhandle->disconnect;
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
clshrinkblastdb options inputfile outputfile

Command line options
====================
--tdb, --taxdb=FILENAME
  Specify filename of taxonomy database. (default: none)

--minlen=INTEGER
  Specify minimum length threshold. (default: 100)

--maxlen=INTEGER
  Specify maximum length threshold. (default: 20000)

--dellongseq=ENABLE|DISABLE
  Specify delete longer sequences or preserve. (default: DISABLE)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
