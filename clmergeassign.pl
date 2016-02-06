use strict;

my $buildno = '0.2.2016.02.06';

print(STDERR <<"_END");
clmergeassign $buildno
=======================================================================

Official web site of this script is
http://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2015  Akifumi S. Tanabe

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

my $preferlower;
my $lowestsources;
my $allsources;
my @inputfiles;
my %priorities;
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'superclass', 'class', 'subclass', 'infraclass', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}
{
	my $priority;
	my %inputfiles;
	# get arguments
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:priority|p)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^ascend(?:ing)?$/i) {
				$priority = 'ascend';
			}
			elsif ($value =~ /^descend(?:ing)?$/i) {
				$priority = 'descend';
			}
			elsif ($value =~ /^equal$/i) {
				$priority = 'equal';
			}
			elsif ($value =~ /^[0-9<=]+$/ || $value =~ /^[0-9>=]+$/) {
				$priority = $value;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+preferlower(?:rank)?$/i) {
			$preferlower = 1;
		}
		elsif ($ARGV[$i] =~ /^-+lowestsources?$/i) {
			$lowestsources = 1;
		}
		elsif ($ARGV[$i] =~ /^-+allsources?$/i) {
			$allsources = 1;
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
	# make priorities
	if ($priority eq 'equal' || !$priority) {
		for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
			$priorities{$inputfiles[$i]} = 0;
		}
	}
	elsif ($priority eq 'ascend') {
		for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
			$priorities{$inputfiles[$i]} = $i;
		}
		@inputfiles = sort({$priorities{$b} <=> $priorities{$a}} keys(%priorities));
	}
	elsif ($priority eq 'descend') {
		for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
			$priorities{$inputfiles[$i]} = scalar(@inputfiles) - 1 - $i;
		}
		@inputfiles = sort({$priorities{$b} <=> $priorities{$a}} keys(%priorities));
	}
	else {
		my @temp = $priority =~ /\d+/g;
		if (scalar(@temp) == scalar(@inputfiles)) {
			my $temp1;
			my $temp2;
			if ($priority =~ /</) {
				$temp1 = 0;
				$temp2 = 1;
			}
			else {
				$temp1 = scalar(@inputfiles) - 1;
				$temp2 = -1;
			}
			while ($priority =~ s/^(\d+)([=<>])(\d+)/$3/) {
				my ($inputfile1, $relation) = ($1, $2);
				$priorities{$inputfiles[$inputfile1]} = $temp1;
				if ($relation =~ /^[<>]$/) {
					$temp1 += $temp2;
				}
			}
			if ($priority =~ /^\d+$/) {
				$priorities{$inputfiles[$priority]} = $temp1;
			}
			else {
				&errorMessage(__LINE__, "Cannot interpret priority.");
			}
		}
		else {
			&errorMessage(__LINE__, "Cannot interpret priority.");
		}
		@inputfiles = sort({$priorities{$b} <=> $priorities{$a}} keys(%priorities));
	}
}
if ($lowestsources && $allsources) {
	&errorMessage(__LINE__, "\"--allsources\" and \"--lowestsources\" are inconsistent.");
}

my %results;
my %sources;
my @queries;
{
	print(STDERR "Reading input files and merging entries...\n");
	my @inputhandle;
	# open all input files
	for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
		unless (open($inputhandle[$i], "< $inputfiles[$i]")) {
			&errorMessage(__LINE__, "Cannot open \"$inputfiles[$i]\".");
		}
	}
	my @labels;
	# read and store labels
	for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
		my $line = readline($inputhandle[$i]);
		$line =~ s/\r?\n?$//;
		my @label = split(/\t/, $line);
		shift(@label);
		$labels[$i] = \@label;
	}
	# merge each line
	while (!eof($inputhandle[0])) {
		# scan from high priority input file
		for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
			my $line = readline($inputhandle[$i]);
			if ($line) {
				$line =~ s/\r?\n?$//;
				my @entry = split(/\t/, $line);
				my $query = shift(@entry);
				if ($i == 0) {
					push(@queries, $query);
					print(STDERR "Merging \"$query\"...\n");
				}
				elsif ($query ne $queries[-1]) { # if query is not same
					&errorMessage(__LINE__, "Input files are not consistent.");
				}
				# if 'preferlower' option is specified
				if ($preferlower && $results{$query} && scalar(@entry) > scalar(@{$results{$query}})) {
					delete($results{$query});
				}
				# scan from higher rank
				for (my $j = 0; $j < scalar(@entry); $j ++) {
					my @existing;
					if ($results{$query}[$taxrank{$labels[$i][$j]}]) {
						@existing = keys(%{$results{$query}[$taxrank{$labels[$i][$j]}]});
					}
					# if the result does not exist
					if (!$existing[0] && $entry[$j] && (!$results{$query} || $taxrank{$labels[$i][$j]} + 1 > scalar(@{$results{$query}}))) {
						$results{$query}[$taxrank{$labels[$i][$j]}]{$entry[$j]} = $priorities{$inputfiles[$i]};
						if ($lowestsources || $allsources) {
							$sources{$query}[$taxrank{$labels[$i][$j]}]{$entry[$j]} = $i;
						}
					}
					# if the result exists, the entry differ from the result, and the priorities are equal
					elsif ($results{$query} && $taxrank{$labels[$i][$j]} < scalar(@{$results{$query}}) && $existing[0] ne $entry[$j] && $results{$query}[$taxrank{$labels[$i][$j]}]{$existing[0]} == $priorities{$inputfiles[$i]}) {
						splice(@{$results{$query}}, $taxrank{$labels[$i][$j]});
						if ($lowestsources || $allsources) {
							splice(@{$sources{$query}}, $taxrank{$labels[$i][$j]});
						}
						last;
					}
					# if the result exists, the entry differ from the result, and the priority is smaller
					elsif ($results{$query} && $taxrank{$labels[$i][$j]} < scalar(@{$results{$query}}) && $existing[0] ne $entry[$j] && $results{$query}[$taxrank{$labels[$i][$j]}]{$existing[0]} > $priorities{$inputfiles[$i]}) {
						last;
					}
				}
			}
			else {
				&errorMessage(__LINE__, "\"$inputhandle[$i]\" is invalid file.");
			}
		}
	}
	# close all input files
	for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
		close($inputhandle[$i]);
	}
	print(STDERR "done.\n\n");
}

# output
{
	print(STDERR "Saving results...");
	my $outputhandle;
	unless (open($outputhandle, "> $outputfile")) {
		&errorMessage(__LINE__, "Cannot make \"$outputfile\".");
	}
	my @temprank;
	for (my $i = 1; $i < scalar(@taxrank); $i ++) {
		foreach my $query (@queries) {
			my @temp = keys(%{$results{$query}[$taxrank{$taxrank[$i]}]});
			if ($temp[0]) {
				push(@temprank, $taxrank[$i]);
				last;
			}
		}
	}
	if ($lowestsources && @temprank) {
		print($outputhandle "query\t" . join("\t", @temprank) . "\tsource\n");
	}
	elsif (@temprank) {
		print($outputhandle "query\t" . join("\t", @temprank) . "\n");
	}
	else {
		print($outputhandle "query\n");
	}
	foreach my $query (@queries) {
		print($outputhandle "$query");
		foreach my $taxrank (@temprank) {
			my @temp1 = keys(%{$results{$query}[$taxrank{$taxrank}]});
			if ($allsources && $temp1[0]) {
				my @temp2 = keys(%{$sources{$query}[$taxrank{$taxrank}]});
				if ($temp2[0]) {
					print($outputhandle "\t$temp1[0] (" . $inputfiles[$sources{$query}[$taxrank{$taxrank}]{$temp2[0]}] . ")");
				}
				else {
					print($outputhandle "\t$temp1[0]");
				}
			}
			elsif ($temp1[0]) {
				print($outputhandle "\t$temp1[0]");
			}
			else {
				print($outputhandle "\t");
			}
		}
		if ($lowestsources) {
			my @temp2;
			if ($sources{$query}[-1]) {
				@temp2 = keys(%{$sources{$query}[-1]});
			}
			if ($temp2[0]) {
				print($outputhandle "\t" . $inputfiles[$sources{$query}[-1]{$temp2[0]}]);
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
clmergeassign options inputfile outputfile

Command line options
====================
-p, --priority=ASCEND|DESCEND|EQUAL|CUSTOM
  Specify priority of each file. (default: EQUAL)

--preferlower
  If this option is specified, lower-level identification will be prefered
regardless of the file priority. (default: off)

--lowestsources
  If this option is specified, source file information of lowest rank will
be added. (default: off)

--allsources
  If this option is specified, source file information of all cells will
be added. (default: off)

Custom priority format
======================
0 means first input file. 9 means 10th input file.
> means that left input file has higher priority than right input file.
< means that left input file has lower priority than right input file.
= means that left and right input files have equal priority.

Examples
0<1=2=3<4
4>1=2>3>0

Acceptable input file formats
=============================
results of classigntax
_END
	exit;
}
