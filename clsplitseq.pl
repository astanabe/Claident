use strict;
use Fcntl ':flock';
use File::Spec;

my $buildno = '0.9.x';

# options
my $compress = 'gz';
my $primerfile;
my $reverseprimerfile;
my $reversecomplement;
my $elimprimer = 1;
my $seqnamestyle = 'illumina';
my $truncateN = 0;
my $useNasUMI = 0;
my $addUMI;
my $tagfile;
my $reversetagfile;
my $elimtag = 1;
my $minlen = 1;
my $maxlen;
my $minqualtag = 0;
my $replaceinternal;
my $converse;
my $maxpmismatch = 0.14;
my $maxnmismatch;
my $reversemaxpmismatch = 0.15;
my $reversemaxnmismatch;
my $needreverseprimer;
my $goscore = -10;
my $gescore = -1;
my $mmscore = -4;
my $mscore = 5;
my $endgap = 'nobody';
my $append;
my $numthreads = 1;

# Input/Output
my @inputfiles;
my $outputfolder;

# other variables
my $devnull = File::Spec->devnull();
my $runname;
my $commonprimername;
my $commontagname;
my @primer;
my %primer;
my %reverseprimer;
my %tag;
my $taglength;
my %reversetag;
my $reversetaglength;

# file handles
my $filehandleinput1;
my $filehandleinput2;
my $filehandleinput3;
my $filehandleinput4;
my $filehandleoutput1;
my $filehandleoutput2;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# read primers
	&readPrimers();
	# read tags
	&readTags();
	# split sequences
	&splitSequences();
	# concatenate FASTQ files
	&concatenateFASTQ();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clsplitseq $buildno
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
}

sub getOptions {
	$outputfolder = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+compress=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:g|gz|gzip)$/i) {
				$compress = 'gz';
			}
			elsif ($value =~ /^(?:b|bz|bz2|bzip|bzip2)$/i) {
				$compress = 'bz2';
			}
			elsif ($value =~ /^(?:x|xz)$/i) {
				$compress = 'xz';
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$compress = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:seq|sequence)namestyle=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:i|illumina)$/i) {
				$seqnamestyle = 'illumina';
			}
			elsif ($value =~ /^(?:o|other)$/i) {
				$seqnamestyle = 'other';
			}
			elsif ($value =~ /^nochange$/i) {
				$seqnamestyle = 'nochange';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:c|converse)$/i) {
			$converse = 1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)mismatch=(.+)$/i) {
			$maxpmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?mismatch=(.+)$/i) {
			$maxnmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+primername=(.+)$/i) {
			$commonprimername = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:5prime|forward|f)?(?:primer|primerfile|p)=(.+)$/i) {
			$primerfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)max(?:imum)?(?:r|rate|p|percentage)mismatch=(.+)$/i) {
			$reversemaxpmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)max(?:imum)?n(?:um)?mismatch=(.+)$/i) {
			$reversemaxnmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)(?:primer|primerfile)=(.+)$/i) {
			$reverseprimerfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+need(?:3prime|reverse|rev|r)primer$/i) {
			$needreverseprimer = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:reversecomplement|revcomp)$/i) {
			$reversecomplement = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:elim|eliminate)primer=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$elimprimer = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$elimprimer = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:trunc|truncate)N=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$truncateN = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$truncateN = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+useNasUMI=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$useNasUMI = 9999;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$useNasUMI = 0;
			}
			elsif ($value =~ /^(\d+)$/i) {
				$useNasUMI = $1;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+addUMI=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$addUMI = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$addUMI = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:tag|index)name=(.+)$/i) {
			$commontagname = $1;
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
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?len(?:gth)?=(\d+)$/i) {
			$minlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?len(?:gth)?=(\d+)$/i) {
			$maxlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?qual(?:ity)?tag=(\d+)$/i) {
			$minqualtag = $1;
		}
		elsif ($ARGV[$i] =~ /^-+replaceinternal$/i) {
			$replaceinternal = 1;
		}
		elsif ($ARGV[$i] =~ /^-+g(?:ap)?o(?:pen)?(?:score)?=(-?\d+)$/i) {
			$goscore = $1;
		}
		elsif ($ARGV[$i] =~ /^-+g(?:ap)?e(?:xtension)?(?:score)?=(-?\d+)$/i) {
			$gescore = $1;
		}
		elsif ($ARGV[$i] =~ /^-+m(?:is)?m(?:atch)?(?:score)?=(-?\d+)$/i) {
			$mmscore = $1;
		}
		elsif ($ARGV[$i] =~ /^-+m(?:atch)?(?:score)?=(-?\d+)$/i) {
			$mscore = $1;
		}
		elsif ($ARGV[$i] =~ /^-+endgap=(nobody|match|mismatch|gap)$/i) {
			$endgap = lc($1);
		}
		elsif ($ARGV[$i] =~ /^-+(?:a|append)$/i) {
			$append = 1;
		}
		elsif ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$runname = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
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
	if (scalar(@inputfiles) > 4) {
		&errorMessage(__LINE__, "Too many input files were given.");
	}
	if (!$runname) {
		&errorMessage(__LINE__, "Run name must be given.");
	}
	if (-e $outputfolder && !$append) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if ($primerfile && $commonprimername) {
		&errorMessage(__LINE__, "Both primer file and common primer name were specified.");
	}
	if ($primerfile && !-e $primerfile) {
		&errorMessage(__LINE__, "\"$primerfile\" does not exist.");
	}
	if ($reverseprimerfile && !-e $reverseprimerfile) {
		&errorMessage(__LINE__, "\"$reverseprimerfile\" does not exist.");
	}
	if ($reverseprimerfile && !$primerfile) {
		&errorMessage(__LINE__, "Reverse primers require associated forward primers.");
	}
	if ($needreverseprimer && !$reverseprimerfile) {
		&errorMessage(__LINE__, "Although \"needreverseprimer\" is specified, reverse primer does not given.");
	}
	if ($tagfile && $commontagname) {
		&errorMessage(__LINE__, "Both tag/index file and common tag/index name were specified.");
	}
	if ($tagfile && !-e $tagfile) {
		&errorMessage(__LINE__, "\"$tagfile\" does not exist.");
	}
	if ($reversetagfile && !-e $reversetagfile) {
		&errorMessage(__LINE__, "\"$reversetagfile\" does not exist.");
	}
	if ($reversetagfile && $reverseprimerfile) {
		$needreverseprimer = 1;
	}
	if (!$tagfile && !$primerfile) {
		&errorMessage(__LINE__, "Both tag and primer are not given.");
	}
	if ($runname =~ /__/) {
		&errorMessage(__LINE__, "\"$runname\" is invalid name. Do not use \"__\" in run name.");
	}
	if ($runname =~ /\s/) {
		&errorMessage(__LINE__, "\"$runname\" is invalid name. Do not use spaces or tabs in run name.");
	}
	if ($minlen < 1) {
		&errorMessage(__LINE__, "Minimum length must be equal to or more than 1.");
	}
	if ($useNasUMI && !defined($addUMI)) {
		$addUMI = 1;
	}
	elsif (!$useNasUMI && $addUMI) {
		&errorMessage(__LINE__, "\"addUMI\" is enabled but \"useNasUMI\" is disabled. This combination is invalid.");
	}
	if ($addUMI && $elimprimer == 0) {
		&errorMessage(__LINE__, "\"addUMI\" is enabled but \"elimprimer\" is disabled. This combination is invalid.");
	}
	$minqualtag += 33;
}

sub readPrimers {
	if ($primerfile || $reverseprimerfile) {
		print(STDERR "Reading primer files...\n");
	}
	if ($primerfile) {
		unless (open($filehandleinput1, "< $primerfile")) {
			&errorMessage(__LINE__, "Cannot open \"$primerfile\".");
		}
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
				my $name = $1;
				my $primer = uc($2);
				$name =~ s/\s+$//;
				if ($name =~ /__/) {
					&errorMessage(__LINE__, "\"$name\" is invalid name. Do not use \"__\" in primer name.");
				}
				$primer =~ s/[^A-Z]//sg;
				if (exists($primer{$name})) {
					&errorMessage(__LINE__, "Primer \"$name\" is doubly used in \"$primerfile\".");
				}
				else {
					$primer{$name} = $primer;
					push(@primer, $name);
				}
			}
		}
		close($filehandleinput1);
		print(STDERR "Forward primers\n");
		foreach (@primer) {
			print(STDERR "$_ : " . $primer{$_} . "\n");
		}
	}
	if ($reverseprimerfile) {
		unless (open($filehandleinput1, "< $reverseprimerfile")) {
			&errorMessage(__LINE__, "Cannot open \"$reverseprimerfile\".");
		}
		my $tempno = 0;
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*\S[^\r\n]*\r?\n(.+)/s) {
				my $reverseprimer = uc($1);
				$reverseprimer =~ s/[^A-Z]//sg;
				if ($reversecomplement) {
					$reverseprimer = &reversecomplement($reverseprimer);
				}
				if ($primer[$tempno]) {
					$reverseprimer{$primer[$tempno]} = $reverseprimer;
					$tempno ++;
				}
				else {
					&errorMessage(__LINE__, "There is no associated forward primer for \"$reverseprimer\".");
				}
			}
		}
		close($filehandleinput1);
		print(STDERR "Reverse primers\n");
		foreach (@primer) {
			print(STDERR "$_ : " . $reverseprimer{$_} . "\n");
		}
	}
	if ($primerfile || $reverseprimerfile) {
		print(STDERR "done.\n\n");
	}
}

sub readTags {
	my %temptags;
	my %tempreversetags;
	if ($tagfile || $reversetagfile) {
		print(STDERR "Reading tag files...\n");
	}
	if ($tagfile) {
		my @tag;
		unless (open($filehandleinput1, "< $tagfile")) {
			&errorMessage(__LINE__, "Cannot open \"$tagfile\".");
		}
		if ($reversetagfile) {
			unless (open($filehandleinput2, "< $reversetagfile")) {
				&errorMessage(__LINE__, "Cannot open \"$reversetagfile\".");
			}
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
				if ($reversetagfile) {
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
		if ($reversetagfile) {
			close($filehandleinput2);
		}
		print(STDERR "Tag sequences\n");
		foreach (@tag) {
			print(STDERR $tag{$_} . " : " . $_ . "\n");
		}
	}
	elsif (!$tagfile && $reversetagfile) {
		my @reversetag;
		unless (open($filehandleinput1, "< $reversetagfile")) {
			&errorMessage(__LINE__, "Cannot open \"$reversetagfile\".");
		}
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.+)/s) {
				my $name = $1;
				my $reversetag = uc($2);
				$name =~ s/\s+$//;
				if ($name =~ /__/) {
					&errorMessage(__LINE__, "\"$name\" is invalid name. Do not use \"__\" in tag name.");
				}
				elsif ($name =~ /^[ACGT]+$/ || $name =~ /^[ACGT]+[\-\+][ACGT]+$/) {
					&errorMessage(__LINE__, "\"$name\" is invalid name. Do not use nucleotide sequence as tag name.");
				}
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
				if (exists($reversetag{$reversetag})) {
					&errorMessage(__LINE__, "Tag \"$reversetag ($name)\" is doubly used in \"$tagfile\".");
				}
				else {
					$reversetag{$reversetag} = $name;
					push(@reversetag, $reversetag);
				}
			}
		}
		close($filehandleinput1);
		print(STDERR "Reverse tag sequences\n");
		foreach (@reversetag) {
			print(STDERR $reversetag{$_} . " : " . $_ . "\n");
		}
	}
	my @temptags = sort(keys(%temptags));
	my @tempreversetags = sort(keys(%tempreversetags));
	if (@temptags && @tempreversetags) {
		print(STDERR "Possible jumped tag combinations\n");
		my @jumpedtag;
		foreach my $temptag (@temptags) {
			foreach my $tempreversetag (@tempreversetags) {
				my $tagseq = "$temptag+$tempreversetag";
				if (!exists($tag{$tagseq})) {
					$tag{$tagseq} = $tagseq;
					push(@jumpedtag, $tagseq);
				}
			}
		}
		foreach (@jumpedtag) {
			print(STDERR $tag{$_} . " : " . $_ . "\n");
		}
	}
	if ($tagfile || $reversetagfile) {
		print(STDERR "done.\n\n");
	}
}

sub splitSequences {
	print(STDERR "Splitting sequences...\n");
	# read input file
	if (!-e $outputfolder && !mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
	}
	$filehandleinput1 = &readFile($inputfiles[0]);
	if ($inputfiles[1]) {
		$filehandleinput2 = &readFile($inputfiles[1]);
	}
	if ($inputfiles[2]) {
		$filehandleinput3 = &readFile($inputfiles[2]);
	}
	if ($inputfiles[3]) {
		$filehandleinput4 = &readFile($inputfiles[3]);
	}
	{
		my $tempnline = 1;
		my $seqname;
		my $nucseq1;
		my $qualseq1;
		my $nucseq2;
		my $qualseq2;
		my $nucseq3;
		my $qualseq3;
		my $nucseq4;
		my $qualseq4;
		my %child;
		my %pid;
		my $child = 0;
		$| = 1;
		$? = 0;
		# Processing FASTQ in parallel
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if ($tempnline % 4 == 1 && /^\@(.+)/) {
				$seqname = $1;
				if ($filehandleinput2) {
					readline($filehandleinput2);
				}
				if ($filehandleinput3) {
					readline($filehandleinput3);
				}
				if ($filehandleinput4) {
					readline($filehandleinput4);
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
				if ($filehandleinput3) {
					$nucseq3 = readline($filehandleinput3);
					$nucseq3 =~ s/\r?\n?$//;
					$nucseq3 =~ s/[^a-zA-Z]//g;
					$nucseq3 = uc($nucseq3);
				}
				if ($filehandleinput4) {
					$nucseq4 = readline($filehandleinput4);
					$nucseq4 =~ s/\r?\n?$//;
					$nucseq4 =~ s/[^a-zA-Z]//g;
					$nucseq4 = uc($nucseq4);
				}
			}
			elsif ($tempnline % 4 == 3 && /^\+/) {
				$tempnline ++;
				if ($filehandleinput2) {
					readline($filehandleinput2);
				}
				if ($filehandleinput3) {
					readline($filehandleinput3);
				}
				if ($filehandleinput4) {
					readline($filehandleinput4);
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
				if ($filehandleinput3) {
					$qualseq3 = readline($filehandleinput3);
					$qualseq3 =~ s/\r?\n?$//;
					$qualseq3 =~ s/\s//g;
					$qualseq3 = $qualseq3;
				}
				if ($filehandleinput4) {
					$qualseq4 = readline($filehandleinput4);
					$qualseq4 =~ s/\r?\n?$//;
					$qualseq4 =~ s/\s//g;
					$qualseq4 = $qualseq4;
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
					undef($nucseq3);
					undef($qualseq3);
					undef($nucseq4);
					undef($qualseq4);
					$tempnline ++;
					next;
				}
				else {
					#print(STDERR "Thread $child\n");
					&processOneSequence($seqname, $nucseq1, $qualseq1, $nucseq2, $qualseq2, $nucseq3, $qualseq3, $nucseq4, $qualseq4, $child);
					exit;
				}
			}
			else {
				&errorMessage(__LINE__, "Invalid FASTQ.\nFile: $inputfiles[0]\nLine: $tempnline");
			}
			$tempnline ++;
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
	if ($filehandleinput3) {
		close($filehandleinput3);
	}
	if ($filehandleinput4) {
		close($filehandleinput4);
	}
}

sub processOneSequence {
	my ($seqname, $nucseq1, $qualseq1, $nucseq2, $qualseq2, $nucseq3, $qualseq3, $nucseq4, $qualseq4, $child) = @_;
	my %options;
	# check data
	if (length($nucseq1) != length($qualseq1)) {
		&errorMessage(__LINE__, "The first sequence of \"$seqname\" is unequal length to quality sequence.");
	}
	if (length($nucseq2) != length($qualseq2)) {
		&errorMessage(__LINE__, "The second sequence of \"$seqname\" is unequal length to quality sequence.");
	}
	if (length($nucseq3) != length($qualseq3)) {
		&errorMessage(__LINE__, "The third sequence of \"$seqname\" is unequal length to quality sequence.");
	}
	if (length($nucseq4) != length($qualseq4)) {
		&errorMessage(__LINE__, "The fourth sequence of \"$seqname\" is unequal length to quality sequence.");
	}
	if ($tagfile && !$reversetagfile) {
		if ($nucseq1 && $nucseq2 && $nucseq3 && $nucseq4) {
			&errorMessage(__LINE__, "The sequence data is inconsistent with tags.");
		}
	}
	elsif (!$tagfile && $reversetagfile) {
		if ($nucseq1 && $nucseq2 && $nucseq3 && $nucseq4) {
			&errorMessage(__LINE__, "The sequence data is inconsistent with tags.");
		}
	}
	elsif (!$tagfile && !$reversetagfile) {
		if ($nucseq3 || $nucseq4) {
			&errorMessage(__LINE__, "The sequence data is inconsistent with tags.");
		}
	}
	# process
	if ($tagfile && $reversetagfile) {
		# if nucseq1, nucseq2, nucseq3, nucseq4 are forward read, index1, index2, reverse read, respectively,
		if ($nucseq1 && $taglength == length($nucseq2) && $reversetaglength == length($nucseq3) && $nucseq4) {
			my $tagseq = "$nucseq2+$nucseq3";
			my $tagqual = "$qualseq2$qualseq3";
			if ($tag{$tagseq} && &checkTagQualities($tagqual)) {
				$options{'tagname'} = $tag{$tagseq};
				$options{'tagseq'} = $tagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, $nucseq4, $qualseq4, 0, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
					&saveToFile($nucseq4, $qualseq4, 2, $seqname, \%options, $child);
				}
			}
			else {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
				&saveToFile($nucseq4, $qualseq4, 2, $seqname, \%options, $child);
			}
		}
		# if nucseq1, nucseq2, nucseq3 are forward read, index1, index2, respectively,
		elsif ($nucseq1 && $taglength == length($nucseq2) && $reversetaglength == length($nucseq3) && !$nucseq4) {
			my $tagseq = "$nucseq2+$nucseq3";
			my $tagqual = "$qualseq2$qualseq3";
			if ($tag{$tagseq} && &checkTagQualities($tagqual)) {
				$options{'tagname'} = $tag{$tagseq};
				$options{'tagseq'} = $tagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, '', '', 1, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
				}
			}
			else {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
			}
		}
		# if nucseq1, nucseq2 are index1+forward read, index2+reverse read, respectively,
		elsif ($nucseq1 && $nucseq2 && !$nucseq3 && !$nucseq4) {
			my $tagseq = substr($nucseq1, 0, $taglength, '') . '+' . substr($nucseq2, 0, $reversetaglength, '');
			my $tagqual = substr($qualseq1, 0, $taglength, '') . substr($qualseq2, 0, $reversetaglength, '');
			if ($tag{$tagseq} && &checkTagQualities($tagqual) && $nucseq1 && $nucseq2) {
				$options{'tagname'} = $tag{$tagseq};
				$options{'tagseq'} = $tagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, $nucseq2, $qualseq2, 0, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
					&saveToFile($nucseq2, $qualseq2, 2, $seqname, \%options, $child);
				}
			}
			elsif ($nucseq1 && $nucseq2) {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
				&saveToFile($nucseq2, $qualseq2, 2, $seqname, \%options, $child);
			}
		}
		# if nucseq1 is index1+forward+index2 read,
		elsif ($nucseq1 && !$nucseq2 && !$nucseq3 && !$nucseq4) {
			my $tagseq = substr($nucseq1, 0, $taglength, '') . '+' . substr($nucseq1, (-1 * $reversetaglength), $reversetaglength, '');
			my $tagqual = substr($qualseq1, 0, $taglength, '') . substr($qualseq1, (-1 * $reversetaglength), $reversetaglength, '');
			if ($tag{$tagseq} && &checkTagQualities($tagqual) && $nucseq1) {
				$options{'tagname'} = $tag{$tagseq};
				$options{'tagseq'} = $tagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, '', '', 2, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
				}
			}
			elsif ($nucseq1) {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
			}
		}
		else {
			&errorMessage(__LINE__, "\"$seqname\" is invalid sequence data.");
		}
	}
	elsif ($tagfile) {
		# if nucseq1, nucseq2, nucseq3 are forward read, index1, reverse read, respectively,
		if ($nucseq1 && $taglength == length($nucseq2) && $nucseq3) {
			my $tagseq = $nucseq2;
			my $tagqual = $qualseq2;
			if ($tag{$tagseq} && &checkTagQualities($tagqual)) {
				$options{'tagname'} = $tag{$tagseq};
				$options{'tagseq'} = $tagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, $nucseq3, $qualseq3, 0, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
					&saveToFile($nucseq3, $qualseq3, 2, $seqname, \%options, $child);
				}
			}
			else {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
				&saveToFile($nucseq3, $qualseq3, 2, $seqname, \%options, $child);
			}
		}
		# if nucseq1, nucseq2 are forward read, index1, respectively,
		elsif ($nucseq1 && $taglength == length($nucseq2)) {
			my $tagseq = $nucseq2;
			my $tagqual = $qualseq2;
			if ($tag{$tagseq} && &checkTagQualities($tagqual)) {
				$options{'tagname'} = $tag{$tagseq};
				$options{'tagseq'} = $tagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, '', '', 1, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
				}
			}
			else {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
			}
		}
		# if nucseq1, nucseq2 are index1+forward read, reverse read, respectively,
		elsif ($nucseq1 && $nucseq2) {
			my $tagseq = substr($nucseq1, 0, $taglength, '');
			my $tagqual = substr($qualseq1, 0, $taglength, '');
			if ($tag{$tagseq} && &checkTagQualities($tagqual) && $nucseq1) {
				$options{'tagname'} = $tag{$tagseq};
				$options{'tagseq'} = $tagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, $nucseq2, $qualseq2, 0, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
					&saveToFile($nucseq2, $qualseq2, 2, $seqname, \%options, $child);
				}
			}
			elsif ($nucseq1) {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
				&saveToFile($nucseq2, $qualseq2, 2, $seqname, \%options, $child);
			}
		}
		# if nucseq1 is index1+forward read,
		elsif ($nucseq1) {
			my $tagseq = substr($nucseq1, 0, $taglength, '');
			my $tagqual = substr($qualseq1, 0, $taglength, '');
			if ($tag{$tagseq} && &checkTagQualities($tagqual) && $nucseq1) {
				$options{'tagname'} = $tag{$tagseq};
				$options{'tagseq'} = $tagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, '', '', 1, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
				}
			}
			elsif ($nucseq1) {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
			}
		}
		else {
			&errorMessage(__LINE__, "\"$seqname\" is invalid sequence data.");
		}
	}
	elsif ($reversetagfile) {
		# if nucseq1, nucseq2, nucseq3 are forward read, index2, reverse read, respectively,
		if ($nucseq1 && $reversetaglength == length($nucseq2) && $nucseq3) {
			my $reversetagseq = $nucseq2;
			my $reversetagqual = $qualseq2;
			if ($reversetag{$reversetagseq} && &checkTagQualities($reversetagqual)) {
				$options{'tagname'} = $reversetag{$reversetagseq};
				$options{'tagseq'} = $reversetagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, $nucseq3, $qualseq3, 0, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
					&saveToFile($nucseq3, $qualseq3, 2, $seqname, \%options, $child);
				}
			}
			else {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
				&saveToFile($nucseq3, $qualseq3, 2, $seqname, \%options, $child);
			}
		}
		# if nucseq1, nucseq2 are forward read, index2, respectively,
		elsif ($nucseq1 && $reversetaglength == length($nucseq2)) {
			my $reversetagseq = $nucseq2;
			my $reversetagqual = $qualseq2;
			if ($reversetag{$reversetagseq} && &checkTagQualities($reversetagqual)) {
				$options{'tagname'} = $reversetag{$reversetagseq};
				$options{'tagseq'} = $reversetagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, '', '', 2, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
				}
			}
			else {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
			}
		}
		# if nucseq1, nucseq2 are forward read, index2+reverse read, respectively,
		elsif ($nucseq1 && $nucseq2) {
			my $reversetagseq = substr($nucseq2, 0, $reversetaglength, '');
			my $reversetagqual = substr($qualseq2, 0, $reversetaglength, '');
			if ($reversetag{$reversetagseq} && &checkTagQualities($reversetagqual) && $nucseq2) {
				$options{'tagname'} = $reversetag{$reversetagseq};
				$options{'tagseq'} = $reversetagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, $nucseq2, $qualseq2, 0, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
					&saveToFile($nucseq2, $qualseq2, 2, $seqname, \%options, $child);
				}
			}
			elsif ($nucseq2) {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
				&saveToFile($nucseq2, $qualseq2, 2, $seqname, \%options, $child);
			}
		}
		# if nucseq1 is forward+index2 read,
		elsif ($nucseq1) {
			my $reversetagseq = substr($nucseq1, (-1 * $reversetaglength), $reversetaglength, '');
			my $reversetagqual = substr($qualseq1, (-1 * $reversetaglength), $reversetaglength, '');
			if ($reversetag{$reversetagseq} && &checkTagQualities($reversetagqual) && $nucseq1) {
				$options{'tagname'} = $reversetag{$reversetagseq};
				$options{'tagseq'} = $reversetagseq;
				if ($primerfile) {
					&searchPrimers($nucseq1, $qualseq1, '', '', 2, $seqname, \%options, $child);
				}
				else {
					if ($commonprimername) {
						$options{'primername'} = $commonprimername;
					}
					&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
				}
			}
			elsif ($nucseq1) {
				$options{'tagname'} = 'undetermined';
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
			}
		}
		else {
			&errorMessage(__LINE__, "\"$seqname\" is invalid sequence data.");
		}
	}
	# if there is no tags,
	else {
		if ($commontagname) {
			$options{'tagname'} = $commontagname;
		}
		else {
			$options{'tagname'} = 'undetermined';
		}
		if ($nucseq1 && $nucseq2) {
			if ($primerfile) {
				&searchPrimers($nucseq1, $qualseq1, $nucseq2, $qualseq2, 0, $seqname, \%options, $child);
			}
			else {
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 1, $seqname, \%options, $child);
				&saveToFile($nucseq2, $qualseq2, 2, $seqname, \%options, $child);
			}
		}
		elsif ($nucseq1) {
			if ($primerfile) {
				&searchPrimers($nucseq1, $qualseq1, '', '', 1, $seqname, \%options, $child);
			}
			else {
				if ($commonprimername) {
					$options{'primername'} = $commonprimername;
				}
				&saveToFile($nucseq1, $qualseq1, 0, $seqname, \%options, $child);
			}
		}
		else {
			&errorMessage(__LINE__, "\"$seqname\" is invalid sequence data.");
		}
	}
}

sub checkTagQualities {
	my @tagqual = unpack('C*', $_[0]);
	my $qualpass = 1;
	for (my $i = 0; $i < scalar(@tagqual); $i ++) {
		if ($tagqual[$i] < $minqualtag) {
			$qualpass = 0;
			last;
		}
	}
	return($qualpass);
}

sub searchPrimers {
	my ($fseq, $fqual, $rseq, $rqual, $ward, $seqname, $options, $child) = @_;
	if ($rseq && $rqual) {
		my $primername;
		my $fumiseq;
		my $fumiqual;
		my $rumiseq;
		my $rumiqual;
		foreach my $tempname (@primer) {
			my $fstart;
			my $fend;
			my $fpmismatch;
			my $fnmismatch;
			($fstart, $fend, $fpmismatch, $fnmismatch, $fumiseq) = &alignPrimer(substr($fseq, 0, length($primer{$tempname}) * 2), $primer{$tempname}, 0);
			if ((defined($maxnmismatch) && $fnmismatch > $maxnmismatch) || $fpmismatch > $maxpmismatch) {
				next;
			}
			else {
				if ($fumiseq) {
					$fumiqual = substr($fqual, $fstart, length($fumiseq));
				}
				my $tempsubstr1;
				my $tempsubstr2;
				if ($elimprimer){
					substr($fseq, 0, $fend + 1, '');
					substr($fqual, 0, $fend + 1, '');
				}
				else {
					$tempsubstr1 = substr($fseq, 0, $fend + 1, '');
				}
				if ($reverseprimerfile) {
					my $rstart;
					my $rend;
					my $rpmismatch;
					my $rnmismatch;
					($rstart, $rend, $rpmismatch, $rnmismatch, $rumiseq) = &alignPrimer(substr($rseq, 0, length($reverseprimer{$tempname}) * 2), $reverseprimer{$tempname}, $ward);
					if ((defined($reversemaxnmismatch) && $rnmismatch > $reversemaxnmismatch) || $rpmismatch > $reversemaxpmismatch) {
						next;
					}
					else {
						if ($rumiseq) {
							$rumiqual = substr($rqual, $rstart, length($rumiseq));
						}
						if ($elimprimer) {
							substr($rseq, 0, $rend + 1, '');
							substr($rqual, 0, $rend + 1, '');
						}
						else {
							$tempsubstr2 = substr($rseq, 0, $rend + 1, '');
						}
					}
				}
				$fseq = lc($tempsubstr1) . $fseq;
				$rseq = lc($tempsubstr2) . $rseq;
				$primername = $tempname;
				last;
			}
		}
		if ($fseq && $fqual && $rseq && $rqual) {
			if ($fumiseq && $fumiqual) {
				$options->{'fumiseq'} = $fumiseq;
				$options->{'fumiqual'} = $fumiqual;
			}
			if ($rumiseq && $rumiqual) {
				$options->{'rumiseq'} = $rumiseq;
				$options->{'rumiqual'} = $rumiqual;
			}
			if ($primername) {
				$options->{'primername'} = $primername;
				&saveToFile($fseq, $fqual, 1, $seqname, $options, $child);
				&saveToFile($rseq, $rqual, 2, $seqname, $options, $child);
			}
			else {
				$options->{'primername'} = 'undetermined';
				&saveToFile($fseq, $fqual, 1, $seqname, $options, $child);
				&saveToFile($rseq, $rqual, 2, $seqname, $options, $child);
			}
		}
	}
	else {
		my $primername;
		my $fumiseq;
		my $fumiqual;
		my $rumiseq;
		my $rumiqual;
		foreach my $tempname (@primer) {
			my $fstart;
			my $fend;
			my $fpmismatch;
			my $fnmismatch;
			($fstart, $fend, $fpmismatch, $fnmismatch, $fumiseq) = &alignPrimer(substr($fseq, 0, length($primer{$tempname}) * 2), $primer{$tempname}, 0);
			if ((defined($maxnmismatch) && $fnmismatch > $maxnmismatch) || $fpmismatch > $maxpmismatch) {
				next;
			}
			else {
				if ($fumiseq) {
					$fumiqual = substr($fqual, $fstart, length($fumiseq));
				}
				my $tempsubstr1;
				my $tempsubstr2;
				if ($elimprimer){
					substr($fseq, 0, $fend + 1, '');
					substr($fqual, 0, $fend + 1, '');
				}
				else {
					$tempsubstr1 = substr($fseq, 0, $fend + 1, '');
				}
				if ($reverseprimerfile && $ward == 1) {
					my $rstart;
					my $rend;
					my $rpmismatch;
					my $rnmismatch;
					($rstart, $rend, $rpmismatch, $rnmismatch, $rumiseq) = &alignPrimer($fseq, $reverseprimer{$tempname}, $ward);
					if ((defined($reversemaxnmismatch) && $rnmismatch > $reversemaxnmismatch) || $rpmismatch > $reversemaxpmismatch) {
						if ($needreverseprimer) {
							next;
						}
					}
					else {
						if ($rumiseq) {
							$rumiqual = substr($fqual, $rend - length($rumiseq) + 1, length($rumiseq));
						}
						if ($elimprimer) {
							substr($fseq, $rstart, length($fseq) - $rstart, '');
							substr($fqual, $rstart, length($fqual) - $rstart, '');
						}
						else {
							$tempsubstr2 = substr($fseq, $rstart, length($fseq) - $rstart, '');
						}
					}
				}
				elsif ($reverseprimerfile && $ward == 2) {
					my $rstart;
					my $rend;
					my $rpmismatch;
					my $rnmismatch;
					($rstart, $rend, $rpmismatch, $rnmismatch, $rumiseq) = &alignPrimer(substr($fseq, -1 * length($reverseprimer{$tempname}) * 2), $reverseprimer{$tempname}, $ward);
					if ((defined($reversemaxnmismatch) && $rnmismatch > $reversemaxnmismatch) || $rpmismatch > $reversemaxpmismatch) {
						if ($needreverseprimer) {
							next;
						}
					}
					else {
						if (length($reverseprimer{$tempname}) * 2 < length($fseq)) {
							$rstart += length($fseq) - (length($reverseprimer{$tempname}) * 2);
							$rend += length($fseq) - (length($reverseprimer{$tempname}) * 2);
						}
						if ($rumiseq) {
							$rumiqual = substr($fqual, $rend - length($rumiseq) + 1, length($rumiseq));
						}
						if ($elimprimer) {
							substr($fseq, $rstart, length($fseq) - $rstart, '');
							substr($fqual, $rstart, length($fqual) - $rstart, '');
						}
						else {
							$tempsubstr2 = substr($fseq, $rstart, length($fseq) - $rstart, '');
						}
					}
				}
				$fseq = lc($tempsubstr1) . $fseq . lc($tempsubstr2);
				$primername = $tempname;
				last;
			}
		}
		if ($fseq && $fqual) {
			if ($fumiseq && $fumiqual) {
				$options->{'fumiseq'} = $fumiseq;
				$options->{'fumiqual'} = $fumiqual;
			}
			if ($rumiseq && $rumiqual) {
				$options->{'rumiseq'} = $rumiseq;
				$options->{'rumiqual'} = $rumiqual;
			}
			if ($primername) {
				$options->{'primername'} = $primername;
				&saveToFile($fseq, $fqual, 0, $seqname, $options, $child);
			}
			else {
				$options->{'primername'} = 'undetermined';
				&saveToFile($fseq, $fqual, 0, $seqname, $options, $child);
			}
		}
	}
}

sub saveToFile {
	my ($nucseq, $qualseq, $strand, $seqname, $options, $child) = @_;
	my $samplename = $runname;
	if ($options->{'tagname'}) {
		$samplename .= '__' . $options->{'tagname'};
	}
	if ($options->{'primername'}) {
		$samplename .= '__' . $options->{'primername'};
	}
	if ($options->{'fumiseq'} =~ /-/ || $options->{'rumiseq'} =~ /-/) {
		$samplename .= '__incompleteUMI';
	}
	my $filenamesuffix;
	if ($strand == 1) {
		$filenamesuffix = ".forward";
	}
	elsif ($strand == 2) {
		$filenamesuffix = ".reverse";
	}
	if (!-e "$outputfolder/$samplename$filenamesuffix") {
		mkdir("$outputfolder/$samplename$filenamesuffix");
	}
	unless (open($filehandleoutput1, ">> $outputfolder/$samplename$filenamesuffix/$child.fastq")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfolder/$samplename$filenamesuffix/$child.fastq\".");
	}
	unless (flock($filehandleoutput1, LOCK_EX)) {
		&errorMessage(__LINE__, "Cannot lock \"$outputfolder/$samplename$filenamesuffix/$child.fastq\".");
	}
	unless (seek($filehandleoutput1, 0, 2)) {
		&errorMessage(__LINE__, "Cannot seek \"$outputfolder/$samplename$filenamesuffix/$child.fastq\".");
	}
	if ($seqnamestyle eq 'illumina') {
		if ($options->{'fumiseq'} && $options->{'rumiseq'}) {
			my $umiseq = ':' . $options->{'fumiseq'} . '+' . $options->{'rumiseq'};
			if ($seqname =~ / /) {
				$seqname =~ s/ /$umiseq /;
			}
			else {
				$seqname .= $umiseq;
			}
		}
		elsif ($options->{'fumiseq'}) {
			my $umiseq = ':' . $options->{'fumiseq'};
			if ($seqname =~ / /) {
				$seqname =~ s/ /$umiseq /;
			}
			else {
				$seqname .= $umiseq;
			}
		}
		if ($seqname !~ / [12]:[NY]:\d+:(?:\d+|[ACGT]+|[ACGT]+\+[ACGT]+)$/ || $seqname =~ s/ [12]:N:0:\d+$//) {
			if ($strand == 2) {
				$seqname .= ' 2:N:0:';
			}
			else {
				$seqname .= ' 1:N:0:';
			}
			if ($options->{'tagseq'}) {
				$seqname .= $options->{'tagseq'};
			}
			else {
				$seqname .= '1';
			}
		}
	}
	if ($options->{'fumiseq'} && $options->{'rumiseq'}) {
		$seqname .= ' UMI:' . $options->{'fumiseq'} . '+' . $options->{'rumiseq'};
	}
	elsif ($options->{'fumiseq'}) {
		$seqname .= ' UMI:' . $options->{'fumiseq'};
	}
	if ($options->{'tagseq'}) {
		$seqname .= ' MID:' . $options->{'tagseq'};
	}
	$seqname .= " SN:$samplename";
	if ($addUMI) {
		if ($strand == 0) {
			print($filehandleoutput1 "\@$seqname\n" . $options->{'fumiseq'} . "$nucseq" . $options->{'rumiseq'} . "\n+\n" . $options->{'fumiqual'} . "$qualseq" . $options->{'rumiqual'} . "\n");
		}
		elsif ($strand == 1) {
			print($filehandleoutput1 "\@$seqname\n" . $options->{'fumiseq'} . "$nucseq\n+\n" . $options->{'fumiqual'} . "$qualseq\n");
		}
		elsif ($strand == 2) {
			print($filehandleoutput1 "\@$seqname\n" . $options->{'rumiseq'} . "$nucseq\n+\n" . $options->{'rumiqual'} . "$qualseq\n");
		}
	}
	else {
		print($filehandleoutput1 "\@$seqname\n$nucseq\n+\n$qualseq\n");
	}
	close($filehandleoutput1);
}

sub concatenateFASTQ {
	print(STDERR "Concatenating FASTQ files...\n");
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		my @fastqfolder = glob("$outputfolder/$runname\__*");
		foreach my $fastqfolder (@fastqfolder) {
			if (-d $fastqfolder) {
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
					print(STDERR "Concatenating $fastqfolder...\n");
					if ($compress) {
						$filehandleoutput1 = writeFile("$fastqfolder.fastq.$compress");
					}
					else {
						$filehandleoutput1 = writeFile("$fastqfolder.fastq");
					}
					foreach my $fastq (glob("$fastqfolder/*.fastq")) {
						unless (open($filehandleinput1, "< $fastq")) {
							&errorMessage(__LINE__, "Cannot open \"$fastq\".");
						}
						while (<$filehandleinput1>) {
							print($filehandleoutput1 $_);
						}
						close($filehandleinput1);
						unlink($fastq);
					}
					close($filehandleoutput1);
					rmdir($fastqfolder);
					exit;
				}
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

sub alignPrimer {
	# $ward == 0: case of forward primer at the head of forward read or reverse primer at the head of reverse read
	# $ward == 1: case of reverse primer at the middle of forward read
	# $ward == 2: case of reverse primer at the tail of forward read
	my $subject = $_[0];
	my ($newsubject, $newquery) = alignTwoSequences($_[0], $_[1]);
	my $ward = $_[2];
	my $subquery = $newquery;
	my $front;
	# case of reverse primer at the middle or tail of forward read
	if ($ward != 0) {
		$front = $subquery =~ s/^-+//;
	}
	# case of forward primer at the head of forward read or reverse primer at the head of reverse read or reverse primer at the middle of forward read
	if ($ward != 2) {
		my $rear = $subquery =~ s/-+$//;
	}
	my $start;
	# case of reverse primer at the tail of forward read
	if ($ward == 2) {
		$start = index($newquery, $subquery);
	}
	# case of forward primer at the head of forward read or reverse primer at the head of reverse read or reverse primer at the middle of forward read
	else {
		$start = rindex($newquery, $subquery);
	}
	my $end;
	my $sublength = length($subquery);
	my $subsubject = substr($newsubject, $start, $sublength);
	my $nmismatch = 0;
	my $alnlength = 0;
	my $head = 1;
	my $umiseq;
	# case of reverse primer at the middle or tail of forward read
	if ($ward) {
		for (my $i = -1; $i >= ($sublength * (-1)); $i --) {
			my $qc = substr($subquery, $i, 1);
			my $sc = substr($subsubject, $i, 1);
			if ($head && $qc eq 'N' && $useNasUMI > length($umiseq)) {
				$umiseq = $sc . $umiseq;
			}
			if ($truncateN && $head && $qc eq 'N') {
				next;
			}
			else {
				if (&testCompatibility($qc, $sc)) {
					$alnlength ++;
				}
				else {
					$nmismatch ++;
					$alnlength ++;
				}
				$head = 0;
			}
		}
	}
	# case of forward primer at the head of forward read or reverse primer at the head of reverse read
	else {
		for (my $i = 0; $i < $sublength; $i ++) {
			my $qc = substr($subquery, $i, 1);
			my $sc = substr($subsubject, $i, 1);
			if ($head && $qc eq 'N' && $useNasUMI > length($umiseq)) {
				$umiseq .= $sc;
			}
			if ($truncateN && $head && $qc eq 'N') {
				next;
			}
			else {
				if (&testCompatibility($qc, $sc)) {
					$alnlength ++;
				}
				else {
					$nmismatch ++;
					$alnlength ++;
				}
				$head = 0;
			}
		}
	}
	my $pmismatch = $nmismatch / $alnlength;
	# debug print
	#print(">query\n$newquery\n>subject\n$newsubject\n\n");
	$subsubject =~ s/-+//g;
	if (!$front) {
		$start = 0;
	}
	else {
		$start = rindex($subject, $subsubject);
	}
	if ($start == -1) {
		$end = -1;
	}
	else {
		$end = $start + length($subsubject) - 1;
	}
	return($start, $end, $pmismatch, $nmismatch, $umiseq);
}

sub alignTwoSequences {
	my @subject = split(//, $_[0]);
	my @query = split(//, $_[1]);
	# align sequences by Needleman-Wunsch algorithm
	{
		my $subjectlength = scalar(@subject);
		my $querylength = scalar(@query);
		# make alignment matrix, gap matrix, route matrix
		my @amatrix;
		my @rmatrix;
		$rmatrix[0][0] = 0;
		$rmatrix[0][1] = 1;
		for (my $i = 2; $i <= $querylength; $i ++) {
			$rmatrix[0][$i] = 1;
		}
		$rmatrix[1][0] = 2;
		for (my $i = 2; $i <= $subjectlength; $i ++) {
			$rmatrix[$i][0] = 2;
		}
		$amatrix[0][0] = 0;
		if ($endgap eq 'gap') {
			$amatrix[0][1] = $goscore;
			for (my $i = 2; $i <= $querylength; $i ++) {
				$amatrix[0][$i] += $amatrix[0][($i - 1)] + $gescore;
			}
			$amatrix[1][0] = $goscore;
			for (my $i = 2; $i <= $subjectlength; $i ++) {
				$amatrix[$i][0] += $amatrix[($i - 1)][0] + $gescore;
			}
		}
		elsif ($endgap eq 'mismatch') {
			$amatrix[0][1] = $mmscore;
			for (my $i = 2; $i <= $querylength; $i ++) {
				$amatrix[0][$i] += $amatrix[0][($i - 1)] + $mmscore;
			}
			$amatrix[1][0] = $mmscore;
			for (my $i = 2; $i <= $subjectlength; $i ++) {
				$amatrix[$i][0] += $amatrix[($i - 1)][0] + $mmscore;
			}
		}
		elsif ($endgap eq 'match') {
			$amatrix[0][1] = $mscore;
			for (my $i = 2; $i <= $querylength; $i ++) {
				$amatrix[0][$i] += $amatrix[0][($i - 1)] + $mscore;
			}
			$amatrix[1][0] = $mscore;
			for (my $i = 2; $i <= $subjectlength; $i ++) {
				$amatrix[$i][0] += $amatrix[($i - 1)][0] + $mscore;
			}
		}
		elsif ($endgap eq 'nobody') {
			$amatrix[0][1] = 0;
			for (my $i = 2; $i <= $querylength; $i ++) {
				$amatrix[0][$i] = 0;
			}
			$amatrix[1][0] = 0;
			for (my $i = 2; $i <= $subjectlength; $i ++) {
				$amatrix[$i][0] = 0;
			}
		}
		# fill matrix
		for (my $i = 1; $i <= $subjectlength; $i ++) {
			for (my $j = 1; $j <= $querylength; $j ++) {
				my @score;
				if (&testCompatibility($query[($j * (-1))], $subject[($i * (-1))])) {
					push(@score, $amatrix[($i - 1)][($j - 1)] + $mscore);
				}
				else {
					push(@score, $amatrix[($i - 1)][($j - 1)] + $mmscore);
				}
				if ($endgap ne 'gap' && ($i == $subjectlength || $j == $querylength)) {
					if ($endgap eq 'mismatch') {
						push(@score, $amatrix[$i][($j - 1)] + $mmscore);
						push(@score, $amatrix[($i - 1)][$j] + $mmscore);
					}
					elsif ($endgap eq 'match') {
						push(@score, $amatrix[$i][($j - 1)] + $mscore);
						push(@score, $amatrix[($i - 1)][$j] + $mscore);
					}
					elsif ($endgap eq 'nobody') {
						push(@score, $amatrix[$i][($j - 1)]);
						push(@score, $amatrix[($i - 1)][$j]);
					}
				}
				else {
					if ($rmatrix[$i][($j - 1)] == 1) {
						push(@score, $amatrix[$i][($j - 1)] + $gescore);
					}
					else {
						push(@score, $amatrix[$i][($j - 1)] + $goscore);
					}
					if ($rmatrix[($i - 1)][$j] == 2) {
						push(@score, $amatrix[($i - 1)][$j] + $gescore);
					}
					else {
						push(@score, $amatrix[($i - 1)][$j] + $goscore);
					}
				}
				if (($score[1] > $score[0] || $score[1] == $score[0] && $i == $subjectlength) && $score[1] > $score[2]) {
					$amatrix[$i][$j] = $score[1];
					$rmatrix[$i][$j] = 1;
				}
				elsif (($score[2] > $score[0] || $score[2] == $score[0] && $j == $querylength) && $score[2] >= $score[1]) {
					$amatrix[$i][$j] = $score[2];
					$rmatrix[$i][$j] = 2;
				}
				else {
					$amatrix[$i][$j] = $score[0];
					$rmatrix[$i][$j] = 0;
				}
			}
		}
		my @newsubject;
		my @newquery;
		my ($ipos, $jpos) = ($subjectlength, $querylength);
		while ($ipos != 0 && $jpos != 0) {
			if ($rmatrix[$ipos][$jpos] == 1) {
				push(@newsubject, '-');
				push(@newquery, shift(@query));
				$jpos --;
			}
			elsif ($rmatrix[$ipos][$jpos] == 2) {
				push(@newsubject, shift(@subject));
				push(@newquery, '-');
				$ipos --;
			}
			else {
				push(@newsubject, shift(@subject));
				push(@newquery, shift(@query));
				$ipos --;
				$jpos --;
			}
		}
		if (@query) {
			while (@query) {
				push(@newsubject, '-');
				push(@newquery, shift(@query));
			}
		}
		elsif (@subject) {
			while (@subject) {
				push(@newsubject, shift(@subject));
				push(@newquery, '-');
			}
		}
		return(join('', @newsubject), join('', @newquery));
	}
}

sub testCompatibility {
	# 0: incompatible
	# 1: compatible
	my ($seq1, $seq2) = @_;
	my $compatibility = 1;
	if ($seq1 ne $seq2) {
		if ($seq1 eq '-' && $seq2 ne '-' ||
			$seq1 ne '-' && $seq2 eq '-' ||
			$seq1 eq 'A' && $seq2 =~ /^[CGTUSYKB]$/ ||
			$seq1 eq 'C' && $seq2 =~ /^[AGTURWKD]$/ ||
			$seq1 eq 'G' && $seq2 =~ /^[ACTUMWYH]$/ ||
			$seq1 =~ /^[TU]$/ && $seq2 =~ /^[ACGMRSV]$/ ||
			$seq1 eq 'M' && $seq2 =~ /^[KGT]$/ ||
			$seq1 eq 'R' && $seq2 =~ /^[YCT]$/ ||
			$seq1 eq 'W' && $seq2 =~ /^[SCG]$/ ||
			$seq1 eq 'S' && $seq2 =~ /^[WAT]$/ ||
			$seq1 eq 'Y' && $seq2 =~ /^[RAG]$/ ||
			$seq1 eq 'K' && $seq2 =~ /^[MAC]$/ ||
			$seq1 eq 'B' && $seq2 eq 'A' ||
			$seq1 eq 'D' && $seq2 eq 'C' ||
			$seq1 eq 'H' && $seq2 eq 'G' ||
			$seq1 eq 'V' && $seq2 =~ /^[TU]$/) {
			$compatibility = 0;
		}
	}
	return($compatibility);
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
clsplitseq options inputfiles outputfolder

Command line options
====================
--runname=RUNNAME
  Specify run name. This is mandatory. (default: none)

--seqnamestyle=ILLUMINA|OTHER|NOCHANGE
  Specify sequence name style. (default:ILLUMINA)

--primername=PRIMERNAME
  Specify primer name. (default: none)

--tagname=TAGNAME
  Specify tag name. (default: none)

--indexname=INDEXNAME
  Specify index name. (default: none)

--compress=GZIP|BZIP2|XZ|DISABLE
  Specify compress output files or not. (default: GZIP)

-p, --primerfile=FILENAME
-fp, --forwardprimerfile=FILENAME
  Specify forward primer list file name. (default: none)

--maxpmismatch=DECIMAL
  Specify maximum acceptable mismatch percentage for primers. (default: 0.14)

--maxnmismatch=INTEGER
  Specify maximum acceptable mismatch number for primers.
(default: Inf)

--reverseprimerfile=FILENAME
  Specify reverse primer list file name. (default: none)

--reversecomplement
  If this option is specified, reverse-complement of reverse primer sequence
will be searched. (default: off)

--reversemaxpmismatch=DECIMAL
  Specify maximum acceptable mismatch percentage for reverse primers.
(default: 0.15)

--reversemaxnmismatch=INTEGER
  Specify maximum acceptable mismatch number for reverse primers.
(default: Inf)

--needreverseprimer
  If this option is specified, unmatched sequence to reverse primer will not be
output. (default: off)

--truncateN=ENABLE|DISABLE
  Specify truncate Ns of 5'-end of primer or not. (default: DISABLE)

--useNasUMI=ENABLE|DISABLE|INTEGER
  Specify whether Ns of 5'-end of primer will be used as UMI or not.
If you want to restrict length of UMI, give INTEGER instead of Boolean.
(default: DISABLE)

--addUMI=ENABLE|DISABLE
  Specify whether UMI will be added to output sequences or not.
(default: ENABLE if useNasUMI is ENABLE)

--elimprimer=ENABLE|DISABLE
  Specify eliminate primer or not. (default:ENABLE)

-t, --tagfile=FILENAME
  Specify tag list file name. (default: none)

--reversetagfile=FILENAME
  Specify reverse tag list file name. (default: none)

--index1file=FILENAME
  Specify index1 file name for Illumina data. (default: none)

--index2file=FILENAME
  Specify index2 file name for Illumina data. (default: none)

-a, --append
  Specify outputfile append or not. (default: off)

--minqualtag=INTEGER
  Specify minimum quality threshold for tag. (default: 0)

--gapopenscore=INTEGER
  Specify gap open score for alignment of primers. (default: -10)

--gapextensionscore=INTEGER
  Specify gap extension score for alignment of primers. (default: -1)

--mismatchscore=INTEGER
  Specify mismatch score for alignment of primers. (default: -4)

--matchscore=INTEGER
  Specify match score for alignment of primers. (default: 5)

--endgap=NOBODY|MATCH|MISMATCH|GAP
  Specify end gap treatment. (default: nobody)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
FASTQ (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
(Quality values must be encoded in Sanger format.)
_END
	exit;
}
