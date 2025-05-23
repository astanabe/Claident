use strict;
use Fcntl ':flock';
use File::Spec;
use Math::CDF;

my $buildno = '0.9.x';

# input/output
my @inputfiles;
my @otufiles;
my $outputfolder;
my $stdconctable;
my $solutionvoltable;
my $watervoltable;

# options
my $tagfile;
my $reversetagfile;
my $reversecomplement;
my $pjump1;
my $pjump2;
my $test = 'thompson';
my $siglevel = 0.05;
my $adjust = 'bonferroni';
my $fwerunit = 'otu';
my $model;
my $numthreads = 1;
my $tableformat = 'matrix';
my $nodel;
my $stdconc;
my $solutionvol;
my $watervol;

# commands
my $Rscript;
my $clestimateconc;

# the other global variables
my $devnull = File::Spec->devnull();
my %table;
my %removed;
my %otusiglevel;
my %pjump;
my %pjump2;
my %tag;
my $taglength;
my $ntags;
my %reversetag;
my $reversetaglength;
my $nreversetags;
my %blanklist;
my %ignoresamplelist;
my %ignoreotulist;
my $blanklist;
my $ignoresamplelist;
my $ignoreotulist;
my $ignoreotuseq;
my %samplenames;
my %sample2blank;
my %sample2sample;
my %blanksamples;
my %blank2sample;
my %otunames;

# file handles
my $filehandleinput1;
my $filehandleinput2;
my $filehandleinput3;
my $filehandleoutput1;
my $filehandleoutput2;
my $filehandleoutput3;
my $filehandleoutput4;
my $filehandleoutput5;
my $filehandleoutput6;
my $filehandleoutput7;
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

Copyright (C) 2011-XXXX  Akifumi S. Tanabe

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
		elsif ($ARGV[$i] =~ /^-+test=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:thompson|t)$/i) {
				$test = 'thompson';
			}
			elsif ($value =~ /^(?:binomial|b)$/i) {
				$test = 'binomial';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+adjust=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:bonferroni|b)$/i) {
				$adjust = 'bonferroni';
			}
			elsif ($value =~ /^(?:none)$/i) {
				$adjust = 'none';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:fwer|fwerunit)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:all|whole)$/i) {
				$fwerunit = 'whole';
			}
			elsif ($value =~ /^otu$/i) {
				$fwerunit = 'otu';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:mode|m)=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:eliminate|e)$/i) {
				next;
			}
			elsif ($value =~ /^(?:subtractmax|s)$/i) {
				&errorMessage(__LINE__, "\"--mode=subtractmax\" option is obsolete.");
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+model=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:2|bivariate|double|dual|separate)$/i) {
				$model = 'separate';
			}
			elsif ($value =~ /^(?:1|univariate|single)$/i) {
				$model = 'single';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:r|rate|p|percentage)(?:jump|hop|hopping)=(.+)$/i) {
			my @pjump = split(/,/, $1);
			if (scalar(@pjump) > 2) {
				&errorMessage(__LINE__, "Too many pjumps were given.");
			}
			$pjump1 = $pjump[0];
			if ($pjump[1]) {
				$pjump2 = $pjump[1];
			}
			else {
				$pjump2 = $pjump[0];
			}
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
		elsif ($ARGV[$i] =~ /^-+(?:std|standard)conc=(.+)$/i) {
			$stdconc = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:std|standard)conctable=(.+)$/i) {
			$stdconctable = $1;
		}
		elsif ($ARGV[$i] =~ /^-+solution(?:vol|volume)=(.+)$/i) {
			$solutionvol = $1;
		}
		elsif ($ARGV[$i] =~ /^-+solution(?:vol|volume)table=(.+)$/i) {
			$solutionvoltable = $1;
		}
		elsif ($ARGV[$i] =~ /^-+water(?:vol|volume)=(.+)$/i) {
			$watervol = $1;
		}
		elsif ($ARGV[$i] =~ /^-+water(?:vol|volume)table=(.+)$/i) {
			$watervoltable = $1;
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
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+nodel$/i) {
			$nodel = 1;
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
	if (scalar(@inputfiles) != scalar(@otufiles)) {
		&errorMessage(__LINE__, "The number of input files is different from the number of otu files.");
	}
	if ($pjump1 > 0.1 || $pjump2 > 0.1) {
		&errorMessage(__LINE__, "Specified tag jump probability is invalid.");
	}
	if ($test eq 'thompson') {
		if (!defined($model)) {
			$model = 'single';
		}
		elsif ($model eq 'separate') {
			&errorMessage(__LINE__, "Modified Thompson Tau test does not support separate model.");
		}
		if ($pjump1 || $pjump2) {
			&errorMessage(__LINE__, "Modified Thompson Tau test does not support tag jump probability.");
		}
	}
	elsif ($test eq 'binomial') {
		if (%blanklist || $blanklist) {
			if (!defined($model)) {
				$model = 'single';
			}
			elsif ($model eq 'separate') {
				&errorMessage(__LINE__, "Decontamination using blank samples does not support separate model.");
			}
		}
		else {
			if (!defined($model) && !$pjump1 && !$pjump2) {
				$model = 'separate';
			}
			elsif (!defined($model) && $pjump1 && $pjump2 && $pjump1 != $pjump2) {
				$model = 'separate';
			}
			elsif (!defined($model) && $pjump1 && $pjump2 && $pjump1 == $pjump2) {
				$model = 'single';
			}
			elsif ($model eq 'single' && !$pjump1 && !$pjump2) {
				&errorMessage(__LINE__, "Removal of tag jump does not support single model probability estimation.");
			}
			elsif ($model eq 'separate' && $pjump1 && $pjump2 && $pjump1 == $pjump2) {
				&errorMessage(__LINE__, "Separate model was selected but forward and reverse tag jump probabilities are the same.");
			}
		}
	}
	if (scalar(@inputfiles) > 1) {
		&errorMessage(__LINE__, "Too many inputs were given.");
	}
#	if (%blanklist && $blanklist) {
#		&errorMessage(__LINE__, "Both blank sample list and blank sample file were given.");
#	}
#	if (%ignoresamplelist && $ignoresamplelist) {
#		&errorMessage(__LINE__, "Both ignoring sample list and ignoring sample file were given.");
#	}
#	if (%ignoreotulist && $ignoreotulist) {
#		&errorMessage(__LINE__, "Both ignoring otu list and ignoring otu file were given.");
#	}
#	if (%ignoreotulist && $ignoreotuseq) {
#		&errorMessage(__LINE__, "Both ignoring otu list and ignoring otu sequence file were given.");
#	}
#	if ($ignoreotulist && $ignoreotuseq) {
#		&errorMessage(__LINE__, "Both ignoring otu file and ignoring otu sequence file were given.");
#	}
	if ($ignoreotulist && !-e $ignoreotulist) {
		&errorMessage(__LINE__, "\"$ignoreotulist\" does not exist.");
	}
	if ($ignoreotuseq && !-e $ignoreotuseq) {
		&errorMessage(__LINE__, "\"$ignoreotuseq\" does not exist.");
	}
	if ((%blanklist || $blanklist) && $pjump1) {
		&errorMessage(__LINE__, "Fixed contamination probability cannot be used in decontamination.");
	}
	if (($tagfile || $reversetagfile) && (%blanklist || $blanklist)) {
		&errorMessage(__LINE__, "Decontamination and removal of tag jump cannot be applied at the same time.");
	}
	if ($tagfile && !$reversetagfile || !$tagfile && $reversetagfile) {
		&errorMessage(__LINE__, "Both forward and reverse tags (dual index) must be given.");
	}
	if (!%blanklist && !$blanklist && (!$tagfile || !$reversetagfile)) {
		&errorMessage(__LINE__, "Both blank list and forward/reverse tags were not given.");
	}
	if ((%blanklist || $blanklist) && ($stdconc || $stdconctable)) {
		if (($solutionvol || $solutionvoltable) && (!$watervol && !$watervoltable)) {
			&errorMessage(__LINE__, "DNA concentration of internal standard and total volume of DNA solution were given, but filtered water volume was lacking.");
		}
		elsif (($watervol || $watervoltable) && (!$solutionvol && !$solutionvoltable)) {
			&errorMessage(__LINE__, "DNA concentration of internal standard and filtered water volume were given, but total volume of DNA solution was lacking.");
		}
		if ($test eq 'binomial') {
			&errorMessage(__LINE__, "Binomial test-based decontamination cannot be applied for estimated DNA concentration.");
		}
	}
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if (!mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
	}
	if (%blanklist || $blanklist) {
		print(STDERR "Decontamination using blank samples will be performed ");
		if ($test eq 'thompson') {
			print(STDERR "based on one-sided modified Thompson Tau test.\n");
			if ($stdconc || $stdconctable) {
				if (($solutionvol || $solutionvoltable) && ($watervol || $watervoltable)) {
					print(STDERR "DNA concentration of internal standard, total volume of DNA solution and filtered water volume were given.\n");
					print(STDERR "Thus, DNA concentration of filtered water will be estimated and decontamination will be performed based on estimated DNA concentration of filtered water.\n");
				}
				else {
					print(STDERR "DNA concentration of internal standard was given.\n");
					print(STDERR "Thus, DNA concentration of extracted DNA solution will be estimated and decontamination will be performed based on estimated DNA concentration of extracted DNA solution.\n");
				}
			}
		}
		elsif ($test eq 'binomial') {
			print(STDERR "based on binomial test");
			if (!$pjump1) {
				print(STDERR " with estimation of optimal contamination probability.\n");
			}
			else {
				print(STDERR ".\n");
			}
		}
	}
	else {
		print(STDERR "Removal of tag jumps will be performed ");
		if ($test eq 'thompson') {
			print(STDERR "based on one-sided modified Thompson Tau test.\n");
		}
		elsif ($test eq 'binomial') {
			print(STDERR "based on binomial test");
			if (!$pjump1) {
				print(STDERR " with estimation of optimal tag jump probability.\n");
			}
			else {
				print(STDERR " with fixed tag jump probability ($pjump1, $pjump2).\n");
			}
			if ($model eq 'separate') {
				print(STDERR "Forward and reverse tag jump probability will be estimated separately.\n");
			}
		}
	}
	if ($adjust eq 'bonferroni') {
		print(STDERR "Significance level is $siglevel but will be adjusted based on Bonferroni method.\n");
		if ($fwerunit eq 'whole') {
			print(STDERR "Family-wise error rate will be controlled in whole data.\n");
		}
		elsif ($fwerunit eq 'otu') {
			print(STDERR "Family-wise error rate will be controlled in each OTU.\n");
		}
	}
	else {
		print(STDERR "Significance level is $siglevel and will not be adjusted.\n");
	}
	# search R
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
			$Rscript = "\"$pathto/Rscript\"";
			$pathto =~ s/\/bin$/\/..\/..\/bin/;
			if (!-e $pathto) {
				&errorMessage(__LINE__, "Cannot find \"$pathto\".");
			}
			$clestimateconc = "\"$pathto/clestimateconc\"";
		}
		else {
			$Rscript = 'Rscript';
			$clestimateconc = 'clestimateconc';
		}
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
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.*)/s) {
				my $name = $1;
				my $tag = uc($2);
				if ($tag) {
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
					if ($line =~ /^>?\s*(\S[^\r\n]*)\r?\n(.*)\r?\n?/s) {
						my $reversetag = uc($2);
						$reversetag =~ s/[^A-Z]//sg;
						if ($reversetag) {
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
			$ntags = scalar(@temptags);
			$nreversetags = scalar(@tempreversetags);
			print(STDERR "Sample vs contaminant source sample associtations\n");
			{
				my %reversejump;
				my %forwardjump;
				foreach my $temptag (@temptags) {
					foreach my $tempreversetag (@tempreversetags) {
						my $tagseq = "$temptag+$tempreversetag";
						if (!exists($tag{$tagseq})) {
							push(@{$reversejump{$temptag}}, $tagseq);
							push(@{$forwardjump{$tempreversetag}}, $tagseq);
						}
						else {
							push(@{$reversejump{$temptag}}, $tag{$tagseq});
							push(@{$forwardjump{$tempreversetag}}, $tag{$tagseq});
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
										foreach my $blanktag (@{$reversejump{$temptag}}) {
											if ($blanktag =~ /^[ACGT]+\+[ACGT]+$/) {
												$sample2blank{$samplename}{'reversejump'}{"$runname\__$blanktag\__$primer"} = 1;
												$blanksamples{"$runname\__$blanktag\__$primer"} = 1;
												$blank2sample{"$runname\__$blanktag\__$primer"}{'reversejump'}{$samplename} = 1;
											}
											elsif ($samplename ne "$runname\__$blanktag\__$primer") {
												$sample2sample{$samplename}{'reversejump'}{"$runname\__$blanktag\__$primer"} = 1;
											}
										}
										foreach my $blanktag (@{$forwardjump{$tempreversetag}}) {
											if ($blanktag =~ /^[ACGT]+\+[ACGT]+$/) {
												$sample2blank{$samplename}{'forwardjump'}{"$runname\__$blanktag\__$primer"} = 1;
												$blanksamples{"$runname\__$blanktag\__$primer"} = 1;
												$blank2sample{"$runname\__$blanktag\__$primer"}{'forwardjump'}{$samplename} = 1;
											}
											elsif ($samplename ne "$runname\__$blanktag\__$primer") {
												$sample2sample{$samplename}{'forwardjump'}{"$runname\__$blanktag\__$primer"} = 1;
											}
										}
									}
								}
							}
						}
					}
				}
			}
			my %tempsamples;
			foreach my $samplename (keys(%sample2blank)) {
				$tempsamples{$samplename} = 1;
			}
			foreach my $samplename (keys(%sample2sample)) {
				$tempsamples{$samplename} = 1;
			}
			foreach my $samplename (sort(keys(%tempsamples))) {
				print(STDERR "$samplename :");
				print(STDERR "\nForward tag sharing / reverse tag jumped samples :");
				if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'reversejump'})) {
					foreach (sort(keys(%{$sample2blank{$samplename}{'reversejump'}}))) {
						print(STDERR "\n  Blank : $_");
					}
				}
				if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{'reversejump'})) {
					foreach (sort(keys(%{$sample2sample{$samplename}{'reversejump'}}))) {
						print(STDERR "\n  Sample : $_");
					}
				}
				print(STDERR "\nReverse tag sharing / forward tag jumped samples :");
				if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'forwardjump'})) {
					foreach (sort(keys(%{$sample2blank{$samplename}{'forwardjump'}}))) {
						print(STDERR "\n  Blank : $_");
					}
				}
				if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{'forwardjump'})) {
					foreach (sort(keys(%{$sample2sample{$samplename}{'forwardjump'}}))) {
						print(STDERR "\n  Sample : $_");
					}
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
					$blank2sample{$blanksample}{$samplename} = 1;
				}
			}
			$blanksamples{$blanksample} = 1;
		}
	}
	if ($blanklist) {
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
				$blank2sample{$blanksample}{$samplename} = 1;
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
					$blank2sample{$blanksample}{$tempsample} = 1;
				}
			}
		}
	}
	if ($ignoresamplelist) {
		foreach my $ignoresample (&readList($ignoresamplelist)) {
			$ignoresamplelist{$ignoresample} = 1;
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
		my %nblanks;
		print(STDERR "Sample vs blank sample associtations\n");
		foreach my $samplename (sort(keys(%sample2blank))) {
			$nblanks{$samplename} = 0;
			print(STDERR "$samplename :");
			foreach (sort(keys(%{$sample2blank{$samplename}}))) {
				$nblanks{$samplename} ++;
				print(STDERR "\n  $_");
			}
			print(STDERR "\n");
		}
		if ($test eq 'thompson') {
			foreach my $samplename (keys(%nblanks)) {
				if ($nblanks{$samplename} <= 1) {
					&errorMessage(__LINE__, "\"$samplename\" have $nblanks{$samplename} associated blank. Modified Thompson Tau test requires 2 or more blanks.");
				}
			}
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
	# case of decontamination using blank samples
	if (%blanklist || $blanklist) {
		if ($test eq 'thompson') {
			if ($stdconc || $stdconctable) {
				# estimate concentration
				&estimateConcentration();
			}
			&performModifiedThompsonTauTest();
		}
		elsif ($test eq 'binomial') {
			# estimate maximum contamination probability from data if contamination probability is not given
			if (!$pjump1) {
				&estimateContaminationProbability();
			}
			# perform binomial test using estimated contamination probability
			&performBinomialTest1();
		}
	}
	# case of removal of tag jump (index hopping)
	else {
		if ($test eq 'thompson') {
			&performModifiedThompsonTauTest();
		}
		elsif ($test eq 'binomial') {
			# estimate tag jump probability from data if tag jump probability is not given
			if ($pjump1 && $pjump2 && $tagfile && $reversetagfile) {
				&calculateTagJumpProbability();
			}
			elsif (!$pjump1 && !$pjump2 && $tagfile && $reversetagfile) {
				&estimateTagJumpProbability();
			}
			# perform binomial test using estimated tag jump probability
			&performBinomialTest2();
		}
	}
	# search result files and renew data table
	foreach my $samplename (keys(%samplenames)) {
		while (my $tempfile = glob("$outputfolder/$samplename.*.temp")) {
			$filehandleinput1 = &readFile($tempfile);
			while (<$filehandleinput1>) {
				if (/^$samplename\t(\S+)\t(\d+)/) {
					$table{$samplename}{$1} = $2;
					$removed{$samplename}{$1} = 1;
				}
			}
			close($filehandleinput1);
			unless ($nodel) {
				unlink($tempfile);
			}
		}
	}
	print(STDERR "done.\n\n");
}

sub estimateConcentration {
	print(STDERR "Estimating concentration based on number of sequences of internal standard...\n");
	my @samplenames = keys(%sample2blank);
	my @otunames = keys(%otunames);
	my @blanksamples = keys(%blank2sample);
	# make temporary community table file
	$filehandleoutput1 = &writeFile("$outputfolder/temptable.tsv");
	print($filehandleoutput1 "samplename\t". join("\t", @otunames) . "\n");
	foreach my $samplename (@samplenames, @blanksamples) {
		if (!$ignoresamplelist{$samplename}) {
			print($filehandleoutput1 "$samplename");
			foreach my $otuname (@otunames) {
				if ($table{$samplename}{$otuname} > 0) {
					print($filehandleoutput1 "\t" . $table{$samplename}{$otuname});
				}
				else {
					print($filehandleoutput1 "\t0");
				}
			}
			print($filehandleoutput1 "\n");
		}
	}
	close($filehandleoutput1);
	# perform concentration estimation
	my $clestimateconcoption;
	if ($stdconctable) {
		$clestimateconcoption .= " --stdconctable=$stdconctable";
	}
	elsif ($stdconc) {
		$clestimateconcoption .= " --stdconc=$stdconc";
	}
	else {
		&errorMessage(__LINE__, "Concentrations of internal standards were not given.");
	}
	if ($solutionvoltable) {
		$clestimateconcoption .= " --solutionvoltable=$solutionvoltable";
	}
	elsif ($solutionvol) {
		$clestimateconcoption .= " --solutionvol=$solutionvol";
	}
	else {
		$clestimateconcoption .= " --solutionvol=1";
	}
	if ($watervoltable) {
		$clestimateconcoption .= " --watervoltable=$watervoltable";
	}
	elsif ($watervol) {
		$clestimateconcoption .= " --watervol=$watervol";
	}
	else {
		$clestimateconcoption .= " --watervol=1";
	}
	if ($nodel) {
		$clestimateconcoption .= " --nodel";
	}
	if (system("$clestimateconc$clestimateconcoption --numthreads=$numthreads $outputfolder/temptable.tsv $outputfolder/estimatedconc.tsv 1> $devnull 2> $outputfolder/estimateconc.log")) {
		&errorMessage(__LINE__, "Cannot run \"$clestimateconc$clestimateconcoption --numthreads=$numthreads $outputfolder/temptable.tsv $outputfolder/estimatedconc.tsv\".");
	}
	unless ($nodel) {
		unlink("$outputfolder/temptable.tsv");
	}
}

sub estimateContaminationProbability {
	print(STDERR "Estimating contamination probability...\n");
	my @samplenames = keys(%sample2blank);
	my @otunames;
	foreach my $otuname (keys(%otunames)) {
		if (!defined($ignoreotulist{$otuname})) {
			push(@otunames, $otuname);
		}
	}
	my @blanksamples = keys(%blank2sample);
	# make temporary community table file
	$filehandleoutput1 = &writeFile("$outputfolder/temptable.tsv");
	print($filehandleoutput1 "samplename\t". join("\t", @otunames) . "\n");
	foreach my $samplename (@samplenames, @blanksamples) {
		print($filehandleoutput1 "$samplename");
		foreach my $otuname (@otunames) {
			if ($table{$samplename}{$otuname} > 0) {
				print($filehandleoutput1 "\t" . $table{$samplename}{$otuname});
			}
			else {
				print($filehandleoutput1 "\t0");
			}
		}
		print($filehandleoutput1 "\n");
	}
	close($filehandleoutput1);
	# perform estimation in parallel
	{
		my %pid;
		my $child = 0;
		my $nchild = 1;
		$| = 1;
		$? = 0;
		foreach my $blanksample (@blanksamples) {
			if (my $pid = fork()) {
				$pid{$pid} = $child;
				if ($nchild == $numthreads) {
					my $endpid = wait();
					while (!exists($pid{$endpid}) && $endpid != -1) {
						$endpid = wait();
					}
					if (exists($pid{$endpid})) {
						$child = $pid{$endpid};
						delete($pid{$endpid});
					}
					elsif ($endpid == -1) {
						$child = 0;
					}
				}
				elsif ($nchild < $numthreads) {
					$child = $nchild;
					$nchild ++;
				}
				if ($?) {
					die(__LINE__);
				}
				next;
			}
			else {
				print(STDERR "\"$blanksample\"...\n");
				$filehandleoutput1 = &writeFile("$outputfolder/$blanksample.pjump.R");
				print($filehandleoutput1 "blanksample <- \"$blanksample\"\n");
				print($filehandleoutput1 "blank2sample <- c(\n\"");
				if (exists($blank2sample{$blanksample})) {
					print($filehandleoutput1 join("\",\n\"", keys(%{$blank2sample{$blanksample}})));
				}
				else {
					&errorMessage(__LINE__, "Unknown error.");
				}
				print($filehandleoutput1 "\"\n)\n");
				print($filehandleoutput1 <<"_END");
table <- read.delim(\"$outputfolder/temptable.tsv\", header=T, row.names=1, check.names=F)
nothers <- length(rownames(table)) - 1
tempsum <- sum(table[blanksample,], na.rm=T)
calcResidualSum <- function (x) {
	pjump <- x
	temppjump <- (pjump / (1 - pjump))
	residualsum <- tempsum - sum((table[blank2sample,] * temppjump) / nothers, na.rm=T)
	abs(residualsum)
}
fit <- optimize(calcResidualSum, interval=c(0, 0.1), maximum=F, tol=1e-9)
print(fit\$minimum)
_END
				close($filehandleoutput1);
				if (system("$Rscript --vanilla $outputfolder/$blanksample.pjump.R 1> $outputfolder/$blanksample.pjump.txt 2> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla $outputfolder/$blanksample.pjump.R 1> $outputfolder/$blanksample.pjump.txt\".");
				}
				unless ($nodel) {
					unlink("$outputfolder/$blanksample.pjump.R");
				}
				exit;
			}
		}
		# join
		while (wait != -1) {
			if ($?) {
				die(__LINE__);
			}
		}
	}
	my $maxpjump;
	foreach my $blanksample (@blanksamples) {
		unless (open($filehandleinput1, "< $outputfolder/$blanksample.pjump.txt")) {
			&errorMessage(__LINE__, "Cannot read \"$outputfolder/$blanksample.pjump.txt\".");
		}
		my $temppjump;
		while (<$filehandleinput1>) {
			if (/ (\d*\.\d+(?:e\-\d+)?)/i) {
				$temppjump = eval($1);
				last;
			}
		}
		if ($temppjump && $temppjump > $maxpjump) {
			$maxpjump = $temppjump;
		}
		elsif (!defined($temppjump)) {
			&errorMessage(__LINE__, "Cannot get contamination probability for $blanksample.");
		}
		close($filehandleinput1);
		unless ($nodel) {
			unlink("$outputfolder/$blanksample.pjump.txt");
		}
	}
	unless ($nodel) {
		unlink("$outputfolder/temptable.tsv");
	}
	if (!defined($maxpjump)) {
		&errorMessage(__LINE__, "Cannot get maximum contamination probability.");
	}
	print(STDERR "The estimated maximum contamination probability is ");
	printf(STDERR "%.10f.\n", $maxpjump);
	$pjump1 = $maxpjump;
	$pjump2 = $pjump2;
}

sub calculateTagJumpProbability {
	print(STDERR "Calculating tag jump probability...\n");
	my @samplenames;
	foreach my $samplename (sort(keys(%samplenames))) {
		if (exists($sample2blank{$samplename}) || exists($sample2sample{$samplename})) {
			push(@samplenames, $samplename);
		}
	}
	my @otunames;
	foreach my $otuname (keys(%otunames)) {
		if (!defined($ignoreotulist{$otuname})) {
			push(@otunames, $otuname);
		}
	}
	# calculate tag jump probability to other tags
	foreach my $samplename (@samplenames) {
		foreach my $type ('reversejump', 'forwardjump') {
			if (!exists($pjump{$samplename}{$type})) {
				my $samplenseq = 0;
				foreach my $otuname (@otunames) {
					if ($table{$samplename}{$otuname} > 0) {
						$samplenseq += $table{$samplename}{$otuname};
					}
					if ($type eq 'reversejump') {
						$samplenseq += &calcfsum($samplename, $otuname);
					}
					elsif ($type eq 'forwardjump') {
						$samplenseq += &calcrsum($samplename, $otuname);
					}
				}
				my $othernseq = 0;
				if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{$type})) {
					foreach my $tempsample (keys(%{$sample2blank{$samplename}{$type}})) {
						foreach my $otuname (@otunames) {
							if ($table{$tempsample}{$otuname} > 0) {
								$othernseq += $table{$tempsample}{$otuname};
							}
							if ($type eq 'reversejump') {
								$othernseq += &calcfsum($tempsample, $otuname);
							}
							elsif ($type eq 'forwardjump') {
								$othernseq += &calcrsum($tempsample, $otuname);
							}
						}
					}
				}
				if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{$type})) {
					foreach my $tempsample (keys(%{$sample2sample{$samplename}{$type}})) {
						foreach my $otuname (@otunames) {
							if ($table{$tempsample}{$otuname} > 0) {
								$othernseq += $table{$tempsample}{$otuname};
							}
							if ($type eq 'reversejump') {
								$othernseq += &calcfsum($tempsample, $otuname);
							}
							elsif ($type eq 'forwardjump') {
								$othernseq += &calcrsum($tempsample, $otuname);
							}
						}
					}
				}
				if ($type eq 'reversejump' && $samplenseq && $othernseq) {
					$pjump{$samplename}{$type} = $pjump1 * ($samplenseq / ($samplenseq + $othernseq)) * ($othernseq / ($samplenseq + $othernseq));
				}
				elsif ($type eq 'forwardjump' && $samplenseq && $othernseq) {
					$pjump{$samplename}{$type} = $pjump2 * ($samplenseq / ($samplenseq + $othernseq)) * ($othernseq / ($samplenseq + $othernseq));
				}
				else {
					$pjump{$samplename}{$type} = 0;
				}
				if ($type eq 'reversejump') {
					if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'forwardjump'})) {
						foreach my $tempsample (keys(%{$sample2blank{$samplename}{'forwardjump'}})) {
							if (exists($pjump{$tempsample}{$type})) {
								&errorMessage(__LINE__, "Unknown error.");
							}
							else {
								$pjump{$tempsample}{$type} = $pjump{$samplename}{$type};
							}
						}
					}
					if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{'forwardjump'})) {
						foreach my $tempsample (keys(%{$sample2sample{$samplename}{'forwardjump'}})) {
							if (exists($pjump{$tempsample}{$type})) {
								&errorMessage(__LINE__, "Unknown error.");
							}
							else {
								$pjump{$tempsample}{$type} = $pjump{$samplename}{$type};
							}
						}
					}
				}
				elsif ($type eq 'forwardjump') {
					if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'reversejump'})) {
						foreach my $tempsample (keys(%{$sample2blank{$samplename}{'reversejump'}})) {
							if (exists($pjump{$tempsample}{$type})) {
								&errorMessage(__LINE__, "Unknown error.");
							}
							else {
								$pjump{$tempsample}{$type} = $pjump{$samplename}{$type};
							}
						}
					}
					if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{'reversejump'})) {
						foreach my $tempsample (keys(%{$sample2sample{$samplename}{'reversejump'}})) {
							if (exists($pjump{$tempsample}{$type})) {
								&errorMessage(__LINE__, "Unknown error.");
							}
							else {
								$pjump{$tempsample}{$type} = $pjump{$samplename}{$type};
							}
						}
					}
				}
			}
		}
	}
}

sub estimateTagJumpProbability {
	print(STDERR "Estimating tag jump probability...\n");
	my @samplenames = keys(%sample2blank);
	my @otunames;
	foreach my $otuname (keys(%otunames)) {
		if (!defined($ignoreotulist{$otuname})) {
			push(@otunames, $otuname);
		}
	}
	my @blanksamples = keys(%blank2sample);
	# make temporary community table file
	$filehandleoutput1 = &writeFile("$outputfolder/temptable.tsv");
	print($filehandleoutput1 "samplename\t". join("\t", @otunames) . "\n");
	foreach my $samplename (@samplenames, @blanksamples) {
		print($filehandleoutput1 "$samplename");
		foreach my $otuname (@otunames) {
			if ($table{$samplename}{$otuname} > 0) {
				print($filehandleoutput1 "\t" . $table{$samplename}{$otuname});
			}
			else {
				print($filehandleoutput1 "\t0");
			}
		}
		print($filehandleoutput1 "\n");
	}
	close($filehandleoutput1);
	# perform estimation in parallel
	{
		my %pid;
		my $child = 0;
		my $nchild = 1;
		$| = 1;
		$? = 0;
		foreach my $samplename (@samplenames) {
			print(STDERR "\"$samplename\"...\n");
			foreach my $type ('reversejump', 'forwardjump') {
				if (my $pid = fork()) {
					$pid{$pid} = $child;
					if ($nchild == $numthreads) {
						my $endpid = wait();
						while (!exists($pid{$endpid}) && $endpid != -1) {
							$endpid = wait();
						}
						if (exists($pid{$endpid})) {
							$child = $pid{$endpid};
							delete($pid{$endpid});
						}
						elsif ($endpid == -1) {
							$child = 0;
						}
					}
					elsif ($nchild < $numthreads) {
						$child = $nchild;
						$nchild ++;
					}
					if ($?) {
						die(__LINE__);
					}
					next;
				}
				else {
					if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{$type})) {
						my @blank = sort({$a cmp $b} keys(%{$sample2blank{$samplename}{$type}}));
						if (!-e "$outputfolder/$blank[0].p$type.txt") {
							# make a file
							unless (open($filehandleoutput1, "+>> $outputfolder/$blank[0].p$type.txt")) {
								&errorMessage(__LINE__, "Cannot make \"$outputfolder/$blank[0].p$type.txt\".");
							}
							unless (flock($filehandleoutput1, LOCK_EX|LOCK_NB)) {
								exit;
							}
							unless (seek($filehandleoutput1, 0, 2)) {
								&errorMessage(__LINE__, "Cannot seek \"$outputfolder/$blank[0].p$type.txt\".");
							}
							my $pjump;
							my $dummy;
							# estimate tag jump probability
							if ($type eq 'reversejump') {
								($dummy, $pjump) = &estimatepjump($type, @blank);
							}
							elsif ($type eq 'forwardjump') {
								($pjump, $dummy) = &estimatepjump($type, @blank);
							}
							# save to file
							printf($filehandleoutput1 "%.10f\n", $pjump);
							close($filehandleoutput1);
						}
					}
					exit;
				}
			}
		}
		# join
		while (wait != -1) {
			if ($?) {
				die(__LINE__);
			}
		}
	}
	# retrieve estimation results and store to hash
	foreach my $samplename (@samplenames) {
		foreach my $type ('reversejump', 'forwardjump') {
			if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{$type})) {
				my @blank = sort({$a cmp $b} keys(%{$sample2blank{$samplename}{$type}}));
				$filehandleinput1 = &readFile("$outputfolder/$blank[0].p$type.txt");
				while (<$filehandleinput1>) {
					if (/(\d*\.\d+(?:e\-\d+)?)/i) {
						$pjump{$samplename}{$type} = eval($1);
					}
				}
				if (!exists($pjump{$samplename}{$type})) {
					&errorMessage(__LINE__, "Cannot get tag jump probability for \"$samplename\".");
				}
				close($filehandleinput1);
			}
		}
	}
	# calculate tag jump probability to all tags including the same tag
	foreach my $samplename (@samplenames) {
		foreach my $type ('reversejump', 'forwardjump') {
			if (!exists($pjump2{$samplename}{$type})) {
				if ($pjump{$samplename}{$type} > 0) {
					my $samplenseq = 0;
					foreach my $otuname (@otunames) {
						if ($table{$samplename}{$otuname} > 0) {
							$samplenseq += $table{$samplename}{$otuname};
						}
						if ($type eq 'reversejump') {
							$samplenseq += &calcfsum($samplename, $otuname);
						}
						elsif ($type eq 'forwardjump') {
							$samplenseq += &calcrsum($samplename, $otuname);
						}
					}
					my $othernseq = 0;
					if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{$type})) {
						foreach my $tempsample (keys(%{$sample2blank{$samplename}{$type}})) {
							foreach my $otuname (@otunames) {
								if ($table{$tempsample}{$otuname} > 0) {
									$othernseq += $table{$tempsample}{$otuname};
								}
								if ($type eq 'reversejump') {
									$othernseq += &calcfsum($tempsample, $otuname);
								}
								elsif ($type eq 'forwardjump') {
									$othernseq += &calcrsum($tempsample, $otuname);
								}
							}
						}
					}
					if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{$type})) {
						foreach my $tempsample (keys(%{$sample2sample{$samplename}{$type}})) {
							foreach my $otuname (@otunames) {
								if ($table{$tempsample}{$otuname} > 0) {
									$othernseq += $table{$tempsample}{$otuname};
								}
								if ($type eq 'reversejump') {
									$othernseq += &calcfsum($tempsample, $otuname);
								}
								elsif ($type eq 'forwardjump') {
									$othernseq += &calcrsum($tempsample, $otuname);
								}
							}
						}
					}
					if ($samplenseq && $othernseq) {
						$pjump2{$samplename}{$type} = $pjump{$samplename}{$type} * (($samplenseq + $othernseq) / $samplenseq) * (($samplenseq + $othernseq) / $othernseq);
					}
					else {
						$pjump2{$samplename}{$type} = 'NA';
					}
				}
				else {
					$pjump2{$samplename}{$type} = 0;
				}
				if ($type eq 'reversejump') {
					if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'forwardjump'})) {
						foreach my $tempsample (keys(%{$sample2blank{$samplename}{'forwardjump'}})) {
							if (exists($pjump2{$tempsample}{$type})) {
								&errorMessage(__LINE__, "Unknown error.");
							}
							else {
								$pjump2{$tempsample}{$type} = $pjump2{$samplename}{$type};
							}
						}
					}
					if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{'forwardjump'})) {
						foreach my $tempsample (keys(%{$sample2sample{$samplename}{'forwardjump'}})) {
							if (exists($pjump2{$tempsample}{$type})) {
								&errorMessage(__LINE__, "Unknown error.");
							}
							else {
								$pjump2{$tempsample}{$type} = $pjump2{$samplename}{$type};
							}
						}
					}
				}
				elsif ($type eq 'forwardjump') {
					if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'reversejump'})) {
						foreach my $tempsample (keys(%{$sample2blank{$samplename}{'reversejump'}})) {
							if (exists($pjump2{$tempsample}{$type})) {
								&errorMessage(__LINE__, "Unknown error.");
							}
							else {
								$pjump2{$tempsample}{$type} = $pjump2{$samplename}{$type};
							}
						}
					}
					if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{'reversejump'})) {
						foreach my $tempsample (keys(%{$sample2sample{$samplename}{'reversejump'}})) {
							if (exists($pjump2{$tempsample}{$type})) {
								&errorMessage(__LINE__, "Unknown error.");
							}
							else {
								$pjump2{$tempsample}{$type} = $pjump2{$samplename}{$type};
							}
						}
					}
				}
			}
		}
	}
	# delete temporary files
	unless ($nodel) {
		foreach my $samplename (@samplenames) {
			foreach my $type ('reversejump', 'forwardjump') {
				if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{$type})) {
					my @blank = sort({$a cmp $b} keys(%{$sample2blank{$samplename}{$type}}));
					unlink("$outputfolder/$blank[0].p$type.txt");
				}
			}
		}
		unlink("$outputfolder/temptable.tsv");
	}
}

sub estimatepjump {
	my $preversejump;
	my $pforwardjump;
	my $type = shift(@_);
	my @blanksamples = @_;
	# make R script
	$filehandleoutput2 = &writeFile("$outputfolder/$blanksamples[0].p$type.R");
	print($filehandleoutput2 "nothertagR <- " . ($nreversetags - 1) . "\n");
	print($filehandleoutput2 "nothertagF <- " . ($ntags - 1) . "\n");
	print($filehandleoutput2 "blanksamples <- c(\n\"" . join("\",\n\"", @blanksamples) . "\"\n)\n");
	print($filehandleoutput2 "blank2sampleR <- c(\n\"");
	for (my $i = 0; $i < scalar(@blanksamples); $i ++) {
		if (%blank2sample && exists($blank2sample{$blanksamples[$i]}) && exists($blank2sample{$blanksamples[$i]}{'reversejump'})) {
			print($filehandleoutput2 join("\",\n\"", keys(%{$blank2sample{$blanksamples[$i]}{'reversejump'}})));
		}
		else {
			&errorMessage(__LINE__, "Unknown error.");
		}
		if ($i + 1 == scalar(@blanksamples)) {
			print($filehandleoutput2 "\"\n)\n");
		}
		else {
			print($filehandleoutput2 "\",\n\"");
		}
	}
	print($filehandleoutput2 "blank2sampleF <- c(\n\"");
	for (my $i = 0; $i < scalar(@blanksamples); $i ++) {
		if (%blank2sample && exists($blank2sample{$blanksamples[$i]}) && exists($blank2sample{$blanksamples[$i]}{'forwardjump'})) {
			print($filehandleoutput2 join("\",\n\"", keys(%{$blank2sample{$blanksamples[$i]}{'forwardjump'}})));
		}
		else {
			&errorMessage(__LINE__, "Unknown error.");
		}
		if ($i + 1 == scalar(@blanksamples)) {
			print($filehandleoutput2 "\"\n)\n");
		}
		else {
			print($filehandleoutput2 "\",\n\"");
		}
	}
	if ($model eq 'separate') {
		print($filehandleoutput2 <<"_END");
table <- read.delim(\"$outputfolder/temptable.tsv\", header=T, row.names=1, check.names=F)
tempsum <- sum(table[blanksamples,], na.rm=T)
calcResidualSum <- function (x) {
	preversejump <- x[1]
	pforwardjump <- x[2]
	if (preversejump < 0 || preversejump > 0.1) {
		(abs(preversejump) + 1) * 1000000
	}
	else if (pforwardjump < 0 || pforwardjump > 0.1) {
		(abs(pforwardjump) + 1) * 1000000
	}
	else {
		temppreversejump <- (preversejump / (1 - preversejump - pforwardjump))
		temppforwardjump <- (pforwardjump / (1 - preversejump - pforwardjump))
		residualsum <- tempsum - sum((table[blank2sampleR,] * temppreversejump) / nothertagR, na.rm=T) - sum((table[blank2sampleF,] * temppforwardjump) / nothertagF, na.rm=T)
		abs(residualsum)
	}
}
fit <- optim(c(0.001, 0.001), calcResidualSum, method="Nelder-Mead", control=list(trace=0, reltol=1e-9, maxit=10000))
print(fit\$par[1])
print(fit\$par[2])
print(fit\$convergence)
_END
	}
	close($filehandleoutput2);
	# run R
	unless (open($pipehandleinput1, "$Rscript --vanilla $outputfolder/$blanksamples[0].p$type.R 2> $devnull |")) {
		&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla $outputfolder/$blanksamples[0].p$type.R\".");
	}
	my $lineno = 1;
	my $convergence;
	while (<$pipehandleinput1>) {
		if ($lineno == 1 && / (\d*\.\d+(?:e\-\d+)?)/i) {
			$preversejump = eval($1);
		}
		elsif ($lineno == 2 && / (\d*\.\d+(?:e\-\d+)?)/i) {
			$pforwardjump = eval($1);
		}
		elsif ($lineno == 3 && / (\d+)/) {
			$convergence = eval($1);
			last;
		}
		$lineno ++;
	}
	close($pipehandleinput1);
	if ($convergence != 0) {
		&errorMessage(__LINE__, "Cannot optimize $type probability for $blanksamples[0].");
	}
	unless ($nodel) {
		unlink("$outputfolder/$blanksamples[0].p$type.R");
	}
	return($preversejump, $pforwardjump);
}

sub performModifiedThompsonTauTest {
	print(STDERR "Performing modified Thompson Tau test...\n");
	my @samplenames = keys(%sample2blank);
	my @otunames;
	foreach my $otuname (keys(%otunames)) {
		if (!defined($ignoreotulist{$otuname})) {
			push(@otunames, $otuname);
		}
	}
	my %estimatedtable;
	# using estimated concentration
	if ($stdconc || $stdconctable) {
		my $ncol;
		# read input file
		$filehandleinput1 = &readFile("$outputfolder/estimatedconc.tsv");
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if ($ncol) {
				my @row = split(/\t/);
				if (scalar(@row) == $ncol + 1) {
					my $samplename = shift(@row);
					for (my $i = 0; $i < scalar(@row); $i ++) {
						$estimatedtable{$samplename}{$otunames[$i]} += $row[$i];
					}
				}
				else {
					&errorMessage(__LINE__, "The input file is invalid.\nThe invalid line is \"$_\".");
				}
			}
			elsif (/^samplename\t(.+)/i) {
				@otunames = split(/\t/, $1);
				$ncol = scalar(@otunames);
			}
			else {
				&errorMessage(__LINE__, "The input file is invalid.");
			}
		}
		close($filehandleinput1);
	}
	# calculate significance level
	my $ntestwhole = 0;
	foreach my $otuname (@otunames) {
		if ($adjust eq 'bonferroni') {
			my $ntest = 0;
			foreach my $samplename (@samplenames) {
				if (!$ignoresamplelist{$samplename} && $table{$samplename}{$otuname} > 0) {
					if (($stdconc || $stdconctable) && (!defined($estimatedtable{$samplename}{$otuname}) || $estimatedtable{$samplename}{$otuname} == 0)) {
						next;
					}
					my @nseqblank;
					my @blanksamples;
					if (%sample2blank && exists($sample2blank{$samplename})) {
						@blanksamples = keys(%{$sample2blank{$samplename}});
					}
					else {
						&errorMessage(__LINE__, "There is no associated blanks for \"$samplename\".");
					}
					if (scalar(@blanksamples) == 2 && ($blanksamples[0] eq 'forwardjump' || $blanksamples[0] eq 'reversejump')) {
						my @tempblanks;
						if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'reversejump'})) {
							push(@tempblanks, keys(%{$sample2blank{$samplename}{'reversejump'}}));
						}
						else {
							&errorMessage(__LINE__, "Unknown error.");
						}
						if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'forwardjump'})) {
							push(@tempblanks, keys(%{$sample2blank{$samplename}{'forwardjump'}}));
						}
						else {
							&errorMessage(__LINE__, "Unknown error.");
						}
						@blanksamples = @tempblanks;
					}
					foreach my $blanksample (@blanksamples) {
						if ($table{$blanksample}{$otuname} > 0) {
							push(@nseqblank, $table{$blanksample}{$otuname});
						}
						else {
							push(@nseqblank, 0);
						}
					}
					if (scalar(@nseqblank) > 1) {
						$ntest ++;
					}
				}
			}
			if ($ntest) {
				if ($fwerunit eq 'otu') {
					$otusiglevel{$otuname} = $siglevel / $ntest;
				}
				elsif ($fwerunit eq 'whole') {
					$ntestwhole += $ntest;
				}
			}
		}
		else {
			$otusiglevel{$otuname} = $siglevel;
		}
	}
	if ($adjust eq 'bonferroni' && $fwerunit eq 'whole') {
		foreach my $otuname (@otunames) {
			$otusiglevel{$otuname} = $siglevel / $ntestwhole;
		}
	}
	{
		my %pid;
		my $child = 0;
		my $nchild = 1;
		$| = 1;
		$? = 0;
		foreach my $samplename (@samplenames) {
			if (!$ignoresamplelist{$samplename}) {
				print(STDERR "\"$samplename\"...\n");
				foreach my $otuname (@otunames) {
					if (my $pid = fork()) {
						$pid{$pid} = $child;
						if ($nchild == $numthreads) {
							my $endpid = wait();
							while (!exists($pid{$endpid}) && $endpid != -1) {
								$endpid = wait();
							}
							if (exists($pid{$endpid})) {
								$child = $pid{$endpid};
								delete($pid{$endpid});
							}
							elsif ($endpid == -1) {
								$child = 0;
							}
						}
						elsif ($nchild < $numthreads) {
							$child = $nchild;
							$nchild ++;
						}
						if ($?) {
							die(__LINE__);
						}
						next;
					}
					else {
						if ($table{$samplename}{$otuname} > 0) {
							if (($stdconc || $stdconctable) && (!defined($estimatedtable{$samplename}{$otuname}) || $estimatedtable{$samplename}{$otuname} == 0)) {
								print(STDERR "Estimated concentration of \"$otuname\" of \"$samplename\" is invalid. If this sample is not the subject of concentration estimation, then there is no problem. If not, check the input file.\n");
								exit;
							}
							my @nseqblank;
							my @blanksamples;
							if (%sample2blank && exists($sample2blank{$samplename})) {
								@blanksamples = keys(%{$sample2blank{$samplename}});
							}
							else {
								&errorMessage(__LINE__, "There is no associated blanks for \"$samplename\".");
							}
							if (scalar(@blanksamples) == 2 && ($blanksamples[0] eq 'forwardjump' || $blanksamples[0] eq 'reversejump')) {
								my @tempblanks;
								if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'reversejump'})) {
									push(@tempblanks, keys(%{$sample2blank{$samplename}{'reversejump'}}));
								}
								else {
									&errorMessage(__LINE__, "Unknown error.");
								}
								if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'forwardjump'})) {
									push(@tempblanks, keys(%{$sample2blank{$samplename}{'forwardjump'}}));
								}
								else {
									&errorMessage(__LINE__, "Unknown error.");
								}
								@blanksamples = @tempblanks;
							}
							foreach my $blanksample (@blanksamples) {
								if ($table{$blanksample}{$otuname} > 0) {
									if ($stdconc || $stdconctable) {
										if ($estimatedtable{$blanksample}{$otuname} > 0) {
											push(@nseqblank, $estimatedtable{$blanksample}{$otuname});
										}
										else {
											&errorMessage(__LINE__, "Estimated concentration of \"$otuname\" of \"$blanksample\" is invalid.");
										}
									}
									else {
										push(@nseqblank, $table{$blanksample}{$otuname});
									}
								}
								else {
									push(@nseqblank, 0);
								}
							}
							if ($table{$samplename}{$otuname} > 0 && scalar(@nseqblank) > 1) {
								if ($stdconc || $stdconctable) {
									if ($estimatedtable{$samplename}{$otuname} > 0) {
										unless (&isOutlier($otusiglevel{$otuname}, $estimatedtable{$samplename}{$otuname}, @nseqblank)) {
											&saveToTempFile("$outputfolder/$samplename.$child.temp", "$samplename\t$otuname\t0\n");
										}
									}
									else {
										&errorMessage(__LINE__, "Estimated concentration of \"$otuname\" of \"$samplename\" is invalid.");
									}
								}
								else {
									unless (&isOutlier($otusiglevel{$otuname}, $table{$samplename}{$otuname}, @nseqblank)) {
										&saveToTempFile("$outputfolder/$samplename.$child.temp", "$samplename\t$otuname\t0\n");
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
				die(__LINE__);
			}
		}
	}
}

sub performBinomialTest1 {
	print(STDERR "Performing binomial test...\n");
	my @samplenames = keys(%sample2blank);
	my @otunames;
	foreach my $otuname (keys(%otunames)) {
		if (!defined($ignoreotulist{$otuname})) {
			push(@otunames, $otuname);
		}
	}
	my @blanksamples = keys(%blank2sample);
	# calculate significance level
	my $ntestwhole = 0;
	foreach my $otuname (@otunames) {
		if ($adjust eq 'bonferroni') {
			my $ntest = 0;
			foreach my $samplename (@samplenames) {
				if (!$ignoresamplelist{$samplename} && $table{$samplename}{$otuname} > 0) {
					$ntest ++;
				}
			}
			if ($ntest) {
				if ($fwerunit eq 'otu') {
					$otusiglevel{$otuname} = $siglevel / $ntest;
				}
				elsif ($fwerunit eq 'whole') {
					$ntestwhole += $ntest;
				}
			}
		}
		else {
			$otusiglevel{$otuname} = $siglevel;
		}
	}
	if ($adjust eq 'bonferroni' && $fwerunit eq 'whole') {
		foreach my $otuname (@otunames) {
			$otusiglevel{$otuname} = $siglevel / $ntestwhole;
		}
	}
	# calculate total number of reads oer OTU
	my %otutotal;
	foreach my $otuname (@otunames) {
		foreach my $samplename (@samplenames, @blanksamples) {
			if ($table{$samplename}{$otuname} > 0) {
				$otutotal{$otuname} += $table{$samplename}{$otuname};
			}
		}
	}
	{
		my %pid;
		my $child = 0;
		my $nchild = 1;
		$| = 1;
		$? = 0;
		foreach my $samplename (@samplenames) {
			if (!$ignoresamplelist{$samplename}) {
				print(STDERR "\"$samplename\"...\n");
				foreach my $otuname (@otunames) {
					if (my $pid = fork()) {
						$pid{$pid} = $child;
						if ($nchild == $numthreads) {
							my $endpid = wait();
							while (!exists($pid{$endpid}) && $endpid != -1) {
								$endpid = wait();
							}
							if (exists($pid{$endpid})) {
								$child = $pid{$endpid};
								delete($pid{$endpid});
							}
							elsif ($endpid == -1) {
								$child = 0;
							}
						}
						elsif ($nchild < $numthreads) {
							$child = $nchild;
							$nchild ++;
						}
						if ($?) {
							die(__LINE__);
						}
						next;
					}
					else {
						if ($table{$samplename}{$otuname} > 0) {
							my $pvalue = (1 - Math::CDF::pbinom($table{$samplename}{$otuname}, $otutotal{$otuname}, $pjump1));
							if ($pvalue > $otusiglevel{$otuname}) {
								&saveToTempFile("$outputfolder/$samplename.$child.temp", "$samplename\t$otuname\t0\n");
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
				die(__LINE__);
			}
		}
	}
}

sub performBinomialTest2 {
	print(STDERR "Performing binomial test...\n");
	my @samplenames;
	foreach my $samplename (sort(keys(%samplenames))) {
		if (exists($sample2blank{$samplename}) || exists($sample2sample{$samplename})) {
			push(@samplenames, $samplename);
		}
	}
	my @otunames;
	foreach my $otuname (keys(%otunames)) {
		if (!defined($ignoreotulist{$otuname})) {
			push(@otunames, $otuname);
		}
	}
	# calculate significance level
	my $ntestwhole = 0;
	foreach my $otuname (@otunames) {
		if ($adjust eq 'bonferroni') {
			my $ntest = 0;
			foreach my $samplename (@samplenames) {
				if (!$ignoresamplelist{$samplename} && $table{$samplename}{$otuname} > 0) {
					$ntest ++;
				}
			}
			if ($ntest) {
				if ($fwerunit eq 'otu') {
					$otusiglevel{$otuname} = $siglevel / $ntest;
				}
				elsif ($fwerunit eq 'whole') {
					$ntestwhole += $ntest;
				}
			}
		}
		else {
			$otusiglevel{$otuname} = $siglevel;
		}
	}
	if ($adjust eq 'bonferroni' && $fwerunit eq 'whole') {
		foreach my $otuname (@otunames) {
			$otusiglevel{$otuname} = $siglevel / $ntestwhole;
		}
	}
	{
		my %pid;
		my $child = 0;
		my $nchild = 1;
		$| = 1;
		$? = 0;
		foreach my $samplename (@samplenames) {
			if (!$ignoresamplelist{$samplename}) {
				print(STDERR "\"$samplename\"...\n");
				foreach my $otuname (@otunames) {
					if (my $pid = fork()) {
						$pid{$pid} = $child;
						if ($nchild == $numthreads) {
							my $endpid = wait();
							while (!exists($pid{$endpid}) && $endpid != -1) {
								$endpid = wait();
							}
							if (exists($pid{$endpid})) {
								$child = $pid{$endpid};
								delete($pid{$endpid});
							}
							elsif ($endpid == -1) {
								$child = 0;
							}
						}
						elsif ($nchild < $numthreads) {
							$child = $nchild;
							$nchild ++;
						}
						if ($?) {
							die(__LINE__);
						}
						next;
					}
					else {
						if ($table{$samplename}{$otuname} > 0) {
							my $rsum = &calcrsum($samplename, $otuname);
							my $fsum = &calcfsum($samplename, $otuname);
							my $rcode = <<"_END";
# Sample: $samplename
# OTU: $otuname
otusiglevel <- $otusiglevel{$otuname}
otuobserved <- $table{$samplename}{$otuname}
otursum <- $rsum
otufsum <- $fsum
_END
							if (exists($pjump{$samplename}{'reversejump'}) && exists($pjump{$samplename}{'forwardjump'})) {
								$rcode .= <<"_END";
preversejump <- $pjump{$samplename}{'reversejump'}
pforwardjump <- $pjump{$samplename}{'forwardjump'}
_END
							}
							else {
								&errorMessage(__LINE__, "The probability of tag jump is missing for \"$samplename\".");
							}
							$rcode .= <<"_END";
pval <- 1
for(i in 0:otuobserved) {
	for(j in 0:i) {
		k <- i - j
		pval <- pval - (dbinom(j, (otursum + j), preversejump, log=F) * dbinom(k, (otufsum + k), pforwardjump, log=F))
		if(pval <= otusiglevel) {
			print(pval <= otusiglevel)
			quit(\"no\")
		}
	}
}
print(pval <= otusiglevel)
_END
							&saveToTempFile("$outputfolder/$samplename.$child.R", $rcode);
							unless (open($pipehandleinput1, "$Rscript --vanilla $outputfolder/$samplename.$child.R 2> $devnull |")) {
								&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla $outputfolder/$samplename.$child.R\".");
							}
							my $testresult;
							while (<$pipehandleinput1>) {
								if (/TRUE/) {
									$testresult = 1;
								}
							}
							close($pipehandleinput1);
							unless ($testresult) {
								&saveToTempFile("$outputfolder/$samplename.$child.temp", "$samplename\t$otuname\t0\n");
							}
							unless ($nodel) {
								unlink("$outputfolder/$samplename.$child.R");
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
				die(__LINE__);
			}
		}
	}
}

sub saveResults {
	print(STDERR "Outputting results...\n");
	foreach my $blanksample (keys(%blanksamples)) {
		delete($samplenames{$blanksample});
	}
	my %removedotu;
	foreach my $otuname (keys(%otunames)) {
		my $tempsum = 0;
		foreach my $samplename (keys(%samplenames)) {
			$tempsum += $table{$samplename}{$otuname};
		}
		if ($tempsum == 0) {
			print(STDERR "The all sequences of the OTU \"$otuname\" was removed. If this OTU is contained in blanks only, abundant in one or more blanks or rare in all samples and blanks, this is not problem. If this OTU is rare in all blanks and contained in one or more samples and not rare, this might be weird. Please check input file.\n");
			$removedotu{$otuname} = 1;
		}
	}
	# save table
	{
		my @otunames = sort({$a cmp $b} keys(%otunames));
		my @samplenames = sort({$a cmp $b} keys(%samplenames));
		unless (open($filehandleoutput1, "> $outputfolder/decontaminated.tsv")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/decontaminated.tsv\".");
		}
		unless (open($filehandleoutput2, "> $outputfolder/removed.tsv")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/removed.tsv\".");
		}
		unless (open($filehandleoutput3, "> $outputfolder/siglevel.tsv")) {
			&errorMessage(__LINE__, "Cannot make \"$outputfolder/siglevel.tsv\".");
		}
		if ($test eq 'binomial' && %pjump) {
			unless (open($filehandleoutput4, "> $outputfolder/preversejump.tsv")) {
				&errorMessage(__LINE__, "Cannot make \"$outputfolder/preversejump.tsv\".");
			}
			unless (open($filehandleoutput5, "> $outputfolder/pforwardjump.tsv")) {
				&errorMessage(__LINE__, "Cannot make \"$outputfolder/pforwardjump.tsv\".");
			}
			unless (open($filehandleoutput6, "> $outputfolder/preversejump2.tsv")) {
				&errorMessage(__LINE__, "Cannot make \"$outputfolder/preversejump2.tsv\".");
			}
			unless (open($filehandleoutput7, "> $outputfolder/pforwardjump2.tsv")) {
				&errorMessage(__LINE__, "Cannot make \"$outputfolder/pforwardjump2.tsv\".");
			}
		}
		if ($tableformat eq 'matrix') {
			print($filehandleoutput1 "samplename\t" . join("\t", @otunames) . "\n");
			print($filehandleoutput2 "samplename\t" . join("\t", @otunames) . "\n");
			print($filehandleoutput3 "samplename\t" . join("\t", @otunames) . "\n");
			if ($test eq 'binomial' && %pjump) {
				print($filehandleoutput4 "samplename\t" . join("\t", @otunames) . "\n");
				print($filehandleoutput5 "samplename\t" . join("\t", @otunames) . "\n");
				print($filehandleoutput6 "samplename\t" . join("\t", @otunames) . "\n");
				print($filehandleoutput7 "samplename\t" . join("\t", @otunames) . "\n");
			}
			foreach my $samplename (@samplenames) {
				print($filehandleoutput1 $samplename);
				print($filehandleoutput2 $samplename);
				print($filehandleoutput3 $samplename);
				if ($test eq 'binomial' && %pjump) {
					print($filehandleoutput4 $samplename);
					print($filehandleoutput5 $samplename);
					print($filehandleoutput6 $samplename);
					print($filehandleoutput7 $samplename);
				}
				foreach my $otuname (@otunames) {
					if ($table{$samplename}{$otuname}) {
						print($filehandleoutput1 "\t$table{$samplename}{$otuname}");
					}
					else {
						print($filehandleoutput1 "\t0");
					}
					if ($removed{$samplename}{$otuname}) {
						print($filehandleoutput2 "\t1");
					}
					else {
						print($filehandleoutput2 "\t0");
					}
					if ($otusiglevel{$otuname}) {
						printf($filehandleoutput3 "\t%.10f", $otusiglevel{$otuname});
					}
					else {
						print($filehandleoutput3 "\t0.0000000000");
					}
					if ($test eq 'binomial' && %pjump) {
						if ($pjump{$samplename}{'reversejump'}) {
							printf($filehandleoutput4 "\t%.10f", $pjump{$samplename}{'reversejump'});
						}
						else {
							print($filehandleoutput4 "\t0.0000000000");
						}
						if ($pjump{$samplename}{'forwardjump'}) {
							printf($filehandleoutput5 "\t%.10f", $pjump{$samplename}{'forwardjump'});
						}
						else {
							print($filehandleoutput5 "\t0.0000000000");
						}
						if ($pjump1 && $pjump2) {
							printf($filehandleoutput6 "\t%.10f", $pjump1);
							printf($filehandleoutput7 "\t%.10f", $pjump2);
						}
						else {
							if ($pjump2{$samplename}{'reversejump'} eq 'NA') {
								print($filehandleoutput6 "\tNA");
							}
							elsif ($pjump2{$samplename}{'reversejump'}) {
								printf($filehandleoutput6 "\t%.10f", $pjump2{$samplename}{'reversejump'});
							}
							else {
								print($filehandleoutput6 "\t0.0000000000");
							}
							if ($pjump2{$samplename}{'forwardjump'} eq 'NA') {
								print($filehandleoutput7 "\tNA");
							}
							elsif ($pjump2{$samplename}{'forwardjump'}) {
								printf($filehandleoutput7 "\t%.10f", $pjump2{$samplename}{'forwardjump'});
							}
							else {
								print($filehandleoutput7 "\t0.0000000000");
							}
						}
					}
				}
				print($filehandleoutput1 "\n");
				print($filehandleoutput2 "\n");
				print($filehandleoutput3 "\n");
				if ($test eq 'binomial' && %pjump) {
					print($filehandleoutput4 "\n");
					print($filehandleoutput5 "\n");
					print($filehandleoutput6 "\n");
					print($filehandleoutput7 "\n");
				}
			}
		}
		elsif ($tableformat eq 'column') {
			print($filehandleoutput1 "samplename\totuname\tnreads\n");
			print($filehandleoutput2 "samplename\totuname\tremoved\n");
			print($filehandleoutput3 "samplename\totuname\tsiglevel\n");
			if ($test eq 'binomial' && %pjump) {
				print($filehandleoutput4 "samplename\totuname\tpreversejump\n");
				print($filehandleoutput5 "samplename\totuname\tpforwardjump\n");
				print($filehandleoutput6 "samplename\totuname\tpreversejump\n");
				print($filehandleoutput7 "samplename\totuname\tpforwardjump\n");
			}
			foreach my $samplename (@samplenames) {
				foreach my $otuname (@otunames) {
					if ($table{$samplename}{$otuname}) {
						print($filehandleoutput1 "$samplename\t$otuname\t$table{$samplename}{$otuname}\n");
					}
					else {
						print($filehandleoutput1 "$samplename\t$otuname\t0\n");
					}
					if ($removed{$samplename}{$otuname}) {
						print($filehandleoutput2 "$samplename\t$otuname\t1\n");
					}
					else {
						print($filehandleoutput2 "$samplename\t$otuname\t0\n");
					}
					if ($otusiglevel{$otuname}) {
						printf($filehandleoutput3 "$samplename\t$otuname\t%.10f\n", $otusiglevel{$otuname});
					}
					else {
						print($filehandleoutput3 "$samplename\t$otuname\t0.0000000000\n");
					}
					if ($test eq 'binomial' && %pjump) {
						if ($pjump{$samplename}{'reversejump'}) {
							printf($filehandleoutput4 "$samplename\t$otuname\t%.10f\n", $pjump{$samplename}{'reversejump'});
						}
						else {
							print($filehandleoutput4 "$samplename\t$otuname\t0.0000000000\n");
						}
						if ($pjump{$samplename}{'forwardjump'}) {
							printf($filehandleoutput5 "$samplename\t$otuname\t%.10f\n", $pjump{$samplename}{'forwardjump'});
						}
						else {
							print($filehandleoutput5 "$samplename\t$otuname\t0.0000000000\n");
						}
						if ($pjump1 && $pjump2) {
							printf($filehandleoutput6 "$samplename\t$otuname\t%.10f\n", $pjump1);
							printf($filehandleoutput7 "$samplename\t$otuname\t%.10f\n", $pjump2);
						}
						else {
							if ($pjump2{$samplename}{'reversejump'} eq 'NA') {
								print($filehandleoutput6 "$samplename\t$otuname\tNA\n");
							}
							elsif ($pjump2{$samplename}{'reversejump'}) {
								printf($filehandleoutput6 "$samplename\t$otuname\t%.10f\n", $pjump2{$samplename}{'reversejump'});
							}
							else {
								print($filehandleoutput6 "$samplename\t$otuname\t0.0000000000\n");
							}
							if ($pjump2{$samplename}{'forwardjump'} eq 'NA') {
								print($filehandleoutput7 "$samplename\t$otuname\tNA\n");
							}
							elsif ($pjump2{$samplename}{'forwardjump'}) {
								printf($filehandleoutput7 "$samplename\t$otuname\t%.10f\n", $pjump2{$samplename}{'forwardjump'});
							}
							else {
								print($filehandleoutput7 "$samplename\t$otuname\t0.0000000000\n");
							}
						}
					}
				}
			}
		}
		close($filehandleoutput1);
		close($filehandleoutput2);
		close($filehandleoutput3);
		if ($test eq 'binomial' && %pjump) {
			close($filehandleoutput4);
			close($filehandleoutput5);
			close($filehandleoutput6);
			close($filehandleoutput7);
		}
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
			if ($otuname && $otunames{$otuname} && !defined($removedotu{$otuname})) {
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
		my $labelline;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;*//g;
			if (/^>(.+)$/) {
				$otuname = $1;
				$labelline = "$_\n"
				#print($filehandleoutput1 );
			}
			elsif ($otuname && $otunames{$otuname} && !defined($removedotu{$otuname}) && / SN:(\S+)/) {
				my $samplename = $1;
				if ($samplename && $samplenames{$samplename} && $table{$samplename}{$otuname} > 0) {
					if ($labelline) {
						print($filehandleoutput1 $labelline);
						undef($labelline);
					}
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

# calculate total number of reads of OTU of forward tag sharing / reverse tag jumped samples
sub calcrsum {
	my $samplename = shift(@_);
	my $otuname = shift(@_);
	my $rsum = 0;
	if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'reversejump'})) {
		foreach my $reversejumpsample (keys(%{$sample2blank{$samplename}{'reversejump'}})) {
			if ($table{$reversejumpsample}{$otuname} > 0) {
				$rsum += $table{$reversejumpsample}{$otuname};
			}
		}
	}
	if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{'reversejump'})) {
		foreach my $reversejumpsample (keys(%{$sample2sample{$samplename}{'reversejump'}})) {
			if ($table{$reversejumpsample}{$otuname} > 0) {
				$rsum += $table{$reversejumpsample}{$otuname};
			}
		}
	}
	return($rsum);
}

# calculate total number of reads of OTU of reverse tag sharing / forward tag jumped samples
sub calcfsum {
	my $samplename = shift(@_);
	my $otuname = shift(@_);
	my $fsum = 0;
	if (%sample2blank && exists($sample2blank{$samplename}) && exists($sample2blank{$samplename}{'forwardjump'})) {
		foreach my $forwardjumpsample (keys(%{$sample2blank{$samplename}{'forwardjump'}})) {
			if ($table{$forwardjumpsample}{$otuname} > 0) {
				$fsum += $table{$forwardjumpsample}{$otuname};
			}
		}
	}
	if (%sample2sample && exists($sample2sample{$samplename}) && exists($sample2sample{$samplename}{'forwardjump'})) {
		foreach my $forwardjumpsample (keys(%{$sample2sample{$samplename}{'forwardjump'}})) {
			if ($table{$forwardjumpsample}{$otuname} > 0) {
				$fsum += $table{$forwardjumpsample}{$otuname};
			}
		}
	}
	return($fsum);
}

sub isOutlier {
	# Modified Thompson Tau test
	my $otusiglevel = shift(@_);
	my $sample = $_[0];
	my $samplesize = scalar(@_);
	my $mean = &mean($samplesize, @_);
	my $stdev = &stdev($samplesize, $mean, @_);
	my $delta = $sample - $mean;
	my $t = Math::CDF::qt((1 - $otusiglevel), ($samplesize - 2));
	my $tau = (($t * ($samplesize - 1)) / (sqrt($samplesize) * sqrt($samplesize - 2 + ($t ** 2))));
	my $deltamax = $tau * $stdev;
	if ($delta > $deltamax) {
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

sub saveToTempFile {
	my $filehandle;
	my $filename = shift(@_);
	my $content = shift(@_);
	unless (open($filehandle, "+>> $filename")) {
		&errorMessage(__LINE__, "Cannot write \"$filename\".");
	}
	unless (flock($filehandle, LOCK_EX)) {
		&errorMessage(__LINE__, "Cannot lock \"$filename\".");
	}
	unless (seek($filehandle, 0, 2)) {
		&errorMessage(__LINE__, "Cannot seek \"$filename\".");
	}
	print($filehandle $content);
	close($filehandle);
}

sub readFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "pigz -p 8 -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "pbzip2 -p8 -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "xz -T 8 -dc $filename 2> $devnull |")) {
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
		unless (open($filehandle, "| pigz -p 8 -c >> $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "| pbzip2 -p8 -c >> $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "| xz -T 8 -c >> $filename 2> $devnull")) {
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
--test=THOMPSON|BINOMIAL
  Specify test method. (default: THOMPSON)

--model=SINGLE|SEPARATE
  Specify the model applying to tag jump binomial test. (default: SEPARATE)

--siglevel=DECIMAL
  Specify significance level for modified Thompson Tau test. (default: 0.05)

--adjust=BONFERRONI|NONE
  Specify correction method for multiple testing. (default: BONFERRONI)

--fwerunit=WHOLE|OTU
  Specify family-wise error rate unit for Bonferroni correction.
(default: OTU)

--pjump=DECIMAL(,DECIMAL)
  Specify the probability of tag jump. (default: none)

--blank=SAMPLENAME,...,SAMPLENAME
  Specify blank sample names. (default: none)

--blanklist=FILENAME
  Specify file name of blank sample list. (default: none)

--ignoresample=SAMPLENAME,...,SAMPLENAME
  Specify ignoring sample names. (default: none)

--ignoresamplelist=FILENAME
  Specify file name of ignoring sample list. (default: none)

--ignoreotu=OTUNAME,...,OTUNAME
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

--stdconc=STDNAME1,DECIMAL1,STDNAME2,DECIMAL2(,STDNAME3,DECIMAL3...)
  Specify DNA concentration of internal standard. (default: none)

--stdconctable=FILENAME
  Specify file name of DNA concentration table of internal standard.

--solutionvol=DECIMAL
  Specify DNA solution volume.

--solutionvoltable=FILENAME
  Specify file name of DNA solution volume of samples.

--watervol=DECIMAL
  Specify filtered water volume.

--watervoltable=FILENAME
  Specify file name of filtered water volume of samples.

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: MATRIX)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTA (uncompressed, gzip-compressed, or bzip2-compressed)
_END
	exit;
}
