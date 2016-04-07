use strict;
use Fcntl ':flock';
use File::Spec;

my $buildno = '0.2.2016.04.07';

my $devnull = File::Spec->devnull();

# options
my $primerfile;
my $maxpmismatch = 0.15;
my $maxnmismatch;
my $reverseprimerfile;
my $reversemaxpmismatch = 0.15;
my $reversemaxnmismatch;
my $minlen;
my $maxlen;
my $minqual = 30;
my $minquallen = 5;
my $minasmlen;
my $maxasmlen;
my $lowqual = 20;
my $maxplowqual = 0.05;
my $runname;
my $append;
my $pearoption;
my $numthreads = 1;

# Input/Output
my $inputfile;
my $outputfolder;

# other variables
my %primer;
my %reverseprimer;
my %reverseprimerrevcomp;
my @sample;
my @pairend;
my @pairendfile;
my %separate;

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
	# read primers
	&readPrimers();
	# read samplesheet
	&readSamplesheet();
	# process FASTQ files
	&processFASTQ();
	# assemble by PEAR
	&assembleByPEAR();
	# process assembled sequences
	&processAssembledFASTQ();
	# compress FASTQ files
	&compressFASTQ();
}

sub printStartupMessage {
	print(STDERR <<"_END");
climportillumina $buildno
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
}

sub getOptions {
	$inputfile = $ARGV[-2];
	unless (-e $inputfile) {
		&errorMessage(__LINE__, "\"$inputfile\" does not exist.");
	}
	$outputfolder = $ARGV[-1];
	my $pearmode = 0;
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] eq 'end') {
			$pearmode = 0;
		}
		elsif ($pearmode) {
			$pearoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] eq 'pear') {
			$pearmode = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:5prime|forward|f)?(?:primer|primerfile|p)=(.+)$/i) {
			$primerfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)mismatch=(.+)$/i) {
			$maxpmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?mismatch=(.+)$/i) {
			$maxnmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)(?:primer|primerfile)=(.+)$/i) {
			$reverseprimerfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)max(?:imum)?(?:r|rate|p|percentage)mismatch=(.+)$/i) {
			$reversemaxpmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)max(?:imum)?n(?:um)?mismatch=(.+)$/i) {
			$reversemaxnmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?len(?:gth)?=(\d+)$/i) {
			$minlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?len(?:gth)?=(\d+)$/i) {
			$maxlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?qual(?:ity)?=(\d+)$/i) {
			$minqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?qual(?:ity)?len(?:gth)?=(\d+)$/i) {
			$minquallen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:asm|assembled)len(?:gth)?=(\d+)$/i) {
			$minasmlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:asm|assembled)len(?:gth)?=(\d+)$/i) {
			$maxasmlen = $1;
		}
		elsif ($ARGV[$i] =~ /^-+lowqual(?:ity)?=(\d+)$/i) {
			$lowqual = $1;
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)lowqual(?:ity)?=(.+)$/i) {
			$maxplowqual = $1;
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
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
		}
	}
}

sub checkVariables {
	if (!$append && -e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
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
	if ($runname =~ /__/) {
		&errorMessage(__LINE__, "\"$runname\" is invalid name. Do not use \"__\" in run name.");
	}
	if ($runname =~ /\s/) {
		&errorMessage(__LINE__, "\"$runname\" is invalid name. Do not use spaces or tabs in run name.");
	}
	if ($pearoption !~ /(?:--min-overlap|-v)/) {
		$pearoption .= ' -v 20';
	}
	if ($pearoption !~ /(?:--max-uncalled-base|-u)/) {
		$pearoption .= ' -u 0';
	}
	if ($pearoption !~ /(?:--threads|-j)/ && $numthreads) {
		$pearoption .= " -j $numthreads";
	}
	if ($pearoption !~ /(?:--min-assembly-length|-n)/ && $minasmlen) {
		print(STDERR "Command line options for pear :$pearoption -n (minasmlen + forwardprimerlength + reverseprimerlength)\n\n");
	}
	else {
		print(STDERR "Command line options for pear :$pearoption\n\n");
	}
	$minqual += 33;
}

sub readPrimers {
	print(STDERR "Reading primer files...\n");
	my @primer;
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
				my @tempprimer = split('', $primer);
				if (exists($primer{$name})) {
					&errorMessage(__LINE__, "Primer \"$name\" is doubly used in \"$primerfile\".");
				}
				else {
					$primer{$name} = \@tempprimer;
					push(@primer, $name);
				}
			}
		}
		close($filehandleinput1);
		print(STDERR "Forward primers\n");
		foreach (@primer) {
			print(STDERR "$_ : " . join('', @{$primer{$_}}) . "\n");
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
				my @tempreverseprimer = split('', $reverseprimer);
				my @tempreverseprimerrevcomp = &reversecomplement(@tempreverseprimer);
				if ($primer[$tempno]) {
					$reverseprimer{$primer[$tempno]} = \@tempreverseprimer;
					$reverseprimerrevcomp{$primer[$tempno]} = \@tempreverseprimerrevcomp;
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
			print(STDERR "$_ : " . join('', @{$reverseprimer{$_}}) . "\n");
		}
		print(STDERR "Reverse primers (reverse-complemented)\n");
		foreach (@primer) {
			print(STDERR "$_ : " . join('', @{$reverseprimerrevcomp{$_}}) . "\n");
		}
	}
	print(STDERR "done.\n\n");
}

sub readSamplesheet {
	print(STDERR "Reading sample sheet...\n");
	unless (open($filehandleinput1, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot open \"$inputfile\".");
	}
	my $sample;
	my $description;
	my $ncol;
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		if (/Sample_?ID/i) {
			my @label = split(/\s*,\s*/, $_, -1);
			$ncol = scalar(@label);
			for (my $i = 0; $i < $ncol; $i ++) {
				if ($label[$i] =~ /^Sample_?ID$/i) {
					$sample = $i;
				}
				elsif ($label[$i] =~ /^Description$/i) {
					$description = $i;
				}
			}
		}
		elsif (defined($sample)) {
			my @row = split(/\s*,\s*/, $_, -1);
			if (scalar(@row) == $ncol) {
				if ($row[$sample] =~ /^[^_]+__([^_]+)$/ && $primer{$1}) {
					push(@sample, $row[$sample]);
				}
				else {
					&errorMessage(__LINE__, "SampleID \"$row[$sample]\" is invalid.\nSampleID need to be \"TemplateID__PrimerSetID\".");
				}
				if ($row[$description] =~ /^Separate/i || $row[$description] =~ /Separate$/i) {
					$separate{$row[$sample]} = 1;
				}
			}
			else {
				last;
			}
		}
	}
	close($filehandleinput1);
	print(STDERR "Sample list\n");
	foreach (@sample) {
		print(STDERR "$_\n");
	}
	print(STDERR "done.\n\n");
}

sub processFASTQ {
	print(STDERR "Processing FASTQs...\n");
	if (!-e $outputfolder && !mkdir($outputfolder)) {
		&errorMessage(__LINE__, "Cannot make output folder.");
	}
	foreach my $sample (@sample) {
		my $pairend;
		while (my $freadfile = glob("$sample\_*_R1*.fastq.gz")) {
			if ($freadfile =~ /^$sample\_.+_R1[_\.]\d+\.fastq\.gz$/) {
				my $rreadfile = $freadfile;
				$rreadfile =~ s/_R1([_\.]\d+\.fastq\.gz)$/_R2$1/;
				if (-e $rreadfile) {
					if ($separate{$sample}) {
						&splitToNEWFASTQ($freadfile, $sample, 1);
						&splitToNEWFASTQ($rreadfile, $sample, 2);
					}
					else {
						push(@pairendfile, $freadfile, $rreadfile);
						$pairend ++;
					}
				}
				elsif ($pairend) {
					&errorMessage(__LINE__, "\"$sample\" is invalid sample.");
				}
				else {
					&splitToNEWFASTQ($freadfile, $sample, 0);
				}
			}
		}
		if ($pairend) {
			push(@pairend, $sample);
		}
	}
	print(STDERR "done.\n\n");
}

sub assembleByPEAR {
	if (@pairendfile) {
		print(STDERR "Decompressing paired-end sequences...\n");
		&decompressByGZIP(@pairendfile);
		print(STDERR "done.\n\n");
	}
	if (@pairend) {
		print(STDERR "Assembling paired-end sequences...\n");
		foreach my $sample (@pairend) {
			while (my $freadfile = glob("$outputfolder/$sample\_*_R1*.fastq")) {
				if ($freadfile =~ /($sample\_.+)_R1([_\.]\d+)\.fastq$/) {
					my $outprefix = "$outputfolder/$1$2";
					my $rreadfile = $freadfile;
					$rreadfile =~ s/_R1([_\.]\d+\.fastq)$/_R2$1/;
					if (-e $rreadfile) {
						$sample =~ /^([^_]+)__([^_]+)$/;
						my $template = $1;
						my $primer = $2;
						my $additionalpearoption;
						if ($pearoption !~ /(?:--min-assembly-length|-n)/ && $minasmlen) {
							$additionalpearoption = " -n " . ($minasmlen + scalar(@{$primer{$primer}}) + scalar(@{$reverseprimerrevcomp{$primer}}));
						}
						if (system("pear$pearoption$additionalpearoption -f $freadfile -r $rreadfile -o $outprefix")) {
							&errorMessage(__LINE__, "Cannot run \"pear$pearoption$additionalpearoption -f $freadfile -r $rreadfile -o $outprefix\".");
						}
						unlink($freadfile);
						unlink($rreadfile);
						unlink("$outprefix.discarded.fastq");
						unlink("$outprefix.unassembled.forward.fastq");
						unlink("$outprefix.unassembled.reverse.fastq");
					}
					else {
						&errorMessage(__LINE__, "\"$sample\" is invalid sample.");
					}
				}
			}
		}
		print(STDERR "done.\n\n");
	}
}

sub processAssembledFASTQ {
	if (@pairend) {
		print(STDERR "Processing assembled FASTQs...\n");
		foreach my $sample (@pairend) {
			while (my $readfile = glob("$outputfolder/$sample\_*.assembled.fastq")) {
				&splitToNEWFASTQ($readfile, $sample, 3);
				unlink($readfile);
			}
		}
		print(STDERR "done.\n\n");
	}
}

sub splitToNEWFASTQ {
	my $readfile = shift(@_);
	my $sample = shift(@_);
	my $status = shift(@_);
	$sample =~ /^([^_]+)__([^_]+)$/;
	my $template = $1;
	my $primer = $2;
	print(STDERR "Processing $readfile...\n");
	$filehandleinput1 = &readFile($readfile);
	{
		my $tempnline = 1;
		my $seqname;
		my @nucseq;
		my @qualseq;
		my $child = 0;
		$| = 1;
		$? = 0;
		# Processing FASTQ in parallel
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if ($tempnline % 4 == 1 && /^\@(\S+)/) {
				$seqname = $1;
				if ($seqname =~ /__/) {
					&errorMessage(__LINE__, "\"$seqname\" is invalid name. Do not use \"__\" in sequence name.\nFile: $readfile\nLine: $tempnline");
				}
			}
			elsif ($tempnline % 4 == 2) {
				s/[^a-zA-Z]//g;
				@nucseq = split('', uc($_));
			}
			elsif ($tempnline % 4 == 3 && /^\+/) {
				$tempnline ++;
				next;
			}
			elsif ($tempnline % 4 == 0 && $seqname && @nucseq) {
				s/\s//g;
				@qualseq = unpack('C*', $_);
				if (my $pid = fork()) {
					$child ++;
					if ($child == $numthreads * 2) {
						if (wait == -1) {
							$child = 0;
						} else {
							$child --;
						}
					}
					if ($?) {
						&errorMessage(__LINE__);
					}
					undef($seqname);
					undef(@nucseq);
					undef(@qualseq);
					$tempnline ++;
					next;
				}
				else {
					&processOneSequence($sample, $status, $primer, $seqname, \@nucseq, \@qualseq, $readfile, $tempnline);
					exit;
				}
			}
			else {
				&errorMessage(__LINE__, "Invalid FASTQ.\nFile: $readfile\nLine: $tempnline");
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
}

sub processOneSequence {
	my $sample = shift(@_);
	my $status = shift(@_);
	my $primer = shift(@_);
	my $seqname = shift(@_);
	my $nucseq = shift(@_);
	my $qualseq = shift(@_);
	my $readfile = shift(@_);
	my $tempnline = shift(@_);
	# check length
	if (scalar(@{$nucseq}) != scalar(@{$qualseq})) {
		&errorMessage(__LINE__, "Base length is not equal to quality length.\nFile: $readfile\nLine: $tempnline");
	}
	# store primer length
	my $primerlength;
	if ($primer{$primer}) {
		$primerlength = scalar(@{$primer{$primer}});
	}
	my $reverseprimerlength;
	if ($reverseprimer{$primer}) {
		$reverseprimerlength = scalar(@{$reverseprimer{$primer}});
	}
	# skip short sequence
	if ($status == 3) {
		if ($minasmlen && (scalar(@{$nucseq}) - $primerlength - $reverseprimerlength) < $minasmlen) {
			exit;
		}
	}
	elsif ($status == 0 || $status == 1) {
		if ($minlen && (scalar(@{$nucseq}) - $primerlength) < $minlen) {
			exit;
		}
	}
	elsif ($status == 2) {
		if ($minlen && (scalar(@{$nucseq}) - $reverseprimerlength) < $minlen) {
			exit;
		}
	}
	# skip long sequence
	if ($status == 3) {
		if ($maxasmlen && (scalar(@{$nucseq}) - $primerlength - $reverseprimerlength) > $maxasmlen) {
			exit;
		}
	}
	elsif ($status == 0 || $status == 1) {
		if ($maxlen && (scalar(@{$nucseq}) - $primerlength) > $maxlen) {
			exit;
		}
	}
	elsif ($status == 2) {
		if ($maxlen && (scalar(@{$nucseq}) - $reverseprimerlength) > $maxlen) {
			exit;
		}
	}
	# check primer position and eliminate
	if (($status == 0 || $status == 1 || $status == 3) && $primer{$primer}) {
		my $nmismatch = 0;
		for (my $i = 0; $i < $primerlength; $i ++) {
			$nmismatch += &testCompatibility($primer{$primer}[$i], $nucseq->[$i]);
		}
		if ((defined($maxnmismatch) && $nmismatch > $maxnmismatch) || $nmismatch / $primerlength > $maxpmismatch) {
			exit;
		}
		splice(@{$nucseq}, 0, $primerlength);
		splice(@{$qualseq}, 0, $primerlength);
	}
	elsif ($status == 2 && $reverseprimer{$primer}) {
		my $nmismatch = 0;
		for (my $i = 0; $i < $reverseprimerlength; $i ++) {
			$nmismatch += &testCompatibility($reverseprimer{$primer}[$i], $nucseq->[$i]);
		}
		if ((defined($reversemaxnmismatch) && $nmismatch > $reversemaxnmismatch) || $nmismatch / $reverseprimerlength > $reversemaxpmismatch) {
			exit;
		}
		splice(@{$nucseq}, 0, $reverseprimerlength);
		splice(@{$qualseq}, 0, $reverseprimerlength);
	}
	# check reverse primer position and eliminate
	if ($status == 3 && $reverseprimerrevcomp{$primer}) {
		my $nmismatch = 0;
		for (my $i = -1; $i >= (-1) * $reverseprimerlength; $i --) {
			$nmismatch += &testCompatibility($reverseprimerrevcomp{$primer}[$i], $nucseq->[$i]);
		}
		if ((defined($reversemaxnmismatch) && $nmismatch > $reversemaxnmismatch) || $nmismatch / $reverseprimerlength > $reversemaxpmismatch) {
			exit;
		}
		splice(@{$nucseq}, (-1) * $reverseprimerlength);
		splice(@{$qualseq}, (-1) * $reverseprimerlength);
	}
	# mask based on quality value
	if (($status == 0 || $status == 1 || $status == 2) && $minqual && $minquallen) {
		# mask end-side characters
		my $num = 0;
		for (my $i = -1; $i >= (-1) * $minquallen && $i >= (-1) * scalar(@{$qualseq}); $i --) {
			if ($qualseq->[$i] < $minqual) {
				$num = $i;
			}
		}
		while ($num != 0) {
			splice(@{$qualseq}, $num);
			splice(@{$nucseq}, $num);
			$num = 0;
			for (my $i = -1; $i >= (-1) * $minquallen && $i >= (-1) * scalar(@{$qualseq}); $i --) {
				if ($qualseq->[$i] < $minqual) {
					$num = $i;
				}
			}
		}
		# skip short sequence
		if ($minlen && scalar(@{$nucseq}) < $minlen) {
			exit;
		}
	}
	# skip low quality sequence
	if ($lowqual && $maxplowqual) {
		my $sum = 0;
		for (my $i = 0; $i < scalar(@{$qualseq}); $i ++) {
			if ($qualseq->[$i] < $lowqual) {
				$sum ++;
			}
		}
		if ($sum / scalar(@{$qualseq}) > $maxplowqual) {
			exit;
		}
	}
	# reverse-complement
	if ($status == 2) {
		@{$nucseq} = &reversecomplement(@{$nucseq});
		@{$qualseq} = reverse(@{$qualseq});
	}
	# output an entry
	my $temprunname;
	if ($runname) {
		$temprunname = $runname;
	}
	else {
		my @temp = split(':', $seqname);
		$temprunname = "$temp[0]_$temp[1]";
	}
	my $outputfile = "$temprunname\__$sample";
	my $tempsample = $sample;
	if ($status == 1) {
		$tempsample .= "_forward";
		$outputfile .= "_forward.fastq";
	}
	elsif ($status == 2) {
		$tempsample .= "_reverse";
		$outputfile .= "_reverse.fastq";
	}
	else {
		$outputfile .= ".fastq";
	}
	unless (open($filehandleoutput1, ">> $outputfolder/$outputfile")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfolder/$outputfile\".");
	}
	unless (flock($filehandleoutput1, LOCK_EX)) {
		&errorMessage(__LINE__, "Cannot lock \"$outputfolder/$outputfile\".");
	}
	unless (seek($filehandleoutput1, 0, 2)) {
		&errorMessage(__LINE__, "Cannot seek \"$outputfolder/$outputfile\".");
	}
	print($filehandleoutput1 "\@$seqname\__$temprunname\__$tempsample\n");
	print($filehandleoutput1 join('', @{$nucseq}) . "\n");
	print($filehandleoutput1 "+\n");
	print($filehandleoutput1 join('', pack('C*', @{$qualseq})) . "\n");
	close($filehandleoutput1);
	exit;
}

sub compressFASTQ {
	print(STDERR "Compressing FASTQ files...\n");
	&compressByGZIP(glob("$outputfolder/*.fastq"));
	print(STDERR "done.\n\n");
}

sub decompressByGZIP {
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $fastq (@_) {
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
				$fastq =~ s/\.gz$//;
				print(STDERR "Decompressing $fastq.gz...\n");
				if (system("gzip -dc $fastq.gz > $outputfolder/$fastq")) {
					&errorMessage(__LINE__, "Cannot run \"gzip -dc $fastq.gz > $outputfolder/$fastq\".");
				}
				exit;
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

sub compressByGZIP {
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $fastq (@_) {
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
				$fastq =~ s/\.gz$//;
				print(STDERR "Compressing $fastq...\n");
				if (system("gzip $fastq")) {
					&errorMessage(__LINE__, "Cannot run \"gzip $fastq\".");
				}
				exit;
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

sub testCompatibility {
	# 0: compatible
	# 1: incompatible
	my ($seq1, $seq2) = @_;
	my $compatibility = 0;
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
			$compatibility = 1;
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

sub reversecomplement {
	my @temp = @_;
	my @seq;
	foreach my $seq (reverse(@temp)) {
		$seq =~ tr/ACGTMRYKVHDBacgtmrykvhdb/TGCAKYRMBDHVtgcakyrmbdhv/;
		push(@seq, $seq);
	}
	return(@seq);
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
climportillumina options inputfile outputfolder

Command line options
====================
-p, --primerfile=FILENAME
-fp, --forwardprimerfile=FILENAME
  Specify forward primer list file name. (default: none)

--maxpmismatch=DECIMAL
  Specify maximum acceptable mismatch percentage for primers. (default: 0.15)

--maxnmismatch=INTEGER
  Specify maximum acceptable mismatch number for primers.
(default: Inf)

--reverseprimerfile=FILENAME
  Specify reverse primer list file name. (default: none)

--reversemaxpmismatch=DECIMAL
  Specify maximum acceptable mismatch percentage for reverse primers.
(default: 0.15)

--reversemaxnmismatch=INTEGER
  Specify maximum acceptable mismatch number for reverse primers.
(default: Inf)

-a, --append
  Specify outputfile append or not. (default: off)

--minlen=INTEGER
  Specify minimum length threshold. (default: 0)

--maxlen=INTEGER
  Specify maximum length threshold. (default: Inf)

--minqual=INTEGER
  Specify minimum quality threshold. (default: 30)

--minquallen=INTEGER
  Specify minimum quality length. (default: 5)

--minasmlen=INTEGER
  Specify minimum assembled length threshold. (default: 0)

--maxasmlen=INTEGER
  Specify maximum assembled length threshold. (default: Inf)

--lowqual=INTEGER
  Specify low quality threshold. (default: 20)

--maxplowqual=DECIMAL
  Specify maximum acceptable percentage of low quality base. (default: 0.05)

--runname=RUNNAME
  Specify run name for replacing run name.
(default: retrieved from sequence name)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
CASAVA Samplesheet CSV
(Sequence files in current folder will be read based on SampleID.)

Acceptable sequence file formats
================================
FASTQ (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
(Quality values must be encoded in Sanger format.)
_END
	exit;
}
