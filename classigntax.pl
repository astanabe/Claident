use strict;
use DBI;

my $buildno = '0.9.x';

print(STDERR <<"_END");
classigntax $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2023  Akifumi S. Tanabe

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

# get input file name
my $inputfile = $ARGV[-2];
# check input file
if (!-e $inputfile) {
	&errorMessage(__LINE__, "Input file does not exist.");
}

# get output file name
my $outputfile = $ARGV[-1];
# check output file
if (-e $outputfile) {
	&errorMessage(__LINE__, "Output file already exists.");
}

# get other arguments
my $taxdb;
my $minnsupporter;
my $maxpopposer;
my $maxpunident;
my $minsoratio;
my $outfmt = 'name';
my %treatasunidentlower;
my %treatasunidentlowerrestriction;
my %treatasunidentupper;
my %treatasunidentupperrestriction;
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'subphylum', 'superclass', 'class', 'subclass', 'infraclass', 'cohort', 'subcohort', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'section', 'subsection', 'series', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma', 'forma specialis', 'strain', 'isolate');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}
for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
	if ($ARGV[$i] =~ /^-+(?:taxdb|tdb)=(.+)$/i) {
		$taxdb = $1;
	}
	elsif ($ARGV[$i] =~ /^-+(?:outfmt|outformat)=(.+)$/i) {
		my $value = $1;
		if ($value =~ /^both$/i) {
			$outfmt = 'both';
		}
		elsif ($value =~ /^(?:taxonomy|taxonomic)?ids?$/i) {
			$outfmt = 'taxid';
		}
		elsif ($value =~ /^(?:taxonomy|taxonomic)?names?$/i) {
			$outfmt = 'name';
		}
		elsif ($value =~ /^full(?:taxonomy|taxonomic)?names?$/i) {
			$outfmt = 'fullname';
		}
		elsif ($value =~ /^supports?$/i) {
			$outfmt = 'support';
		}
		else {
			&errorMessage(__LINE__, "Invalid option.");
		}
	}
	elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?support(?:er)?=(\d+)$/i) {
		$minnsupporter = $1;
	}
	elsif ($ARGV[$i] =~ /^-+(?:max(?:imum)?(?:r|rate|p|percentage)opposer?|allowunsupport(?:ed)?)=(.+)$/i) {
		$maxpopposer = $1;
	}
	elsif ($ARGV[$i] =~ /^-+(?:max(?:imum)?(?:r|rate|p|percentage)unident(?:ified)?|allowunident(?:ified)?)=(.+)$/i) {
		$maxpunident = $1;
	}
	elsif ($ARGV[$i] =~ /^-+min(?:imum)?s(?:upporter|upport)?o(?:pposer|ppose)?ratio=(.+)$/i) {
		$minsoratio = $1;
	}
	elsif ($ARGV[$i] =~ /^-+min(?:imum)?s(?:upporter|upport)?u(?:nsupport)?ratio=(.+)$/i) {
		$minsoratio = $1;
	}
	elsif ($ARGV[$i] =~ /^-+treat(?:as)?unident(?:ified)?low(?:er)?=(.+)$/i) {
		my @words = split(/,/, $1);
		for (my $j = 0; $j < scalar(@words); $j ++) {
			if ($taxrank{$words[$j]} && $words[($j + 1)]) {
				$treatasunidentlowerrestriction{lc($words[($j + 1)])} = $taxrank{$words[$j]};
			}
			else {
				$treatasunidentlower{lc($words[$j])} = 1;
			}
		}
	}
	elsif ($ARGV[$i] =~ /^-+treat(?:as)?unident(?:ified)?up(?:per)?=(.+)$/i) {
		my @words = split(/,/, $1);
		for (my $j = 0; $j < scalar(@words); $j ++) {
			if ($taxrank{$words[$j]} && $words[($j + 1)]) {
				$treatasunidentupperrestriction{lc($words[($j + 1)])} = $taxrank{$words[$j]};
			}
			else {
				$treatasunidentupper{lc($words[$j])} = 1;
			}
		}
	}
	else {
		&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
	}
}

# check variables
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
if ($outfmt eq 'support' && (defined($minnsupporter) || defined($maxpopposer) || defined($maxpunident) || defined($minsoratio))) {
	&errorMessage(__LINE__, "The incompatible options for \"--outfmt=support\" was specified.");
}
unless (defined($minnsupporter)) {
	$minnsupporter = 2;
}
elsif ($minnsupporter < 1) {
	&errorMessage(__LINE__, "Minimum number of supporter sequences is too small.");
}
unless (defined($maxpopposer)) {
	$maxpopposer = 0;
}
elsif ($maxpopposer < 0 || $maxpopposer >= 1) {
	&errorMessage(__LINE__, "Allowed opposer sequence percentage is invalid.");
}
unless (defined($maxpunident)) {
	$maxpunident = 0;
}
elsif ($maxpunident < 0 || $maxpunident > 1) {
	&errorMessage(__LINE__, "Allowed unidentified percentage is invalid.");
}
unless (defined($minsoratio)) {
	$minsoratio = 10;
}
elsif ($minsoratio < 1) {
	&errorMessage(__LINE__, "Minimum supporter/opposer ratio is invalid.");
}

# read input file
my @queries;
my %acc2taxid;
my %query2acclist;
{
	my $inputhandle;
	unless (open($inputhandle, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
	}
	my $query;
	while (<$inputhandle>) {
		s/\r?\n?$//;
		s/;+size=\d+;*//g;
		s/;+base62=[A-Za-z0-9]+;*//g;
		if (/^>(.+)$/) {
			$query = $1;
			push(@queries, $query);
		}
		elsif ($query && /^([^>].*)$/) {
			my $acc = $1;
			if ($acc) {
				push(@{$query2acclist{$query}}, $acc);
				$acc2taxid{$acc} = 1;
			}
		}
		else {
			&errorMessage(__LINE__, "\"$inputfile\" is invalid.");
		}
	}
	close($inputhandle);
}

# search at taxdb
my $dbhandle;
unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$taxdb", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
	&errorMessage(__LINE__, "Cannot connect database.");
}
{
	print(STDERR "Getting accessions...");
	my $statement;
	unless ($statement = $dbhandle->prepare("SELECT acc, taxid FROM acc_taxid WHERE acc IN ('" . join("', '", keys(%acc2taxid)) . "')")) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	unless ($statement->execute) {
		&errorMessage(__LINE__, "Cannot execute SELECT.");
	}
	my $lineno = 1;
	while (my @row = $statement->fetchrow_array) {
		$acc2taxid{$row[0]} = $row[1];
		if ($lineno % 10000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	print(STDERR "done.\n\n");
}
my %parents;
my %ranks;
{
	print(STDERR "Reading nodes table...");
	my $statement;
	unless ($statement = $dbhandle->prepare('SELECT taxid, parent, rank FROM nodes')) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	unless ($statement->execute) {
		&errorMessage(__LINE__, "Cannot execute SELECT.");
	}
	my $lineno = 1;
	while (my @row = $statement->fetchrow_array) {
		$parents{$row[0]} = $row[1];
		if ($taxrank{$row[2]}) {
			$ranks{$row[0]} = $taxrank{$row[2]};
		}
		if ($lineno % 10000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	print(STDERR "done.\n\n");
}
my %taxid2taxon;
if ($outfmt eq 'both' || $outfmt eq 'name' || $outfmt eq 'support' || %treatasunidentlower || %treatasunidentupper) {
	print(STDERR "Reading names table...");
	my $statement;
	unless ($statement = $dbhandle->prepare('SELECT taxid, name, nameclass FROM names')) {
		&errorMessage(__LINE__, "Cannot prepare SQL statement.");
	}
	unless ($statement->execute) {
		&errorMessage(__LINE__, "Cannot execute SELECT.");
	}
	my $lineno = 1;
	while (my @row = $statement->fetchrow_array) {
		if (!$taxid2taxon{$row[0]} && $row[2] =~ /scientific name/i) {
			$taxid2taxon{$row[0]} = $row[1];
		}
		if ($lineno % 10000 == 0) {
			print(STDERR '.');
		}
		$lineno ++;
	}
	print(STDERR "done.\n\n");
}
$dbhandle->disconnect;

# search higher taxa
{
	print(STDERR "Getting higher taxids...");
	foreach my $acc (keys(%acc2taxid)) {
		if ($acc2taxid{$acc} == 1) {
			&errorMessage(__LINE__, "Taxdb does not have \"Accession:$acc\" entry.");
		}
		else {
			my $taxid = $acc2taxid{$acc};
			delete($acc2taxid{$acc});
			if ($ranks{$taxid}) {
				$acc2taxid{$acc}{$ranks{$taxid}} = $taxid;
			}
			&getParents($acc, $taxid);
		}
	}
	print(STDERR "done.\n\n");
}

# BLAST result to taxonomy
my %results;
my %supports;
{
	print(STDERR "Identifying by using BLAST results...\n");
	for (my $i = 0; $i < scalar(@queries); $i ++) {
		print(STDERR "Identifying \"$queries[$i]\"...\n");
		if ($query2acclist{$queries[$i]}) {
			my $nneighborhoods = scalar(@{$query2acclist{$queries[$i]}});
			my $result;
			# search lower rank to upper rank
			for (my $j = -1; $j > scalar(@taxrank) * (-1); $j --) {
				my %taxcomp;
				my $nident = 0;
				my @temp;
				# check equal or lower rank
				foreach my $acc (@{$query2acclist{$queries[$i]}}) {
					my $temp1;
					for (my $k = $j; $k <= -1; $k ++) {
						if (exists($acc2taxid{$acc}{$taxrank{$taxrank[$k]}})) {
							my $temp2;
							foreach my $keyword (keys(%treatasunidentlower)) {
								if ((!exists($treatasunidentlowerrestriction{$keyword}) || $treatasunidentlowerrestriction{$keyword} == $taxrank{$taxrank[$k]}) && $taxid2taxon{$acc2taxid{$acc}{$taxrank{$taxrank[$k]}}} =~ /$keyword/) {
									$temp2 = 1;
									last;
								}
							}
							unless ($temp2) {
								$taxcomp{$acc2taxid{$acc}{$taxrank{$taxrank[$k]}}} ++;
								$nident ++;
								$temp1 = 1;
								last;
							}
						}
					}
					unless ($temp1) {
						push(@temp, $acc);
					}
				}
				# get best supported taxid
				foreach my $taxid (sort({$taxcomp{$b} <=> $taxcomp{$a}} keys(%taxcomp))) {
					# check upper rank
					if ($parents{$taxid}) {
						my $parent = $parents{$taxid};
						while (!$ranks{$parent}) {
							if ($parents{$parent}) {
								$parent = $parents{$parent};
							}
							else {
								last;
							}
						}
						if ($parent && $ranks{$parent}) {
							foreach my $acc (@temp) {
								for (my $k = $j - 1; $k > scalar(@taxrank) * (-1); $k --) {
									if (exists($acc2taxid{$acc}{$taxrank{$taxrank[$k]}})) {
										my $temp;
										foreach my $keyword (keys(%treatasunidentupper)) {
											if ((!exists($treatasunidentupperrestriction{$keyword}) || $treatasunidentupperrestriction{$keyword} == $taxrank{$taxrank[$k]}) && $taxid2taxon{$acc2taxid{$acc}{$taxrank{$taxrank[$k]}}} =~ /$keyword/) {
												$temp = 1;
												last;
											}
										}
										unless ($temp) {
											my $tempparent = $parent;
											while ($taxrank{$taxrank[$k]} < $ranks{$tempparent}) {
												if ($parents{$tempparent}) {
													$tempparent = $parents{$tempparent};
												}
												else {
													last;
												}
											}
											if ($tempparent && $ranks{$tempparent} && $acc2taxid{$acc}{$taxrank{$taxrank[$k]}} != $tempparent) {
												$nident ++;
											}
											last;
										}
									}
								}
							}
						}
					}
					# store results
					if ($outfmt eq 'support') {
						$results{$queries[$i]}{$taxrank{$taxrank[$j]}} = $taxid;
						$supports{$queries[$i]}{$taxrank{$taxrank[$j]}} = $taxcomp{$taxid} . ':' . ($nident - $taxcomp{$taxid}) . ':' . ($nneighborhoods - $nident) . '/' . $nneighborhoods;
					}
					elsif (($nident - $taxcomp{$taxid}) / $nneighborhoods <= $maxpopposer && 1 - ($nident / $nneighborhoods) <= $maxpunident && $taxcomp{$taxid} >= $minnsupporter) {
						if ($nident - $taxcomp{$taxid} == 0 || $nident - $taxcomp{$taxid} > 0 && $taxcomp{$taxid} / ($nident - $taxcomp{$taxid}) >= $minsoratio) {
							$results{$queries[$i]}{$taxrank{$taxrank[$j]}} = $taxid;
							$result = $taxid;
						}
					}
					last;
				}
				if ($outfmt ne 'support' && $results{$queries[$i]}{$taxrank{$taxrank[$j]}}) {
					last;
				}
			}
			# trace upperward
			if ($outfmt ne 'support') {
				&getParents2($queries[$i], $result);
			}
		}
	}
	print(STDERR "done.\n\n");
}

# save results to output file
{
	print(STDERR "Saving identification results...");
	my $outputhandle;
	unless (open($outputhandle, "> $outputfile")) {
		&errorMessage(__LINE__, "Cannot make \"$outputfile\".");
	}
	my @temprank;
	for (my $i = 1; $i < scalar(@taxrank); $i ++) {
		foreach my $query (@queries) {
			if ($results{$query}{$taxrank{$taxrank[$i]}}) {
				push(@temprank, $taxrank[$i]);
				last;
			}
		}
	}
	if (@temprank) {
		print($outputhandle "query\t" . join("\t", @temprank) . "\n");
	}
	else {
		print($outputhandle "query\n");
	}
	foreach my $query (@queries) {
		print($outputhandle "$query");
		foreach my $taxrank (@temprank) {
			if ($results{$query}{$taxrank{$taxrank}}) {
				if ($outfmt eq 'both') {
					print($outputhandle "\t$taxid2taxon{$results{$query}{$taxrank{$taxrank}}} ($results{$query}{$taxrank{$taxrank}})");
				}
				elsif ($outfmt eq 'taxid') {
					print($outputhandle "\t$results{$query}{$taxrank{$taxrank}}");
				}
				elsif ($outfmt eq 'name') {
					print($outputhandle "\t$taxid2taxon{$results{$query}{$taxrank{$taxrank}}}");
				}
				elsif ($outfmt eq 'support') {
					print($outputhandle "\t$taxid2taxon{$results{$query}{$taxrank{$taxrank}}}: $supports{$query}{$taxrank{$taxrank}}");
				}
			}
			else {
				print($outputhandle "\t");
			}
		}
		print($outputhandle "\n");
	}
	close($outputhandle);
	print(STDERR "done.\n\n");
}

# get parents
sub getParents {
	my $acc = shift(@_);
	my $daughterid = shift(@_);
	if ($parents{$daughterid}) {
		if ($ranks{$parents{$daughterid}}) {
			$acc2taxid{$acc}{$ranks{$parents{$daughterid}}} = $parents{$daughterid};
		}
		&getParents($acc, $parents{$daughterid});
	}
}

sub getParents2 {
	my $query = shift(@_);
	my $daughterid = shift(@_);
	if ($parents{$daughterid}) {
		if ($ranks{$parents{$daughterid}}) {
			$results{$query}{$ranks{$parents{$daughterid}}} = $parents{$daughterid};
		}
		&getParents2($query, $parents{$daughterid});
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
classigntax options inputfile outputfile

Command line options
====================
--tdb, --taxdb=FILENAME
  Specify filename of taxonomy database. (default: none)

--outfmt, --outformat=ID|NAME|BOTH|SUPPORT
  Specify output format. (default: NAME)

--minnsupporter=INTEGER
  Specify minimum number of supporter sequences. (default: 2)

--maxpopposer=DECIMAL
  Specify maximum acceptable percentage of opposer sequences.
(default: 0)

--maxpunident=INTEGER
  Specify maximum acceptable percentage of unidentified sequences.
(default: 0)

--minsoratio=INTEGER|DECIMAL
  Specify minimum ratio of the number of supporter sequences to the
number of opposer sequences. (default: 10)

--treatasunidentlower=REGEXP(,REGEXP..)
  Specify regular expression(s) for taxonomic names. You can use regular
expression but you cannot use comma. All keywords will be used as OR
conditions. (default: none)

--treatasunidentupper=REGEXP(,REGEXP..)
  Specify regular expression(s) for taxonomic names. You can use regular
expression but you cannot use comma. All keywords will be used as OR
conditions. (default: none)

Acceptable input file formats
=============================
BLAST result of clidentseq
_END
	exit;
}
