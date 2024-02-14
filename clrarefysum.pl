use strict;
use Cwd 'getcwd';
use File::Spec;
use File::Path 'rmtree';
use POSIX 'log10';

my $buildno = '0.9.x';

# options
my $tableformat;
my $runname;
my $numthreads = 1;
my $seed = time^$$;
my $nodel;
my $minpcov = 0.95;
my $pcov;
my $minntotalseqsample;
my $nreplicate = 10;

# input/output
my $inputfile;
my $output;

# other variables
my $devnull = File::Spec->devnull();
my $root = getcwd();
my %table;
my %nsamplelist;
my %inputpcov;
my %outputpcov;
my %outputnseq;
my @otunames;
my @samplenames;
my @fibnum;

# commands
my $Rscript;

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
	# read input file
	&readSummary();
	# get input coverage
	&calculateInputCoverage();
	# determine output number of sequences
	&determineOutputNumberOfSequences();
	# perform rarefaction
	&rarefySamples();
	# make output file
	&saveSummary();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clrarefysum $buildno
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
	$inputfile = $ARGV[-2];
	$output = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:o|output|tableformat)=(.+)$/i) {
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
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:r|rate|p|percentage)(?:cov|coverage)=(.+)$/i) {
			$minpcov = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:r|rate|p|percentage)(?:cov|coverage)=(.+)$/i) {
			$pcov = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?totalseq(?:uence)?s?sam(?:ple)?=(\d+)$/i) {
			$minntotalseqsample = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:um)?(?:replicate|repl?)=(\d+)$/i) {
			$nreplicate = $1;
		}
		elsif ($ARGV[$i] =~ /^-+seed=(\d+)$/i) {
			$seed = $1;
		}
		elsif ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$runname = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+nodel$/i) {
			$nodel = 1;
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
	while (glob("$output*")) {
		if (/^$output\_(?:inputpcov|outputpcov|outputnseq)\.tsv$/ || /^$output\-r\d+\.tsv$/) {
			&errorMessage(__LINE__, "Output file already exists.");
		}
		if (/^$output\.temp$/) {
			&errorMessage(__LINE__, "Temporary folder already exists.");
		}
	}
	# check
	if ($minpcov < 0 || $minpcov > 1) {
		&errorMessage(__LINE__, "The minimum coverage is invalid.");
	}
	if ($pcov < 0 || $pcov > 1) {
		&errorMessage(__LINE__, "The specified coverage is invalid.");
	}
	if ($nreplicate == 0) {
		&errorMessage(__LINE__, "The number of replicates is invalid.");
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
		}
		else {
			$Rscript = 'Rscript';
		}
	}
}

sub readSummary {
	my $ncol;
	my $format;
	my %ntotalseq;
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
				$ntotalseq{$row[0]} += $row[2];
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
					$ntotalseq{$samplename} += $row[$i];
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
	if ($minntotalseqsample) {
		foreach my $samplename (@samplenames) {
			if ($ntotalseq{$samplename} < $minntotalseqsample) {
				$nsamplelist{$samplename} = 1;
			}
		}
	}
}

sub calculateInputCoverage {
	print(STDERR "Calculating coverages of input samples...\n");
	# make temporary folder
	unless (mkdir("$output.temp")) {
		&errorMessage(__LINE__, "Cannot make working directory.");
	}
	# calculate in parallel
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $samplename (@samplenames) {
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
				print(STDERR "\"$samplename\"...\n");
				my $tempfolder = "$output.temp/$samplename";
				# make temporary folder
				unless (mkdir($tempfolder)) {
					&errorMessage(__LINE__, "Cannot make \"$tempfolder\".");
				}
				# change directory
				unless (chdir($tempfolder)) {
					&errorMessage(__LINE__, "Cannot change working directory.");
				}
				# make R script
				$filehandleoutput1 = &writeFile("calculatepcov.R");
				print($filehandleoutput1 "library(vegan)\n");
				print($filehandleoutput1 "community <- c(\n");
				if (@otunames && $table{$samplename}) {
					my $switch = 0;
					foreach my $otuname (@otunames) {
						if ($table{$samplename}{$otuname}) {
							if ($switch) {
								print($filehandleoutput1 ",\n");
							}
							print($filehandleoutput1 $table{$samplename}{$otuname});
							$switch = 1;
						}
					}
				}
				else {
					&errorMessage(__LINE__, "Unknown error.");
				}
				print($filehandleoutput1 "\n)\n");
				print($filehandleoutput1 "inputpcov <- 1 - rareslope(community, sum(community) - 1)\n");
				print($filehandleoutput1 "write.table(inputpcov, \"inputpcov.tsv\", sep=\"\\t\", append=F, quote=F, row.names=F, col.names=F, na=\"NA\")\n");
				close($filehandleoutput1);
				# run R
				if (system("$Rscript --vanilla calculatepcov.R 1> $devnull 2> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla calculatepcov.R 1> $devnull\".");
				}
				# change directory
				unless (chdir($root)) {
					&errorMessage(__LINE__, "Cannot change working directory.");
				}
				exit;
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot calculate input coverage correctly.');
		}
	}
	my $minpcovinput = 1;
	# glob output files
	foreach my $samplename (@samplenames) {
		# read output files
		my $tempfolder = "$output.temp/$samplename";
		if (-e "$output.temp/$samplename/inputpcov.tsv") {
			# check coverage and store
			$filehandleinput1 = &readFile("$output.temp/$samplename/inputpcov.tsv");
			while (<$filehandleinput1>) {
				if (/(\S+)/) {
					my $inputpcov = eval($1);
					if ($inputpcov >= 0 && $inputpcov <= 1) {
						if (($minpcov && $inputpcov < $minpcov) || ($pcov && $inputpcov < $pcov)) {
							$nsamplelist{$samplename} = 1;
						}
						if (!$nsamplelist{$samplename} && $inputpcov < $minpcovinput) {
							$minpcovinput = $inputpcov;
						}
						$inputpcov{$samplename} = $inputpcov;
					}
					else {
						&errorMessage(__LINE__, "Coverage of \"$samplename\" ($inputpcov) is invalid.");
					}
					last;
				}
				else {
					&errorMessage(__LINE__, "\"$output.temp/$samplename/inputpcov.tsv\" is invalid.");
				}
			}
			close($filehandleinput1);
		}
		else {
			&errorMessage(__LINE__, "Cannot find \"$output.temp/$samplename/inputpcov.tsv\".");
		}
		# delete temporary folder
		unless ($nodel) {
			rmtree($tempfolder);
		}
	}
	# delete temporary folder
	unless ($nodel) {
		rmtree("$output.temp");
	}
	# determine pcov
	if (!$pcov) {
		if ($minpcovinput > $minpcov) {
			$pcov = $minpcovinput;
		}
		else {
			$pcov = $minpcov;
		}
		print(STDERR "Coverage threshold for rarefaction is \"$pcov\".\n");
	}
	print(STDERR "done.\n\n");
}

sub determineOutputNumberOfSequences {
	print(STDERR "Determining output numbers of sequences of samples based on coverage threshold...\n");
	# make temporary folder
	if (!mkdir("$output.temp") && !$nodel) {
		&errorMessage(__LINE__, "Cannot make working directory.");
	}
	# calculate in parallel
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $samplename (@samplenames) {
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
				if ($nsamplelist{$samplename}) {
					exit;
				}
				print(STDERR "\"$samplename\"...\n");
				my $tempfolder = "$output.temp/$samplename";
				# make temporary folder
				if (!mkdir($tempfolder) && !$nodel) {
					&errorMessage(__LINE__, "Cannot make \"$tempfolder\".");
				}
				# change directory
				if (!chdir($tempfolder)) {
					&errorMessage(__LINE__, "Cannot change working directory.");
				}
				# make R script
				$filehandleoutput1 = &writeFile("calculatenseq.R");
				print($filehandleoutput1 "library(vegan)\n");
				print($filehandleoutput1 "community <- c(\n");
				my $ntotalseq = 0;
				if (@otunames && $table{$samplename}) {
					my $switch = 0;
					foreach my $otuname (@otunames) {
						if ($table{$samplename}{$otuname}) {
							if ($switch) {
								print($filehandleoutput1 ",\n");
							}
							$ntotalseq += $table{$samplename}{$otuname};
							print($filehandleoutput1 $table{$samplename}{$otuname});
							$switch = 1;
						}
					}
				}
				else {
					&errorMessage(__LINE__, "Unknown error.");
				}
				print($filehandleoutput1 "\n)\n");
				print($filehandleoutput1 "ntotalseq <- $ntotalseq\n");
				my $fibomax = &getLargerFibonacci($ntotalseq);
				print($filehandleoutput1 "fibomax <- $fibomax\n");
				my $targetslope = 1 - $pcov;
				print($filehandleoutput1 "targetslope <- ");
				printf($filehandleoutput1 "%.10f\n", $targetslope);
				print($filehandleoutput1 <<"_END");
calcResidual <- function (x) {
	if (x > ntotalseq - 1) {
		Inf
	}
	else {
		abs(rareslope(community, trunc(x + 0.5)) - targetslope)
	}
}
fit <- optimize(calcResidual, interval=c(0, fibomax), maximum=F, tol=1e-10)
_END
				print($filehandleoutput1 "outputnseq <- trunc(fit\$minimum + 0.5)\n");
				print($filehandleoutput1 "outputpcov <- 1 - rareslope(community, outputnseq)\n");
				print($filehandleoutput1 "write.table(cbind(outputnseq, outputpcov), \"outputnseq.tsv\", sep=\"\\t\", append=F, quote=F, row.names=F, col.names=F, na=\"NA\")\n");
				close($filehandleoutput1);
				# run R
				if (system("$Rscript --vanilla calculatenseq.R 1> $devnull 2> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla calculatenseq.R 1> $devnull\".");
				}
				# change directory
				if (!chdir($root)) {
					&errorMessage(__LINE__, "Cannot change working directory.");
				}
				exit;
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot calculate output number of sequences correctly.');
		}
	}
	# glob output files
	foreach my $samplename (@samplenames) {
		if ($nsamplelist{$samplename}) {
			next;
		}
		# read output files
		my $tempfolder = "$output.temp/$samplename";
		if (-e "$output.temp/$samplename/outputnseq.tsv") {
			# check number of sequences and store
			$filehandleinput1 = &readFile("$output.temp/$samplename/outputnseq.tsv");
			while (<$filehandleinput1>) {
				if (/(\d+)\t(\S+)/) {
					my $outputnseq = $1;
					my $outputpcov = eval($2);
					if ($outputnseq > 0) {
						$outputnseq{$samplename} = $outputnseq;
					}
					else {
						&errorMessage(__LINE__, "Output number of sequences of \"$samplename\" ($outputnseq) is invalid.");
					}
					if ($outputpcov - $pcov < 0.5) {
						$outputpcov{$samplename} = $outputpcov;
					}
					else {
						&errorMessage(__LINE__, "Output coverage of \"$samplename\" ($outputpcov) is invalid.");
					}
					last;
				}
				else {
					&errorMessage(__LINE__, "\"$output.temp/$samplename/outputnseq.tsv\" is invalid.");
				}
			}
			close($filehandleinput1);
		}
		else {
			&errorMessage(__LINE__, "Cannot find \"$output.temp/$samplename/outputnseq.tsv\".");
		}
		# delete temporary folder
		unless ($nodel) {
			rmtree($tempfolder);
		}
	}
	# delete temporary folder
	unless ($nodel) {
		rmtree("$output.temp");
	}
	print(STDERR "done.\n\n");
}

sub rarefySamples {
	print(STDERR "Performing rarefaction...\n");
	# make temporary folder
	if (!mkdir("$output.temp") && !$nodel) {
		&errorMessage(__LINE__, "Cannot make working directory.");
	}
	# change directory
	if (!chdir("$output.temp")) {
		&errorMessage(__LINE__, "Cannot change working directory.");
	}
	# make unrarefied summary table
	$filehandleoutput1 = &writeFile("unrarefied.tsv");
	print($filehandleoutput1 "samplename\t" . join("\t", @otunames) . "\n");
	foreach my $samplename (@samplenames) {
		if (!$nsamplelist{$samplename}) {
			print($filehandleoutput1 $samplename);
			foreach my $otuname (@otunames) {
				if ($table{$samplename}{$otuname}) {
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
	# make R script
	$filehandleoutput1 = &writeFile("rarefy.R");
	print($filehandleoutput1 <<"_END");
library(vegan)
unrarefied <- read.delim("unrarefied.tsv", header=T, row.names=1, check.names=F)
rownames <- as.data.frame(row.names(unrarefied), row.names=row.names(unrarefied))
colnames(rownames) <- "samplename"
ranseed <- $seed
set.seed(ranseed)
nreplicate <- $nreplicate
_END
	print($filehandleoutput1 "nseq <- c(\n");
	{
		my $switch = 0;
		foreach my $samplename (@samplenames) {
			if (!$nsamplelist{$samplename}) {
				if ($outputnseq{$samplename}) {
					if ($switch) {
						print($filehandleoutput1 ",\n");
					}
					print($filehandleoutput1 $outputnseq{$samplename});
					$switch = 1;
				}
				else {
					&errorMessage(__LINE__, "Output number of sequences does not exist for \"$samplename\".");
				}
			}
		}
	}
	print($filehandleoutput1 "\n)\n");
	print($filehandleoutput1 <<'_END');
options(warn = -1)
for(i in 1:nreplicate) {
	message(paste("Replicate", i, "..."))
	rarefied <- rrarefy(unrarefied, nseq)
	write.table(cbind(rownames, rarefied), paste0("rarefied", i, ".tsv"), sep="\t", append=F, quote=F, row.names=F, col.names=T, na="NA")
}
_END
	close($filehandleoutput1);
	# run R
	if (system("$Rscript --vanilla rarefy.R")) {
		&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla rarefy.R\".");
	}
	# change directory
	unless (chdir($root)) {
		&errorMessage(__LINE__, "Cannot change working directory.");
	}
	print(STDERR "done.\n\n");
}

sub saveSummary {
	print(STDERR "Saving results...\n");
	# save output files
	# inputpcov
	print(STDERR "Input coverages...\n");
	$filehandleoutput1 = &writeFile($output . "_inputpcov.tsv");
	print($filehandleoutput1 "samplename\tinputpcov\n");
	foreach my $samplename (@samplenames) {
		if ($inputpcov{$samplename}) {
			printf($filehandleoutput1 "$samplename\t%.10f\n", $inputpcov{$samplename});
		}
		else {
			print($filehandleoutput1 "$samplename\t0\n");
		}
	}
	close($filehandleoutput1);
	# outputpcov
	print(STDERR "Output coverages...\n");
	$filehandleoutput1 = &writeFile($output . "_outputpcov.tsv");
	print($filehandleoutput1 "samplename\toutputpcov\n");
	foreach my $samplename (@samplenames) {
		if ($outputpcov{$samplename}) {
			printf($filehandleoutput1 "$samplename\t%.10f\n", $outputpcov{$samplename});
		}
		else {
			print($filehandleoutput1 "$samplename\t0\n");
		}
	}
	close($filehandleoutput1);
	# outputnseq
	print(STDERR "Output numbers of sequences...\n");
	$filehandleoutput1 = &writeFile($output . "_outputnseq.tsv");
	print($filehandleoutput1 "samplename\toutputnseq\n");
	foreach my $samplename (@samplenames) {
		if ($outputnseq{$samplename}) {
			print($filehandleoutput1 "$samplename\t" . $outputnseq{$samplename} . "\n");
		}
		else {
			print($filehandleoutput1 "$samplename\t0\n");
		}
	}
	close($filehandleoutput1);
	# rarefied summary
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		for (my $i = 1; $i <= $nreplicate; $i ++) {
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
				my $length = length($nreplicate);
				my %temptable;
				my @tempotunames;
				my @tempsamplenames;
				my $ncol;
				# read input file
				print(STDERR "Replicate $i...\n");
				$filehandleinput1 = &readFile("$output.temp/rarefied$i.tsv");
				while (<$filehandleinput1>) {
					s/\r?\n?$//;
					if (/^samplename\t(.+)/i) {
						@tempotunames = split(/\t/, $1);
						$ncol = scalar(@tempotunames);
					}
					elsif ($ncol && @tempotunames) {
						my @row = split(/\t/);
						if (scalar(@row) == $ncol + 1) {
							my $samplename = shift(@row);
							push(@tempsamplenames, $samplename);
							for (my $i = 0; $i < scalar(@row); $i ++) {
								$temptable{$samplename}{$tempotunames[$i]} += $row[$i];
							}
						}
						else {
							&errorMessage(__LINE__, "\"$output.temp/rarefied$i.tsv\" is invalid.\nThe invalid line is \"$_\".");
						}
					}
					else {
						&errorMessage(__LINE__, "\"$output.temp/rarefied$i.tsv\" is invalid.");
					}
				}
				close($filehandleinput1);
				$filehandleoutput1 = &writeFile("$output-r" . sprintf("%0*d", $length, $i) . ".tsv");
				if ($tableformat eq 'matrix') {
					# output header
					print($filehandleoutput1 "samplename\t" . join("\t", @tempotunames) . "\n");
					# output data
					foreach my $samplename (@tempsamplenames) {
						print($filehandleoutput1 $samplename);
						foreach my $otuname (@tempotunames) {
							if ($temptable{$samplename}{$otuname}) {
								print($filehandleoutput1 "\t" . $temptable{$samplename}{$otuname});
							}
							else {
								print($filehandleoutput1 "\t0");
							}
						}
						print($filehandleoutput1 "\n");
					}
				}
				elsif ($tableformat eq 'column') {
					my $sequenceornot = 1;
					foreach my $otuname (@tempotunames) {
						if ($sequenceornot != 0 && $otuname =~ /^[A-Za-z0-9]{34,}$/) {
							$sequenceornot = -1;
						}
						elsif ($otuname =~ /[^ACGTacgt]/) {
							$sequenceornot = 0;
							last;
						}
					}
					# output header
					if ($sequenceornot == 1) {
						print($filehandleoutput1 "samplename\tsequence\tncopies\n");
					}
					elsif ($sequenceornot == -1) {
						print($filehandleoutput1 "samplename\tbase62sequence\tncopies\n");
					}
					else {
						print($filehandleoutput1 "samplename\totuname\tncopies\n");
					}
					# output data
					foreach my $samplename (@tempsamplenames) {
						my @tempotus = sort({$temptable{$samplename}{$b} <=> $temptable{$samplename}{$a}} @tempotunames);
						foreach my $otuname (@tempotus) {
							my $tempname = $otuname;
							if ($temptable{$samplename}{$otuname}) {
								print($filehandleoutput1 "$samplename\t$otuname\t" . $temptable{$samplename}{$otuname} . "\n");
							}
						}
					}
				}
				close($filehandleoutput1);
				exit;
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot calculate output number of sequences correctly.');
		}
	}
	print(STDERR "done.\n\n");
	# delete temporary folder
	unless ($nodel) {
		rmtree("$output.temp");
	}
}

sub getLargerFibonacci {
	my $nseq = shift(@_);
	my $nearestth = int((log10($nseq) + log10(sqrt(5))) / log10(1.61803398874989) + 0.5);
	my $fibn = &getFibonacci($nearestth);
	if ($fibn >= $nseq) {
		return($fibn);
	}
	else {
		return(&getFibonacci($nearestth + 1));
	}
}

sub getFibonacci {
	my $n = shift(@_);
	if (!$fibnum[$n]) {
		$fibnum[$n] = int(((1.61803398874989 ** $n) / sqrt(5)) + 0.5);
	}
	return($fibnum[$n]);
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
		unless (open($filehandle, "lbzip2 -n 8 -dc $filename 2> $devnull |")) {
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
		unless (open($filehandle, "| lbzip2 -n 8 -c >> $filename 2> $devnull")) {
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
clrarefysum options inputfile outputprefix

Command line options
====================
--minpcov=DECIMAL
  Specify required minimum percent coverage of output samples.
(default: 0.95)

--pcov=DECIMAL
  Specify required percent coverage of output samples. (default: none)

--minntotalseqsample=INTEGER
  Specify minimum total number of sequences of input samples. If the
total number of sequences of a sample is smaller than this value, the
sample will be omitted. (default: 0)

--nreplicate=INTEGER
  Specify number of replicates of rarefaction. (default: 10)

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: same as input)

--runname=RUNNAME
  Specify run name for replacing run name.
(default: given by sequence name)

--seed=INTEGER
  Specify the random number seed. (default: auto)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
Output of clsumclass
(Tab-delimited text)
_END
	exit;
}
