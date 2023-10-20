use strict;
use DBI;
use LWP::UserAgent;

my $buildno = '0.9.x';

print(STDERR <<"_END");
clretrieveacc $buildno
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
my $excluderefseq = 1;
my %includetaxa;
my %includetaxarestriction;
my %excludetaxa;
my %excludetaxarestriction;
my %includetaxid;
my %excludetaxid;
my $acclist;
my $nacclist;
my $maxrank;
my $minrank;
my $additional;
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'subphylum', 'superclass', 'class', 'subclass', 'infraclass', 'cohort', 'subcohort', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'section', 'subsection', 'series', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma', 'forma specialis', 'strain', 'isolate');
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
	elsif ($ARGV[$i] =~ /^-+(?:acc|accession|seqid)list=(.+)$/i) {
		$acclist = $1;
	}
	elsif ($ARGV[$i] =~ /^-+n(?:egative)?(?:acc|accession|seqid)list=(.+)$/i) {
		$nacclist = $1;
	}
	elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:rank)?=(.+)$/i) {
		my $rank = $1;
		if ($rank =~ /^(?:superkingdom|kingdom|subkingdom|superphylum|phylum|subphylum|superclass|class|subclass|infraclass|cohort|subcohort|superorder|order|suborder|infraorder|parvorder|superfamily|family|subfamily|tribe|subtribe|genus|subgenus|section|subsection|series|species group|species subgroup|species|subspecies|varietas|forma|forma specialis|strain|isolate)$/) {
			$maxrank = $taxrank{$rank};
		}
		else {
			&errorMessage(__LINE__, "Invalid rank \"$rank\".");
		}
	}
	elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:rank)?=(.+)$/i) {
		my $rank = $1;
		if ($rank =~ /^(?:superkingdom|kingdom|subkingdom|superphylum|phylum|subphylum|superclass|class|subclass|infraclass|cohort|subcohort|superorder|order|suborder|infraorder|parvorder|superfamily|family|subfamily|tribe|subtribe|genus|subgenus|section|subsection|series|species group|species subgroup|species|subspecies|varietas|forma|forma specialis|strain|isolate)$/) {
			$minrank = $taxrank{$rank};
		}
		else {
			&errorMessage(__LINE__, "Invalid rank \"$rank\".");
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
	elsif ($ARGV[$i] =~ /^-+(?:additional|additionalfiltering|addfilter)=(.+)$/i) {
		my $value = $1;
		if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
			$additional = 1;
		}
		elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
			$additional = 0;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
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
if ($acclist && !-e $acclist) {
	&errorMessage(__LINE__, "\"$acclist\" does not exist.");
}
if ($nacclist && !-e $nacclist) {
	&errorMessage(__LINE__, "\"$nacclist\" does not exist.");
}
if ($maxrank && $minrank && $maxrank > $minrank) {
	&errorMessage(__LINE__, "Maxrank is lower rank than minrank.");
}
if (!$taxdb && (%includetaxa || %excludetaxa || %includetaxid || %excludetaxid || $acclist || $nacclist || $maxrank || $minrank || %includetaxarestriction || %excludetaxarestriction)) {
	&errorMessage(__LINE__, "Taxdb was not given.");
}

unless ($taxdb) {
	print(STDERR "Requesting accession list to NCBI...\n");
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
	$ua->agent('clretrieveacc/prerelease');
	$ua->env_proxy;
	my $baseurl = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=nucleotide&idtype=acc&term=' . &encodeURL($keyword);
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
	print(STDERR "Total number of matched sequences: $numhits\nNow downloading accession list...");
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
				if ($excluderefseq) {
					if (/<Id>([A-Za-z0-9]+)(?:\.\d+)?<\/Id>/i) {
						print($outputhandle "$1\n");
					}
				}
				else {
					if (/<Id>([A-Za-z0-9_]+)(?:\.\d+)?<\/Id>/i) {
						print($outputhandle "$1\n");
					}
				}
			}
			close($outputhandle);
		}
		else {
			sleep(30);
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
					if ($excluderefseq) {
						if (/<Id>([A-Za-z0-9]+)(?:\.\d+)?<\/Id>/i) {
							print($outputhandle "$1\n");
						}
					}
					else {
						if (/<Id>([A-Za-z0-9_]+)(?:\.\d+)?<\/Id>/i) {
							print($outputhandle "$1\n");
						}
					}
				}
				close($outputhandle);
			}
			else {
				&errorMessage(__LINE__, "Cannot search at NCBI.\nError status: " . $res->status_line . "\n");
			}
		}
		if ($i + 10000 >= $numhits) {
			print(STDERR "done.\n\n");
		}
		else {
			print(STDERR ($i + 10000) . '...');
			sleep(10);
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
	unless ($dbhandle = DBI->connect("dbi:SQLite:dbname=$taxdb", '', '', {RaiseError => 1, PrintError => 0, AutoCommit => 1, AutoInactiveDestroy => 1})) {
		&errorMessage(__LINE__, "Cannot connect database.");
	}
	my %taxon2taxid;
	my %taxid2taxon;
	{
		print(STDERR "Reading names table...");
		my $statement;
		unless ($statement = $dbhandle->prepare("SELECT taxid, name FROM names WHERE nameclass='scientific name'")) {
			&errorMessage(__LINE__, "Cannot prepare SQL statement.");
		}
		unless ($statement->execute) {
			&errorMessage(__LINE__, "Cannot execute SELECT.");
		}
		my $lineno = 1;
		while (my @row = $statement->fetchrow_array) {
			$row[1] = lc($row[1]);
			push(@{$taxon2taxid{$row[1]}}, $row[0]);
			push(@{$taxid2taxon{$row[0]}}, $row[1]);
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
	# search for taxids by includetaxa
	if (%includetaxa) {
		print(STDERR "Searching by includetaxa...");
		foreach my $taxon (keys(%taxon2taxid)) {
			foreach my $taxid (@{$taxon2taxid{$taxon}}) {
				foreach my $word (keys(%includetaxa)) {
					if ((!exists($includetaxarestriction{$word}) || $includetaxarestriction{$word} == $ranks{$taxid}) && $taxon =~ /$word/) {
						$includetaxid{$taxid} = 1;
					}
				}
			}
		}
		undef(%includetaxa);
		print(STDERR "done.\n\n");
	}
	# search for taxids by excludetaxa
	if (%excludetaxa) {
		print(STDERR "Searching by excludetaxa...");
		foreach my $taxon (keys(%taxon2taxid)) {
			foreach my $taxid (@{$taxon2taxid{$taxon}}) {
				foreach my $word (keys(%excludetaxa)) {
					if ((!exists($excludetaxarestriction{$word}) || $excludetaxarestriction{$word} == $ranks{$taxid}) && $taxon =~ /$word/) {
						$excludetaxid{$taxid} = 1;
					}
				}
			}
		}
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
	# search for taxids by acclist
	my %positiveaccs;
	if ($acclist) {
		print(STDERR "Reading positive accession list...");
		my $inputhandle;
		unless (open($inputhandle, "< $acclist")) {
			&errorMessage(__LINE__, "Cannot read \"$acclist\".");
		}
		while (<$inputhandle>) {
			if (/[A-Za-z0-9_]+/) {
				$positiveaccs{$&} = 1;
			}
		}
		close($inputhandle);
		print(STDERR "done.\n\n");
		if (!%includetaxid) {
			print(STDERR "Searching by accession list...");
			my $statement;
			unless ($statement = $dbhandle->prepare("SELECT taxid FROM acc_taxid WHERE acc IN ('" . join("', '", keys(%positiveaccs)) . "')")) {
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
	# search for taxids by keywords
	if (%keywords) {
		print(STDERR "Searching by keywords...");
		my %temptaxid;
		foreach my $keyword (keys(%keywords)) {
			foreach my $taxid (keys(%includetaxid)) {
				foreach my $taxon (@{$taxid2taxon{$taxid}}) {
					if ((!exists($keywordsrestriction{$keyword}) || $keywordsrestriction{$keyword} == $ranks{$taxid}) && $taxon =~ /$keyword/) {
						$temptaxid{$taxid} = 1;
					}
				}
			}
		}
		%includetaxid = %temptaxid;
		print(STDERR "done.\n\n");
	}
	# search for taxids by ngwords
	if (%ngwords) {
		print(STDERR "Searching by ngwords...");
		foreach my $ngword (keys(%ngwords)) {
			foreach my $taxid (keys(%includetaxid)) {
				foreach my $taxon (@{$taxid2taxon{$taxid}}) {
					if ((!exists($ngwordsrestriction{$ngword}) || $ngwordsrestriction{$ngword} == $ranks{$taxid}) && $taxon =~ /$ngword/) {
						delete($includetaxid{$taxid});
					}
				}
			}
		}
		print(STDERR "done.\n\n");
	}
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
	# additional filtering
	if ($additional) {
		print(STDERR "Applying additional filtering...");
		foreach my $taxid (keys(%includetaxid)) {
			if ($ranks{$taxid} == $taxrank{'species'}) {
				my $pass = 1;
				foreach my $taxon (@{$taxid2taxon{$taxid}}) {
					if ($taxon =~ / sp\./) {
						$pass = 0;
						last;
					}
				}
				if ($pass == 0) {
					foreach my $parentid (&getParents($taxid)) {
						if ($includetaxid{$parentid}) {
							$pass = 1;
							last;
						}
					}
					if ($pass == 0) {
						delete($includetaxid{$taxid});
					}
				}
			}
		}
		print(STDERR "done.\n\n");
	}
	undef(%taxid2taxon);
	undef(%daughters);
	undef(%parents);
	undef(%ranks);
	# store nacclist
	my %negativeaccs;
	if ($nacclist) {
		print(STDERR "Reading negative accession list...");
		my $inputhandle;
		unless (open($inputhandle, "< $nacclist")) {
			&errorMessage(__LINE__, "Cannot read \"$nacclist\".");
		}
		while (<$inputhandle>) {
			if (/[A-Za-z0-9_]+/) {
				$negativeaccs{$&} = 1;
			}
		}
		close($inputhandle);
		print(STDERR "done.\n\n");
	}
	# get accessions by taxids
	{
		print(STDERR "Saving accessions...");
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
		if (%positiveaccs && %negativeaccs) {
			unless ($statement = $dbhandle->prepare("SELECT DISTINCT acc FROM acc_taxid WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ") AND acc IN ('" . join("', '", keys(%positiveaccs)) . "') AND acc NOT IN ('" . join("', '", keys(%negativeaccs)) . "')")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
		}
		elsif (%positiveaccs) {
			unless ($statement = $dbhandle->prepare("SELECT DISTINCT acc FROM acc_taxid WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ") AND acc IN ('" . join("', '", keys(%positiveaccs)) . "')")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
		}
		elsif (%negativeaccs) {
			unless ($statement = $dbhandle->prepare("SELECT DISTINCT acc FROM acc_taxid WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ") AND acc NOT IN ('" . join("', '", keys(%negativeaccs)) . "')")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
		}
		else {
			unless ($statement = $dbhandle->prepare("SELECT DISTINCT acc FROM acc_taxid WHERE taxid IN (" . join(', ', keys(%includetaxid)) . ")")) {
				&errorMessage(__LINE__, "Cannot prepare SQL statement.");
			}
		}
		unless ($statement->execute) {
			&errorMessage(__LINE__, "Cannot execute SELECT.");
		}
		my $lineno = 1;
		while (my @row = $statement->fetchrow_array) {
			if (!$excluderefseq || $row[0] !~ /_/) {
				print($outputhandle "$row[0]\n");
			}
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
	sub getParents {
		my $daughterid = shift(@_);
		if ($parents{$daughterid}) {
			my @parents = &getParents($parents{$daughterid});
			if (@parents) {
				return($parents{$daughterid}, @parents);
			}
			else {
				return($parents{$daughterid});
			}
		}
		else {
			return();
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
clretrieveacc options outputfile

Command line options
====================
--tdb, --taxdb=FILENAME
  Specify filename of taxonomy database. If this is not specified, this
script retrieve accessions from NCBI. (default: none)

-k, --keyword=REGEXP(,REGEXP..)
  Specify regular expression(s) for scientific names. You can use regular
expression but you cannot use comma. All keywords will be used as AND
conditions. (default: none)

-n, --ngword=REGEXP(,REGEXP..)
  Specify regular expression(s) for scientific names. You can use regular
expression but you cannot use comma. All ngwords will be used as AND
conditions. (default: none)

--includetaxa=NAME(,NAME..)
  Specify include taxa by scientific name. (default: none)

--excludetaxa=NAME(,NAME..)
  Specify exclude taxa by scientific name. (default: none)

--includetaxid=ID(,ID..)
  Specify include taxa by NCBI taxonomy ID. (default: none)

--excludetaxid=ID(,ID..)
  Specify exclude taxa by NCBI taxonomy ID. (default: none)

--acclist=FILENAME
  Specify file name of accession list. (default: none)

--negativeacclist=FILENAME
  Specify file name of negative accession list. (default: none)

--maxrank=RANK
  Specify maximum taxonomic rank. (default: none)

--minrank=RANK
  Specify minimum taxonomic rank. (default: none)

--excluderefseq=ENABLE|DISABLE
  Specify whether RefSeq accession exclusion will be applied or not.
(default: ENABLE)

--additional=ENABLE|DISABLE
  Specify whether additional filtering will be applied or not.
(default: DISABLE)

--timeout=INTEGER
  Specify timeout limit for NCBI access by seconds. (default: 300)
_END
	exit;
}
