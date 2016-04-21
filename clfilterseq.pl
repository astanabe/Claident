use strict;
use Fcntl ':flock';
use File::Spec;

my $buildno = '0.2.x';

# options
my $append;
my $minlen = 1;
my $maxlen;
my $ovlen = 'truncate';
my $minqual;
my $maxqual;
my $ovqual = 'cap';
my $minquallen = 1;
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

# Input/Output
my @inputfiles;
my $output;
my $contigmembers;
my $otufile;
my $replicatelist;

# other variables
my $devnull = File::Spec->devnull();
my $format;
my %members;
my %eliminate;

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
	# read contigmembers or otufile
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
http://www.fifthdimension.jp/products/claident/ .
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
}

sub getOptions {
	$output = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:keyword|keywords|k)=(.+)$/i) {
			my $keywords = $1;
			foreach my $keyword (split(/,/, $keywords)) {
				$keywords{$keyword} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:ngword|ngwords|n)=(.+)$/i) {
			my $ngwords = $1;
			foreach my $ngword (split(/,/, $ngwords)) {
				$ngwords{$ngword} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:c|converse)$/i) {
			$converse = 1;
		}
		elsif ($ARGV[$i] =~ /^-+folder$/i) {
			$folder = 1;
		}
		elsif ($ARGV[$i] =~ /^-+output=(?:folder|dir|directory)$/i) {
			$folder = 1;
		}
		elsif ($ARGV[$i] =~ /^-+contigmembers?=(.+)$/i) {
			$contigmembers = $1;
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
		elsif ($ARGV[$i] =~ /^-+(?:over|ov)(?:len|length)=(.+)$/i) {
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
	elsif ($folder) {
		mkdir($output);
	}
	else {
		my @temp = glob("$output.*");
		if (@temp) {
			&errorMessage(__LINE__, "Temporary files already exist.");
		}
	}
	if ($contigmembers && $otufile) {
		&errorMessage(__LINE__, "Both contigmembers and OTU files were given, but these options are incompatible.");
	}
	if ($contigmembers && !-e $contigmembers) {
		&errorMessage(__LINE__, "\"$contigmembers\" does not exist.");
	}
	if ($otufile && !-e $otufile) {
		&errorMessage(__LINE__, "\"$otufile\" does not exist.");
	}
	if ($replicatelist && !-e $replicatelist) {
		&errorMessage(__LINE__, "\"$replicatelist\" does not exist.");
	}
	if (($minnseq || $replicatelist) && !$otufile && !$contigmembers) {
		my $prefix = $inputfiles[0];
		$prefix =~ s/\.(?:gz|bz2|xz)$//i;
		$prefix =~ s/\.[^\.]+$//;
		if (-e "$prefix.otu.gz") {
			$otufile = "$prefix.otu.gz";
		}
		elsif (-e "$prefix.otu") {
			$otufile = "$prefix.otu";
		}
		elsif (-e "$prefix.contigmembers.gz") {
			$contigmembers = "$prefix.contigmembers.gz";
		}
		elsif (-e "$prefix.contigmembers.txt") {
			$contigmembers = "$prefix.contigmembers.txt";
		}
		elsif (-e "$prefix.contigmembers") {
			$contigmembers = "$prefix.contigmembers";
		}
	}
	if ($minnseq && !$contigmembers && !$otufile) {
		&errorMessage(__LINE__, "The minimum number threshold for reads of contigs requires contigmembers or OTU file.");
	}
	if ($replicatelist && !$contigmembers && !$otufile) {
		&errorMessage(__LINE__, "Replicate list requires contigmembers or OTU file.");
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
}

sub readMembers {
	# read contig members
	if ($contigmembers && $minnseq) {
		$filehandleinput1 = &readFile($contigmembers);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			my @temp = split(/\t/, $_);
			if (scalar(@temp) > 2) {
				$members{$temp[0]} = scalar(@temp) - 1;
			}
			elsif (scalar(@temp) == 2) {
				$members{$temp[1]} = 1;
			}
			elsif (/.+/) {
				&errorMessage(__LINE__, "The contigmembers file is invalid.");
			}
		}
		close($filehandleinput1);
	}
	elsif ($otufile && $minnseq) {
		$filehandleinput1 = &readFile($otufile);
		my $centroid;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;?//g;
			if (/^>(.+)$/) {
				$centroid = $1;
				$members{$centroid} = 1;
			}
			elsif ($centroid && /^([^>].*)$/) {
				$members{$centroid} ++;
			}
			else {
				&errorMessage(__LINE__, "\"$otufile\" is invalid.");
			}
		}
		close($filehandleinput1);
	}
	elsif ($contigmembers && $replicatelist) {
		# read contigmembers and store
		my %table;
		my %otusum;
		my @otunames;
		$filehandleinput1 = &readFile($contigmembers);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			my @row = split(/\t/, $_);
			if (scalar(@row) > 2) {
				my $otuname = shift(@row);
				push(@otunames, $otuname);
				foreach my $contigmember (@row) {
					my @temp = split(/__/, $contigmember);
					if (scalar(@temp) == 3) {
						my ($temp, $temprunname, $primer) = @temp;
						if ($runname) {
							$temprunname = $runname;
						}
						$table{"$temprunname\__$primer"}{$otuname} ++;
						$otusum{$otuname} ++;
					}
					elsif (scalar(@temp) == 4) {
						my ($temp, $temprunname, $tag, $primer) = @temp;
						if ($runname) {
							$temprunname = $runname;
						}
						$table{"$temprunname\__$tag\__$primer"}{$otuname} ++;
						$otusum{$otuname} ++;
					}
					else {
						&errorMessage(__LINE__, "\"$contigmember\" is invalid name.");
					}
				}
			}
			elsif (scalar(@row) == 2) {
				push(@otunames, $row[1]);
				my @temp = split(/__/, $row[1]);
				if (scalar(@temp) == 3) {
					my ($temp, $temprunname, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$primer"}{$row[1]} ++;
					$otusum{$row[1]} ++;
				}
				elsif (scalar(@temp) == 4) {
					my ($temp, $temprunname, $tag, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$tag\__$primer"}{$row[1]} ++;
					$otusum{$row[1]} ++;
				}
				else {
					&errorMessage(__LINE__, "\"$row[1]\" is invalid name.");
				}
			}
			else {
				&errorMessage(__LINE__, "The contigmembers file is invalid.");
			}
		}
		close($filehandleinput1);
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
	elsif ($otufile && $replicatelist) {
		# read OTU file and store
		my %table;
		my %otusum;
		my @otunames;
		$filehandleinput1 = &readFile($otufile);
		my $otuname;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;?//g;
			if (/^>(.+)$/) {
				$otuname = $1;
				push(@otunames, $otuname);
				my @temp = split(/__/, $otuname);
				if (scalar(@temp) == 3) {
					my ($temp, $temprunname, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$primer"}{$otuname} ++;
					$otusum{$otuname} ++;
				}
				elsif (scalar(@temp) == 4) {
					my ($temp, $temprunname, $tag, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$tag\__$primer"}{$otuname} ++;
					$otusum{$otuname} ++;
				}
				else {
					&errorMessage(__LINE__, "\"$otuname\" is invalid name.");
				}
			}
			elsif ($otuname && /^([^>].*)$/) {
				my $otumember = $1;
				my @temp = split(/__/, $otumember);
				if (scalar(@temp) == 3) {
					my ($temp, $temprunname, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$primer"}{$otuname} ++;
					$otusum{$otuname} ++;
				}
				elsif (scalar(@temp) == 4) {
					my ($temp, $temprunname, $tag, $primer) = @temp;
					if ($runname) {
						$temprunname = $runname;
					}
					$table{"$temprunname\__$tag\__$primer"}{$otuname} ++;
					$otusum{$otuname} ++;
				}
				else {
					&errorMessage(__LINE__, "\"$otumember\" is invalid name.");
				}
			}
			else {
				&errorMessage(__LINE__, "\"$otufile\" is invalid.");
			}
		}
		close($filehandleinput1);
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
	print(STDERR "\nProcessing sequences...\n");
	$filehandleinput1 = &readFile($inputfiles[0]);
	if ($inputfiles[1]) {
		$filehandleinput2 = &readFile($inputfiles[1]);
	}
	if ($format eq 'FASTQ') {
		my $tempnline = 1;
		my $seqname;
		my $nucseq1;
		my $qualseq1;
		my $nucseq2;
		my $qualseq2;
		my %child;
		my %pid;
		my $child = 0;
		$| = 1;
		$? = 0;
		# Processing FASTQ in parallel
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if ($tempnline % 4 == 1 && /^\@(\S+)/) {
				$seqname = $1;
				if ($filehandleinput2) {
					readline($filehandleinput2);
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
			elsif ($tempnline % 4 == 0 && $seqname && $nucseq1) {
				s/\s//g;
				$qualseq1 = $_;
				if ($filehandleinput2) {
					$qualseq2 = readline($filehandleinput2);
					$qualseq2 =~ s/\r?\n?$//;
					$qualseq2 =~ s/\s//g;
					$qualseq2 = $qualseq2;
				}
				if (my $pid = fork()) {
					for (my $i = 0; $i < $numthreads * 2; $i ++) {
						if (!exists($child{$i})) {
							$child{$i} = 1;
							$pid{$pid} = $i;
							$child = $i;
							last;
						}
					}
					my @child = keys(%child);
					if (scalar(@child) == $numthreads * 2) {
						my $endpid = wait();
						if ($endpid == -1) {
							undef(%child);
							undef(%pid);
						}
						else {
							delete($child{$pid{$endpid}});
							delete($pid{$endpid});
						}
					}
					if ($?) {
						&errorMessage(__LINE__);
					}
					undef($seqname);
					undef($nucseq1);
					undef($qualseq1);
					undef($nucseq2);
					undef($qualseq2);
					$tempnline ++;
					next;
				}
				else {
					if (!$eliminate{$seqname}) {
						if (scalar(@inputfiles) == 2 && $nucseq1 && $qualseq1 && $nucseq2 && $qualseq2) {
							($nucseq1, $qualseq1) = &processOneSequence($seqname, $nucseq1, $qualseq1);
							($nucseq2, $qualseq2) = &processOneSequence($seqname, $nucseq2, $qualseq2);
							if ($nucseq1 && $qualseq1 && $nucseq2 && $qualseq2) {
								{
									my $filename = $inputfiles[0];
									$filename =~ s/^.+[\\\/]//;
									&saveToFile($nucseq1, $qualseq1, $seqname, $filename, $child);
								}
								{
									my $filename = $inputfiles[1];
									$filename =~ s/^.+[\\\/]//;
									&saveToFile($nucseq2, $qualseq2, $seqname, $filename, $child);
								}
							}
						}
						elsif (scalar(@inputfiles) == 1 && $nucseq1 && $qualseq1 && !$nucseq2 && !$qualseq2) {
							($nucseq1, $qualseq1) = &processOneSequence($seqname, $nucseq1, $qualseq1);
							if ($nucseq1 && $qualseq1) {
								my $filename = $inputfiles[0];
								$filename =~ s/^.+[\\\/]//;
								&saveToFile($nucseq1, $qualseq1, $seqname, $filename, $child);
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
	}
	elsif ($format eq 'FASTA') {
		my $seqname;
		my $nucseq1;
		my $nucseq2;
		my $temp;
		my %child;
		my %pid;
		my $child = 0;
		$| = 1;
		$? = 0;
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
				$seqname = $1;
				$seqname =~ s/;size=\d+;?//g;
				$nucseq1 = uc($2);
				$nucseq1 =~ s/[^A-Z]//g;
				if ($filehandleinput2) {
					$temp = readline($filehandleinput2);
					$temp =~ /^>?\s*\S[^\r\n]*\r?\n(.+)\r?\n?/s;
					$nucseq2 = uc($1);
					$nucseq2 =~ s/[^A-Z]//g;
				}
				if (my $pid = fork()) {
					for (my $i = 0; $i < $numthreads * 2; $i ++) {
						if (!exists($child{$i})) {
							$child{$i} = 1;
							$pid{$pid} = $i;
							$child = $i;
							last;
						}
					}
					my @child = keys(%child);
					if (scalar(@child) == $numthreads * 2) {
						my $endpid = wait();
						if ($endpid == -1) {
							undef(%child);
							undef(%pid);
						}
						else {
							delete($child{$pid{$endpid}});
							delete($pid{$endpid});
						}
					}
					if ($?) {
						&errorMessage(__LINE__);
					}
					undef($seqname);
					undef($nucseq1);
					undef($nucseq2);
					next;
				}
				else {
					if (!$eliminate{$seqname}) {
						if (scalar(@inputfiles) == 2 && $nucseq1 && $nucseq2) {
							$nucseq1 = &processOneSequence($seqname, $nucseq1);
							$nucseq2 = &processOneSequence($seqname, $nucseq2);
							if ($nucseq1 && $nucseq2) {
								{
									my $filename = $inputfiles[0];
									$filename =~ s/^.+[\\\/]//;
									&saveToFile($nucseq1, '', $seqname, $filename, $child);
								}
								{
									my $filename = $inputfiles[1];
									$filename =~ s/^.+[\\\/]//;
									&saveToFile($nucseq2, '', $seqname, $filename, $child);
								}
							}
						}
						elsif (scalar(@inputfiles) == 1 && $nucseq1) {
							$nucseq1 = &processOneSequence($seqname, $nucseq1);
							if ($nucseq1) {
								my $filename = $inputfiles[0];
								$filename =~ s/^.+[\\\/]//;
								&saveToFile($nucseq1, '', $seqname, $filename, $child);
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
	close($filehandleinput1);
	if ($filehandleinput2) {
		close($filehandleinput2);
	}
	print(STDERR "done.\n");
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
				if ($child == $numthreads) {
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
	my @nucseq = split('', $nucseq);
	my @qualseq;
	if ($format eq 'FASTQ') {
		@qualseq = unpack('C*', $qualseq);
	}
	if ($minnseq && $members{$seqname} < $minnseq) {
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
-k, --keyword=REGEXP(,REGEXP..)
  Specify regular expression(s) for sequence names. You can use regular
expression but you cannot use comma. All keywords will be used as AND
conditions. (default: none)

-n, --ngword=REGEXP(,REGEXP..)
  Specify regular expression(s) for sequence names. You can use regular
expression but you cannot use comma. All ngwords will be used as AND
conditions. (default: none)

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

--minqual=INTEGER
  Specify minimum quality threshold. (default: none)

--minquallen=INTEGER
  Specify minimum quality length threshold. (default: 1)

--minmeanqual=INTEGER
  Specify minimum mean quality threshold. (default: minqual)

--maxplowqual=DECIMAL
  Specify maximum percent threshold of low quality sequences. (default: 1)

--replaceinternal
  Specify whether internal low-quality characters replace to missing
data (?) or not. (default: off)

--contigmembers=FILENAME
  Specify file path to contigmembers file. (default: none)

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
