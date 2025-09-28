use strict;
use Cwd 'getcwd';
use File::Spec;
use File::Path 'rmtree';

my $buildno = '0.9.x';

# input/output
my $inputfile;
my $outputfolder;
my $taxfile;
my $replicatelist;

# options
my $chromeexec;
my $mogrifyexec;
my @targetrank;
my $logtransform = 1;
my $color = '"random-dark"';
my $bgcolor = '"white"';
my $size = '1600x900';
my $rotation = 'rotateRatio=0';
my $maxntry = 10;
my $runname;
my $numthreads = 1;
my $nodel;
my $append;

# commands
my $Rscript;

# global variables
my $devnull = File::Spec->devnull();
my $root = getcwd();
my %table;
my @otunames;
my @samplenames;
my @taxrank = ('no rank', 'superkingdom', 'kingdom', 'subkingdom', 'superphylum', 'phylum', 'subphylum', 'superclass', 'class', 'subclass', 'infraclass', 'cohort', 'subcohort', 'superorder', 'order', 'suborder', 'infraorder', 'parvorder', 'superfamily', 'family', 'subfamily', 'tribe', 'subtribe', 'genus', 'subgenus', 'section', 'subsection', 'series', 'species group', 'species subgroup', 'species', 'subspecies', 'varietas', 'forma', 'forma specialis', 'strain', 'isolate');
my %taxrank;
for (my $i = 0; $i < scalar(@taxrank); $i ++) {
	$taxrank{$taxrank[$i]} = $i;
}
$taxrank{'domain'} = 1;
$taxrank{'realm'} = 1;
my %taxonomy;
my @taxranknames;
my %parentsample;

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
	# read list files
	&readListFiles();
	# read taxonomy file
	&readTaxonomyFile();
	# read input file
	&readSummary();
	# plot word cloud
	&plotWordCloud();
}

sub printStartupMessage {
	print(STDERR <<"_END");
clplotwordcloud $buildno
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
	# get input file name
	$inputfile = $ARGV[-2];
	# get output folder name
	$outputfolder = $ARGV[-1];
	# read command line options
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+chrome(?:exec|executable)?=(.+)$/i) {
			$chromeexec = $1;
		}
		elsif ($ARGV[$i] =~ /^-+mogrify(?:exec|executable)?=(.+)$/i) {
			$mogrifyexec = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:target)?(?:tax|taxonomy)?(?:unit|rank|level)=(.+)$/i) {
			my @temp = split(',', $1);
			my %targetrank;
			foreach my $taxrank (@temp) {
				if ($taxrank{$taxrank}) {
					$targetrank{$taxrank{$taxrank}} = 1;
				}
				else {
					&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
				}
			}
			if (%targetrank) {
				@targetrank = keys(%targetrank);
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+logtrans(?:form)?=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t)$/i) {
				$logtransform = 1;
			}
			elsif ($value =~ /^(?:disable|d|no|n|false|f)$/i) {
				$logtransform = 0;
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+color=(.+)$/i) {
			if ($1 =~ /^dark$/i) {
				$color = '"random-dark"';
			}
			elsif ($1 =~ /^light$/i) {
				$color = '"random-light"';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:bgcolor|background|backgroundcolor)=(.+)$/i) {
			if ($1 =~ /^white$/i) {
				$bgcolor = '"white"';
			}
			elsif ($1 =~ /^black$/i) {
				$bgcolor = '"black"';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+size=(.+)$/i) {
			if ($1 =~ /^1600x900$/i) {
				$size = '1600x900';
			}
			elsif ($1 =~ /^1500x1000$/i) {
				$size = '1500x1000';
			}
			elsif ($1 =~ /^1280x960$/i) {
				$size = '1280x960';
			}
			elsif ($1 =~ /^1200x1200$/i) {
				$size = '1200x1200';
			}
			elsif ($1 =~ /^960x1280$/i) {
				$size = '960x1280';
			}
			elsif ($1 =~ /^1000x1500$/i) {
				$size = '1000x1500';
			}
			elsif ($1 =~ /^900x1600$/i) {
				$size = '900x1600';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is unknown option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?(?:try|trials?)=(.+)$/i) {
			$maxntry = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:replicate|repl?)list=(.+)$/i) {
			$replicatelist = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:tax|taxonomy)file=(.+)$/i) {
			$taxfile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$runname = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:a|append)$/i) {
			$append = 1;
		}
		elsif ($ARGV[$i] =~ /^-+nodel$/i) {
			$nodel = 1;
		}
		elsif ($ARGV[$i] =~ /^-+anemone$/i) {
			$logtransform = 1;
			$color = '"random-dark"';
			$bgcolor = '"whitesmoke"';
			$size = '1500x1000';
			$rotation = 'rotateRatio=0';
			foreach my $taxrank ('phylum', 'class', 'order', 'family', 'genus', 'species') {
				if ($taxrank{$taxrank}) {
					push(@targetrank, $taxrank{$taxrank});
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
	# check output folder
	if ($outputfolder =~ /^samplename$/i) {
		$append = 1;
	}
	else {
		if (-e $outputfolder && !$append) {
			&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
		}
		if (!mkdir($outputfolder) && !$append) {
			&errorMessage(__LINE__, "Cannot make output folder.");
		}
	}
	# sort targetrank
	@targetrank = sort({$taxrank{$b} <=> $taxrank{$a}} @targetrank);
	# search Chrome executable
	if ($chromeexec) {
		if (system("$chromeexec --version 2> " . $devnull . ' 1> ' . $devnull)) {
			&errorMessage(__LINE__, "\"$chromeexec\" is not valid.");
		}
	}
	else {
		if (system("google-chrome --version 2> " . $devnull . ' 1> ' . $devnull)) {
			if (system("chromium-browser --version 2> " . $devnull . ' 1> ' . $devnull)) {
				&errorMessage(__LINE__, "Cannot find Chrome executable.\nThis command require Google Chrome or Chromium.\nPlease install one of them.");
			}
			else {
				$chromeexec = 'chromium-browser';
			}
		}
		else {
			$chromeexec = 'google-chrome';
		}
	}
	# search mogrify executable
	if ($mogrifyexec) {
		if (system("$mogrifyexec -version 2> " . $devnull . ' 1> ' . $devnull)) {
			&errorMessage(__LINE__, "\"$mogrifyexec\" is not valid.");
		}
	}
	else {
		if (system("mogrify -version 2> " . $devnull . ' 1> ' . $devnull)) {
			&errorMessage(__LINE__, "Cannot find \"mogrify\" executable.\nThis command require \"mogrify\" command contained in ImageMagick.\nPlease install ImageMagick.");
		}
		else {
			$mogrifyexec = 'mogrify';
		}
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

sub readListFiles {
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

sub readTaxonomyFile {
	unless (open($filehandleinput1, "< $taxfile")) {
		&errorMessage(__LINE__, "Cannot read \"$taxfile\".");
	}
	{
		my $lineno = 1;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			if ($lineno == 1 && /\t/) {
				@taxranknames = split(/\t/, lc($_));
				shift(@taxranknames);
				foreach my $rank (@taxranknames) {
					if (!exists($taxrank{$rank})) {
						&errorMessage(__LINE__, "\"$rank\" is invalid taxonomic rank.");
					}
				}
			}
			elsif (/\t/) {
				my @entry = split(/\t/, $_, -1);
				my $otuname = shift(@entry);
				if (scalar(@entry) == scalar(@taxranknames)) {
					for (my $i = 0; $i < scalar(@entry); $i ++) {
						$taxonomy{$otuname}{$taxrank{$taxranknames[$i]}} = $entry[$i];
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
				if ($replicatelist) {
					if ($parentsample{$row[0]}) {
						$row[0] = $parentsample{$row[0]};
					}
					else {
						my $tagname;
						my @temp = split(/__/, $row[0]);
						if (scalar(@temp) == 3) {
							$tagname = $temp[1];
						}
						if ($parentsample{$tagname}) {
							$row[0] =~ s/__$tagname\__/__$parentsample{$tagname}\__/;
						}
					}
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
				if ($replicatelist) {
					if ($parentsample{$samplename}) {
						$samplename = $parentsample{$samplename};
					}
					else {
						my $tagname;
						my @temp = split(/__/, $samplename);
						if (scalar(@temp) == 3) {
							$tagname = $temp[1];
						}
						if ($parentsample{$tagname}) {
							$samplename =~ s/__$tagname\__/__$parentsample{$tagname}\__/;
						}
					}
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
}

sub plotWordCloud {
	print(STDERR "Preparing files for plotting...\n");
	# make required files, run plotting and delete temporary files
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $targetrank (@targetrank) {
			# make new table
			my %newtable;
			my @newotunames;
			{
				my %otu2newotu;
				my %newotu;
				foreach my $otuname (@otunames) {
					if ($taxonomy{$otuname}{$targetrank}) {
						my $taxon = $taxonomy{$otuname}{$targetrank};
						$otu2newotu{$otuname} = $taxon;
						$newotu{$taxon} = 0;
					}
				}
				if (%otu2newotu) {
					foreach my $samplename (@samplenames) {
						foreach my $otuname (@otunames) {
							if ($taxonomy{$otuname}{$targetrank}) {
								$newtable{$samplename}{$otu2newotu{$otuname}} += $table{$samplename}{$otuname};
								$newotu{$otu2newotu{$otuname}} += $table{$samplename}{$otuname};
							}
						}
					}
				}
				foreach my $otuname (keys(%newotu)) {
					if ($newotu{$otuname} > 0) {
						push(@newotunames, $otuname);
					}
				}
			}
			# plot wordcloud in parallel
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
					my $tempfolder;
					my $outfileprefix;
					# make output folder
					if ($outputfolder =~ /^samplename$/i) {
						$tempfolder = $samplename;
						$outfileprefix = $taxrank[$targetrank];
					}
					else {
						$tempfolder = $outputfolder;
						$outfileprefix = "$samplename.$taxrank[$targetrank]";
					}
					if ($append) {
						if (!-e $tempfolder && !mkdir($tempfolder)) {
							&errorMessage(__LINE__, "Cannot find \"$tempfolder\".");
						}
						if (!-d $tempfolder) {
							&errorMessage(__LINE__, "\"$tempfolder\" is not directory.");
						}
					}
					# change directory
					unless (chdir($tempfolder)) {
						&errorMessage(__LINE__, "Cannot change working directory.");
					}
					# get max
					my $max = 0;
					my @tempname;
					my @tempval;
					foreach my $otuname (@newotunames) {
						if ($newtable{$samplename}{$otuname} > $max) {
							$max = $newtable{$samplename}{$otuname};
						}
						if ($newtable{$samplename}{$otuname} > 0) {
							push(@tempname, $otuname);
							push(@tempval, $newtable{$samplename}{$otuname});
						}
					}
					if ($max) {
						# scale to 1-20
						if ($logtransform) {
							my $scale = exp(20) / $max;
							map({$_ = int(log($_ * $scale) + 0.5)} @tempval);
						}
						else {
							my $scale = 20 / $max;
							map({$_ = int($_ * $scale + 0.5)} @tempval);
						}
						# sort
						my %tempval;
						for (my $i = 0; $i < scalar(@tempval); $i ++) {
							$tempval{$tempname[$i]} = $tempval[$i];
						}
						@tempname = sort({$tempval{$b} <=> $tempval{$a} || $a cmp $b} @tempname);
						@tempval = sort({$b <=> $a} @tempval);
						# make tempfile
						unless (open($filehandleoutput1, "> $outfileprefix.tsv")) {
							&errorMessage(__LINE__, "Cannot make \"$outfileprefix.tsv\".");
						}
						print($filehandleoutput1 "name\tfreq\n");
						for (my $i = 0; $i < scalar(@tempval); $i ++) {
							if ($tempval[$i] > 0) {
								$tempname[$i] =~ s/^unidentified //;
								print($filehandleoutput1 $tempname[$i] . "\t" . $tempval[$i] . "\n");
							}
						}
						print($filehandleoutput1 "dummy\t0.00001\n");
						close($filehandleoutput1);
						unless (open($filehandleoutput1, "> $outfileprefix.R")) {
							&errorMessage(__LINE__, "Cannot make \"$outfileprefix.R\".");
						}
						my $ellipticity;
						if ($size eq '1600x900') {
							$ellipticity = 0.65;
						}
						elsif ($size eq '1500x1000') {
							$ellipticity = 0.8;
						}
						elsif ($size eq '1280x960') {
							$ellipticity = 0.9;
						}
						elsif ($size eq '1200x1200') {
							$ellipticity = 1.2;
						}
						elsif ($size eq '960x1280') {
							$ellipticity = 1.5;
						}
						elsif ($size eq '1000x1500') {
							$ellipticity = 1.67;
						}
						elsif ($size eq '900x1600') {
							$ellipticity = 1.8;
						}
						my $minSize;
						my $fontsize;
						if ($logtransform) {
							$minSize = 10;
							$fontsize = 1;
						}
						else {
							$minSize = 10;
							$fontsize = 2;
						}
						print($filehandleoutput1 "library(wordcloud2)\nlibrary(htmlwidgets)\n");
						print($filehandleoutput1 "saveWidget(wordcloud2(read.delim(\"$outfileprefix.tsv\", header=T, check.names=F), color=$color, backgroundColor=$bgcolor, ellipticity=$ellipticity, minSize=$minSize, size=$fontsize, $rotation, widgetsize=c(5000, 5000), fontFamily=\"Noto Sans\", fontWeight=\"bold\"), \"$outfileprefix.html\", selfcontained=F, background=$bgcolor)\n");
						close($filehandleoutput1);
						print(STDERR "Plotting word cloud of $taxrank[$targetrank] of \"$samplename\"...\n");
						if (-e "$outfileprefix.R" && -e "$outfileprefix.tsv") {
							if (system("$Rscript --vanilla $outfileprefix.R 2>> $outfileprefix.log" . ' 1> ' . $devnull)) {
								&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla $outfileprefix.R\" correctly.");
							}
						}
						else {
							&errorMessage(__LINE__, "Unknown error.");
						}
						if (-e "$outfileprefix.html" && -d "$outfileprefix\_files") {
							#if (system($^X . " -i -npe 's/(?:\\\\n)+ *//g' $outfileprefix.html 2>> $outfileprefix.log" . ' 1> ' . $devnull)) {
							#	&errorMessage(__LINE__, "Cannot run \"" . $^X . " -i -npe 's/(?:\\\\n)+ *//g' $outfileprefix.html\" correctly.");
							#}
							unlink("$outfileprefix.png");
							my $ntry = 0;
							while ((!-e "$outfileprefix.png" || (-s "$outfileprefix.png") < 10240) && $ntry < $maxntry) {
								my $chromeerror = 0;
								system("timeout 600 $chromeexec --headless --single-process --disable-dev-shm-usage --disable-gpu --no-proxy-server --lang=en-US --disk-cache-dir=$outfileprefix --user-data-dir=$outfileprefix --crash-dumps-dir=$outfileprefix --screenshot=$outfileprefix.png --window-size=6000,6000 --run-all-compositor-stages-before-draw --virtual-time-budget=100000000 $outfileprefix.html 2>> $outfileprefix.log" . ' 1> ' . $devnull);
								$filehandleinput1 = &readFile("$outfileprefix.log");
								while (<$filehandleinput1>) {
									if (/^Fontconfig error: /) {
										$chromeerror = 1;
										last;
									}
								}
								close($filehandleinput1);
								if ($chromeerror) {
									unlink("$outfileprefix.png");
									unlink("$outfileprefix.log");
								}
								elsif (-e "$outfileprefix.png" && !-z "$outfileprefix.png") {
									if (system("$mogrifyexec -fuzz 50% -trim -fuzz 50% -trim -background $bgcolor -resize $size -gravity center -extent $size $outfileprefix.png 2>> $outfileprefix.log" . ' 1> ' . $devnull)) {
										&errorMessage(__LINE__, "Cannot run \"$mogrifyexec -fuzz 50% -trim -fuzz 50% -trim -background $bgcolor -resize $size -gravity center -extent $size $outfileprefix.png\" correctly.");
									}
								}
								$ntry ++;
							}
							if ((-s "$outfileprefix.png") < 10240) {
								unlink("$outfileprefix.png");
							}
						}
						else {
							&errorMessage(__LINE__, "Cannot run \"$Rscript --vanilla $outfileprefix.R\" correctly.");
						}
						unless ($nodel) {
							unlink("$outfileprefix.tsv");
							unlink("$outfileprefix.R");
							unlink("$outfileprefix.html");
							unlink("$outfileprefix.log");
							rmtree("$outfileprefix\_files");
							rmtree("$outfileprefix");
						}
					}
					unless (chdir($root)) {
						&errorMessage(__LINE__, "Cannot change working directory.");
					}
					exit;
				}
			}
		}
	}
	# join
	while (wait != -1) {
		if ($?) {
			&errorMessage(__LINE__, 'Cannot plot word cloud correctly.');
		}
	}
	print(STDERR "done.\n\n");
}

sub readFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "pigz -p $numthreads -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "pbzip2 -p$numthreads -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "xz -T $numthreads -dc $filename 2> $devnull |")) {
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
clplotwordcloud options inputfile outputfolder

Command line options
====================
--chromeexec=CHROMEEXECUTABLE
  Specify Chrome or Chromium executable. (default: google-chrome or
chromium-browser)

--mogrifyexec=MOGRIFYEXECUTABLE
  Specify mogrify executable. (default: mogrify)

--taxfile=FILENAME
  Specify output of classigntax. (default: none)

--targetrank=RANK
  Specify target taxonomic rank. (default: species)

--logtransform=ENABLE|DISABLE
  Specify whether log-transformation will be applied or not. (default:
DISABLE)

--color=DARK|LIGHT
  Specify character color scheme. (default: DARK)

--bgcolor=WHITE|BLACK
  Specify backgroung color. (default: WHITE)

--size=1600x900|1500x1000|1280x960|1200x1200|960x1280|1000x1500|900x1600
  Specify output image size. (default: 1600x900)

--maxntry=INTEGER
  Specify maximum number of trials. (default: 10)

--replicatelist=FILENAME
  Specify the list file of PCR replicates. (default: none)

--runname=RUNNAME
  Specify run name for replacing run name.
(default: given by sequence name)

-a, --append
  Specify outputfile append or not. (default: off)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input file formats
=============================
Output of clsumclass
(Tab-delimited text)
_END
	exit;
}
