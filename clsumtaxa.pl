use strict;
use File::Spec;

my $buildno = '0.9.x';

# options
my $targetrank;
my $numbering;
my $topN;
my $tableformat;
my $sortkey = 'abundance';
my $runname;

# input/output
my $inputfile;
my $outputfile;
my $taxfile;

# other variables
my $devnull = File::Spec->devnull();
my %table;
my @otunames;
my @samplenames;
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'subphylum', 'superclass', 'class', 'subclass', 'infraclass', 'cohort', 'subcohort', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'section', 'subsection', 'series', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma', 'forma specialis', 'strain', 'isolate');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}
my %taxonomy;

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
	# read taxonomy file
	&readTaxonomyFile();
	# read input file
	&readSummary();
	# process summary table
	&processSummary();
	# make output file
	&saveSummary();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clsumtaxa $buildno
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
	$inputfile = $ARGV[-2];
	$outputfile = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:target)?(?:tax|taxonomy)?(?:unit|rank|level)=(.+)$/i) {
			my $taxrank = $1;
			if ($taxrank{$taxrank}) {
				$targetrank = $taxrank{$taxrank};
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+sortkey=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^abundance$/i) {
				$sortkey = 'abundance';
			}
			elsif ($value =~ s/ ?name$//i && $taxrank{$value}) {
				$sortkey = $taxrank{$value};
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:o|output|tableformat)=(.+)$/i) {
			if ($1 =~ /^matrix$/i) {
				$tableformat = 'matrix';
			}
			elsif ($1 =~ /^column$/i) {
				$tableformat = 'column';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+numbering=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$numbering = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$numbering = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+topN=(\d+)$/i) {
			$topN = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:tax|taxonomy)file=(.+)$/i) {
			$taxfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$runname = $1;
		}
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	unless (-e $inputfile) {
		&errorMessage(__LINE__, "\"$inputfile\" does not exist.");
	}
	if (-e $outputfile) {
		&errorMessage(__LINE__, "Output file already exists.");
	}
	if (!$taxfile) {
		&errorMessage(__LINE__, "Taxonomy file is not given.");
	}
	if (!-e $taxfile) {
		&errorMessage(__LINE__, "\"$taxfile\" does not exist.");
	}
	if (!$targetrank) {
		$targetrank = $taxrank{'species'};
	}
}

sub readTaxonomyFile {
	my @rank;
	unless (open($filehandleinput1, "< $taxfile")) {
		&errorMessage(__LINE__, "Cannot read \"$taxfile\".");
	}
	{
		my $lineno = 1;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if ($lineno == 1 && /\t/) {
				@rank = split(/\t/, lc($_));
				shift(@rank);
				foreach my $rank (@rank) {
					if (!exists($taxrank{$rank})) {
						&errorMessage(__LINE__, "\"$rank\" is invalid taxonomic rank.");
					}
				}
			}
			elsif (/\t/) {
				my @entry = split(/\t/, $_, -1);
				my $otuname = shift(@entry);
				if (scalar(@entry) == scalar(@rank)) {
					for (my $i = 0; $i < scalar(@entry); $i ++) {
						$taxonomy{$otuname}{$taxrank{$rank[$i]}} = $entry[$i];
					}
				}
				else {
					&errorMessage(__LINE__, "Input taxonomy file is invalid.");
				}
			}
			else {
				&errorMessage(__LINE__, "Input taxonomy file is invalid.");
			}
			$lineno ++;
		}
	}
	close($filehandleinput1);
}

sub readSummary {
	my $ncol;
	my $format;
	# read input file
	$filehandleinput1 = &readFile($inputfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		if ($format eq 'column') {
			my @row = split(/\t/);
			if (scalar(@row) == 3) {
				if ($runname) {
					$row[0] =~ s/^.+?(__)/$runname$1/;
				}
				$table{$row[0]}{$row[1]} += $row[2];
			}
			else {
				&errorMessage(__LINE__, "The input file is invalid.\nThe invalid line is \"$_\".");
			}
		}
		elsif ($format eq 'matrix') {
			my @row = split(/\t/);
			if (scalar(@row) == $ncol + 1) {
				my $samplename = shift(@row);
				if ($runname) {
					$samplename =~ s/^.+?(__)/$runname$1/;
				}
				push(@samplenames, $samplename);
				for (my $i = 0; $i < scalar(@row); $i ++) {
					$table{$samplename}{$otunames[$i]} += $row[$i];
				}
			}
			else {
				&errorMessage(__LINE__, "The input file is invalid.\nThe invalid line is \"$_\".");
			}
		}
		elsif (/^samplename\totuname\tnreads/i) {
			$format = 'column';
		}
		elsif (/^samplename\t(.+)/i) {
			@otunames = split(/\t/, $1);
			$ncol = scalar(@otunames);
			$format = 'matrix';
		}
		else {
			&errorMessage(__LINE__, "The input file is invalid.");
		}
	}
	close($filehandleinput1);
	if ($format eq 'column') {
		@samplenames = sort({$a cmp $b} keys(%table));
		foreach my $samplename (@samplenames) {
			@otunames = sort({$a cmp $b} keys(%{$table{$samplename}}));
			last;
		}
	}
	if (!$tableformat) {
		$tableformat = $format;
	}
}

sub processSummary {
	my %otu2newotu;
	my %newotu;
	foreach my $otuname (@otunames) {
		if ($taxonomy{$otuname}{$targetrank}) {
			my $taxon = $taxonomy{$otuname}{$targetrank};
			$taxon =~ s/ /_/g;
			$otu2newotu{$otuname} = $taxon;
			$newotu{$taxon} = 0;
			if ($sortkey =~ /^\d+$/) {
				$taxonomy{$taxon}{$sortkey} = $taxonomy{$otuname}{$sortkey};
			}
		}
		else {
			$otu2newotu{$otuname} = $otuname;
			$newotu{$otuname} = 0;
			if ($sortkey =~ /^\d+$/) {
				$taxonomy{$otuname}{$sortkey} = $otuname;
			}
		}
	}
	if (%otu2newotu) {
		foreach my $samplename (@samplenames) {
			foreach my $otuname (@otunames) {
				if ($taxonomy{$otuname}{$targetrank}) {
					$table{$samplename}{$otu2newotu{$otuname}} += $table{$samplename}{$otuname};
					$newotu{$otu2newotu{$otuname}} += $table{$samplename}{$otuname};
					delete($table{$samplename}{$otuname});
				}
				else {
					$newotu{$otu2newotu{$otuname}} += $table{$samplename}{$otuname};
				}
			}
		}
	}
	if ($sortkey eq 'abundance') {
		@otunames = sort({$newotu{$b} <=> $newotu{$a}} keys(%newotu));
	}
	if ($topN) {
		while (scalar(@otunames) > $topN) {
			my $otuname = pop(@otunames);
			foreach my $samplename (@samplenames) {
				$table{$samplename}{'others'} += $table{$samplename}{$otuname};
				delete($table{$samplename}{$otuname});
			}
		}
		push(@otunames, 'others');
	}
	if ($sortkey =~ /^\d+$/) {
		@otunames = sort({$taxonomy{$a}{$sortkey} cmp $taxonomy{$b}{$sortkey} || $newotu{$b} <=> $newotu{$a}} keys(%newotu));
	}
	if ($numbering) {
		my @newotu;
		my $length = length(scalar(@otunames));
		my $num = 1;
		foreach my $otuname (@otunames) {
			my $newotu = sprintf("%0*d", $length, $num) . "_$otuname";
			push(@newotu, $newotu);
			foreach my $samplename (@samplenames) {
				$table{$samplename}{$newotu} = $table{$samplename}{$otuname};
				delete($table{$samplename}{$otuname});
			}
			$num ++;
		}
		@otunames = @newotu;
	}
}

sub saveSummary {
	@samplenames = sort({$a cmp $b} keys(%table));
	# save output file
	$filehandleoutput1 = &writeFile($outputfile);
	if ($tableformat eq 'matrix') {
		print($filehandleoutput1 "samplename\t" . join("\t", @otunames) . "\n");
		foreach my $samplename (@samplenames) {
			print($filehandleoutput1 $samplename);
			foreach my $otuname (@otunames) {
				if ($table{$samplename}{$otuname}) {
					print($filehandleoutput1 "\t$table{$samplename}{$otuname}");
				}
				else {
					print($filehandleoutput1 "\t0");
				}
			}
			print($filehandleoutput1 "\n");
		}
	}
	elsif ($tableformat eq 'column') {
		my $templabel = $taxrank[$targetrank];
		$templabel =~ s/ /_/g;
		print($filehandleoutput1 "samplename\t$templabel\tnreads\n");
		foreach my $samplename (@samplenames) {
			foreach my $otuname (@otunames) {
				if ($table{$samplename}{$otuname}) {
					print($filehandleoutput1 "$samplename\t$otuname\t$table{$samplename}{$otuname}\n");
				}
				else {
					print($filehandleoutput1 "$samplename\t$otuname\t0\n");
				}
			}
		}
	}
	close($filehandleoutput1);
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
clsumtaxa options inputfile outputfile

Command line options
====================
--taxfile=FILENAME
  Specify output of classigntax. (default: none)

--targetrank=RANK
  Specify target taxonomic rank. (default: species)

--numbering=ENABLE|DISABLE
  Specify whether number need to be added to head of otunames ot not.
(default: ENABLE)

--sortkey=ABUNDANCE|RANKNAME
  Specify which key should be used to sort order. Note that RANKNAME should be
specified like below. (default: ABUNDANCE)
--sortkey=familyname
--sortkey=classname
--sortkey=\"species group name\"

--topN=INTEGER
  If this value specified, only top N abundant taxa will be output and the
other taxa will be combined to \"others\".

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: same as input)

--runname=RUNNAME
  Specify run name for replacing run name.
(default: given by sequence name)

Acceptable input file formats
=============================
Output of clsumclass
(Tab-delimited text)
_END
	exit;
}
