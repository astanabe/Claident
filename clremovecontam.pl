use strict;
use File::Spec;
use Statistics::Distributions;

my $buildno = '0.9.x';

# input/output
my @inputfiles;
my @otufiles;
my $outputfolder;

# options
my $mode = 'eliminate';
my $tagfile;
my $reversetagfile;
my $reversecomplement;
my $maxpjump;
my $siglevel = 0.05;
my $tagjump = 'half';
my $tableformat = 'matrix';

# the other global variables
my $devnull = File::Spec->devnull();
my %table;
my %tag;
my $taglength;
my %reversetag;
my $reversetaglength;
my %blanklist;
my %ignoresamplelist;
my %ignoreotulist;
my $blanklist;
my $ignoresamplelist;
my $ignoreotulist;
my $ignoreotuseq;
my %samplenames;
my %sample2blank;
my %blanksamples;
my %otunames;

# file handles
my $filehandleinput1;
my $filehandleinput2;
my $filehandleinput3;
my $filehandleoutput1;
my $filehandleoutput2;
my $filehandleoutput3;
my $pipehandleinput1;
my $pipehandleinput2;
my $pipehandleoutput1;
my $pipehandleoutput2;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# read otu file
	&readMembers();
	# read tags
	&readTags();
	# read list files
	&readListFiles();
	# decontaminate
	&removeContaminants();
	# output results
	&saveResults();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clremovecontam $buildno
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
	$outputfolder = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:sig|significant|significance)level=(.+)$/i) {
			if ($1 > 0 && $1 < 1) {
				$siglevel = $1;
			}
			else {
				&errorMessage(__LINE__, "Significance level is invalid.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+tagjump=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:full|f)$/i) {
				$tagjump = 'full';
			}
			elsif ($value =~ /^(?:half|h)$/i) {
				$tagjump = 'half';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:mode|m)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:eliminate|e)$/i) {
				$mode = 'eliminate';
			}
			elsif ($value =~ /^(?:subtractmax|s)$/i) {
				$mode = 'subtractmax';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)(?:jump|hop|hopping)=(.+)$/i) {
			$maxpjump = $1;
		}
		elsif ($ARGV[$i] =~ /^-+blank(?:sample|samples)?=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$blanklist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:sample|samples)=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$ignoresamplelist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)=(.+)$/i) {
			my @temp = split(',', $1);
			foreach my $temp (@temp) {
				$ignoreotulist{$temp} = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+blanklist=(.+)$/i) {
			$blanklist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:sample|samples)list=(.+)$/i) {
			$ignoresamplelist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)list=(.+)$/i) {
			$ignoreotulist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:ignore|ignoring)(?:otu|otus)seq=(.+)$/i) {
			$ignoreotuseq = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:tag|tagfile|t|index1|index1file)=(.+)$/i) {
			$tagfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)(?:tag|tagfile|t)=(.+)$/i) {
			$reversetagfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:index2|index2file)=(.+)$/i) {
			$reversetagfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:reversecomplement|revcomp)$/i) {
			$reversecomplement = 1;
		}
		elsif ($ARGV[$i] =~ /^-+tableformat=(.+)$/i) {
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
	if (!@inputfiles) {
		&errorMessage(__LINE__, "No input file was specified.");
	}
	{
		my @newinputfiles;
		my @tempinputfiles;
		foreach my $inputfile (@inputfiles) {
			if (-d $inputfile) {
				my @temp = sort(glob("$inputfile/*.fasta"), glob("$inputfile/*.fasta.gz"), glob("$inputfile/*.fasta.bz2"), glob("$inputfile/*.fasta.xz"));
				for (my $i = 0; $i < scalar(@temp); $i ++) {
					if (-e $temp[$i]) {
						my $otufile = $temp[$i];
						$otufile =~ s/\.(?:fq|fastq|fa|fasta|fas)(?:\.gz|\.bz2|\.xz)?$/.otu.gz/;
						if (-e $otufile) {
							push(@newinputfiles, $temp[$i]);
							push(@otufiles, $otufile);
						}
					}
					else {
						&errorMessage(__LINE__, "The input files \"$temp[$i]\" is invalid.");
					}
				}
			}
			elsif (-e $inputfile) {
				my $otufile = $inputfile;
				$otufile =~ s/\.(?:fq|fastq|fa|fasta|fas)(?:\.gz|\.bz2|\.xz)?$/.otu.gz/;
				if (-e $otufile) {
					push(@newinputfiles, $inputfile);
					push(@otufiles, $otufile);
				}
			}
			else {
				&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
			}
		}
		@inputfiles = @newinputfiles;
	}
	if ($maxpjump > 0.5) {
		&errorMessage(__LINE__, "The minimum percentage threshold for reads is invalid.");
	}
	if (scalar(@inputfiles) > 1) {
		&errorMessage(__LINE__, "Too many inputs were given.");
	}
	if (%blanklist && $blanklist) {
		&errorMessage(__LINE__, "Both blank sample list and blank sample file were given.");
	}
	if (%ignoresamplelist && $ignoresamplelist) {
		&errorMessage(__LINE__, "Both ignoring sample list and ignoring sample file were given.");
	}
	if (%ignoreotulist && $ignoreotulist) {
		&errorMessage(__LINE__, "Both ignoring otu list and ignoring otu file were given.");
	}
	if (%ignoreotulist && $ignoreotuseq) {
		&errorMessage(__LINE__, "Both ignoring otu list and ignoring otu sequence file were given.");
	}
	if ($ignoreotulist && $ignoreotuseq) {
		&errorMessage(__LINE__, "Both ignoring otu file and ignoring otu sequence file were given.");
	}
	if ($ignoreotulist && !-e $ignoreotulist) {
		&errorMessage(__LINE__, "\"$ignoreotulist\" does not exist.");
	}
	if ($ignoreotuseq && !-e $ignoreotuseq) {
		&errorMessage(__LINE__, "\"$ignoreotuseq\" does not exist.");
	}
	if (($tagfile || $reversetagfile) && (%blanklist || $blanklist)) {
		&errorMessage(__LINE__, "Removal of tag-jump and contamination cannot be applied at the same time.");
	}
	if ($tagfile && !$reversetagfile || !$tagfile && $reversetagfile) {
		&errorMessage(__LINE__, "Both forward and reverse tags (dual index) must be given.");
	}
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
}

sub readMembers {
	print(STDERR "Reading OTU file...\n");
	# read input file
	$filehandleinput1 = &readFile($otufiles[0]);
	my $otuname;
	my $runname;
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;+size=\d+;*//g;
		if (/^>(.+)$/) {
			$otuname = $1;
			$otunames{$otuname} = 1;
		}
		elsif ($otuname && / SN:(\S+)/) {
			my $samplename = $1;
			my @temp = split(/__/, $samplename);
			if (scalar(@temp) == 3) {
				my ($run, $tag, $primer) = @temp;
				if (!$runname) {
					$runname = $run;
				}
				elsif ($runname ne $run) {
					&errorMessage(__LINE__, "Multiple run name was detected. Cannot treat multiple run samples at the same time.");
				}
				$table{$samplename}{$otuname} ++;
				$samplenames{$samplename} = 1;
			}
			else {
				&errorMessage(__LINE__, "\"$_\" is invalid name.");
			}
		}
		else {
			&errorMessage(__LINE__, "\"$otufiles[0]\" is invalid.");
		}
	}
	close($filehandleinput1);
	print(STDERR "done.\n\n");
}

sub readTags {
	if ($tagfile && $reversetagfile) {
		print(STDERR "Reading tag files...\n");
		my %temptags;
		my %tempreversetags;
		my @tag;
		unless (open($filehandleinput1, "< $tagfile")) {
			&errorMessage(__LINE__, "Cannot open \"$tagfile\".");
		}
		unless (open($filehandleinput2, "< $reversetagfile")) {
			&errorMessage(__LINE__, "Cannot open \"$reversetagfile\".");
		}
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
				my $name = $1;
				my $tag = uc($2);
				$name =~ s/\s+$//;
				if ($name =~ /__/) {
					&errorMessage(__LINE__, "\"$name\" is invalid name. Do not use \"__\" in tag name.");
				}
				elsif ($name =~ /^[ACGT]+$/ || $name =~ /^[ACGT]+[\-\+][ACGT]+$/) {
					&errorMessage(__LINE__, "\"$name\" is invalid name. Do not use nucleotide sequence as tag name.");
				}
				$tag =~ s/[^A-Z]//sg;
				if ($tag =~ /[^ACGT]/) {
					&errorMessage(__LINE__, "\"$tag\" is invalid tag. Do not use degenerate character in tag.");
				}
				if ($taglength && $taglength != length($tag)) {
					&errorMessage(__LINE__, "All tags must have same length.");
				}
				else {
					$taglength = length($tag);
				}
				my $line = readline($filehandleinput2);
				if ($line =~ /^>?\s*(\S[^\r\n]*)\r?\n(.+)\r?\n?/s) {
					my $reversetag = uc($2);
					$reversetag =~ s/[^A-Z]//sg;
					if ($reversetag =~ /[^ACGT]/) {
						&errorMessage(__LINE__, "\"$reversetag\" is invalid tag. Do not use degenerate character in tag.");
					}
					if ($reversecomplement) {
						$reversetag = &reversecomplement($reversetag);
					}
					if ($reversetaglength && $reversetaglength != length($reversetag)) {
						&errorMessage(__LINE__, "All reverse tags must have same length.");
					}
					else {
						$reversetaglength = length($reversetag);
					}
					$temptags{$tag} = 1;
					$tempreversetags{$reversetag} = 1;
					$tag .= '+' . $reversetag;
				}
				if (exists($tag{$tag})) {
					&errorMessage(__LINE__, "Tag \"$tag ($name)\" is doubly used in \"$tagfile\".");
				}
				else {
					$tag{$tag} = $name;
					push(@tag, $tag);
				}
			}
		}
		close($filehandleinput1);
		close($filehandleinput2);
		print(STDERR "Tag sequences\n");
		foreach (@tag) {
			print(STDERR $tag{$_} . " : " . $_ . "\n");
		}
		my @temptags = sort(keys(%temptags));
		my @tempreversetags = sort(keys(%tempreversetags));
		if (@temptags && @tempreversetags) {
			print(STDERR "Sample vs contaminant source sample associtations\n");
			if ($tagjump eq 'half') {
				my %halfjump;
				my %reversehalfjump;
				foreach my $temptag (@temptags) {
					foreach my $tempreversetag (@tempreversetags) {
						my $tagseq = "$temptag+$tempreversetag";
						if (!exists($tag{$tagseq})) {
							push(@{$halfjump{$temptag}}, $tagseq);
							push(@{$reversehalfjump{$tempreversetag}}, $tagseq);
						}
						elsif ($maxpjump > 0) {
							push(@{$halfjump{$temptag}}, $tag{$tagseq});
							push(@{$reversehalfjump{$tempreversetag}}, $tag{$tagseq});
						}
					}
				}
				foreach my $temptag (@temptags) {
					foreach my $tempreversetag (@tempreversetags) {
						my $tagseq = "$temptag+$tempreversetag";
						if ($tag{$tagseq}) {
							foreach my $samplename (keys(%samplenames)) {
								my @temp = split(/__/, $samplename);
								if (scalar(@temp) == 3) {
									my ($runname, $tag, $primer) = @temp;
									if ($tag eq $tag{$tagseq}) {
										foreach my $blanktag (@{$halfjump{$temptag}}, @{$reversehalfjump{$tempreversetag}}) {
											$sample2blank{$samplename}{"$runname\__$blanktag\__$primer"} = 1;
											if ($blanktag =~ /^[ACGT]+\+[ACGT]+$/) {
												$blanksamples{"$runname\__$blanktag\__$primer"} = 1;
											}
										}
									}
								}
							}
						}
					}
				}
			}
			elsif ($tagjump eq 'full') {
				foreach my $temptag (@temptags) {
					foreach my $tempreversetag (@tempreversetags) {
						my $tagseq = "$temptag+$tempreversetag";
						foreach my $samplename (keys(%samplenames)) {
							my @temp = split(/__/, $samplename);
							if (scalar(@temp) == 3) {
								my ($runname, $tag, $primer) = @temp;
								if ($tag !~ /^[ACGT]+\+[ACGT]+$/) {
									if (!exists($tag{$tagseq})) {
										$sample2blank{$samplename}{"$runname\__$tagseq\__$primer"} = 1;
										$blanksamples{"$runname\__$tagseq\__$primer"} = 1;
									}
									elsif ($maxpjump > 0) {
										$sample2blank{$samplename}{"$runname\__$tag{$tagseq}\__$primer"} = 1;
									}
								}
							}
						}
					}
				}
			}
			foreach my $samplename (sort(keys(%sample2blank))) {
				print(STDERR "$samplename :");
				foreach (sort(keys(%{$sample2blank{$samplename}}))) {
					print(STDERR "\n  $_");
				}
				print(STDERR "\n");
			}
		}
		print(STDERR "done.\n\n");
	}
}

sub readListFiles {
	print(STDERR "Reading blank and/or ignoring lists...\n");
	if (%blanklist) {
		foreach my $blanksample (keys(%blanklist)) {
			foreach my $samplename (keys(%samplenames)) {
				if (!$blanklist{$samplename}) {
					$sample2blank{$samplename}{$blanksample} = 1;
				}
			}
			$blanksamples{$blanksample} = 1;
		}
	}
	elsif ($blanklist) {
		$filehandleinput1 = &readFile($blanklist);
		my $samplename;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if (/^>(.+)$/) {
				$samplename = $1;
			}
			elsif ($samplename && /^([^>].*)$/) {
				my $blanksample = $1;
				$sample2blank{$samplename}{$blanksample} = 1;
				$blanksamples{$blanksample} = 1;
			}
			elsif (/^([^>].*)$/) {
				my $blanksample = $1;
				$blanksamples{$blanksample} = 1;
			}
		}
		close($filehandleinput1);
	}
	if (%blanksamples && !%sample2blank) {
		foreach my $tempsample (keys(%samplenames)) {
			if (!$blanksamples{$tempsample}) {
				foreach my $blanksample (keys(%blanksamples)) {
					$sample2blank{$tempsample}{$blanksample} = 1;
				}
			}
		}
	}
	if (%ignoresamplelist) {
		foreach my $ignoresample (keys(%ignoresamplelist)) {
			delete($sample2blank{$ignoresample});
		}
	}
	elsif ($ignoresamplelist) {
		foreach my $ignoresample (&readList($ignoresamplelist)) {
			delete($sample2blank{$ignoresample});
		}
	}
	if ($ignoreotulist) {
		foreach my $ignoreotu (&readList($ignoreotulist)) {
			$ignoreotulist{$ignoreotu} = 1;
		}
	}
	if ($ignoreotuseq) {
		foreach my $ignoreotu (&readSeq($ignoreotuseq)) {
			$ignoreotulist{$ignoreotu} = 1;
		}
	}
	if (%blanklist || $blanklist) {
		print(STDERR "Sample vs blank sample associtations\n");
		foreach my $samplename (sort(keys(%sample2blank))) {
			print(STDERR "$samplename :");
			foreach (sort(keys(%{$sample2blank{$samplename}}))) {
				print(STDERR "\n  $_");
			}
			print(STDERR "\n");
		}
	}
	print(STDERR "done.\n\n");
}

sub readList {
	my $listfile = shift(@_);
	my @list;
	$filehandleinput1 = &readFile($listfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
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
			push(@list, $seqname);
		}
	}
	close($filehandleinput1);
	return(@list);
}

sub removeContaminants {
	print(STDERR "Detecting and removing contaminants...\n");
	my %newtable;
	foreach my $samplename (keys(%table)) {
		foreach my $otuname (keys(%{$table{$samplename}})) {
			$newtable{$samplename}{$otuname} = $table{$samplename}{$otuname};
		}
	}
	if ($maxpjump > 0) {
		foreach my $samplename (keys(%sample2blank)) {
			foreach my $otuname (keys(%{$table{$samplename}})) {
				if (!defined($ignoreotulist{$otuname})) {
					my $sum = 0;
					foreach my $blanksample (keys(%{$sample2blank{$samplename}})) {
						if ($table{$blanksample}{$otuname} > 0) {
							$sum += $table{$blanksample}{$otuname};
						}
					}
					if ($table{$samplename}{$otuname} > 0 && $sum) {
						if ($table{$samplename}{$otuname} <= ($sum * $maxpjump)) {
							$newtable{$samplename}{$otuname} = 0;
						}
					}
				}
			}
		}
	}
	else {
		foreach my $samplename (keys(%sample2blank)) {
			foreach my $otuname (keys(%{$table{$samplename}})) {
				if (!defined($ignoreotulist{$otuname})) {
					my @nseqblank;
					foreach my $blanksample (keys(%{$sample2blank{$samplename}})) {
						if ($table{$blanksample}{$otuname} > 0) {
							push(@nseqblank, $table{$blanksample}{$otuname});
						}
					}
					if ($table{$samplename}{$otuname} > 0 && @nseqblank) {
						my $tempmax = &max(@nseqblank);
						if ($table{$samplename}{$otuname} > $tempmax) {
							if (scalar(@nseqblank) > 1) {
								if (isOutlier($table{$samplename}{$otuname}, @nseqblank)) {
									if ($mode eq 'subtractmax') {
										$newtable{$samplename}{$otuname} -= $tempmax;
									}
								}
								else {
									$newtable{$samplename}{$otuname} = 0;
								}
							}
							elsif ($mode eq 'subtractmax') {
								$newtable{$samplename}{$otuname} -= $tempmax;
							}
						}
						else {
							$newtable{$samplename}{$otuname} = 0;
						}
					}
				}
			}
		}
	}
	foreach my $samplename (keys(%newtable)) {
		foreach my $otuname (keys(%{$newtable{$samplename}})) {
			$table{$samplename}{$otuname} = $newtable{$samplename}{$otuname};
		}
	}
	print(STDERR "done.\n\n");
}

sub saveResults {
	print(STDERR "Outputing results...\n");
	foreach my $blanksample (keys(%blanksamples)) {
		delete($samplenames{$blanksample});
	}
	foreach my $otuname (keys(%otunames)) {
		my $tempsum = 0;
		foreach my $samplename (keys(%samplenames)) {
			$tempsum += $table{$samplename}{$otuname};
		}
		if ($tempsum == 0) {
			delete($otunames{$otuname});
		}
	}
	if (!mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
	}
	# save table
	{
		my @otunames = sort({$a cmp $b} keys(%otunames));
		my @samplenames = sort({$a cmp $b} keys(%samplenames));
		unless (open($filehandleoutput1, "> $outputfolder/decontaminated.tsv")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/decontaminated.tsv\".");
		}
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
	# read input fasta and save output fasta
	$filehandleoutput1 = &writeFile("$outputfolder/decontaminated.fasta");
	$filehandleinput1 = &readFile($inputfiles[0]);
	{
		my $otuname;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;*//g;
			if (/^>(.+)$/) {
				$otuname = $1;
			}
			if ($otuname && $otunames{$otuname}) {
				print($filehandleoutput1 "$_\n");
			}
		}
	}
	close($filehandleinput1);
	close($filehandleoutput1);
	# read input OTU file and save output OTU file
	$filehandleoutput1 = &writeFile("$outputfolder/decontaminated.otu.gz");
	$filehandleinput1 = &readFile($otufiles[0]);
	{
		my $otuname;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;*//g;
			if (/^>(.+)$/) {
				$otuname = $1;
				print($filehandleoutput1 "$_\n");
			}
			elsif ($otuname && $otunames{$otuname} && / SN:(\S+)/) {
				my $samplename = $1;
				if ($samplename && $samplenames{$samplename} && $table{$samplename}{$otuname} > 0) {
					print($filehandleoutput1 "$_\n");
					$table{$samplename}{$otuname} --;
				}
			}
		}
	}
	close($filehandleinput1);
	close($filehandleoutput1);
	print(STDERR "done.\n\n");
}

sub max {
	my $max = 0;
	foreach (@_) {
		if ($_ > $max) {
			$max = $_;
		}
	}
	return($max);
}

sub isOutlier {
	# Modified Thompson Tau test
	my $currentabundance = $_[0];
	my $samplesize = scalar(@_);
	my $mean = &mean($samplesize, @_);
	my $stdev = &stdev($samplesize, $mean, @_);
	my $currentdeviation = abs($currentabundance - $mean);
	my $t = Statistics::Distributions::tdistr(($samplesize - 2), $siglevel);
	if ($currentdeviation > (($t * ($samplesize - 1)) / (sqrt($samplesize) * sqrt($samplesize - 2 + ($t ** 2)))) * $stdev) {
		return(1);
	}
	else {
		return(0);
	}
}

sub mean {
	my $samplesize = shift(@_);
	if ($samplesize > 1) {
		my $sum = 0;
		foreach (@_) {
			$sum += $_;
		}
		return($sum / $samplesize);
	}
	else {
		&errorMessage(__LINE__, "Invalid data.");
	}
}

sub stdev {
	my $samplesize = shift(@_);
	if ($samplesize > 1) {
		my $mean = shift(@_);
		my $temp = 0;
		foreach (@_) {
			$temp += ($_ - $mean) ** 2;
		}
		return(sqrt($temp / ($samplesize - 1)));
	}
	else {
		&errorMessage(__LINE__, "Invalid data.");
	}
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

sub reversecomplement {
	my @temp = split('', $_[0]);
	my @seq;
	foreach my $seq (reverse(@temp)) {
		$seq =~ tr/ACGTMRYKVHDBacgtmrykvhdb/TGCAKYRMBDHVtgcakyrmbdhv/;
		push(@seq, $seq);
	}
	return(join('', @seq));
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
clremovecontam options inputfolder outputfolder
clremovecontam options inputfile outputfolder

Command line options
====================
--mode=ELIMINATE|SUBTRACTMAX
  Specify run mode. (default: ELIMINATE)

--siglevel=DECIMAL
  Specify significance level for modified Thompson Tau test. (default: 0.05)

--maxpjump=DECIMAL
  Specify the maximum percentage threshold of tag jump. (default: none)

--blank=SAMPLENAME,...,SAMPLENAME
  Specify blank sample names. (default: none)

--blanklist=FILENAME
  Specify file name of blank sample list. (default: none)

--ignoresample=SAMPLENAME,...,SAMPLENAME
  Specify ignoring sample names. (default: none)

--ignoresamplelist=FILENAME
  Specify file name of ignoring sample list. (default: none)

--ignoreotu=SAMPLENAME,...,SAMPLENAME
  Specify ignoring otu names. (default: none)

--ignoreotulist=FILENAME
  Specify file name of ignoring otu list. (default: none)

--ignoreotuseq=FILENAME
  Specify file name of ignoring otu list. (default: none)

-t, --tagfile=FILENAME
  Specify tag list file name. (default: none)

--reversetagfile=FILENAME
  Specify reverse tag list file name. (default: none)

--index1file=FILENAME
  Specify index1 file name for Illumina data. (default: none)

--index2file=FILENAME
  Specify index2 file name for Illumina data. (default: none)

--tagjump=HALF|FULL
  Specify tag jump assumption. (default: HALF)

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: MATRIX)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, or bzip2-compressed)
_END
	exit;
}
