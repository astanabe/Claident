use strict;
use DBI;
use LWP::UserAgent;

my $buildno = '0.2.x';

print(STDERR <<"_END");
clretrievegi $buildno
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

# get output file name
my $outputfile = $ARGV[-1];
# check output file
if ($outputfile !~ /^stdout$/i && -e $outputfile) {
	&errorMessage(__LINE__, "Output file already exists.");
}

# get other arguments
my $timeout = 300;
my $taxdb;
my @keywords;
my %keywords;
my %keywordsrestriction;
my @ngwords;
my %ngwords;
my %ngwordsrestriction;
my %includetaxa;
my %includetaxarestriction;
my %excludetaxa;
my %excludetaxarestriction;
my %includetaxid;
my %excludetaxid;
my $gilist;
my $ngilist;
my $maxrank;
my $minrank;
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'superclass', 'class', 'subclass', 'infraclass', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}
for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
	if ($ARGV[$i] =~ /^-+(?:timeout|t)=(\d+)$/i) {
		$timeout = $1;
	}
	elsif ($ARGV[$i] =~ /^-+(?:taxdb|tdb)=(.+)$/i) {
		$taxdb = $1;
	}
	elsif ($ARGV[$i] =~ /^-+(?:keyword|keywords|k)=(.+)$/i) {
		@keywords = split(/,/, $1);
	}
	elsif ($ARGV[$i] =~ /^-+(?:ngword|ngwords|n)=(.+)$/i) {
		@ngwords = split(/,/, $1);
	}
	elsif ($ARGV[$i] =~ /^-+in(?:clude)?tax(?:on|a)?=(.+)$/i) {
		my @words = split(/,/, $1);
		for (my $j = 0; $j < scalar(@words); $j ++) {
			if ($taxrank{$words[$j]} && $words[($j + 1)]) {
				$includetaxarestriction{lc($words[($j + 1)])} = $taxrank{$words[$j]};
			}
			else {
				$includetaxa{lc($words[$j])} = 1;
			}
		}
	}
	elsif ($ARGV[$i] =~ /^-+ex(?:clude)?tax(?:on|a)?=(.+)$/i) {
		my @words = split(/,/, $1);
		for (my $j = 0; $j < scalar(@words); $j ++) {
			if ($taxrank{$words[$j]} && $words[($j + 1)]) {
				$excludetaxarestriction{lc($words[($j + 1)])} = $taxrank{$words[$j]};
			}
			else {
				$excludetaxa{lc($words[$j])} = 1;
			}
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
	elsif ($ARGV[$i] =~ /^-+n(?:egative)?gilist=(.+)$/i) {
		$ngilist = $1;
	}
	elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:rank)?=(.+)$/i) {
		my $rank = $1;
		if ($rank =~ /^(?:superkingdom|kingdom|subkingdom|superphylum|phylum|superclass|class|subclass|infraclass|superorder|order|suborder|infraorder|parvorder|superfamily|family|subfamily|tribe|subtribe|genus|subgenus|species group|species subgroup|species|subspecies|varietas|forma)$/) {
			$maxrank = $taxrank{$rank};
		}
		else {
			&errorMessage(__LINE__, "Invalid rank \"$rank\".");
		}
	}
	elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:rank)?=(.+)$/i) {
		my $rank = $1;
		if ($rank =~ /^(?:superkingdom|kingdom|subkingdom|superphylum|phylum|superclass|class|subclass|infraclass|superorder|order|suborder|infraorder|parvorder|superfamily|family|subfamily|tribe|subtribe|genus|subgenus|species group|species subgroup|species|subspecies|varietas|forma)$/) {
			$minrank = $taxrank{$rank};
		}
		else {
			&errorMessage(__LINE__, "Invalid rank \"$rank\".");
		}
	}
	else {
		&errorMessage(__LINE__, "Invalid option.");
	}
}

# check variables
if ($taxdb && !-e $taxdb) {
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
if ($gilist && !-e $gilist) {
	&errorMessage(__LINE__, "\"$gilist\" does not exist.");
}
if ($ngilist && !-e $ngilist) {
	&errorMessage(__LINE__, "\"$ngilist\" does not exist.");
}
if ($maxrank && $minrank && $maxrank > $minrank) {
	&errorMessage(__LINE__, "Maxrank is lower rank than minrank.");
}
if (!$taxdb && (%includetaxa || %excludetaxa || %includetaxid || %excludetaxid || $gilist || $ngilist || $maxrank || $minrank || %includetaxarestriction || %excludetaxarestriction)) {
	&errorMessage(__LINE__, "Taxdb was not given.");
}

unless ($taxdb) {
	print(STDERR "Requesting GI list to NCBI...\n");
	my $keyword;
	{
		$keyword = join(' AND ', @keywords);
		if ($keyword && @ngwords) {
			$keyword .= ' NOT ' . join(' NOT ', @ngwords);
		}
		elsif (@ngwords) {
			$keyword .= 'NOT ' . join(' NOT ', @ngwords);
		}
	}
	my $numhits;
	my $ua = LWP::UserAgent->new;
	$ua->timeout($timeout);
	$ua->agent('clretrievegi/prerelease');
	$ua->env_proxy;
	my $baseurl = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=nuccore&term=' . &encodeURL($keyword);
	print(STDERR "Requesting $baseurl...\n");
	my $req = HTTP::Request->new(POST => $baseurl . '&rettype=count');
	my $res = $ua->request($req);
	if ($res->is_success) {
		foreach (split(/\n/,$res->content)) {
			#print(STDERR "$_\n");
			if (/<Count>(\d+)<\/Count>/i) {
				$numhits = $1;
				last;
			}
		}
	}
	else {
		&errorMessage(__LINE__, "Cannot search at NCBI.\nError status: " . $res->status_line . "\n");
	}
	print(STDERR "Total number of matched sequences: $numhits\nNow downloading GI list...");
	for (my $i = 0; $i < $numhits; $i += 10000) {
		$req = HTTP::Request->new(POST => $baseurl . '&retstart=' . $i . '&retmax=10000');
		$res = $ua->request($req);
		if ($res->is_success) {
			my $outputhandle;
			if ($outputfile =~ /^stdout$/i) {
				unless (open($outputhandle, '>-')) {
					&errorMessage(__LINE__, "Cannot write STDOUT.");
				}
			}
			else {
				unless (open($outputhandle, ">> $outputfile")) {
					&errorMessage(__LINE__, "Cannot write \"$outputfile\".");
				}
			}
			foreach (split(/\n/,$res->content)) {
				#print(STDERR "$_\n");
				if (/<Id>(\d+)<\/Id>/i) {
					print($outputhandle "$1\n");
				}
			}
			close($outputhandle);
		}
		else {
			&errorMessage(__LINE__, "Cannot search at NCBI.\nError status: " . $res->status_line . "\n");
		}
		if ($i + 10000 >= $numhits) {
			print(STDERR "done.\n\n");
		}
		else {
			print(STDERR ($i + 10000) . '...');
		}
	}
	sub encodeURL {
		my $str = shift;
		$str =~ s/([^\w ])/'%'.unpack('H2', $1)/eg;
		$str =~ tr/ /+/;
		return $str;
	}
}
else {
	# parse keywords and ngwords
	for (my $j = 0; $j < scalar(@keywords); $j ++) {
		if ($taxrank{$keywords[$j]} && $keywords[($j + 1)]) {
			$keywordsrestriction{lc($keywords[($j + 1)])} = $taxrank{$keywords[$j]};
		}
		else {
			$keywords{lc($keywords[$j])} = 1;
		}
	}
	for (my $j = 0; $j < scalar(@ngwords); $j ++) {
		if ($taxrank{$ngwords[$j]} && $ngwords[($j + 1)]) {
			$ngwordsrestriction{lc($ngwords[($j + 1)])} = $taxrank{$ngwords[$j]};
		}
		else {
			$ngwords{lc($ngwords[$j])} = 1;
		}
	}
	# connect to database
	my $dbhandle;
	unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$taxdb", '', '')) {
		&errorMessage(__LINE__, "Cannot connect database.");
	}
	my %taxon2taxid;
	my %taxid2taxon;
	{
		print(STDERR "Reading names table...");
		my $statement;
		unless ($statement = $dbhandle->prepare('SELECT taxid, name FROM names')) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		unless ($statement->execute) {
			&errorMessage(__LINE__, "Cannot execute SELECT.");
		}
		my $lineno = 1;
		while (my @row = $statement->fetchrow_array) {
			push(@{$taxon2taxid{lc($row[1])}}, $row[0]);
			if (%keywords || %ngwords) {
				if ($taxid2taxon{$row[0]}) {
					$taxid2taxon{$row[0]} .= ', ' . lc($row[1]);
				}
				else {
					$taxid2taxon{$row[0]} = lc($row[1]);
				}
			}
			if ($lineno % 10000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
		print(STDERR "done.\n\n");
	}
	my %daughters;
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
			push(@{$daughters{$row[1]}}, $row[0]);
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
	# search for taxids by includetaxa/excludetaxa
	if (%includetaxa || %excludetaxa) {
		print(STDERR "Searching by includetaxa/excludetaxa...");
		foreach my $taxon (keys(%taxon2taxid)) {
			foreach my $taxid (@{$taxon2taxid{$taxon}}) {
				foreach my $word (keys(%includetaxa)) {
					if ((!exists($includetaxarestriction{$word}) || $includetaxarestriction{$word} == $ranks{$taxid}) && $taxon =~ /$word/) {
						$includetaxid{$taxid} = 1;
					}
				}
				foreach my $word (keys(%excludetaxa)) {
					if ((!exists($excludetaxarestriction{$word}) || $excludetaxarestriction{$word} == $ranks{$taxid}) && $taxon =~ /$word/) {
						$excludetaxid{$taxid} = 1;
					}
				}
			}
		}
		undef(%includetaxa);
		undef(%excludetaxa);
		print(STDERR "done.\n\n");
	}
	# search for taxids by includetaxid
	print(STDERR "Searching by includetaxid...");
	if (%includetaxid) {
		foreach my $parentid (keys(%includetaxid)) {
			&getDaughters($parentid);
		}
	}
	else {
		foreach my $name (keys(%taxon2taxid)) {
			foreach my $taxid (@{$taxon2taxid{$name}}) {
				$includetaxid{$taxid} = 1;
			}
		}
	}
	undef(%taxon2taxid);
	print(STDERR "done.\n\n");
	# search for taxids by gilist
	my %positivegis;
	if ($gilist) {
		my $inputhandle;
		unless (open($inputhandle, "< $gilist")) {
			&errorMessage(__LINE__, "Cannot read \"$gilist\".");
		}
		while (<$inputhandle>) {
			if (/^\d+/) {
				$positivegis{$&} = 1;
			}
		}
		close($inputhandle);
		if (!%includetaxid) {
			print(STDERR "Searching by gilist...");
			my $statement;
			unless ($statement = $dbhandle->prepare("SELECT taxid FROM gi_taxid_nucl WHERE gi IN (" . join(', ', keys(%positivegis)) . ")")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
			unless ($statement->execute) {
				&errorMessage(__LINE__, "Cannot execute SELECT.");
			}
			my $lineno = 1;
			while (my @row = $statement->fetchrow_array) {
				$includetaxid{$row[0]} = 1;
				if ($lineno % 10000 == 0) {
					print(STDERR '.');
				}
				$lineno ++;
			}
			print(STDERR "done.\n\n");
		}
	}
	# store ngilist
	my %negativegis;
	if ($ngilist) {
		my $inputhandle;
		unless (open($inputhandle, "< $ngilist")) {
			&errorMessage(__LINE__, "Cannot read \"$ngilist\".");
		}
		while (<$inputhandle>) {
			if (/^\d+/) {
				$negativegis{$&} = 1;
			}
		}
		close($inputhandle);
	}
	# search for taxids by keywords/ngwords
	if (%keywords || %ngwords) {
		print(STDERR "Searching by keywords/ngwords...");
		foreach my $taxid (keys(%includetaxid)) {
			foreach my $keyword (keys(%keywords)) {
				if ((!exists($keywordsrestriction{$keyword}) || $keywordsrestriction{$keyword} == $ranks{$taxid}) && $taxid2taxon{$taxid} !~ /$keyword/) {
					delete($includetaxid{$taxid});
				}
			}
			foreach my $ngword (keys(%ngwords)) {
				if ((!exists($ngwordsrestriction{$ngword}) || $ngwordsrestriction{$ngword} == $ranks{$taxid}) && $taxid2taxon{$taxid} =~ /$ngword/) {
					delete($includetaxid{$taxid});
				}
			}
		}
		print(STDERR "done.\n\n");
	}
	undef(%taxid2taxon);
	# delete taxids by excludetaxid
	if (%excludetaxid) {
		print(STDERR "Deleting by excludetaxid...");
		foreach my $parentid (keys(%excludetaxid)) {
			delete($includetaxid{$parentid});
			&deleteDaughters($parentid);
		}
		print(STDERR "done.\n\n");
	}
	# delete taxids above maxrank
	if ($maxrank) {
		print(STDERR "Deleting by maxrank...");
		foreach my $taxid (keys(%includetaxid)) {
			if (exists($includetaxid{$taxid}) && $ranks{$taxid} > 0 && $ranks{$taxid} < $maxrank) {
				delete($includetaxid{$taxid});
				&deleteParents($taxid);
			}
			elsif (exists($includetaxid{$taxid}) && $ranks{$taxid} > 0 && $ranks{$taxid} == $maxrank) {
				&deleteParents($taxid);
			}
		}
		print(STDERR "done.\n\n");
	}
	# delete taxids below minrank
	if ($minrank) {
		print(STDERR "Deleting by minrank...");
		foreach my $taxid (keys(%includetaxid)) {
			if (exists($includetaxid{$taxid}) && $ranks{$taxid} > 0 && $ranks{$taxid} > $minrank) {
				delete($includetaxid{$taxid});
				&deleteDaughters($taxid);
			}
			elsif (exists($includetaxid{$taxid}) && $ranks{$taxid} > 0 && $ranks{$taxid} == $minrank) {
				&deleteDaughters($taxid);
			}
		}
		print(STDERR "done.\n\n");
	}
	undef(%daughters);
	undef(%parents);
	undef(%ranks);
	# get GIs by taxids
	{
		print(STDERR "Saving GIs...");
		my $outputhandle;
		if ($outputfile =~ /^stdout$/i) {
			unless (open($outputhandle, '>-')) {
				&errorMessage(__LINE__, "Cannot write STDOUT.");
			}
		}
		else {
			unless (open($outputhandle, ">> $outputfile")) {
				&errorMessage(__LINE__, "Cannot write \"$outputfile\".");
			}
		}
		my $statement;
		if (%positivegis && %negativegis) {
			unless ($statement = $dbhandle->prepare("SELECT DISTINCT gi FROM gi_taxid_nucl WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ") AND gi IN (" . join(', ', keys(%positivegis)) . ") AND gi NOT IN (" . join(', ', keys(%negativegis)) . ")")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
		}
		elsif (%positivegis) {
			unless ($statement = $dbhandle->prepare("SELECT DISTINCT gi FROM gi_taxid_nucl WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ") AND gi IN (" . join(', ', keys(%positivegis)) . ")")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
		}
		elsif (%negativegis) {
			unless ($statement = $dbhandle->prepare("SELECT DISTINCT gi FROM gi_taxid_nucl WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ") AND gi NOT IN (" . join(', ', keys(%negativegis)) . ")")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
		}
		else {
			unless ($statement = $dbhandle->prepare("SELECT DISTINCT gi FROM gi_taxid_nucl WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ")")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
		}
		unless ($statement->execute) {
			&errorMessage(__LINE__, "Cannot execute SELECT.");
		}
		my $lineno = 1;
		while (my @row = $statement->fetchrow_array) {
			print($outputhandle "$row[0]\n");
			if ($lineno % 100000 == 0) {
				print(STDERR '.');
			}
			$lineno ++;
		}
		close($outputhandle);
		print(STDERR "done.\n\n");
	}
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
	sub deleteParents {
		my $daughterid = shift(@_);
		if ($parents{$daughterid}) {
			delete($includetaxid{$parents{$daughterid}});
			&deleteParents($parents{$daughterid});
		}
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
clretrievegi options outputfile

Command line options
====================
--tdb, --taxdb=FILENAME
  Specify filename of taxonomy database. If this is not specified, this
script retrieve GIs from NCBI. (default: none)

-k, --keyword=REGEXP(,REGEXP..)
  Specify regular expression(s) for sequence names. You can use regular
expression but you cannot use comma. All keywords will be used as AND
conditions. (default: none)

-n, --ngword=REGEXP(,REGEXP..)
  Specify regular expression(s) for sequence names. You can use regular
expression but you cannot use comma. All ngwords will be used as AND
conditions. (default: none)

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

--negativegilist=FILENAME
  Specify file name of negative GI list. (default: none)

--maxrank=RANK
  Specify maximum taxonomic rank. (default: none)

--minrank=RANK
  Specify minimum taxonomic rank. (default: none)

--timeout=INTEGER
  Specify timeout limit for NCBI access by seconds. (default: 300)
_END
	exit;
}
