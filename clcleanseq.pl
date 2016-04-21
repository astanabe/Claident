use strict;
use File::Spec;
use File::Copy::Recursive ('fcopy', 'rcopy', 'dircopy');
use Cwd 'getcwd';

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
my $assams1option = ' --minident=1 --minovllen=0 --strand=plus --assemblemode=blatfast --mappingmode=nucmer --linkagemode=single --mergemode=normal';
my $assams2option = ' --minident=1 --minovllen=0 --strand=plus --assemblemode=blatfast --mappingmode=none --linkagemode=single --mergemode=normal';
my $assams3option = ' --minident=0 --minovllen=0 --strand=plus --assemblemode=blatfast --mappingmode=none --linkagemode=single --mergemode=normal';
my $vsearchoption;
my $borderchim = 1;
my $mincleanclustersize = 0;
my $denoise = 1;
my $uchime = 1;
my $pnoisycluster = 0.5;
my $minnpositive = 1;
my $minppositive = 0;
my $usesingleton;
my $runname;
my $minnreplicate = 2;
my $minpreplicate = 1;
my $trimlowcoverage = 1;
my $minncoverage = 2;
my $minpcoverage = 0.5;
my $numthreads = 1;

# input/output
my $outputfolder;
my @inputfiles;
my $replicatelist;

# commands
my $toAmos_new;
my $hashoverlap;
my $ungappedoverlap;
my $tigger;
my $makeconsensus;
my $recallConsensus;
my $bank2fasta;
my $bank2fastq;
my $listReadPlacedStatus;
my $dumpreads;
my $bankreport;
my $banktransact;
my $bankcombine;
my $pblat;
my $blat2nucmer;
my $nucmerAnnotate;
my $nucmer2ovl;
my $ovl2OVL;
my $cvgStat;
my $vsearch;

# global variables
my $root = getcwd();
my %firstinputfiles;
my %replicate;

# file handles
my $filehandleinput1;
my $filehandleinput2;
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
	# check running environment
	&checkEnvironment();
	# read replicate list file
	&readListFiles();
	# make output directory
	if (!-e $outputfolder && !mkdir($outputfolder)) {
		&errorMessage(__LINE__, 'Cannot make output folder.');
	}
	# change working directory
	unless (chdir($outputfolder)) {
		&errorMessage(__LINE__, 'Cannot change working directory.');
	}
	# run assembling for each sample
	&runAssamsExactEach();
	# prepare chimera detection
	&prepareChimeraDetection();
	# run chimera detection
	&runChimeraDetection();
	# store chimeric sequences
	&storeChimericSequences();
	# run noise detection
	&runNoiseDetection();
	# delete noisy sequences
	&deleteNoisySequences();
	# clean temporary files
	&cleanTemporaryFiles();
	# delete zero-length files
	&deleteZeroLengthFiles();
	# compress text files
	&compressTXTs();
	# change working directory
	unless (chdir($root)) {
		&errorMessage(__LINE__, 'Cannot change working directory.');
	}
	exit(0);
}

sub printStartupMessage {
	print(STDERR <<"_END");
clcleanseq $buildno
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
	# get arguments
	$outputfolder = $ARGV[-1];
	my $vsearchmode = 0;
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] eq 'end') {
			$vsearchmode = 0;
		}
		elsif ($vsearchmode) {
			$vsearchoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] eq 'vsearch' || $ARGV[$i] =~ 'uchime') {
			$vsearchmode = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:borderline|border)=(n|c|chimera|nonchimera)$/i) {
			if ($1 =~ /^(?:n|nonchimera)$/i) {
				$borderchim = 0;
			}
			elsif ($1 =~ /^(?:c|chimera)$/i) {
				$borderchim = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:detect|clean)(?:mode)?=(n|noise|c|chimera|n\+c|c\+n)$/i) {
			if ($1 =~ /^(?:n|noise)$/i) {
				$denoise = 1;
				$uchime = 0;
			}
			elsif ($1 =~ /^(?:c|chimera)$/i) {
				$denoise = 0;
				$uchime = 1;
			}
			elsif ($1 =~ /^(?:n\+c|c\+n)$/i) {
				$denoise = 1;
				$uchime = 1;
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:r|rate|p|percentage)noisycluster=(\d(?:\.\d+)?)/i) {
			$pnoisycluster = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?cleanclustersize=(\d+)$/i) {
			$mincleanclustersize = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?positive=(\d+)$/i) {
			$minnpositive = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:r|rate|p|percentage)positive=(\d(?:\.\d+)?)$/i) {
			$minppositive = $1;
		}
		elsif ($ARGV[$i] =~ /^-+usesingletons?$/i) {
			$usesingleton = 1;
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
		elsif ($ARGV[$i] =~ /^-+usesingletons?=(enable|disable|yes|no|true|false|E|D|Y|N|T|F)$/i) {
			if ($1 =~ /^(?:enable|yes|true|E|Y|T)$/i) {
				$usesingleton = 1;
			}
			elsif ($1 =~ /^(?:disable|no|false|D|N|F)$/i) {
				$usesingleton = 0;
			}
		}
		elsif ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$runname = $1;
		}
		elsif ($ARGV[$i] =~ /^-+trimlowcov(?:erage)?=(enable|disable|yes|no|true|false|E|D|Y|N|T|F)$/i) {
			if ($1 =~ /^(?:enable|yes|true|E|Y|T)$/i) {
				$trimlowcoverage = 1;
			}
			elsif ($1 =~ /^(?:disable|no|false|D|N|F)$/i) {
				$trimlowcoverage = 0;
			}
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?n(?:um)?cov(?:erage)?=(\d+)$/i) {
			$minncoverage = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?(?:r|rate|p|percentage)cov(?:erage)?=(\d(?:\.\d+)?)$/i) {
			$minpcoverage = $1;
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
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if ($vsearchoption =~ /-(?:chimeras|db|nonchimeras|uchime_denovo|uchime_ref|uchimealns|uchimeout|uchimeout5|centroids|cluster_fast|cluster_size|cluster_smallmem|clusters|consout|cons_truncate|derep_fulllength|sortbylength|sortbysize|output|allpairs_global|shuffle) /) {
		&errorMessage(__LINE__, "The option for vsearch is invalid.");
	}
	if ($vsearchoption =~ /\-+input/) {
		&errorMessage(__LINE__, "The option for vsearch is invalid.");
	}
	if ($vsearchoption !~ /-fasta_width /) {
		$vsearchoption .= " --fasta_width 999999";
	}
	if ($vsearchoption !~ /-maxseqlength /) {
		$vsearchoption .= " --maxseqlength 50000";
	}
	if ($vsearchoption !~ /-minseqlength /) {
		$vsearchoption .= " --minseqlength 32";
	}
	if ($vsearchoption !~ /-notrunclabels/) {
		$vsearchoption .= " --notrunclabels";
	}
	if ($vsearchoption !~ /-abskew /) {
		$vsearchoption .= " --abskew 2.0";
	}
	if ($vsearchoption !~ /-dn /) {
		$vsearchoption .= " --dn 1.4";
	}
	if ($vsearchoption !~ /-mindiffs /) {
		$vsearchoption .= " --mindiffs 3";
	}
	if ($vsearchoption !~ /-mindiv /) {
		$vsearchoption .= " --mindiv 0.1";
	}
	if ($vsearchoption !~ /-minh /) {
		$vsearchoption .= " --minh 0.1";
	}
	if ($vsearchoption !~ /-xn /) {
		$vsearchoption .= " --xn 8.0";
	}
	if ($vsearchoption !~ /-strand /) {
		$vsearchoption .= " --strand plus";
	}
	if (!@inputfiles) {
		&errorMessage(__LINE__, "No input file was specified.");
	}
	if ($replicatelist && !-e $replicatelist) {
		&errorMessage(__LINE__, "\"$replicatelist\" does not exist.");
	}
	if ($minnreplicate < 2) {
		&errorMessage(__LINE__, "The minimum number of replicate is invalid.");
	}
	if ($minpreplicate > 1) {
		&errorMessage(__LINE__, "The minimum percentage of replicate is invalid.");
	}
	print(STDERR "Command line options for vsearch for chimera detection :$vsearchoption\n\n");
	# search vsearch
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
			$vsearch = "\"$pathto/vsearch\"";
		}
		else {
			$vsearch = 'vsearch';
		}
	}
}

sub checkEnvironment {
	my $pathto;
	if ($ENV{'ASSAMSHOME'}) {
		$pathto = $ENV{'ASSAMSHOME'};
	}
	else {
		my $temp;
		if (-e '.assams') {
			$temp = '.assams';
		}
		elsif (-e $ENV{'HOME'} . '/.assams') {
			$temp = $ENV{'HOME'} . '/.assams';
		}
		elsif (-e '/etc/assams/.assams') {
			$temp = '/etc/assams/.assams';
		}
		if ($temp) {
			unless (open($filehandleinput1, "< $temp")) {
				&errorMessage(__LINE__, "Cannot read \"$temp\".");
			}
			while (<$filehandleinput1>) {
				if (/^\s*ASSAMSHOME\s*=\s*(\S[^\r\n]*)/) {
					$pathto = $1;
					$pathto =~ s/\s+$//;
					last;
				}
			}
			close($filehandleinput1);
		}
	}
	if ($pathto) {
		$pathto =~ s/^"(.+)"$/$1/;
		$pathto =~ s/\/$//;
		$pathto .= '/bin';
		if (!-e $pathto) {
			&errorMessage(__LINE__, "Cannot find \"$pathto\".");
		}
		$toAmos_new = "\"$pathto/toAmos_new\"";
		$hashoverlap = "\"$pathto/hash-overlap\"";
		$ungappedoverlap = "\"$pathto/ungapped-overlap\"";
		$tigger = "\"$pathto/tigger\"";
		$makeconsensus = "\"$pathto/make-consensus\"";
		$recallConsensus = "\"$pathto/recallConsensus\"";
		$bank2fasta = "\"$pathto/bank2fasta\"";
		$bank2fastq = "\"$pathto/bank2fastq\"";
		$listReadPlacedStatus = "\"$pathto/listReadPlacedStatus\"";
		$dumpreads = "\"$pathto/dumpreads\"";
		$bankreport = "\"$pathto/bank-report\"";
		$banktransact = "\"$pathto/bank-transact\"";
		$bankcombine = "\"$pathto/bank-combine\"";
		$pblat = "\"$pathto/pblat\"";
		$blat2nucmer = "\"$pathto/blat2nucmer\"";
		$nucmerAnnotate = "\"$pathto/nucmerAnnotate\"";
		$nucmer2ovl = "\"$pathto/nucmer2ovl\"";
		$ovl2OVL = "\"$pathto/ovl2OVL\"";
		$cvgStat = "\"$pathto/cvgStat\"";
	}
	else {
		$toAmos_new = 'toAmos_new';
		$hashoverlap = 'hash-overlap';
		$ungappedoverlap = 'ungapped-overlap';
		$tigger = 'tigger';
		$makeconsensus = 'make-consensus';
		$recallConsensus = 'recallConsensus';
		$bank2fasta = 'bank2fasta';
		$bank2fastq = 'bank2fastq';
		$listReadPlacedStatus = 'listReadPlacedStatus';
		$dumpreads = 'dumpreads';
		$bankreport = 'bank-report';
		$banktransact = 'bank-transact';
		$bankcombine = 'bank-combine';
		$pblat = 'pblat';
		$blat2nucmer = 'blat2nucmer';
		$nucmerAnnotate = 'nucmerAnnotate';
		$nucmer2ovl = 'nucmer2ovl';
		$ovl2OVL = 'ovl2OVL';
		$cvgStat = 'cvgStat';
	}
}

sub readListFiles {
	if ($replicatelist) {
		$filehandleinput1 = &readFile($replicatelist);
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			my @temp = split(/\t/, $_);
			for (my $i = 1; $i < scalar(@temp); $i ++) {
				push(@{$replicate{$temp[0]}}, $temp[$i]);
			}
		}
		close($filehandleinput1);
	}
}

sub runAssamsExactEach {
	# run first assams in parallel
	print(STDERR "Running assembly based on exact overlap by assams at each file...\n");
	my @newinput;
	foreach my $inputfile (@inputfiles) {
		print(STDERR "Processing $inputfile...\n");
		my $filename = $inputfile;
		$filename =~ s/^.+(?:\/|\\)//;
		$filename =~ s/\.(?:gz|bz2|xz)$//;
		$filename =~ s/\.[^\.]+$//;
		push(@newinput, $filename);
		if ($runname) {
			my $tempinputfile;
			if ($inputfile =~ /^\//) {
				$tempinputfile = $inputfile;
			}
			else {
				$tempinputfile = "$root/$inputfile";
			}
			&renameRunName($tempinputfile, "$filename.renamed.fastq.gz");
			$firstinputfiles{$filename} = "$filename.renamed.fastq.gz";
		}
		else {
			if ($inputfile =~ /^\//) {
				$firstinputfiles{$filename} = $inputfile;
			}
			else {
				$firstinputfiles{$filename} = "$root/$inputfile";
			}
		}
		if (system("assams$assams1option --numthreads=$numthreads $firstinputfiles{$filename} $filename.dereplicated.bnk 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"assams$assams1option --numthreads=$numthreads $firstinputfiles{$filename} $filename.dereplicated.bnk\".");
		}
	}
	@inputfiles = @newinput;
	print(STDERR "done.\n\n");
}

sub prepareChimeraDetection {
	if ($uchime) {
		# prepare for chimera detection
		print(STDERR "Preparing files for chimera detection...\n");
		{
			my $child = 0;
			$| = 1;
			$? = 0;
			foreach my $inputfile (@inputfiles) {
				if (my $pid = fork()) {
					$child ++;
					if ($child >= ($numthreads + 1)) {
						if (wait == -1) {
							$child = 0;
						} else {
							$child --;
						}
					}
					if ($?) {
						&errorMessage(__LINE__, "The processes did not finished correctly.");
					}
					next;
				}
				else {
					my ($exactcontigmembers, $exactsingletons) = &getContigMembersfromBank("$inputfile.dereplicated.bnk");
					unless (open($filehandleoutput1, "> $inputfile.preuchime.fasta")) {
						&errorMessage(__LINE__, "Cannot write \"$inputfile.preuchime.fasta\".");
					}
					if (-e "$inputfile.dereplicated.bnk/CTG.ifo") {
						# contigs to preuchime
						if ($exactcontigmembers->{"$inputfile.dereplicated.bnk"}) {
							unless (open($pipehandleinput1, "$bank2fasta -b $inputfile.dereplicated.bnk -iid 2> $devnull |")) {
								&errorMessage(__LINE__, "Cannot run \"$bank2fasta -b $inputfile.dereplicated.bnk -iid\".");
							}
							while (<$pipehandleinput1>) {
								if (/^>(\d+)/) {
									my $contigname = "contig_$1";
									if ($exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}) {
										my $size = scalar(@{$exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}});
										print($filehandleoutput1 ">$contigname;size=$size;\n");
									}
									else {
										&errorMessage(__LINE__, "Invalid assemble results.\nBank: $inputfile.dereplicated.bnk\nContig: $contigname\n");
									}
								}
								else {
									print($filehandleoutput1 $_);
								}
							}
							close($pipehandleinput1);
							if ($?) {
								&errorMessage(__LINE__, "Cannot run \"$bank2fasta -b $inputfile.dereplicated.bnk -iid\".");
							}
						}
						# singletons to preuchime
						if (system("$listReadPlacedStatus -S -I $inputfile.dereplicated.bnk > $inputfile.preuchime.singletons.iid 2> $devnull")) {
							&errorMessage(__LINE__, "Cannot run \"$listReadPlacedStatus -S -I $inputfile.dereplicated.bnk > $inputfile.preuchime.singletons.iid\".");
						}
						if (!-z "$inputfile.preuchime.singletons.iid") {
							unless (open($pipehandleinput1, "$dumpreads -r -e -I $inputfile.preuchime.singletons.iid $inputfile.dereplicated.bnk 2> $devnull |")) {
								&errorMessage(__LINE__, "Cannot run \"$dumpreads -r -e -I $inputfile.preuchime.singletons.iid $inputfile.dereplicated.bnk\".");
							}
						}
					}
					# contigs and/or singletons to preuchime
					elsif ($exactsingletons->{"$inputfile.dereplicated.bnk"} || $exactcontigmembers->{"$inputfile.dereplicated.bnk"}) {
						unless (open($pipehandleinput1, "$dumpreads -r -e $inputfile.dereplicated.bnk 2> $devnull |")) {
							&errorMessage(__LINE__, "Cannot run \"$dumpreads -r -e $inputfile.dereplicated.bnk\".");
						}
					}
					if ($pipehandleinput1) {
						my $contig = 0;
						while (<$pipehandleinput1>) {
							if (/^>(contig_\d+)/) {
								my $contigname = $1;
								if ($exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}) {
									my $size = scalar(@{$exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}});
									s/^>(contig_\d+)/>$1;size=$size;/;
								}
								else {
									&errorMessage(__LINE__, "Invalid assemble results.\nBank: $inputfile.dereplicated.bnk\nContig: $contigname\n");
								}
								$contig = 1;
							}
							elsif (/^>\S+/) {
								s/^>(\S+)/>$1;size=1;/;
								my $singleton = $1;
								unless (open($filehandleoutput2, ">> $inputfile.singletons.txt")) {
									&errorMessage(__LINE__, "Cannot write \"$inputfile.singletons.txt\".");
								}
								print($filehandleoutput2 $singleton . "\n");
								close($filehandleoutput2);
								$contig = 0;
							}
							if ($contig || $usesingleton) {
								print($filehandleoutput1 $_);
							}
						}
						close($pipehandleinput1);
					}
					if ($?) {
						&errorMessage(__LINE__, "Cannot run \"$dumpreads -r -e -I $inputfile.preuchime.singletons.iid $inputfile.dereplicated.bnk\".");
					}
					unlink("$inputfile.preuchime.singletons.iid");
					close($filehandleoutput1);
					exit;
				}
			}
			# join
			while (wait != -1) {
				if ($?) {
					&errorMessage(__LINE__, "The processes did not finished correctly.");
				}
			}
		}
		print(STDERR "done.\n\n");
	}
}

sub runChimeraDetection {
	if ($uchime) {
		# run chimera detection in parallel
		print(STDERR "Running chimera detection by uchime at each file...\n");
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $inputfile (@inputfiles) {
			if (my $pid = fork()) {
				$child ++;
				if ($child >= $numthreads) {
					if (wait == -1) {
						$child = 0;
					} else {
						$child --;
					}
				}
				if ($?) {
					&errorMessage(__LINE__, "The processes did not finished correctly.");
				}
				next;
			}
			else {
				print(STDERR "Processing $inputfile...\n");
				if (-e "$inputfile.preuchime.fasta" && !-z "$inputfile.preuchime.fasta") {
					if (system("$vsearch$vsearchoption --uchime_denovo $inputfile.preuchime.fasta --uchimeout $inputfile.uchime.txt 1> $devnull 2> $devnull")) {
						&errorMessage(__LINE__, "Chimera detection by uchime was failed at \"$inputfile.preuchime.fasta\".");
					}
					if (!-e "$inputfile.uchime.txt") {
						unless (open($filehandleoutput1, "> $inputfile.uchime.txt")) {
							&errorMessage(__LINE__, "Cannot write \"$inputfile.uchime.txt\".");
						}
						close($filehandleoutput1);
					}
				}
				else {
					unless (open($filehandleoutput1, "> $inputfile.uchime.txt")) {
						&errorMessage(__LINE__, "Cannot write \"$inputfile.uchime.txt\".");
					}
					close($filehandleoutput1);
				}
				unlink("$inputfile.preuchime.fasta");
				exit;
			}
		}
		# join
		while (wait != -1) {
			if ($?) {
				&errorMessage(__LINE__, "The processes did not finished correctly.");
			}
		}
		print(STDERR "done.\n\n");
	}
}

sub storeChimericSequences {
	if ($uchime) {
		# delete chimeras
		print(STDERR "Storing chimeric sequences...\n");
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $inputfile (@inputfiles) {
			if (my $pid = fork()) {
				$child ++;
				if ($child >= ($numthreads + 1)) {
					if (wait == -1) {
						$child = 0;
					} else {
						$child --;
					}
				}
				if ($?) {
					&errorMessage(__LINE__, "The processes did not finished correctly.");
				}
				next;
			}
			else {
				if (-e "$inputfile.uchime.txt") {
					my ($exactcontigmembers, $exactsingletons) = &getContigMembersfromBank("$inputfile.dereplicated.bnk");
					# store chimera list
					my @chimericreads;
					unless (open($filehandleinput1, "< $inputfile.uchime.txt")) {
						&errorMessage(__LINE__, "Cannot open \"$inputfile.uchime.txt\".");
					}
					while (<$filehandleinput1>) {
						my @entry = split(/\t/, $_);
						if (($entry[-1] =~ /^Y/ || ($entry[-1] =~ /^\?/ && $borderchim)) && $entry[1] =~ /^(.+);size=\d+;/) {
							my $seqname = $1;
							if ($seqname =~ /^(contig_\d+)/) {
								if (@{$exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$1}}) {
									foreach my $member (@{$exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$1}}) {
										push(@chimericreads, $member);
									}
								}
								else {
									&errorMessage(__LINE__, "Assembly \"$inputfile.dereplicated.bnk\" is invalid.");
								}
							}
							else {
								push(@chimericreads, $seqname);
							}
						}
					}
					close($filehandleinput1);
					if (@chimericreads) {
						unless (open($filehandleoutput1, ">> $inputfile.chimericreads.txt")) {
							&errorMessage(__LINE__, "Cannot write \"$inputfile.chimericreads.txt\".");
						}
						foreach my $chimera (@chimericreads) {
							print($filehandleoutput1 $chimera . "\n");
						}
						close($filehandleoutput1);
					}
				}
				else {
					&errorMessage(__LINE__, "UCHIME result \"$inputfile.uchime.txt\" is invalid.");
				}
				exit;
			}
		}
		# join
		while (wait != -1) {
			if ($?) {
				&errorMessage(__LINE__, "The processes did not finished correctly.");
			}
		}
		print(STDERR "done.\n\n");
	}
}

sub runNoiseDetection {
	if ($denoise) {
		print(STDERR "Running noise detection...\n");
	}
	else {
		print(STDERR "Running additional computation...\n");
	}
	# merge assembly
	if (@inputfiles > 1) {
		if (system("assams$assams2option --numthreads=$numthreads " . join('.dereplicated.bnk ', @inputfiles) . ".dereplicated.bnk denoising1.bnk 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"assams$assams2option --numthreads=$numthreads " . join('.dereplicated.bnk ', @inputfiles) . ".dereplicated.bnk denoising1.bnk\".");
		}
	}
	else {
		unless (dircopy("$inputfiles[0].dereplicated.bnk", "denoising1.bnk")) {
			&errorMessage(__LINE__, "Cannot copy \"$inputfiles[0].dereplicated.bnk\" to \"denoising1.bnk\".");
		}
		unless (fcopy("$inputfiles[0].dereplicated.contigmembers.gz", "denoising1.contigmembers.gz")) {
			&errorMessage(__LINE__, "Cannot copy \"$inputfiles[0].dereplicated.contigmembers.gz\" to \"denoising1.contigmembers.gz\".");
		}
	}
	# contigs to denoising1
	my ($primarycontigmembers, $primarysingletons) = &getContigMembersfromBank("denoising1.bnk");
	my %primaryclustersize;
	if (-e "denoising1.bnk/CTG.ifo" && $primarycontigmembers->{"denoising1.bnk"}) {
		my @tempcontig = sort({$a cmp $b} keys(%{$primarycontigmembers->{"denoising1.bnk"}}));
		if (@tempcontig) {
			if ($uchime) {
				my %chimeric;
				foreach my $inputfile (@inputfiles) {
					if (-e "$inputfile.chimericreads.txt") {
						unless (open($filehandleinput1, "< $inputfile.chimericreads.txt")) {
							&errorMessage(__LINE__, "Cannot read \"$inputfile.chimericreads.txt\".");
						}
						while (<$filehandleinput1>) {
							if (/^(\S+)/) {
								$chimeric{$1} = 1;
							}
						}
						close($filehandleinput1);
					}
				}
				my %singleton;
				if (!$usesingleton) {
					foreach my $inputfile (@inputfiles) {
						if (-e "$inputfile.singletons.txt") {
							unless (open($filehandleinput1, "< $inputfile.singletons.txt")) {
								&errorMessage(__LINE__, "Cannot read \"$inputfile.singletons.txt\".");
							}
							while (<$filehandleinput1>) {
								if (/^(\S+)/) {
									$singleton{$1} = 1;
								}
							}
							close($filehandleinput1);
						}
					}
				}
				foreach my $primarycontig (@tempcontig) {
					my @tempchimeric;
					my $numchimeric = 0;
					my $numsingleton = 0;
					my $numall = 0;
					my @tempnonchimeric;
					foreach my $member (@{$primarycontigmembers->{"denoising1.bnk"}->{$primarycontig}}) {
						if ($chimeric{$member}) {
							push(@tempchimeric, $member);
							$numchimeric ++;
						}
						else {
							push(@tempnonchimeric, $member);
							if ($singleton{$member}) {
								$numsingleton ++;
							}
						}
						$numall ++;
					}
					if ($minnpositive > 0 && $numchimeric >= $minnpositive && ($numchimeric / $numall) >= $minppositive || $numsingleton == $numall) {
						foreach my $seqname (@tempnonchimeric) {
							$chimeric{$seqname} = 1;
						}
					}
					elsif ($numchimeric < $numall) {
						foreach my $member (@tempchimeric) {
							#my $prefix = $member;
							#$prefix =~ s/^.+?__//;
							#unless (open($filehandleoutput1, ">> $prefix.falsepositives.txt")) {
							#	&errorMessage(__LINE__, "Cannot write \"$prefix.falsepositives.txt\".");
							#}
							#print($filehandleoutput1 $member . "\n");
							#close($filehandleoutput1);
							delete($chimeric{$member});
						}
					}
				}
				foreach my $inputfile (@inputfiles) {
					unlink("$inputfile.chimericreads.txt");
					unlink("$inputfile.singletons.txt");
				}
				foreach my $member (sort({$a cmp $b} keys(%chimeric))) {
					my $prefix = $member;
					$prefix =~ s/^.+?__//;
					unless (open($filehandleoutput1, ">> $prefix.chimericreads.txt")) {
						&errorMessage(__LINE__, "Cannot write \"$prefix.chimericreads.txt\".");
					}
					print($filehandleoutput1 $member . "\n");
					close($filehandleoutput1);
				}
				if (!$usesingleton && $primarysingletons->{"denoising1.bnk"}) {
					foreach my $member (@{$primarysingletons->{"denoising1.bnk"}}) {
						my $prefix = $member;
						$prefix =~ s/^.+?__//;
						unless (open($filehandleoutput1, ">> $prefix.singletons.txt")) {
							&errorMessage(__LINE__, "Cannot write \"$prefix.singletons.txt\".");
						}
						print($filehandleoutput1 $member . "\n");
						close($filehandleoutput1);
					}
				}
			}
			if ($denoise) {
				foreach my $primarycontig (@tempcontig) {
					$primaryclustersize{$primarycontig} = scalar(@{$primarycontigmembers->{"denoising1.bnk"}->{$primarycontig}});
				}
			}
		}
	}
	else {
		&errorMessage(__LINE__, "Assembly \"denoising1.bnk\" is invalid.");
	}
	if ($denoise) {
		if ($mincleanclustersize == 0) {
			# assemble denoising1 to denoising2
			if (-e 'denoising1.bnk') {
				&dumpAllContigsSingletonsfromBank("denoising1.bnk", "denoising1.fastq", 'primarycontig', 0);
				if (system("assams$assams3option --numthreads=$numthreads denoising1.fastq denoising2.bnk 1> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"assams$assams3option --numthreads=$numthreads denoising1.fastq denoising2.bnk\".");
				}
			}
			# read assemble result
			my ($secondarycontigmembers, $secondarysingletons) = &getContigMembersfromBank("denoising2.bnk");
			# determine threshold
			if ($secondarycontigmembers->{"denoising2.bnk"}) {
				my @primaryclustersize;
				foreach my $secondarycontig (keys(%{$secondarycontigmembers->{"denoising2.bnk"}})) {
					my @tempclustersize;
					foreach my $primarycontig (@{$secondarycontigmembers->{"denoising2.bnk"}->{$secondarycontig}}) {
						$primarycontig =~ s/^primarycontig_/contig_/;
						if ($primaryclustersize{$primarycontig}) {
							push(@tempclustersize, $primaryclustersize{$primarycontig});
						}
					}
					@tempclustersize = sort({$b <=> $a} @tempclustersize);
					shift(@tempclustersize);
					if (@tempclustersize) {
						push(@primaryclustersize, @tempclustersize);
					}
				}
				@primaryclustersize = sort({$a <=> $b} @primaryclustersize);
				$mincleanclustersize = $primaryclustersize[int(scalar(@primaryclustersize) * $pnoisycluster)]; # + 1
			}
			if ($mincleanclustersize < 2) {
				&errorMessage(__LINE__, "Unknown error.");
			}
		}
		# save sequence names for elimination
		if ($mincleanclustersize > 2) {
			foreach my $primarycontig (sort({$a cmp $b} keys(%{$primarycontigmembers->{"denoising1.bnk"}}))) {
				if ($primaryclustersize{$primarycontig} < $mincleanclustersize) {
					foreach my $member (@{$primarycontigmembers->{"denoising1.bnk"}->{$primarycontig}}) {
						my $prefix = $member;
						$prefix =~ s/^.+?__//;
						unless (open($filehandleoutput1, ">> $prefix.noisyreads.txt")) {
							&errorMessage(__LINE__, "Cannot write \"$prefix.noisyreads.txt\".");
						}
						print($filehandleoutput1 $member . "\n");
						close($filehandleoutput1);
					}
				}
			}
		}
		if ($mincleanclustersize > 1) {
			foreach my $member (@{$primarysingletons->{"denoising1.bnk"}}) {
				my $prefix = $member;
				$prefix =~ s/^.+?__//;
				unless (open($filehandleoutput1, ">> $prefix.noisyreads.txt")) {
					&errorMessage(__LINE__, "Cannot write \"$prefix.noisyreads.txt\".");
				}
				print($filehandleoutput1 $member . "\n");
				close($filehandleoutput1);
			}
		}
	}
	# additional noise and/or chimera detection based on replicate list
	if ($replicatelist && %replicate) {
		print(STDERR "Running additional chimera detection using replicates...\n");
		my %table;
		my %otusum;
		my @otunames;
		foreach my $primarycontig (keys(%{$primarycontigmembers->{"denoising1.bnk"}})) {
			push(@otunames, $primarycontig);
			foreach my $member (@{$primarycontigmembers->{"denoising1.bnk"}->{$primarycontig}}) {
				my @temp = split(/__/, $member);
				if (scalar(@temp) == 3) {
					my ($temp, $temprunname, $primer) = @temp;
					$table{"$temprunname\__$primer"}{$primarycontig} ++;
					$otusum{$primarycontig} ++;
					
				}
				elsif (scalar(@temp) == 4) {
					my ($temp, $temprunname, $tag, $primer) = @temp;
					$table{"$temprunname\__$tag\__$primer"}{$primarycontig} ++;
					$otusum{$primarycontig} ++;
				}
				else {
					&errorMessage(__LINE__, "Unknown error.");
				}
			}
		}
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
				foreach my $member (@{$primarycontigmembers->{"denoising1.bnk"}->{$otuname}}) {
					my $prefix = $member;
					$prefix =~ s/^.+?__//;
					unless (open($filehandleoutput1, ">> $prefix.chimericreads.txt")) {
						&errorMessage(__LINE__, "Cannot write \"$prefix.chimericreads.txt\".");
					}
					print($filehandleoutput1 $member . "\n");
					close($filehandleoutput1);
				}
			}
		}
	}
	print(STDERR "done.\n\n");
}

sub deleteNoisySequences {
	# delete chimeric and/or noisy sequences
	print(STDERR "Deleting chimeric and/or noisy sequences...\n");
	if ($denoise) {
		# save parameter
		unless (open($filehandleoutput1, "> parameter.txt")) {
			&errorMessage(__LINE__, "Cannot write \"parameter.txt\".");
		}
		print($filehandleoutput1 "minimum clean cluster size: $mincleanclustersize\n");
		close($filehandleoutput1);
	}
	foreach my $inputfile (@inputfiles) {
		my %chimeric;
		my %noisy;
		my %notclean;
		# read the results of chimera detection
		if ($uchime) {
			if (-e "$inputfile.chimericreads.txt") {
				unless (open($filehandleinput1, "< $inputfile.chimericreads.txt")) {
					&errorMessage(__LINE__, "Cannot read \"$inputfile.chimericreads.txt\".");
				}
				while (<$filehandleinput1>) {
					if (/^(\S+)/) {
						$chimeric{$1} = 1;
						$notclean{$1} = 1;
					}
				}
				close($filehandleinput1);
			}
			if (!$usesingleton && -e "$inputfile.singletons.txt") {
				unless (open($filehandleinput1, "< $inputfile.singletons.txt")) {
					&errorMessage(__LINE__, "Cannot read \"$inputfile.singletons.txt\".");
				}
				while (<$filehandleinput1>) {
					if (/^(\S+)/) {
						$chimeric{$1} = 1;
						$notclean{$1} = 1;
					}
				}
				close($filehandleinput1);
			}
		}
		# read the results of noisy reads detection
		if ($denoise) {
			# read noisy read list
			if (-e "$inputfile.noisyreads.txt") {
				unless (open($filehandleinput1, "< $inputfile.noisyreads.txt")) {
					&errorMessage(__LINE__, "Cannot read \"$inputfile.noisyreads.txt\".");
				}
				while (<$filehandleinput1>) {
					if (/^(\S+)/) {
						$noisy{$1} = 1;
						$notclean{$1} = 1;
					}
				}
				close($filehandleinput1);
			}
		}
		# output dereplicated FASTQ
		{
			my ($exactcontigmembers, $exactsingletons) = &getContigMembersfromBank("$inputfile.dereplicated.bnk");
			if ($uchime) {
				$filehandleinput1 = &readFile("$inputfile.dereplicated.contigmembers.gz");
				$filehandleoutput1 = writeFile("$inputfile.chimeraremoved.dereplicated.contigmembers.gz");
				while (<$filehandleinput1>) {
					s/^contig_/dereplicated_/;
					print($filehandleoutput1 $_);
				}
				close($filehandleoutput1);
				close($filehandleinput1);
			}
			if ($denoise) {
				$filehandleinput1 = &readFile("$inputfile.dereplicated.contigmembers.gz");
				$filehandleoutput1 = writeFile("$inputfile.denoised.dereplicated.contigmembers.gz");
				while (<$filehandleinput1>) {
					s/^contig_/dereplicated_/;
					print($filehandleoutput1 $_);
				}
				close($filehandleoutput1);
				close($filehandleinput1);
			}
			if ($uchime && $denoise) {
				$filehandleinput1 = &readFile("$inputfile.dereplicated.contigmembers.gz");
				$filehandleoutput1 = writeFile("$inputfile.cleaned.dereplicated.contigmembers.gz");
				while (<$filehandleinput1>) {
					s/^contig_/dereplicated_/;
					print($filehandleoutput1 $_);
				}
				close($filehandleoutput1);
				close($filehandleinput1);
			}
			if ($uchime) {
				$filehandleoutput1 = &writeFile("$inputfile.chimeraremoved.dereplicated.fastq.gz");
			}
			if ($denoise) {
				$filehandleoutput2 = &writeFile("$inputfile.denoised.dereplicated.fastq.gz");
			}
			if ($uchime && $denoise) {
				$filehandleoutput3 = &writeFile("$inputfile.cleaned.dereplicated.fastq.gz");
			}
			my $chimeric = 0;
			my $noisy = 0;
			my $notclean = 0;
			my $tempnline = 1;
			if (-e "$inputfile.dereplicated.bnk/CTG.ifo") {
				# contigs
				if ($exactcontigmembers->{"$inputfile.dereplicated.bnk"}) {
					my $lowcov;
					if ($trimlowcoverage) {
						$lowcov = &getContigLowCoveragePositions("$inputfile.dereplicated.bnk");
						unless (open($pipehandleinput1, "$bank2fastq -Q 33 -b $inputfile.dereplicated.bnk -iid -g 2> $devnull |")) {
							&errorMessage(__LINE__, "Cannot run \"$bank2fasta -b $inputfile.dereplicated.bnk -iid -g\".");
						}
					}
					else {
						unless (open($pipehandleinput1, "$bank2fastq -Q 33 -b $inputfile.dereplicated.bnk -iid 2> $devnull |")) {
							&errorMessage(__LINE__, "Cannot run \"$bank2fasta -b $inputfile.dereplicated.bnk -iid\".");
						}
					}
					my $contigiid;
					my @deletepos;
					while (<$pipehandleinput1>) {
						if ($tempnline % 4 == 1 && /^\@(\d+)/) {
							$chimeric = 0;
							$noisy = 0;
							$notclean = 0;
							$contigiid = $1;
							my $contigname = "contig_$1";
							my $outputname = "dereplicated_$1";
							if ($exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}) {
								my $ab = scalar(@{$exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}});
								foreach my $member (@{$exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}}) {
									if ($chimeric{$member}) {
										$chimeric = 1;
									}
									if ($noisy{$member}) {
										$noisy = 1;
									}
									if ($notclean{$member}) {
										$notclean = 1;
									}
								}
								if (!$chimeric && $filehandleoutput1) {
									print($filehandleoutput1 "\@$outputname nreads=$ab\n");
								}
								if (!$noisy && $filehandleoutput2) {
									print($filehandleoutput2 "\@$outputname nreads=$ab\n");
								}
								if (!$notclean && $filehandleoutput3) {
									print($filehandleoutput3 "\@$outputname nreads=$ab\n");
								}
							}
							else {
								&errorMessage(__LINE__, "Invalid assemble results.\nBank: $inputfile.dereplicated.bnk\nContig: $contigname\n");
							}
						}
						else {
							if ($trimlowcoverage && $contigiid && $lowcov->{$contigiid} && ($tempnline % 4 == 2 || $tempnline % 4 == 0)) {
								s/\r?\n?$//;
								my @tempseq = split('', $_);
								foreach my $pos (@{$lowcov->{$contigiid}}) {
									splice(@tempseq, $pos, 1);
								}
								if ($tempnline % 4 == 2) {
									if (@deletepos) {
										&errorMessage(__LINE__, "Unknown error.");
									}
									for (my $i = scalar(@tempseq) - 1; $i >= 0; $i --) {
										if ($tempseq[$i] eq '-') {
											push(@deletepos, $i);
										}
									}
								}
								foreach my $pos (@deletepos) {
									splice(@tempseq, $pos, 1);
								}
								if ($tempnline % 4 == 0) {
									undef(@deletepos);
								}
								$_ = join('', @tempseq) . "\n";
							}
							if (!$chimeric && $filehandleoutput1) {
								print($filehandleoutput1 $_);
							}
							if (!$noisy && $filehandleoutput2) {
								print($filehandleoutput2 $_);
							}
							if (!$notclean && $filehandleoutput3) {
								print($filehandleoutput3 $_);
							}
						}
						$tempnline ++;
					}
					close($pipehandleinput1);
					if ($?) {
						&errorMessage(__LINE__, "Cannot run \"$bank2fastq -Q 33 -b $inputfile.dereplicated.bnk -iid\".");
					}
				}
				# singletons
				if (system("$listReadPlacedStatus -S -I $inputfile.dereplicated.bnk > $inputfile.dereplicated.singletons.iid 2> $devnull")) {
					&errorMessage(__LINE__, "Cannot run \"$listReadPlacedStatus -S -I $inputfile.dereplicated.bnk > $inputfile.dereplicated.singletons.iid\".");
				}
				if (!-z "$inputfile.dereplicated.singletons.iid") {
					unless (open($pipehandleinput1, "$dumpreads -f -Q 33 -r -e -I $inputfile.dereplicated.singletons.iid $inputfile.dereplicated.bnk 2> $devnull |")) {
						&errorMessage(__LINE__, "Cannot run \"$dumpreads -f -Q 33 -r -e -I $inputfile.dereplicated.singletons.iid $inputfile.dereplicated.bnk\".");
					}
				}
			}
			# contigs and/or singletons
			elsif ($exactsingletons->{"$inputfile.dereplicated.bnk"} || $exactcontigmembers->{"$inputfile.dereplicated.bnk"}) {
				unless (open($pipehandleinput1, "$dumpreads -f -Q 33 -r -e $inputfile.dereplicated.bnk 2> $devnull |")) {
					&errorMessage(__LINE__, "Cannot run \"$dumpreads -f -Q 33 -r -e $inputfile.dereplicated.bnk\".");
				}
			}
			if ($pipehandleinput1) {
				$tempnline = 1;
				while (<$pipehandleinput1>) {
					if ($tempnline % 4 == 1 && /^\@contig_(\d+)/) {
						$chimeric = 0;
						$noisy = 0;
						$notclean = 0;
						my $contigname = "contig_$1";
						my $outputname = "dereplicated_$1";
						if ($exactcontigmembers && $exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}) {
							my $ab = scalar(@{$exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}});
							foreach my $member (@{$exactcontigmembers->{"$inputfile.dereplicated.bnk"}->{$contigname}}) {
								if ($chimeric{$member}) {
									$chimeric = 1;
								}
								if ($noisy{$member}) {
									$noisy = 1;
								}
								if ($notclean{$member}) {
									$notclean = 1;
								}
							}
							if (!$chimeric && $filehandleoutput1) {
								print($filehandleoutput1 "\@$outputname nreads=$ab\n");
							}
							if (!$noisy && $filehandleoutput2) {
								print($filehandleoutput2 "\@$outputname nreads=$ab\n");
							}
							if (!$notclean && $filehandleoutput3) {
								print($filehandleoutput3 "\@$outputname nreads=$ab\n");
							}
						}
						else {
							&errorMessage(__LINE__, "Invalid assemble results.\nBank: $inputfile.dereplicated.bnk\nContig: $contigname\n");
						}
					}
					elsif ($tempnline % 4 == 1 && /^\@(\S+)/) {
						$chimeric = 0;
						$noisy = 0;
						$notclean = 0;
						my $member = $1;
						if ($chimeric{$member}) {
							$chimeric = 1;
						}
						if ($noisy{$member}) {
							$noisy = 1;
						}
						if ($notclean{$member}) {
							$notclean = 1;
						}
						if (!$chimeric && $filehandleoutput1) {
							print($filehandleoutput1 "\@$member nreads=1\n");
						}
						if (!$noisy && $filehandleoutput2) {
							print($filehandleoutput2 "\@$member nreads=1\n");
						}
						if (!$notclean && $filehandleoutput3) {
							print($filehandleoutput3 "\@$member nreads=1\n");
						}
					}
					else {
						if (!$chimeric && $filehandleoutput1) {
							print($filehandleoutput1 $_);
						}
						if (!$noisy && $filehandleoutput2) {
							print($filehandleoutput2 $_);
						}
						if (!$notclean && $filehandleoutput3) {
							print($filehandleoutput3 $_);
						}
					}
					$tempnline ++;
				}
				close($pipehandleinput1);
				if ($?) {
					&errorMessage(__LINE__, "Cannot run \"$dumpreads -f -Q 33 -r -e -I $inputfile.dereplicated.singletons.iid $inputfile.dereplicated.bnk\".");
				}
			}
			unlink("$inputfile.dereplicated.singletons.iid");
			if ($filehandleoutput1) {
				close($filehandleoutput1);
			}
			if ($filehandleoutput2) {
				close($filehandleoutput2);
			}
			if ($filehandleoutput3) {
				close($filehandleoutput3);
			}
		}
		# output FASTQ
		if (-e $firstinputfiles{$inputfile}) {
			if ($uchime) {
				$filehandleoutput1 = &writeFile("$inputfile.chimeraremoved.fastq.gz");
			}
			if ($denoise) {
				$filehandleoutput2 = &writeFile("$inputfile.denoised.fastq.gz");
			}
			if ($uchime && $denoise) {
				$filehandleoutput3 = &writeFile("$inputfile.cleaned.fastq.gz");
			}
			$filehandleinput1 = &readFile($firstinputfiles{$inputfile});
			my $chimeric = 1;
			my $noisy = 1;
			my $notclean = 1;
			my $tempnline = 1;
			while (<$filehandleinput1>) {
				if ($tempnline % 4 == 1 && /^\@(\S+)/) {
					if ($chimeric{$1}) {
						$chimeric = 1;
					}
					else {
						$chimeric = 0;
					}
					if ($noisy{$1}) {
						$noisy = 1;
					}
					else {
						$noisy = 0;
					}
					if ($notclean{$1}) {
						$notclean = 1;
					}
					else {
						$notclean = 0;
					}
				}
				if (!$chimeric && $filehandleoutput1) {
					print($filehandleoutput1 $_);
				}
				if (!$noisy && $filehandleoutput2) {
					print($filehandleoutput2 $_);
				}
				if (!$notclean && $filehandleoutput3) {
					print($filehandleoutput3 $_);
				}
				$tempnline ++;
			}
			close($filehandleinput1);
			if ($filehandleoutput1) {
				close($filehandleoutput1);
			}
			if ($filehandleoutput2) {
				close($filehandleoutput2);
			}
			if ($filehandleoutput3) {
				close($filehandleoutput3);
			}
		}
		else {
			&errorMessage(__LINE__, "Cannot find \"$firstinputfiles{$inputfile}\".");
		}
	}
	print(STDERR "done.\n\n");
}

sub cleanTemporaryFiles {
	# delete temporary files
	print(STDERR "Deleting temporary files...\n");
	if ($uchime) {
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $inputfile (@inputfiles) {
			if (my $pid = fork()) {
				$child ++;
				if ($child >= ($numthreads + 1)) {
					if (wait == -1) {
						$child = 0;
					} else {
						$child --;
					}
				}
				if ($?) {
					&errorMessage(__LINE__, "The processes did not finished correctly.");
				}
				next;
			}
			else {
				# delete bank
				if (system("$bankreport -p -b $inputfile.dereplicated.bnk 2> $devnull | gzip -c > $inputfile.dereplicated.afg.gz")) {
					&errorMessage(__LINE__, "Cannot run \"$bankreport -p -b $inputfile.dereplicated.bnk | gzip -c > $inputfile.dereplicated.afg.gz\".");
				}
				&deleteBanks("$inputfile.dereplicated.bnk");
				exit;
			}
		}
		# join
		while (wait != -1) {
			if ($?) {
				&errorMessage(__LINE__, "The processes did not finished correctly.");
			}
		}
	}
	# delete bank
	if (system("$bankreport -p -b denoising1.bnk 2> $devnull | gzip -c > denoising1.afg.gz")) {
		&errorMessage(__LINE__, "Cannot run \"$bankreport -p -b denoising1.bnk | gzip -c > denoising1.afg.gz\".");
	}
	&deleteBanks("denoising1.bnk");
	if ($denoise) {
		unlink("denoising1.fastq");
		# delete bank
		if (system("$bankreport -p -b denoising2.bnk 2> $devnull | gzip -c > denoising2.afg.gz")) {
			&errorMessage(__LINE__, "Cannot run \"$bankreport -p -b denoising2.bnk | gzip -c > denoising2.afg.gz\".");
		}
		&deleteBanks("denoising2.bnk");
	}
	print(STDERR "done.\n\n");
}

sub deleteZeroLengthFiles {
	print(STDERR "Deleting zero-length files...\n");
	&uncompressByGZIP(glob("*.fastq.gz"));
	print(STDERR "done.\n\n");
}

sub compressTXTs {
	print(STDERR "Compressing TXT files...\n");
	&compressByGZIP(glob("*.txt"));
	print(STDERR "done.\n\n");
}

sub dumpAllContigsSingletonsfromBank {
	my $bankname = shift(@_);
	my $filename = shift(@_);
	my $prefix = shift(@_);
	my $trimlowcov = shift(@_);
	if (-e "$bankname/CTG.ifo") {
		my $lowcov;
		if ($trimlowcov) {
			$lowcov = &getContigLowCoveragePositions($bankname);
			unless (open($pipehandleinput1, "$bank2fastq -b $bankname -iid -Q 33 -g 2> $devnull |")) {
				&errorMessage(__LINE__, "Cannot run \"$bank2fastq -b $bankname -iid -Q 33 -g\".");
			}
		}
		else {
			unless (open($pipehandleinput1, "$bank2fastq -b $bankname -iid -Q 33 2> $devnull |")) {
				&errorMessage(__LINE__, "Cannot run \"$bank2fastq -b $bankname -iid -Q 33\".");
			}
		}
		unless (open($filehandleoutput1, ">> $filename")) {
			&errorMessage(__LINE__, "Cannot write \"$filename\".");
		}
		my $tempnline = 1;
		my $contigiid;
		my @deletepos;
		while (<$pipehandleinput1>) {
			if ($tempnline % 4 == 1 && /^\@/) {
				s/^\@(\d+)(\r?\n?)$/\@$prefix\_$1$2/;
				$contigiid = $1;
			}
			elsif ($trimlowcov && $contigiid && $lowcov->{$contigiid} && ($tempnline % 4 == 2 || $tempnline % 4 == 0)) {
				s/\r?\n?$//;
				my @tempseq = split('', $_);
				foreach my $pos (@{$lowcov->{$contigiid}}) {
					splice(@tempseq, $pos, 1);
				}
				if ($tempnline % 4 == 2) {
					if (@deletepos) {
						&errorMessage(__LINE__, "Unknown error.");
					}
					for (my $i = scalar(@tempseq) - 1; $i >= 0; $i --) {
						if ($tempseq[$i] eq '-') {
							push(@deletepos, $i);
						}
					}
				}
				foreach my $pos (@deletepos) {
					splice(@tempseq, $pos, 1);
				}
				if ($tempnline % 4 == 0) {
					undef(@deletepos);
				}
				$_ = join('', @tempseq) . "\n";
			}
			print($filehandleoutput1 $_);
			$tempnline ++;
		}
		close($filehandleoutput1);
		close($pipehandleinput1);
		if (system("$listReadPlacedStatus -S -I $bankname > $filename.singletons.iid 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$listReadPlacedStatus -S -I $bankname > $filename.singletons.iid\".");
		}
		unless (open($pipehandleinput1, "$dumpreads -f -Q 33 -r -e -I $filename.singletons.iid $bankname 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot run \"$dumpreads -f -Q 33 -r -e -I $filename.singletons.iid $bankname\".");
		}
		unless (open($filehandleoutput1, ">> $filename")) {
			&errorMessage(__LINE__, "Cannot write \"$filename\".");
		}
		$tempnline = 1;
		while (<$pipehandleinput1>) {
			if ($tempnline % 4 == 1 && /^\@/) {
				s/^\@contig_(\d+)(\r?\n?)$/\@$prefix\_$1$2/;
			}
			print($filehandleoutput1 $_);
			$tempnline ++;
		}
		close($filehandleoutput1);
		close($pipehandleinput1);
		unless (unlink("$filename.singletons.iid")) {
			&errorMessage(__LINE__, "Cannot delete \"$filename.singletons.iid\".");
		}
	}
	else {
		unless (open($pipehandleinput1, "$dumpreads -f -Q 33 -r -e $bankname 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot run \"$dumpreads -f -Q 33 -r -e $bankname\".");
		}
		unless (open($filehandleoutput1, ">> $filename")) {
			&errorMessage(__LINE__, "Cannot write \"$filename\".");
		}
		my $tempnline = 1;
		while (<$pipehandleinput1>) {
			if ($tempnline % 4 == 1 && /^\@/) {
				s/^\@contig_(\d+)(\r?\n?)$/\@$prefix\_$1$2/;
			}
			print($filehandleoutput1 $_);
			$tempnline ++;
		}
		close($filehandleoutput1);
		close($pipehandleinput1);
	}
}

sub getContigLowCoveragePositions {
	my $bankname = shift(@_);
	my %lowcov;
	unless (open($pipehandleinput1, "$cvgStat -ctg -red -iid -b $bankname 2> $devnull |")) {
		&errorMessage(__LINE__, "Cannot run \"$cvgStat -ctg -red -iid -b $bankname\".");
	}
	my $contigiid;
	my @coverage;
	my $maxcov = 1;
	while (<$pipehandleinput1>) {
		if (/^>(\d+)/) {
			if ($contigiid && @coverage && $maxcov > 1) {
				my @head;
				for (my $i = 0; $i < scalar(@coverage); $i ++) {
					if ($coverage[$i] < $minncoverage || $coverage[$i] / $maxcov < $minpcoverage) {
						push(@head, $i);
					}
					else {
						last;
					}
				}
				my @tail;
				for (my $i = scalar(@coverage) - 1; $i >= 0; $i --) {
					if ($coverage[$i] < $minncoverage || $coverage[$i] / $maxcov < $minpcoverage) {
						push(@tail, $i);
					}
					else {
						last;
					}
				}
				push(@{$lowcov{$contigiid}}, @tail, reverse(@head));
			}
			$contigiid = $1;
			undef(@coverage);
			$maxcov = 1;
		}
		elsif ($contigiid && /^(\d+)\t(\d+)\t(\d+)/) {
			my ($start, $end, $cov) = ($1, $2, $3);
			if ($cov > $maxcov) {
				$maxcov = $cov;
			}
			for (my $i = $start; $i < $end; $i ++) {
				$coverage[$i] = $cov;
			}
		}
	}
	close($pipehandleinput1);
	if ($contigiid && @coverage && $maxcov > 1) {
		my @head;
		for (my $i = 0; $i < scalar(@coverage); $i ++) {
			if ($coverage[$i] < $minncoverage || $coverage[$i] / $maxcov < $minpcoverage) {
				push(@head, $i);
			}
			else {
				last;
			}
		}
		my @tail;
		for (my $i = scalar(@coverage) - 1; $i >= 0; $i --) {
			if ($coverage[$i] < $minncoverage || $coverage[$i] / $maxcov < $minpcoverage) {
				push(@tail, $i);
			}
			else {
				last;
			}
		}
		push(@{$lowcov{$contigiid}}, @tail, reverse(@head));
	}
	return(\%lowcov);
}

sub getContigMembersfromBank {
	my %contigmembers;
	my %singletons;
	foreach my $bankname (@_) {
		my $prefix = $bankname;
		$prefix =~ s/\.bnk$//;
		if (-e "$prefix.contigmembers.gz") {
			$filehandleinput1 = &readFile("$prefix.contigmembers.gz");
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				if (my @row = split(/\t/)) {
					if (scalar(@row) > 2) {
						my $contigname = shift(@row);
						foreach my $member (@row) {
							push(@{$contigmembers{$bankname}{$contigname}}, $member);
						}
					}
					elsif (scalar(@row) == 2) {
						push(@{$singletons{$bankname}}, $row[1]);
					}
					else {
						&errorMessage(__LINE__, "Unknown error in processing a line\n$_\nof \"$prefix.contigmembers.gz\".");
					}
				}
			}
			close($filehandleinput1);
		}
		elsif (-e "$bankname/CTG.ifo") {
			# get the members
			unless (open($pipehandleinput1, "$listReadPlacedStatus $bankname 2> $devnull |")) {
				&errorMessage(__LINE__, "Cannot run \"$listReadPlacedStatus $bankname\".");
			}
			while (<$pipehandleinput1>) {
				s/\r?\n?$//;
				if (my @row = split(/\t/)) {
					if (scalar(@row) == 4 && $row[2] eq 'S') {
						push(@{$singletons{$bankname}}, $row[1]);
					}
					elsif (scalar(@row) == 5 && $row[2] eq 'P') {
						push(@{$contigmembers{$bankname}{"contig_$row[4]"}}, $row[1]);
					}
					else {
						&errorMessage(__LINE__, "Unknown error in processing a sequence \"$row[1]\" of \"contig_$row[4]\" in \"$bankname\".");
					}
				}
			}
			close($pipehandleinput1);
			if ($?) {
				&errorMessage(__LINE__, "Cannot run \"$listReadPlacedStatus $bankname\".");
			}
		}
		else {
			unless (open($pipehandleinput1, "$dumpreads -r -e $bankname 2> $devnull |")) {
				&errorMessage(__LINE__, "Cannot run \"$dumpreads -r -e $bankname\".");
			}
			while (<$pipehandleinput1>) {
				if (/^>(.+)(\r?\n?)$/) {
					push(@{$singletons{$bankname}}, $1);
				}
			}
			close($pipehandleinput1);
		}
	}
	return(\%contigmembers, \%singletons);
}

sub deleteBanks {
	foreach my $bankname (@_) {
		while (glob("$bankname/*")) {
			unless (unlink($_)) {
				&errorMessage(__LINE__, "Cannot delete \"$_\".");
			}
		}
		if (-e $bankname && -d $bankname) {
			unless (rmdir($bankname)) {
				&errorMessage(__LINE__, "Cannot delete \"$bankname\".");
			}
		}
	}
}

sub renameRunName {
	my $filenamein = shift(@_);
	my $filenameout = shift(@_);
	$filehandleinput1 = &readFile($filenamein);
	$filehandleoutput1 = &writeFile($filenameout);
	my $tempnline = 1;
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		if ($tempnline % 4 == 1 && /^\@(.+)/) {
			my $seqname = $1;
			my @temp = split(/__/, $seqname);
			if (scalar(@temp) == 3) {
				my ($temp, $temprunname, $primer) = @temp;
				$seqname = "$temp\__$runname\__$primer";
			}
			elsif (scalar(@temp) == 4) {
				my ($temp, $temprunname, $tag, $primer) = @temp;
				$seqname = "$temp\__$runname\__$tag\__$primer";
			}
			else {
				&errorMessage(__LINE__, "\"$seqname\" is invalid name.");
			}
			print($filehandleoutput1 "\@$seqname\n");
		}
		elsif ($tempnline % 4 == 1) {
			&errorMessage(__LINE__, "\"$filenamein\" is invalid.");
		}
		else {
			print($filehandleoutput1 "$_\n");
		}
		$tempnline ++;
	}
	close($filehandleoutput1);
	close($filehandleinput1);
}

sub writeFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "| gzip -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "| bzip2 -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.xz$/i) {
		unless (open($filehandle, "| xz -c > $filename 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	else {
		unless (open($filehandle, "> $filename")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	return($filehandle);
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

sub uncompressByGZIP {
	{
		my $child = 0;
		$| = 1;
		$? = 0;
		foreach my $compressed (@_) {
			if (-e $compressed && !-z $compressed) {
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
					my $nonzero = 0;
					$filehandleinput1 = &readFile($compressed);
					while (<$filehandleinput1>) {
						if (/./) {
							$nonzero ++;
						}
						last;
					}
					close($filehandleinput1);
					if ($nonzero == 0) {
						unlink($compressed);
						if ($compressed =~ s/\.dereplicated\.fastq\.gz$/.dereplicated.contigmembers.gz/) {
							unlink($compressed);
						}
					}
					exit;
				}
			}
			elsif (-e $compressed && -z $compressed) {
				unlink($compressed);
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
		foreach my $uncompressed (@_) {
			if ($uncompressed ne 'parameter.txt') {
				if (-e $uncompressed && !-z $uncompressed) {
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
						print(STDERR "Compressing $uncompressed...\n");
						if (system("gzip $uncompressed")) {
							&errorMessage(__LINE__, "Cannot run \"gzip $uncompressed\".");
						}
						exit;
					}
				}
				elsif (-e $uncompressed && -z $uncompressed) {
					unlink($uncompressed);
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
clcleanseq options inputfiles outputfolder

Command line options
====================
vsearch options end
  Specify commandline options for vsearch.
(default: --minh 0.1 --mindiv 0.1)

--borderline=CHIMERA|NONCHIMERA
  Specify borderline cases treat as chimera or nonchimera.
(default: CHIMERA)

--mincleanclustersize=INTEGER
  Specify minimum size of clean cluster. 0 means automatically
determined (but this will take a while). (default: 0)

--detectmode=NOISE|CHIMERA|N+C
  Specify detect mode. (default: N+C)

--pnoisycluster=DECIMAL
  Specify the percentage of noisy cluster. (default: 0.5)

--minnpositive=INTEGER
  The OTU that consists of this number of reads will be treated as true
positive in chimera detection. 0 means all reads. (default: 1)

--minppositive=DECIMAL
  The OTU that consists of this proportion of reads will be treated as true
positive in chimera detection. 1 means all reads. (default: 0)

--usesingleton=ENABLE|DISABLE
  Specify singletons should be used for chimera detection or not.
(default: DISABLE)

--trimlowcoverage=ENABLE|DISABLE
  Specify low coverage ends should be trimmed or not. (default: ENABLE)

--minncoverage=INTEGER
  Specify the minimum number of coverage. (default: 2)

--minpcoverage=DECIMAL
  Specify the minimum percentage of coverage (coverage / max coverage).
(default: 0.5)

--replicatelist=FILENAME
  Specify the list file of PCR replicates. (default: none)

--minnreplicate=INTEGER
  Specify the minimum number of \"presense\" replicates required for clean
and nonchimeric OTUs. (default: 2)

--minpreplicate=DECIMAL
  Specify the minimum percentage of \"presense\" replicates per sample
required for clean and nonchimeric OTUs. (default: 1)

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
