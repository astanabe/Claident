use strict;
use warnings;
use File::Spec;

my $buildno = '0.9.x';

# input/output
my $inputfile;
my $outputfile;
my $replicatelist;
my $otulist;
my $otuseq;
my $notulist;
my $notuseq;
my $samplelist;
my $nsamplelist;
my $taxfile;

# options
my $runname;
my $minnseqotu = 0;
my $minnseqsample = 0;
my $minntotalseqotu = 0;
my $minntotalseqsample = 0;
my $minpseqotu = 0;
my $minpseqsample = 0;
my %includetaxa;
my %includetaxarestriction;
my %excludetaxa;
my %excludetaxarestriction;
my $tableformat;

# global variables
my $devnull = File::Spec->devnull();
my %otulist;
my %notulist;
my %samplelist;
my %nsamplelist;
my %table;
my @otunames;
my @samplenames;
my %parentsample;
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
	# read list files
	&readListFiles();
	# read sequence files
	&readSequenceFiles();
	# read summary
	&readSummary();
	# filter
	&filterColumnsRows();
	# save summary
	&saveSummary();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clfiltersum $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
To know script details, see above URL.

Copyright (C) 2011-2022  Akifumi S. Tanabe

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
		if ($ARGV[$i] =~ /^-+otu=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$otulist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?otu=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$notulist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+sample=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$samplelist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?sample=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$nsamplelist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+otulist=(.+)$/i) {
			$otulist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?otulist=(.+)$/i) {
			$notulist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+otuseq=(.+)$/i) {
			$otuseq = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?otuseq=(.+)$/i) {
			$notuseq = $1;
		}
		elsif ($ARGV[$i] =~ /^-+samplelist=(.+)$/i) {
			$samplelist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:egative)?samplelist=(.+)$/i) {
			$nsamplelist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?seq(?:uence)?s?(?:con|contig|otu)=(\d+)$/i) {
			$minnseqotu = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?seq(?:uence)?s?sam(?:ple)?=(\d+)$/i) {
			$minnseqsample = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?totalseq(?:uence)?s?(?:con|contig|otu)=(\d+)$/i) {
			$minntotalseqotu = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?totalseq(?:uence)?s?sam(?:ple)?=(\d+)$/i) {
			$minntotalseqsample = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:r|rate|p|percentage)seq(?:uence)?s?(?:con|contig|otu)=(\d+(?:\.\d+)?)$/i) {
			$minpseqotu = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:r|rate|p|percentage)seq(?:uence)?s?sam(?:ple)?=(\d+(?:\.\d+)?)$/i) {
			$minpseqsample = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:replicate|repl?)list=(.+)$/i) {
			$replicatelist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$runname = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:tax|taxonomy)file=(.+)$/i) {
			$taxfile = $1;
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
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	# check input file
	if (!-e $inputfile) {
		&errorMessage(__LINE__, "Input file does not exist.");
	}
	# check output file
	if (-e $outputfile) {
		&errorMessage(__LINE__, "Output file already exists.");
	}
	# check files
	if ($otulist && !-e $otulist) {
		&errorMessage(__LINE__, "\"$otulist\" does not exist.");
	}
	if ($notulist && !-e $notulist) {
		&errorMessage(__LINE__, "\"$notulist\" does not exist.");
	}
	if ($otuseq && !-e $otuseq) {
		&errorMessage(__LINE__, "\"$otuseq\" does not exist.");
	}
	if ($notuseq && !-e $notuseq) {
		&errorMessage(__LINE__, "\"$notuseq\" does not exist.");
	}
	if ($samplelist && !-e $samplelist) {
		&errorMessage(__LINE__, "\"$samplelist\" does not exist.");
	}
	if ($nsamplelist && !-e $nsamplelist) {
		&errorMessage(__LINE__, "\"$nsamplelist\" does not exist.");
	}
	if ($replicatelist && !-e $replicatelist) {
		&errorMessage(__LINE__, "\"$replicatelist\" does not exist.");
	}
	if ($taxfile && !-e $taxfile) {
		&errorMessage(__LINE__, "\"$taxfile\" does not exist.");
	}
	# check incompatible options
	if ($otulist && $notulist) {
		&errorMessage(__LINE__, "The OTU list and the negative OTU list cannot be given at the same time.");
	}
	if ($otulist && $notuseq) {
		&errorMessage(__LINE__, "The OTU list and the negative OTU sequence cannot be given at the same time.");
	}
	if ($otuseq && $notulist) {
		&errorMessage(__LINE__, "The OTU sequence and the negative OTU list cannot be given at the same time.");
	}
	if ($otuseq && $notuseq) {
		&errorMessage(__LINE__, "The OTU sequence and the negative OTU sequence cannot be given at the same time.");
	}
	if ($samplelist && $nsamplelist) {
		&errorMessage(__LINE__, "The sample list and the negative sample list cannot be given at the same time.");
	}
	if (%otulist && %notulist) {
		&errorMessage(__LINE__, "The OTU list and the negative OTU list cannot be given at the same time.");
	}
	if (%samplelist && %nsamplelist) {
		&errorMessage(__LINE__, "The sample list and the negative sample list cannot be given at the same time.");
	}
	# check percentage
	if ($minpseqotu < 0 || $minpseqotu > 1) {
		&errorMessage(__LINE__, "The minimum percentage of OTU is invalid.");
	}
	if ($minpseqsample < 0 || $minpseqsample > 1) {
		&errorMessage(__LINE__, "The minimum percentage of sample is invalid.");
	}
}

sub readTaxonomyFile {
	if ($taxfile) {
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
}

sub readListFiles {
	if ($otulist) {
		foreach my $otu (&readList($otulist)) {
			$otulist{$otu} = 1;
		}
	}
	elsif ($notulist) {
		foreach my $otu (&readList($notulist)) {
			$notulist{$otu} = 1;
		}
	}
	if ($samplelist) {
		foreach my $sample (&readList($samplelist)) {
			$samplelist{$sample} = 1;
		}
	}
	elsif ($nsamplelist) {
		foreach my $sample (&readList($nsamplelist)) {
			$nsamplelist{$sample} = 1;
		}
	}
	if ($replicatelist) {
		$filehandleinput1 = &readFile($replicatelist);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			my @temp = split(/\t/, $_);
			for (my $i = 0; $i < scalar(@temp); $i ++) {
				$parentsample{$temp[$i]} = $temp[0];
			}
		}
		close($filehandleinput1);
	}
}

sub readSequenceFiles {
	if ($otuseq) {
		foreach my $otu (&readSeq($otuseq)) {
			$otulist{$otu} = 1;
		}
	}
	elsif ($notuseq) {
		foreach my $otu (&readSeq($notuseq)) {
			$notulist{$otu} = 1;
		}
	}
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
				if ($replicatelist && $parentsample{$row[0]}) {
					$row[0] = $parentsample{$row[0]};
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
				if ($replicatelist && $parentsample{$samplename}) {
					$samplename = $parentsample{$samplename};
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

sub filterColumnsRows {
	# filter samples
	if ($samplelist) {
		foreach my $samplename (@samplenames) {
			unless ($samplelist{$samplename}) {
				delete($table{$samplename});
			}
		}
	}
	elsif ($nsamplelist) {
		foreach my $samplename (@samplenames) {
			if ($nsamplelist{$samplename}) {
				delete($table{$samplename});
			}
		}
	}
	# renew samplenames
	@samplenames = sort({$a cmp $b} keys(%table));
	# filter OTUs
	if (%otulist) {
		foreach my $samplename (@samplenames) {
			foreach my $otuname (@otunames) {
				unless ($otulist{$otuname}) {
					delete($table{$samplename}{$otuname});
				}
			}
		}
	}
	elsif (%notulist) {
		foreach my $samplename (@samplenames) {
			foreach my $otuname (@otunames) {
				if ($notulist{$otuname}) {
					delete($table{$samplename}{$otuname});
				}
			}
		}
	}
	if ($taxfile && %includetaxa) {
		my @deleteotu;
		foreach my $otuname (@otunames) {
			my $hit = 0;
			foreach my $word (keys(%includetaxa)) {
				if (!exists($includetaxarestriction{$word})) {
					foreach my $rank (keys(%{$taxonomy{$otuname}})) {
						if ($taxonomy{$otuname}{$rank} =~ /$word/i) {
							$hit = 1;
							last;
						}
					}
					if ($hit) {
						last;
					}
				}
				elsif ($taxonomy{$otuname}{$includetaxarestriction{$word}} && $taxonomy{$otuname}{$includetaxarestriction{$word}} =~ /$word/i) {
					$hit = 1;
					last;
				}
			}
			if ($hit == 0) {
				push(@deleteotu, $otuname);
			}
		}
		foreach my $samplename (@samplenames) {
			foreach my $otuname (@deleteotu) {
				delete($table{$samplename}{$otuname});
			}
		}
	}
	if ($taxfile && %excludetaxa) {
		my @deleteotu;
		foreach my $otuname (@otunames) {
			my $hit = 0;
			foreach my $word (keys(%excludetaxa)) {
				if (!exists($excludetaxarestriction{$word})) {
					my $hit = 0;
					foreach my $rank (keys(%{$taxonomy{$otuname}})) {
						if ($taxonomy{$otuname}{$rank} =~ /$word/i) {
							$hit = 1;
							last;
						}
					}
					if ($hit) {
						last;
					}
				}
				elsif ($taxonomy{$otuname}{$excludetaxarestriction{$word}} && $taxonomy{$otuname}{$excludetaxarestriction{$word}} =~ /$word/i) {
					$hit = 1;
					last;
				}
			}
			if ($hit) {
				push(@deleteotu, $otuname);
			}
		}
		foreach my $samplename (@samplenames) {
			foreach my $otuname (@deleteotu) {
				delete($table{$samplename}{$otuname});
			}
		}
	}
	# renew otunames
	foreach my $samplename (@samplenames) {
		@otunames = sort({$a cmp $b} keys(%{$table{$samplename}}));
		last;
	}
	# select columns and rows
	if ($minnseqotu || $minnseqsample || $minntotalseqotu || $minntotalseqsample || $minpseqotu || $minpseqsample) {
		my $switch = 1;
		while ($switch) {
			my %outcol;
			my %outrow;
			my %coltotal;
			my %rowtotal;
			# count total of selected columns and rows
			foreach my $samplename (@samplenames) {
				foreach my $otuname (@otunames) {
					$coltotal{$otuname} += $table{$samplename}{$otuname};
					$rowtotal{$samplename} += $table{$samplename}{$otuname};
				}
			}
			# select columns which has one or more, equal or larger value cell than $minnseqotu and $minpseqotu
			# select rows which has one or more, equal or larger value cell than $minnseqsample and $minpseqsample
			if ($minnseqotu || $minnseqsample || $minpseqotu || $minpseqsample) {
				foreach my $samplename (@samplenames) {
					foreach my $otuname (@otunames) {
						if ($coltotal{$otuname} && $table{$samplename}{$otuname} >= $minnseqotu && $table{$samplename}{$otuname} / $coltotal{$otuname} >= $minpseqotu) {
							$outcol{$otuname} = 1;
						}
						if ($rowtotal{$samplename} && $table{$samplename}{$otuname} >= $minnseqsample && $table{$samplename}{$otuname} / $rowtotal{$samplename} >= $minpseqsample) {
							$outrow{$samplename} = 1;
						}
					}
				}
			}
			else {
				foreach my $samplename (@samplenames) {
					$outrow{$samplename} = 1;
				}
				foreach my $otuname (@otunames) {
					$outcol{$otuname} = 1;
				}
			}
			# delete columns which has smaller number of total sequences than $minntotalseqotu
			if ($minntotalseqotu) {
				foreach my $otuname (keys(%outcol)) {
					if ($coltotal{$otuname} < $minntotalseqotu) {
						delete($outcol{$otuname});
						delete($coltotal{$otuname});
					}
				}
			}
			# delete rows which has smaller number of total sequences than $minntotalseqsample
			if ($minntotalseqsample) {
				foreach my $samplename (keys(%outrow)) {
					if ($rowtotal{$samplename} < $minntotalseqsample) {
						delete($outrow{$samplename});
						delete($rowtotal{$samplename});
					}
				}
			}
			# make new table
			$switch = 0;
			foreach my $samplename (@samplenames) {
				unless ($outrow{$samplename}) {
					delete($table{$samplename});
					$switch = 1;
				}
				else {
					foreach my $otuname (@otunames) {
						unless ($outcol{$otuname}) {
							delete($table{$samplename}{$otuname});
							$switch = 1;
						}
					}
				}
			}
			@otunames = sort({$a cmp $b} keys(%outcol));
			@samplenames = sort({$a cmp $b} keys(%outrow));
		}
	}
}

sub saveSummary {
	@otunames = sort({$a cmp $b} @otunames);
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
		print($filehandleoutput1 "samplename\totuname\tnreads\n");
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

sub readList {
	my $listfile = shift(@_);
	my @list;
	$filehandleinput1 = &readFile($listfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;+size=\d+;*//g;
		s/\t.+//;
		push(@list, $_);
	}
	close($filehandleinput1);
	return(@list);
}

sub readSeq {
	my $seqfile = shift(@_);
	my @list;
	$filehandleinput1 = &readFile($seqfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		if (/^> *(.+)/) {
			my $seqname = $1;
			$seqname =~ s/;+size=\d+;*//g;
			push(@list, $seqname);
		}
	}
	close($filehandleinput1);
	return(@list);
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
clfiltersum options inputfile outputfile

Command line options
====================
--taxfile=FILENAME
  Specify output of classigntax. (default: none)

--includetaxa=NAME(,NAME..)
  Specify include taxa by scientific name. (default: none)

--excludetaxa=NAME(,NAME..)
  Specify exclude taxa by scientific name. (default: none)

--replicatelist=FILENAME
  Specify the list file of PCR replicates. (default: none)

--otu=OTUNAME,...,OTUNAME
  Specify output OTU names. The unspecified OTUs will be deleted.

--negativeotu=OTUNAME,...,OTUNAME
  Specify delete OTU names. The specified OTUs will be deleted.

--sample=SAMPLENAME,...,SAMPLENAME
  Specify output sample names. The unspecified samples will be deleted.

--negativesample=SAMPLENAME,...,SAMPLENAME
  Specify delete sample names. The specified samples will be deleted.

--otulist=FILENAME
  Specify output OTU list file name. The file must contain 1 OTU name
at a line.

--negativeotulist=FILENAME
  Specify delete OTU list file name. The file must contain 1 OTU name
at a line.

--otuseq=FILENAME
  Specify output OTU sequence file name. The file must contain 1 OTU
name at a line.

--negativeotuseq=FILENAME
  Specify delete OTU sequence file name. The file must contain 1 OTU
name at a line.

--samplelist=FILENAME
  Specify output sample list file name. The file must contain 1 sample
name at a line.

--negativesamplelist=FILENAME
  Specify delete sample list file name. The file must contain 1 sample
name at a line.

--minnseqotu=INTEGER
  Specify minimum number of sequences of OTU. If the number of
sequences of a OTU is smaller than this value at all samples, the
OTU will be omitted. (default: 0)

--minnseqsample=INTEGER
  Specify minimum number of sequences of sample. If the number of
sequences of a sample is smaller than this value at all OTUs, the
sample will be omitted. (default: 0)

--minntotalseqotu=INTEGER
  Specify minimum total number of sequences of OTU. If the total
number of sequences of a OTU is smaller than this value, the OTU
will be omitted. (default: 0)

--minntotalseqsample=INTEGER
  Specify minimum total number of sequences of sample. If the total
number of sequences of a sample is smaller than this value, the sample
will be omitted. (default: 0)

--minpseqotu=DECIMAL
  Specify minimum percentage of sequences of OTU. If the number of
sequences of a OTU / the total number of sequences of a OTU is
smaller than this value at all samples, the OTU will be omitted.
(default: 0)

--minpseqsample=DECIMAL
  Specify minimum percentage of sequences of sample. If the number of
sequences of a sample / the total number of sequences of a sample is
smaller than this value at all OTUs, the sample will be omitted.
(default: 0)

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: same as input)

Acceptable input file formats
=============================
Output of clsumclass
(Tab-delimited text)
_END
	exit;
}

