use strict;
use Cwd 'getcwd';
use File::Spec;
use File::Path 'rmtree';

my $buildno = '0.9.x';

# options
my $tableformat;
my $runname;
my $numthreads = 1;
my %stdconc;
my $solutionvol;
my $watervol;
my $nodel;

# input/output
my $inputfile;
my $outputfile;
my $stdtable;
my $stdconctable;
my $solutionvoltable;
my $watervoltable;

# other variables
my $devnull = File::Spec->devnull();
my $root = getcwd();
my %table;
my %solutionvol;
my %watervol;
my @otunames;
my @samplenames;

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
	# read table files
	&readTableFiles();
	# read input file
	&readSummary();
	# estimate concentration
	&estimateConcentration();
	# make output file
	&saveSummary();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clestimateconc $buildno
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
	$inputfile = $ARGV[-2];
	$outputfile = $ARGV[-1];
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:std|standard)conc=(.+)$/i) {
			my @temp = split(',', $1);
			if (scalar(@temp) % 2 == 0) {
				for (my $j = 0; $j < scalar(@temp); $j += 2) {
					if ($temp[($j + 1)] =~ /^(?:\d+|\d+\.\d+)$/) {
						$stdconc{$temp[$j]} = $temp[($j + 1)];
					}
					else {
						&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
					}
				}
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
			}
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
		elsif ($ARGV[$i] =~ /^-+(?:stdtable|standardtable)=(.+)$/i) {
			$stdtable = $1;
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
	if (-e $outputfile) {
		&errorMessage(__LINE__, "Output file already exists.");
	}
	# check files
	if ($stdtable && !-e $stdtable) {
		&errorMessage(__LINE__, "\"$stdtable\" does not exist.");
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

sub readTableFiles {
	if ($stdconctable) {
		my $lineno = 1;
		my @label;
		$filehandleinput1 = &readFile($stdconctable);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			my @row = split(/\t/, $_);
			if ($lineno ==1 && scalar(@row) > 2 && $_ !~ /\t(?:\d+|\d+\.\d+)\t/ && $_ !~ /\t(?:\d+|\d+\.\d+)$/) {
				@label = @row;
			}
			elsif ($lineno > 1 && @label && scalar(@row) == scalar(@label)) {
				for (my $i = 1; $i < scalar(@label); $i ++) {
					if ($row[$i] =~ /^(?:\d+|\d+\.\d+)$/) {
						$stdconc{$row[0]}{$label[$i]} = $row[$i];
					}
					else {
						&errorMessage(__LINE__, "\"$stdconctable\" is invalid.");
					}
				}
			}
			elsif (scalar(@row) == 2 && $row[1] =~ /^(?:\d+|\d+\.\d+)$/) {
				$stdconc{$row[0]} = $row[1];
			}
			elsif (scalar(@row) == 3 && $row[2] =~ /^(?:\d+|\d+\.\d+)$/) {
				$stdconc{$row[0]}{$row[1]} = $row[2];
			}
			elsif (@row) {
				&errorMessage(__LINE__, "\"$stdconctable\" is invalid.");
			}
			$lineno ++;
		}
		close($filehandleinput1);
	}
	if ($solutionvoltable) {
		$filehandleinput1 = &readFile($solutionvoltable);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			my @row = split(/\t/, $_);
			if (scalar(@row) == 2 && $row[1] =~ /^(?:\d+|\d+\.\d+)$/) {
				$solutionvol{$row[0]} = $row[1];
			}
		}
		close($filehandleinput1);
	}
	if ($watervoltable) {
		$filehandleinput1 = &readFile($watervoltable);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			my @row = split(/\t/, $_);
			if (scalar(@row) == 2 && $row[1] =~ /^(?:\d+|\d+\.\d+)$/) {
				$watervol{$row[0]} = $row[1];
			}
		}
		close($filehandleinput1);
	}
}

sub readSummary {
	&readTable($inputfile);
	if ($stdtable && -e $stdtable) {
		&readTable($stdtable);
	}
}

sub estimateConcentration {
	print(STDERR "Estimating concentration based on number of sequences of internal standard...\n");
	# make temporary folder
	unless (mkdir("$outputfile.temp")) {
		&errorMessage(__LINE__, "Cannot make working directory.");
	}
	# estimate in parallel
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
				my $tempfolder = "$outputfile.temp/$samplename";
				# make temporary folder
				unless (mkdir($tempfolder)) {
					&errorMessage(__LINE__, "Cannot make \"$tempfolder\".");
				}
				# change directory
				unless (chdir($tempfolder)) {
					&errorMessage(__LINE__, "Cannot change working directory.");
				}
				# check stdconc and store stdotu
				my @stdotu;
				if ($stdconc{$samplename}) {
					@stdotu = sort({$stdconc{$samplename}{$a} <=> $stdconc{$samplename}{$b}} keys(%{$stdconc{$samplename}}));
				}
				elsif (%stdconc) {
					@stdotu = keys(%stdconc);
					foreach my $stdotu (@stdotu) {
						if ($stdconc{$stdotu} !~ /^(?:\d+|\d+\.\d+)$/ || exists($table{$stdotu})) {
							exit;
						}
					}
					@stdotu = sort({$stdconc{$a} <=> $stdconc{$b}} @stdotu);
				}
				else {
					&errorMessage(__LINE__, "There is no stdconc.");
				}
				# check nreads of stdotus and those order
				if (@stdotu) {
					foreach my $stdotu (@stdotu) {
						if (!exists($table{$samplename}{$stdotu}) || $table{$samplename}{$stdotu} == 0) {
							print(STDERR "There is no reads of \"$stdotu\" in \"$samplename\".\nThis is weird.\nEstimated values will be replaced to 0.\n");
							exit;
						}
					}
				}
				# make R script
				$filehandleoutput1 = &writeFile("estimateconc.R");
				print($filehandleoutput1 "community <- c(\n");
				if (@otunames && $table{$samplename}) {
					for (my $i = 0; $i < scalar(@otunames); $i ++) {
						if ($i == scalar(@otunames) - 1) {
							if ($table{$samplename}{$otunames[$i]}) {
								print($filehandleoutput1 "$table{$samplename}{$otunames[$i]}\n");
							}
							else {
								print($filehandleoutput1 "0\n");
							}
						}
						else {
							if ($table{$samplename}{$otunames[$i]}) {
								print($filehandleoutput1 "$table{$samplename}{$otunames[$i]},\n");
							}
							else {
								print($filehandleoutput1 "0,\n");
							}
						}
					}
				}
				else {
					&errorMessage(__LINE__, "Unknown error.");
				}
				print($filehandleoutput1 ")\n");
				print($filehandleoutput1 "standard <- c(\n");
				if (@stdotu && $table{$samplename}) {
					for (my $i = 0; $i < scalar(@stdotu); $i ++) {
						if ($i == scalar(@stdotu) - 1) {
							if (exists($table{$samplename}{$stdotu[$i]}) && $table{$samplename}{$stdotu[$i]} > 0) {
								print($filehandleoutput1 "$table{$samplename}{$stdotu[$i]}\n");
							}
							else {
								print($filehandleoutput1 "0\n");
							}
						}
						else {
							if (exists($table{$samplename}{$stdotu[$i]}) && $table{$samplename}{$stdotu[$i]} > 0) {
								print($filehandleoutput1 "$table{$samplename}{$stdotu[$i]},\n");
							}
							else {
								print($filehandleoutput1 "0,\n");
							}
						}
					}
				}
				else {
					&errorMessage(__LINE__, "Unknown error.");
				}
				print($filehandleoutput1 ")\n");
				print($filehandleoutput1 "stdconc <- c(\n");
				if (@stdotu && $stdconc{$samplename}) {
					for (my $i = 0; $i < scalar(@stdotu); $i ++) {
						if ($i == scalar(@stdotu) - 1) {
							if (exists($stdconc{$samplename}{$stdotu[$i]}) && $stdconc{$samplename}{$stdotu[$i]} > 0) {
								print($filehandleoutput1 "$stdconc{$samplename}{$stdotu[$i]}\n");
							}
							else {
								print($filehandleoutput1 "0\n");
							}
						}
						else {
							if (exists($stdconc{$samplename}{$stdotu[$i]}) && $stdconc{$samplename}{$stdotu[$i]} > 0) {
								print($filehandleoutput1 "$stdconc{$samplename}{$stdotu[$i]},\n");
							}
							else {
								print($filehandleoutput1 "0,\n");
							}
						}
					}
				}
				elsif (@stdotu && %stdconc) {
					for (my $i = 0; $i < scalar(@stdotu); $i ++) {
						if ($i == scalar(@stdotu) - 1) {
							if (exists($stdconc{$stdotu[$i]}) && $stdconc{$stdotu[$i]} > 0) {
								print($filehandleoutput1 "$stdconc{$stdotu[$i]}\n");
							}
							else {
								print($filehandleoutput1 "0\n");
							}
						}
						else {
							if (exists($stdconc{$stdotu[$i]}) && $stdconc{$stdotu[$i]} > 0) {
								print($filehandleoutput1 "$stdconc{$stdotu[$i]},\n");
							}
							else {
								print($filehandleoutput1 "0,\n");
							}
						}
					}
				}
				else {
					&errorMessage(__LINE__, "Unknown error.");
				}
				print($filehandleoutput1 ")\n");
				if (exists($solutionvol{$samplename}) && $solutionvol{$samplename} > 0) {
					print($filehandleoutput1 "solutionvol <- $solutionvol{$samplename}\n");
				}
				elsif ($solutionvol > 0) {
					print($filehandleoutput1 "solutionvol <- $solutionvol\n");
				}
				else {
					print($filehandleoutput1 "solutionvol <- 1\n");
				}
				if (exists($watervol{$samplename}) && $watervol{$samplename} > 0) {
					print($filehandleoutput1 "watervol <- $watervol{$samplename}\n");
				}
				elsif ($watervol > 0) {
					print($filehandleoutput1 "watervol <- $watervol\n");
				}
				else {
					# change directory
					unless (chdir($root)) {
						&errorMessage(__LINE__, "Cannot change working directory.");
					}
					exit;
				}
				print($filehandleoutput1 "fitted <- lm(standard ~ stdconc + 0)\n");
				print($filehandleoutput1 "slope <- fitted\$coefficients\n");
				print($filehandleoutput1 "rsquared <- summary(fitted)\$r.squared\n");
				print($filehandleoutput1 "estimated <- (community / slope) * (solutionvol / watervol)\n");
				print($filehandleoutput1 "write.table(estimated, \"estimated.tsv\", sep=\"\t\", append=F, quote=F, row.names=F, col.names=F, na=\"NA\")\n");
				print($filehandleoutput1 "write.table(slope, \"slope.tsv\", sep=\"\t\", append=F, quote=F, row.names=F, col.names=F, na=\"NA\")\n");
				print($filehandleoutput1 "write.table(rsquared, \"rsquared.tsv\", sep=\"\t\", append=F, quote=F, row.names=F, col.names=F, na=\"NA\")\n");
				close($filehandleoutput1);
				# run R
				if (system("$Rscript --vanilla estimateconc.R 1> $devnull 2> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla estimateconc.R 1> $devnull\".");
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
			&errorMessage(__LINE__, 'Cannot calculate concentration correctly.');
		}
	}
	# glob output files and get results
	# slope <= 0 or rsquared < 0.49 samples are replaced to 0
	my %stdotu;
	foreach my $samplename (@samplenames) {
		my @stdotu;
		if ($stdconc{$samplename}) {
			@stdotu = keys(%{$stdconc{$samplename}});
		}
		elsif (%stdconc) {
			my $error;
			@stdotu = keys(%stdconc);
			foreach my $stdotu (@stdotu) {
				if ($stdconc{$stdotu} !~ /^(?:\d+|\d+\.\d+)$/ || exists($table{$stdotu})) {
					$error = 1;
					last;
				}
			}
			if ($error) {
				undef(@stdotu);
			}
		}
		foreach my $stdotu (@stdotu) {
			$stdotu{$stdotu} = 1;
		}
		# read output files
		my $tempfolder = "$outputfile.temp/$samplename";
		if (-e "$outputfile.temp/$samplename/estimated.tsv" && -e "$outputfile.temp/$samplename/slope.tsv" && -e "$outputfile.temp/$samplename/rsquared.tsv") {
			my $error;
			# check slope
			$filehandleinput1 = &readFile("$outputfile.temp/$samplename/slope.tsv");
			while (<$filehandleinput1>) {
				if (/(\S+)/ && eval($1) <= 0) {
					print(STDERR " Slope of \"$samplename\" is negative.\nThis is weird.\nEstimated values will be replaced to 0.\n");
					$error = 1;
					last;
				}
			}
			close($filehandleinput1);
			# check rsquared
			$filehandleinput1 = &readFile("$outputfile.temp/$samplename/rsquared.tsv");
			while (<$filehandleinput1>) {
				if (/(\S+)/ && eval($1) < 0.49) {
					print(STDERR " R-squared of \"$samplename\" is lower than 0.49.\nThis is weird.\nEstimated values will be replaced to 0.\n");
					$error = 1;
					last;
				}
			}
			close($filehandleinput1);
			# renew table data
			if ($error) {
				foreach my $otuname (@otunames) {
					if (exists($table{$samplename}{$otuname})) {
						if ($table{$samplename}{$otuname} > 0) {
							$table{$samplename}{$otuname} = 0;
						}
					}
				}
			}
			else {
				my @estimated;
				$filehandleinput1 = &readFile("$outputfile.temp/$samplename/estimated.tsv");
				while (<$filehandleinput1>) {
					if (/(\S+)/) {
						push(@estimated, eval($1));
					}
				}
				close($filehandleinput1);
				if (scalar(@otunames) == scalar(@estimated)) {
					for (my $i = 0; $i < scalar(@otunames); $i ++) {
						$table{$samplename}{$otunames[$i]} = $estimated[$i];
					}
				}
				else {
					&errorMessage(__LINE__, "Unknown error.");
				}
			}
		}
		else {
			foreach my $otuname (@otunames) {
				if (exists($table{$samplename}{$otuname})) {
					if ($table{$samplename}{$otuname} > 0) {
						$table{$samplename}{$otuname} = 0;
					}
				}
			}
		}
		# delete temporary folder
		unless ($nodel) {
			rmtree($tempfolder);
		}
	}
	# delete stdotu data from table
	foreach my $samplename (@samplenames) {
		foreach my $otuname (@otunames) {
			if (exists($stdotu{$otuname}) && $stdotu{$otuname} > 0) {
				delete($table{$samplename}{$otuname});
			}
		}
	}
	@otunames = sort({$a cmp $b} keys(%{$table{$samplenames[0]}}));
	# delete temporary folder
	unless ($nodel) {
		rmtree("$outputfile.temp");
	}
	print(STDERR "done.\n\n");
}

sub saveSummary {
	print(STDERR "Save results...\n");
	# save output file
	$filehandleoutput1 = &writeFile($outputfile);
	if ($tableformat eq 'matrix') {
		# output header
		print($filehandleoutput1 "samplename\t" . join("\t", @otunames) . "\n");
		# output data
		foreach my $samplename (@samplenames) {
			print($filehandleoutput1 $samplename);
			foreach my $otuname (@otunames) {
				if ($table{$samplename}{$otuname}) {
					printf($filehandleoutput1 "\t%.15f", $table{$samplename}{$otuname});
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
		foreach my $otuname (@otunames) {
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
		foreach my $samplename (@samplenames) {
			my @tempotus = sort({$table{$samplename}{$b} <=> $table{$samplename}{$a}} @otunames);
			foreach my $otuname (@tempotus) {
				my $tempname = $otuname;
				if ($table{$samplename}{$otuname}) {
					print($filehandleoutput1 "$samplename\t$otuname\t");
					printf($filehandleoutput1 "%.15f\n", $table{$samplename}{$otuname});
				}
			}
		}
	}
	close($filehandleoutput1);
	print(STDERR "done.\n\n");
}

sub readTable {
	my $tablefile = shift(@_);
	my $ncol;
	my $format;
	my @tempotunames;
	# read input file
	$filehandleinput1 = &readFile($tablefile);
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
				for (my $i = 0; $i < scalar(@row); $i ++) {
					$table{$samplename}{$tempotunames[$i]} += $row[$i];
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
			@tempotunames = split(/\t/, $1);
			$ncol = scalar(@tempotunames);
			$format = 'matrix';
		}
		else {
			&errorMessage(__LINE__, "The input file is invalid.");
		}
	}
	close($filehandleinput1);
	@samplenames = sort({$a cmp $b} keys(%table));
	@otunames = sort({$a cmp $b} keys(%{$table{$samplenames[0]}}));
	if (!$tableformat) {
		$tableformat = $format;
	}
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
clestimateconc options inputfile outputfile

Command line options
====================
--stdconc=DECIMAL,DECIMAL(,DECIMAL...)
  Specify DNA concentration of internal standard. (default: none)

--stdconctable=FILENAME
  Specify file name of DNA concentration table of internal standard.

--stdtable=FILENAME
  Specify separated internal standard nread table.

--solutionvol=DECIMAL
  Specify DNA solution volume.

--solutionvoltable=FILENAME
  Specify file name of DNA solution volume of samples.

--watervol=DECIMAL
  Specify filtered water volume.

--watervoltable=FILENAME
  Specify file name of filtered water volume of samples.

--tableformat=COLUMN|MATRIX
  Specify output table format. (default: same as input)

--runname=RUNNAME
  Specify run name for replacing run name.
(default: given by sequence name)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
Output of clsumclass
(Tab-delimited text)
_END
	exit;
}
