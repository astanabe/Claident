use strict;
use Fcntl ':flock';
use File::Spec;

my $buildno = '0.9.x';

# options
my $append;
my $minlen = 1;
my $maxlen;
my $ovlen = 'truncate';
my $minqual;
my $maxqual;
my $ovqual = 'cap';
my $minquallen;
my $minmeanqual;
my $maxplowqual;
my $replaceinternal;
my %keywords;
my %ngwords;
my $converse;
my $minnseq;
my $folder;
my $runname;
my $minnreplicate = 2;
my $minpreplicate = 1;
my $minnpositive = 1;
my $minppositive = 0;
my $numthreads = 1;
my $targetrank;
my $numbering = 1;
my $fuseotu = 1;
my $topN;

# Input/Output
my @inputfiles;
my $output;
my $otufile;
my $replicatelist;
my $taxfile;
my $otulist;
my $otuseq;
my $notulist;
my $notuseq;

# other variables
my $devnull = File::Spec->devnull();
my $format;
my %members;
my %eliminate;
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'subphylum', 'superclass', 'class', 'subclass', 'infraclass', 'cohort', 'subcohort', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'section', 'subsection', 'series', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma', 'forma specialis', 'strain', 'isolate');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}
my %taxonomy;
my %otu2newotu;
my %newotu2otu;
my %otulist;
my %notulist;
my $qthreads;
my $hthreads;

# file handles
my $filehandleinput1;
my $filehandleinput2;
my $filehandleoutput1;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# read list files
	&readListFiles();
	# read sequence files
	&readSequenceFiles();
	# read taxonomy file
	&readTaxonomyFile();
	# read otufile
	&readMembers();
	# recognize file format
	&recognizeFormat();
	# process sequences
	&processSequences();
	# concatenate FASTQ files
	&concatenateFiles();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clfilterseq $buildno
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
	$output = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:keyword|keywords)=(.+)$/i) {
			my $keywords = $1;
			foreach my $keyword (split(/,/, $keywords)) {
				$keywords{$keyword} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:ngword|ngwords)=(.+)$/i) {
			my $ngwords = $1;
			foreach my $ngword (split(/,/, $ngwords)) {
				$ngwords{$ngword} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+otu=(.+)$/i) {
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
		elsif ($ARGV[$i] =~ /^-+(?:c|converse)$/i) {
			$converse = 1;
		}
		elsif ($ARGV[$i] =~ /^-+folder$/i) {
			$folder = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:o|output)=(?:folder|dir|directory)$/i) {
			$folder = 1;
		}
		elsif ($ARGV[$i] =~ /^-+otufile=(.+)$/i) {
			$otufile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?len(?:gth)?=(\d+)$/i) {
			$minlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?len(?:gth)?=(\d+)$/i) {
			$maxlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:overflow|over|ov)(?:len|length)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:elim|eliminate)$/i) {
				$ovlen = 'eliminate';
			}
			elsif ($value =~ /^(?:trunc|truncate)$/i) {
				$ovlen = 'truncate';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?qual(?:ity)?=(\d+)$/i) {
			$minqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?qual(?:ity)?=(\d+)$/i) {
			$maxqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:over|ov)qual(?:ity)?=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:elim|eliminate)$/i) {
				$ovqual = 'eliminate';
			}
			elsif ($value =~ /^cap$/i) {
				$ovqual = 'cap';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?qual(?:ity)?len(?:gth)?=(\d+)$/i) {
			$minquallen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?meanqual(?:ity)?=(\d+)$/i) {
			$minmeanqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)lowqual(?:ity)?=(.+)$/i) {
			$maxplowqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:n|num)(?:seqs?|sequences?|reads?)=(\d+)$/i) {
			$minnseq = $1;
		}
		elsif ($ARGV[$i] =~ /^-+replaceinternal$/i) {
			$replaceinternal = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:replicate|repl?)list=(.+)$/i) {
			$replicatelist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?(?:replicate|repl?)=(\d+)$/i) {
			$minnreplicate = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:r|rate|p|percentage)(?:replicate|repl?)=(\d(?:\.\d+)?)$/i) {
			$minpreplicate = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?positive=(\d+)$/i) {
			$minnpositive = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:r|rate|p|percentage)positive=(\d(?:\.\d+)?)$/i) {
			$minppositive = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:a|append)$/i) {
			$append = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$runname = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:tax|taxonomy)file=(.+)$/i) {
			$taxfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:target)?(?:tax|taxonomy)?(?:unit|rank|level)=(.+)$/i) {
			my $taxrank = $1;
			if ($taxrank{$taxrank}) {
				$targetrank = $taxrank{$taxrank};
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
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
		elsif ($ARGV[$i] =~ /^-+fuseotu=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$fuseotu = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$fuseotu = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+topN=(\d+)$/i) {
			$topN = $1;
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
}

sub checkVariables {
	if (scalar(@inputfiles) < 1) {
		&errorMessage(__LINE__, "Input file was not given.");
	}
	if (scalar(@inputfiles) > 2) {
		&errorMessage(__LINE__, "Too many input files were given.");
	}
	if (scalar(@inputfiles) == 2) {
		$folder = 1;
	}
	if (-e $output && !$append) {
		&errorMessage(__LINE__, "\"$output\" already exists.");
	}
	elsif ($folder && !mkdir($output) && !$append) {
		&errorMessage(__LINE__, 'Cannot make output folder.');
	}
	else {
		my @temp = glob("$output.*");
		if (@temp) {
			&errorMessage(__LINE__, "Temporary files already exist.");
		}
	}
	if ($otufile && !-e $otufile) {
		&errorMessage(__LINE__, "\"$otufile\" does not exist.");
	}
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
	if (%otulist && %notulist) {
		&errorMessage(__LINE__, "The OTU list and the negative OTU list cannot be given at the same time.");
	}
	if ($replicatelist && !-e $replicatelist) {
		&errorMessage(__LINE__, "\"$replicatelist\" does not exist.");
	}
	if ($taxfile && !-e $taxfile) {
		&errorMessage(__LINE__, "\"$taxfile\" does not exist.");
	}
	if (!$targetrank) {
		$targetrank = $taxrank{'species'};
	}
	if (($minnseq || $replicatelist) && !$otufile) {
		my $prefix = $inputfiles[0];
		$prefix =~ s/\.(?:gz|bz2|xz)$//i;
		$prefix =~ s/\.[^\.]+$//;
		if (-e "$prefix.otu.gz") {
			$otufile = "$prefix.otu.gz";
		}
		elsif (-e "$prefix.otu") {
			$otufile = "$prefix.otu";
		}
	}
	if ($minnseq && !$otufile) {
		&errorMessage(__LINE__, "The minimum number threshold for reads of contigs requires OTU file.");
	}
	if ($replicatelist && !$otufile) {
		&errorMessage(__LINE__, "Replicate list requires OTU file.");
	}
	if ($minnseq && $replicatelist) {
		&errorMessage(__LINE__, "The minimum number threshold for reads of contigs is incompatible to replicate list.");
	}
	if ($minnreplicate < 2) {
		&errorMessage(__LINE__, "The minimum number of replicate is invalid.");
	}
	if ($minpreplicate > 1) {
		&errorMessage(__LINE__, "The minimum percentage of replicate is invalid.");
	}
	if ($minppositive > 1) {
		&errorMessage(__LINE__, "The minimum percentage of true positive for noisy/chimeric OTU detection is invalid.");
	}
	if ($minlen < 1) {
		&errorMessage(__LINE__, "Minimum length must be equal to or more than 1.");
	}
	if ($minqual) {
		$minqual += 33;
	}
	if ($minmeanqual) {
		$minmeanqual += 33;
	}
	$qthreads = int($numthreads / 4);
	if ($qthreads < 1) {
		$qthreads = 1;
	}
	$hthreads = int($numthreads / 2);
	if ($hthreads < 1) {
		$hthreads = 1;
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

sub readMembers {
	# read OTU file
	if ($otufile && ($replicatelist || $taxfile)) {
		# read OTU file and store
		my %table;
		my %otusum;
		my @otunames;
		$filehandleinput1 = &readFile($otufile);
		my $otuname;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;+size=\d+;*//g;
			if (/^>(.+)$/) {
				$otuname = $1;
				push(@otunames, $otuname);
			}
			elsif ($otuname && / SN:(\S+)/) {
				my $samplename = $1;
				my @temp = split(/__/, $samplename);
				if (scalar(@temp) == 3) {
					my ($temprunname, $tag, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$tag\__$primer"}{$otuname} ++;
					$otusum{$otuname} ++;
				}
				else {
					&errorMessage(__LINE__, "\"$_\" is invalid name.");
				}
			}
			else {
				&errorMessage(__LINE__, "\"$otufile\" is invalid.");
			}
		}
		close($filehandleinput1);
		if ($replicatelist) {
			# read replicatelist
			my %replicate;
			$filehandleinput1 = &readFile($replicatelist);
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				my @temp = split(/\t/, $_);
				for (my $i = 0; $i < scalar(@temp); $i ++) {
					push(@{$replicate{$temp[0]}}, $temp[$i]);
				}
			}
			close($filehandleinput1);
			# determine whether chimeric OTU or not within sample
			my %withinsample;
			foreach my $sample (keys(%replicate)) {
				my %nreps;
				my %nreads;
				foreach my $replicate (@{$replicate{$sample}}) {
					foreach my $otuname (@otunames) {
						if ($table{$replicate}{$otuname}) {
							$nreps{$otuname} ++;
							$nreads{$otuname} += $table{$replicate}{$otuname};
						}
					}
				}
				foreach my $otuname (keys(%nreps)) {
					if ($nreps{$otuname} < $minnreplicate || ($nreps{$otuname} / @{$replicate{$sample}}) < $minpreplicate) {
						$withinsample{$otuname} += $nreads{$otuname};
					}
				}
			}
			# determine whether chimeric OTU or not in total
			foreach my $otuname (@otunames) {
				if ($withinsample{$otuname} >= $minnpositive && ($withinsample{$otuname} / $otusum{$otuname}) >= $minppositive) {
					$eliminate{$otuname} = 1;
				}
			}
		}
		if ($taxfile) {
			my %newotu;
			foreach my $otuname (@otunames) {
				if ($taxonomy{$otuname}{$targetrank}) {
					my $taxon = $taxonomy{$otuname}{$targetrank};
					$taxon =~ s/ /_/g;
					unless ($fuseotu) {
						$taxon = $otuname . ':' . $taxon;
					}
					$otu2newotu{$otuname} = $taxon;
					$newotu{$taxon} = 0;
				}
			}
			if (%otu2newotu) {
				foreach my $samplename (keys(%table)) {
					foreach my $otuname (@otunames) {
						if ($taxonomy{$otuname}{$targetrank}) {
							$newotu{$otu2newotu{$otuname}} += $table{$samplename}{$otuname};
							if (!defined($newotu2otu{$otu2newotu{$otuname}}) || $table{$samplename}{$otuname} > $table{$samplename}{$newotu2otu{$otu2newotu{$otuname}}}) {
								$newotu2otu{$otu2newotu{$otuname}} = $otuname;
							}
						}
					}
				}
			}
			@otunames = sort({$newotu{$b} <=> $newotu{$a}} keys(%newotu));
			if ($topN) {
				while (scalar(@otunames) > $topN) {
					my $otuname = pop(@otunames);
					delete($newotu2otu{$otuname});
				}
			}
			if ($numbering) {
				my $length = length(scalar(@otunames));
				my $num = 1;
				foreach my $otuname (@otunames) {
					my $newotu = sprintf("%0*d", $length, $num) . "_$otuname";
					$newotu2otu{$newotu} = $newotu2otu{$otuname};
					delete($newotu2otu{$otuname});
					$num ++;
				}
			}
		}
	}
	elsif ($otufile && $minnseq) {
		$filehandleinput1 = &readFile($otufile);
		my $otuname;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;+size=\d+;*//g;
			if (/^>(.+)$/) {
				$otuname = $1;
			}
			elsif ($otuname && /^([^>].*)$/) {
				$members{$otuname} ++;
			}
			else {
				&errorMessage(__LINE__, "\"$otufile\" is invalid.");
			}
		}
		close($filehandleinput1);
	}
}

sub recognizeFormat {
	$filehandleinput1 = &readFile($inputfiles[0]);
	while (<$filehandleinput1>) {
		if (/^\@/) {
			$format = 'FASTQ';
			last;
		}
		elsif (/^>/) {
			$format = 'FASTA';
			last;
		}
	}
	close($filehandleinput1);
	unless ($format) {
		&errorMessage(__LINE__, "Cannot recognize format.");
	}
}

sub processSequences {
	print(STDERR "Processing sequences...\n");
	$filehandleinput1 = &readFile($inputfiles[0]);
	if ($inputfiles[1]) {
		$filehandleinput2 = &readFile($inputfiles[1]);
	}
	if ($format eq 'FASTQ') {
		my $tempnline = 1;
		my $seqname1;
		my $nucseq1;
		my $qualseq1;
		my $seqname2;
		my $nucseq2;
		my $qualseq2;
		my %pid;
		my $child = 0;
		my $nchild = 1;
		$| = 1;
		$? = 0;
		# Processing FASTQ in parallel
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if ($tempnline % 4 == 1 && /^\@(.+)/) {
				$seqname1 = $1;
				$seqname1 =~ s/;+size=\d+;*//g;
				if ($filehandleinput2) {
					$seqname2 = readline($filehandleinput2);
					$seqname2 =~ s/^\@//;
					$seqname2 =~ s/^\s*\r?\n?$//;
					$seqname2 =~ s/;+size=\d+;*//g;
				}
			}
			elsif ($tempnline % 4 == 2) {
				s/[^a-zA-Z]//g;
				$nucseq1 = uc($_);
				if ($filehandleinput2) {
					$nucseq2 = readline($filehandleinput2);
					$nucseq2 =~ s/\r?\n?$//;
					$nucseq2 =~ s/[^a-zA-Z]//g;
					$nucseq2 = uc($nucseq2);
				}
			}
			elsif ($tempnline % 4 == 3 && /^\+/) {
				$tempnline ++;
				if ($filehandleinput2) {
					readline($filehandleinput2);
				}
				next;
			}
			elsif ($tempnline % 4 == 0 && $seqname1) {
				s/\s//g;
				$qualseq1 = $_;
				if ($filehandleinput2) {
					$qualseq2 = readline($filehandleinput2);
					$qualseq2 =~ s/\r?\n?$//;
					$qualseq2 =~ s/\s//g;
					$qualseq2 = $qualseq2;
				}
				if (my $pid = fork()) {
					$pid{$pid} = $child;
					if ($nchild == $numthreads * 2) {
						my $endpid = wait();
						if (exists($pid{$endpid})) {
							$child = $pid{$endpid};
							delete($pid{$endpid});
						}
						elsif ($endpid == -1) {
							$child = 0;
						}
						else {
							print(STDERR "WARNING!: Unkown PID \"$endpid\".\n");
							$child = int(rand($nchild));
						}
					}
					elsif ($nchild < $numthreads * 2) {
						$child = $nchild;
						$nchild ++;
					}
					if ($?) {
						&errorMessage(__LINE__);
					}
					undef($seqname1);
					undef($nucseq1);
					undef($qualseq1);
					undef($seqname2);
					undef($nucseq2);
					undef($qualseq2);
					$tempnline ++;
					next;
				}
				else {
					if (!$eliminate{$seqname1}) {
						if (scalar(@inputfiles) == 2 && $nucseq1 && $qualseq1 && $nucseq2 && $qualseq2) {
							($nucseq1, $qualseq1) = &processOneSequence($seqname1, $nucseq1, $qualseq1);
							($nucseq2, $qualseq2) = &processOneSequence($seqname2, $nucseq2, $qualseq2);
							if ($nucseq1 && $qualseq1 && $nucseq2 && $qualseq2) {
								{
									my $filename = $inputfiles[0];
									$filename =~ s/^.+[\\\/]//;
									if ($taxfile) {
										&saveToFile($nucseq1, $qualseq1, $otu2newotu{$seqname1}, $filename, $child);
									}
									else {
										&saveToFile($nucseq1, $qualseq1, $seqname1, $filename, $child);
									}
								}
								{
									my $filename = $inputfiles[1];
									$filename =~ s/^.+[\\\/]//;
									if ($taxfile) {
										&saveToFile($nucseq2, $qualseq2, $otu2newotu{$seqname2}, $filename, $child);
									}
									else {
										&saveToFile($nucseq2, $qualseq2, $seqname2, $filename, $child);
									}
								}
							}
						}
						elsif (scalar(@inputfiles) == 1 && $nucseq1 && $qualseq1 && !$nucseq2 && !$qualseq2) {
							($nucseq1, $qualseq1) = &processOneSequence($seqname1, $nucseq1, $qualseq1);
							if ($nucseq1 && $qualseq1) {
								my $filename = $inputfiles[0];
								$filename =~ s/^.+[\\\/]//;
								if ($taxfile) {
									&saveToFile($nucseq1, $qualseq1, $otu2newotu{$seqname1}, $filename, $child);
								}
								else {
									&saveToFile($nucseq1, $qualseq1, $seqname1, $filename, $child);
								}
							}
						}
					}
					exit;
				}
			}
			else {
				&errorMessage(__LINE__, "Invalid FASTQ.\nFile: $inputfiles[0]\nLine: $tempnline");
			}
			$tempnline ++;
		}
		# join
		while (wait != -1) {
			if ($?) {
				&errorMessage(__LINE__, 'Cannot split sequence file correctly.');
			}
		}
	}
	elsif ($format eq 'FASTA') {
		my $seqname1;
		my $nucseq1;
		my $seqname2;
		my $nucseq2;
		my $temp;
		my %pid;
		my $child = 0;
		my $nchild = 1;
		$| = 1;
		$? = 0;
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.*)/s) {
				$seqname1 = $1;
				$nucseq1 = uc($2);
				$seqname1 =~ s/;+size=\d+;*//g;
				$nucseq1 =~ s/[^A-Z]//g;
				if ($nucseq1) {
					if ($filehandleinput2) {
						$temp = readline($filehandleinput2);
						$temp =~ /^>?\s*(\S[^\r\n]*)\r?\n(.*)\r?\n?/s;
						$seqname2 = $1;
						$nucseq2 = uc($2);
						$seqname2 =~ s/;+size=\d+;*//g;
						$nucseq2 =~ s/[^A-Z]//g;
					}
					if (my $pid = fork()) {
						$pid{$pid} = $child;
						if ($nchild == $numthreads * 2) {
							my $endpid = wait();
							if (exists($pid{$endpid})) {
								$child = $pid{$endpid};
								delete($pid{$endpid});
							}
							elsif ($endpid == -1) {
								$child = 0;
							}
							else {
								print(STDERR "WARNING!: Unkown PID \"$endpid\".\n");
								$child = int(rand($nchild));
							}
						}
						elsif ($nchild < $numthreads * 2) {
							$child = $nchild;
							$nchild ++;
						}
						if ($?) {
							&errorMessage(__LINE__);
						}
						undef($seqname1);
						undef($nucseq1);
						undef($seqname2);
						undef($nucseq2);
						next;
					}
					else {
						if (!$eliminate{$seqname1}) {
							if (scalar(@inputfiles) == 2 && $nucseq1 && $nucseq2) {
								$nucseq1 = &processOneSequence($seqname1, $nucseq1);
								$nucseq2 = &processOneSequence($seqname2, $nucseq2);
								if ($nucseq1 && $nucseq2) {
									{
										my $filename = $inputfiles[0];
										$filename =~ s/^.+[\\\/]//;
										if ($taxfile) {
											&saveToFile($nucseq1, '', $otu2newotu{$seqname1}, $filename, $child);
										}
										else {
											&saveToFile($nucseq1, '', $seqname1, $filename, $child);
										}
									}
									{
										my $filename = $inputfiles[1];
										$filename =~ s/^.+[\\\/]//;
										if ($taxfile) {
											&saveToFile($nucseq2, '', $otu2newotu{$seqname2}, $filename, $child);
										}
										else {
											&saveToFile($nucseq2, '', $seqname2, $filename, $child);
										}
									}
								}
							}
							elsif (scalar(@inputfiles) == 1 && $nucseq1) {
								$nucseq1 = &processOneSequence($seqname1, $nucseq1);
								if ($nucseq1) {
									my $filename = $inputfiles[0];
									$filename =~ s/^.+[\\\/]//;
									if ($taxfile) {
										&saveToFile($nucseq1, '', $otu2newotu{$seqname1}, $filename, $child);
									}
									else {
										&saveToFile($nucseq1, '', $seqname1, $filename, $child);
									}
								}
							}
						}
						exit;
					}
				}
			}
		}
		# join
		while (wait != -1) {
			if ($?) {
				&errorMessage(__LINE__, 'Cannot split sequence file correctly.');
			}
		}
	}
	close($filehandleinput1);
	if ($filehandleinput2) {
		close($filehandleinput2);
	}
	print(STDERR "done.\n\n");
}

sub concatenateFiles {
	print(STDERR "Concatenating files...\n");
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $inputfile (@inputfiles) {
			if (my $pid = fork()) {
				$child ++;
				if ($child == 4) {
					if (wait == -1) {
						$child = 0;
					} else {
						$child --;
					}
				}
				if ($?) {
					&errorMessage(__LINE__);
				}
				next;
			}
			else {
				$inputfile =~ s/^.+[\\\/]//;
				print(STDERR "Concatenating $inputfile...\n");
				my @seqfiles;
				if ($folder) {
					while (my $tempfile = glob("$output/$inputfile.*")) {
						if (-z $tempfile) {
							unlink($tempfile);
						}
						else {
							push(@seqfiles, $tempfile);
						}
					}
				}
				else {
					while (my $tempfile = glob("$output.*")) {
						if (-z $tempfile) {
							unlink($tempfile);
						}
						else {
							push(@seqfiles, $tempfile);
						}
					}
				}
				if (@seqfiles) {
					if ($folder) {
						$filehandleoutput1 = writeFile("$output/$inputfile");
					}
					else {
						$filehandleoutput1 = writeFile("$output");
					}
					foreach my $seqfile (@seqfiles) {
						unless (open($filehandleinput1, "< $seqfile")) {
							&errorMessage(__LINE__, "Cannot open \"$seqfile\".");
						}
						while (<$filehandleinput1>) {
							print($filehandleoutput1 $_);
						}
						close($filehandleinput1);
						unlink($seqfile);
					}
					close($filehandleoutput1);
				}
				exit;
			}
		}
		# join
		while (wait != -1) {
			if ($?) {
				&errorMessage(__LINE__, 'Cannot concatenate sequence file correctly.');
			}
		}
	}
	print(STDERR "done.\n\n");
}

sub processOneSequence {
	my ($seqname, $nucseq, $qualseq) = @_;
	if ($taxfile && (!defined($otu2newotu{$seqname}) || !defined($newotu2otu{$otu2newotu{$seqname}}) || $newotu2otu{$otu2newotu{$seqname}} ne $seqname) || %otulist && !$otulist{$seqname} || %notulist && $notulist{$seqname} || $minnseq && $members{$seqname} < $minnseq) {
		if ($format eq 'FASTQ') {
			return('', '');
		}
		else {
			return('');
		}
	}
	if (%keywords || %ngwords) {
		my $out = 1;
		foreach my $keyword (keys(%keywords)) {
			if ($seqname !~ /$keyword/i) {
				$out = 0;
			}
		}
		foreach my $ngword (keys(%ngwords)) {
			if ($seqname =~ /$ngword/i) {
				$out = 0;
			}
		}
		if (!$out && !$converse || $out && $converse) {
			if ($format eq 'FASTQ') {
				return('', '');
			}
			else {
				return('');
			}
		}
	}
	my @nucseq = split('', $nucseq);
	my @qualseq;
	if ($format eq 'FASTQ') {
		@qualseq = unpack('C*', $qualseq);
	}
	# skip short sequence
	if (scalar(@nucseq) < $minlen) {
		if ($format eq 'FASTQ') {
			return('', '');
		}
		else {
			return('');
		}
	}
	# truncate based on quality value
	if ($format eq 'FASTQ' && $minqual && $minquallen) {
		# truncate end-side characters
		my $num = 0;
		for (my $i = -1; $i >= (-1) * $minquallen && $i >= (-1) * scalar(@qualseq); $i --) {
			if ($qualseq[$i] < $minqual) {
				$num = $i;
			}
		}
		while ($num != 0) {
			splice(@qualseq, $num);
			splice(@nucseq, $num);
			$num = 0;
			for (my $i = -1; $i >= (-1) * $minquallen && $i >= (-1) * scalar(@qualseq); $i --) {
				if ($qualseq[$i] < $minqual) {
					$num = $i;
				}
			}
		}
		# mask internal characters
		if ($replaceinternal) {
			for (my $i = 0; $i < scalar(@qualseq); $i ++) {
				if ($qualseq[$i] < $minqual) {
					splice(@nucseq, $i, 1, '?');
				}
			}
		}
		# skip short sequence
		if (scalar(@nucseq) < $minlen) {
			if ($format eq 'FASTQ') {
				return('', '');
			}
			else {
				return('');
			}
		}
	}
	# trim longer sequence than threshold
	if ($maxlen && scalar(@nucseq) > $maxlen) {
		if ($ovlen eq 'truncate') {
			if ($format eq 'FASTQ') {
				splice(@qualseq, $maxlen);
			}
			splice(@nucseq, $maxlen);
		}
		elsif ($ovlen eq 'eliminate') {
			if ($format eq 'FASTQ') {
				return('', '');
			}
			else {
				return('');
			}
		}
	}
	# skip low quality sequence
	if ($format eq 'FASTQ' && $minqual && $maxplowqual) {
		my $sum = 0;
		for (my $i = 0; $i < scalar(@qualseq); $i ++) {
			if ($qualseq[$i] < $minqual) {
				$sum ++;
			}
		}
		if ($sum / scalar(@qualseq) > $maxplowqual) {
			if ($format eq 'FASTQ') {
				return('', '');
			}
			else {
				return('');
			}
		}
	}
	# skip low quality sequence
	if ($format eq 'FASTQ' && $minmeanqual) {
		my $sum = 0;
		for (my $i = 0; $i < scalar(@qualseq); $i ++) {
			$sum += $qualseq[$i];
		}
		if ($sum / scalar(@qualseq) < $minmeanqual) {
			if ($format eq 'FASTQ') {
				return('', '');
			}
			else {
				return('');
			}
		}
	}
	# cap high quality values
	if ($format eq 'FASTQ' && $maxqual) {
		my $eliminate = 0;
		for (my $i = 0; $i < scalar(@qualseq); $i ++) {
			if ($qualseq[$i] > $maxqual) {
				if ($ovqual eq 'cap') {
					splice(@qualseq, $i, 1, $maxqual);
				}
				elsif ($ovqual eq 'eliminate') {
					$eliminate = 1;
					last;
				}
			}
		}
		if ($eliminate) {
			if ($format eq 'FASTQ') {
				return('', '');
			}
			else {
				return('');
			}
		}
	}
	# output an entry
	if ($format eq 'FASTQ') {
		return(join('', @nucseq), join('', pack('C*', @qualseq)));
	}
	else {
		return(join('', @nucseq));
	}
}

sub saveToFile {
	my ($nucseq, $qualseq, $seqname, $filename, $child) = @_;
	if ($folder) {
		unless (open($filehandleoutput1, ">> $output/$filename.$child")) {
			&errorMessage(__LINE__, "Cannot write \"$output/$filename.$child\".");
		}
		unless (flock($filehandleoutput1, LOCK_EX)) {
			&errorMessage(__LINE__, "Cannot lock \"$output/$filename.$child\".");
		}
		unless (seek($filehandleoutput1, 0, 2)) {
			&errorMessage(__LINE__, "Cannot seek \"$output/$filename.$child\".");
		}
	}
	else {
		unless (open($filehandleoutput1, ">> $output.$child")) {
			&errorMessage(__LINE__, "Cannot write \"$output.$child\".");
		}
		unless (flock($filehandleoutput1, LOCK_EX)) {
			&errorMessage(__LINE__, "Cannot lock \"$output.$child\".");
		}
		unless (seek($filehandleoutput1, 0, 2)) {
			&errorMessage(__LINE__, "Cannot seek \"$output.$child\".");
		}
	}
	if ($format eq 'FASTQ') {
		print($filehandleoutput1 "\@$seqname\n$nucseq\n+\n$qualseq\n");
	}
	else {
		print($filehandleoutput1 ">$seqname\n$nucseq\n");
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
		unless (open($filehandle, "pigz -p $hthreads -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "lbzip2 -n $hthreads -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "xz -T $hthreads -dc $filename 2> $devnull |")) {
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
		unless (open($filehandle, "| pigz -p $qthreads -c >> $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "| lbzip2 -n $qthreads -c >> $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "| xz -T $qthreads -c >> $filename 2> $devnull")) {
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
	print("ERROR!: line $lineno\n$message\n");
	print("If you want to read help message, run this script without options.\n");
	exit(1);
}

sub helpMessage {
	print <<"_END";
Usage
=====
clfilterseq options inputfile outputfile

Command line options
====================
--keyword=REGEXP(,REGEXP..)
  Specify regular expression(s) for sequence names. You can use regular
expression but you cannot use comma. All keywords will be used as AND
conditions. (default: none)

--ngword=REGEXP(,REGEXP..)
  Specify regular expression(s) for sequence names. You can use regular
expression but you cannot use comma. All ngwords will be used as AND
conditions. (default: none)

--otu=OTUNAME,...,OTUNAME
  Specify output OTU names. The unspecified OTUs will be deleted.

--negativeotu=OTUNAME,...,OTUNAME
  Specify delete OTU names. The specified OTUs will be deleted.

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

-c, --converse
  If this option is specified, matched sequences will be cut off and
nonmatched sequences will be saved. (default: off)

-a, --append
  Specify outputfile append or not. (default: off)

-o, --output=FILE|DIRECTORY
  Specify output format. (default: FILE)

--minlen=INTEGER
  Specify minimum length threshold. (default: 1)

--maxlen=INTEGER
  Specify maximum length threshold. (default: Inf)

--ovlen=ELIMINATE|TRUNCATE
  Specify whether 1 whole sequence is eliminated or overflow is truncated if
sequence length is longer than maxlen.

--minqual=INTEGER
  Specify minimum quality threshold. (default: none)

--minquallen=INTEGER
  Specify minimum quality length threshold. (default: 1)

--minmeanqual=INTEGER
  Specify minimum mean quality threshold. (default: none)

--maxplowqual=DECIMAL
  Specify maximum percent threshold of low quality sequences. (default: 1)

--replaceinternal
  Specify whether internal low-quality characters replace to missing
data (?) or not. (default: off)

--otufile=FILENAME
  Specify file path to otu file. (default: none)

--minnseq=INTEGER
  Specify the minimum number threshold for reads of contigs.
(default: 0)

--replicatelist=FILENAME
  Specify the list file of PCR replicates. (default: none)

--minnreplicate=INTEGER
  Specify the minimum number of \"presense\" replicates required for clean
and nonchimeric OTUs. (default: 2)

--minpreplicate=DECIMAL
  Specify the minimum percentage of \"presense\" replicates per sample
required for clean and nonchimeric OTUs. (default: 1)

--minnpositive=INTEGER
  The OTU that consists of this number of reads will be treated as true
positive in noise/chimera detection. (default: 1)

--minppositive=DECIMAL
  The OTU that consists of this proportion of reads will be treated as true
positive in noise/chimera detection. (default: 0)

--taxfile=FILENAME
  Specify output of classigntax. (default: none)

--targetrank=RANK
  Specify target taxonomic rank. (default: species)

--fuseotu=ENABLE|DISABLE
  Specify whether OTU will be fused or not. (default:ENABLE)

--numbering=ENABLE|DISABLE
  Specify whether number need to be added to head of otunames ot not.
(default: ENABLE)

--topN=INTEGER
  If this value specified, only top N abundant taxa will be output and the
other taxa will be combined to \"others\".

--runname=RUNNAME
  Specify run name for replacing run name.
(default: given by sequence name)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTQ (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
(Quality values must be encoded in Sanger format.)
_END
	exit;
}
