use strict;
use File::Spec;
use Cwd 'getcwd';
use File::Copy::Recursive ('fcopy', 'rcopy', 'dircopy');

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
my $numthreads = 1;
my $nsteps = 2;
my $assams1option = ' --minovllen=0 --assemblemode=blatfast --mappingmode=none --mergemode=normal --linkagemode=single --addniter=1';
my $assams2option = ' --minovllen=0 --assemblemode=minimus --mappingmode=nucmer --mergemode=accurate --addniter=10';
my $linkagemode = 'single';
my $trimlowcoverage = 1;
my $minncoverage = 2;
my $minpcoverage = 0.5;

# input/output
my $outputfolder;
my $inputfolder;

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

# global variables
my $root = getcwd;

# file handles
my $filehandleinput1;
my $filehandleinput2;
my $filehandleoutput1;
my $filehandleoutput2;
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
	# make output directory
	if (!-e $outputfolder && !mkdir($outputfolder)) {
		&errorMessage(__LINE__, 'Cannot make output folder.');
	}
	# change working directory
	unless (chdir($outputfolder)) {
		&errorMessage(__LINE__, 'Cannot change working directory.');
	}
	# run assembling
	&runAssams();
	# save output files
	&saveToFASTQ();
	# change working directory
	unless (chdir($root)) {
		&errorMessage(__LINE__, 'Cannot change working directory.');
	}
}

sub printStartupMessage {
	print(STDERR <<"_END");
clreclassclass $buildno
=======================================================================

Official web site of this script is
https://www.fifthdimension.jp/products/claident/ .
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
	$inputfolder = $ARGV[-2];
	$outputfolder = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:min(?:imum)?ident(?:ity|ities)?|m)=(.+)$/i) {
			if (($1 > 0.7 && $1 < 1) || $1 == 0) {
				$assams1option .= " --minident=$1";
				$assams2option .= " --minident=$1";
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:strand|s)=(forward|plus|single|both|double)$/i) {
			if ($1 =~ /^(?:forward|plus|single)$/i) {
				$assams1option .= ' --strand=plus';
				$assams2option .= ' --strand=plus';
			}
			else {
				$assams1option .= ' --strand=both';
				$assams2option .= ' --strand=both';
			}
		}
		elsif ($ARGV[$i] =~ /^-+linkage(?:mode)?=(complete|single|c|s)$/i) {
			if ($1 =~ /^(?:complete|c)$/i) {
				$linkagemode = 'complete';
			}
			elsif ($1 =~ /^(?:single|s)$/i) {
				$linkagemode = 'single';
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+n(?:um)?steps?=(\d+)$/i) {
			$nsteps = $1;
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
		else {
			&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
		}
	}
}

sub checkVariables {
	if (!-e $inputfolder) {
		&errorMessage(__LINE__, "\"$inputfolder\" does not exist.");
	}
	if (-e $outputfolder) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	if ($assams1option !~ /-+(?:min(?:imum)?ident(?:ity|ities)?|m)=(.+)/i) {
		$assams1option .= ' --minident=0.97';
	}
	if ($assams2option !~ /-+(?:min(?:imum)?ident(?:ity|ities)?|m)=(.+)/i) {
		$assams2option .= ' --minident=0.97';
	}
	if ($assams1option !~ /-+(?:strand|s)=(forward|plus|single|both|double)/i) {
		$assams1option .= ' --strand=plus';
	}
	if ($assams2option !~ /-+(?:strand|s)=(forward|plus|single|both|double)/i) {
		$assams2option .= ' --strand=plus';
	}
	$assams2option .= " --linkagemode=$linkagemode";
	if ($nsteps > 2 || $nsteps < 1) {
		&errorMessage(__LINE__, "The number of steps is invalid.");
	}
	if ($nsteps == 2) {
		print(STDERR "Command line options for assams in first run:$assams1option\n");
		print(STDERR "Command line options for assams in second run:$assams2option\n");
	}
	else {
		print(STDERR "Command line options for assams:$assams2option\n");
	}
	print(STDERR "\n");
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

sub runAssams {
	print(STDERR "Running assembly by assams...\n");
	unless (fcopy("$root/$inputfolder/concatenated.fastq.gz", "concatenated.fastq.gz")) {
		&errorMessage(__LINE__, "Cannot copy \"$root/$inputfolder/concatenated.fastq.gz\" to \"concatenated.fastq.gz\"\.");
	}
	unless (fcopy("$root/$inputfolder/concatenated.contigmembers.gz", "concatenated.contigmembers.gz")) {
		&errorMessage(__LINE__, "Cannot copy \"$root/$inputfolder/concatenated.contigmembers.gz\" to \"concatenated.contigmembers.gz\"\.");
	}
	if (system("gzip -dc $root/$inputfolder/assembled.afg.gz | $banktransact -c -f -b previous.bnk -m - 1> $devnull 2> $devnull")) {
		&errorMessage(__LINE__, "Cannot run \"gzip -dc $root/$inputfolder/assembled.afg.gz | $banktransact -c -f -b previous.bnk -m -\".");
	}
	if ($nsteps == 2) {
		# run first assams
		if (system("assams$assams1option --numthreads=$numthreads previous.bnk firstrun.bnk 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"assams$assams1option --numthreads=$numthreads previous.bnk firstrun.bnk\".");
		}
		&deleteBanks("previous.bnk");
		# run second assams
		if (system("assams$assams2option --rawreads=concatenated.fastq.gz --numthreads=$numthreads firstrun.bnk assembled.bnk 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"assams$assams2option --rawreads=concatenated.fastq.gz --numthreads=$numthreads firstrun.bnk assembled.bnk\".");
		}
		&deleteBanks("firstrun.bnk");
		unlink("firstrun.contigmembers.gz");
	}
	else {
		if (system("assams$assams2option --rawreads=concatenated.fastq.gz --numthreads=$numthreads previous.bnk assembled.bnk 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"assams$assams2option --rawreads=concatenated.fastq.gz --numthreads=$numthreads previous.bnk assembled.bnk\".");
		}
		&deleteBanks("previous.bnk");
	}
	&associateReadstoContig("assembled.bnk", "concatenated.fastq.gz");
	print(STDERR "done.\n\n");
}

sub saveToFASTQ {
	# convert to FASTQ/FASTA
	if ($trimlowcoverage) {
		&dumpAllContigsSingletonsfromBank("assembled.bnk", "assembled.fastq", 'amongsampleotu', 1);
		&dumpAllContigsSingletonsfromBanktoFASTA("assembled.bnk", "assembled.fasta", 'amongsampleotu', 1);
	}
	else {
		&dumpAllContigsSingletonsfromBank("assembled.bnk", "assembled.fastq", 'amongsampleotu', 0);
		&dumpAllContigsSingletonsfromBanktoFASTA("assembled.bnk", "assembled.fasta", 'amongsampleotu', 0);
	}
	if (system("gzip assembled.fastq")) {
		&errorMessage(__LINE__, "Cannot run \"gzip assembled.fastq\".");
	}
	if (system("$bankreport -p -b assembled.bnk 2> $devnull | gzip -c > assembled.afg.gz")) {
		&errorMessage(__LINE__, "Cannot run \"$bankreport -p -b assembled.bnk | gzip -c > assembled.afg.gz\".");
	}
	&deleteBanks("assembled.bnk");
}

sub associateReadstoContig {
	my $banknamein = shift(@_);
	my $contigmembers = $banknamein;
	$contigmembers =~ s/\.bnk$/.contigmembers.gz/;
	$contigmembers =~ s/\.fastq$/.contigmembers.gz/;
	$contigmembers =~ s/\.fastq\.gz$/.contigmembers.gz/;
	$contigmembers =~ s/\.afg$/.contigmembers.gz/;
	$contigmembers =~ s/\.afg\.gz$/.contigmembers.gz/;
	my $primarybank = shift(@_);
	my ($secondarycontigmembers, $secondarysingletons) = &getContigMembersfromBank($banknamein);
	my ($primarycontigmembers, $primarysingletons) = &getContigMembersfromBank($primarybank);
	$filehandleoutput1 = writeFile($contigmembers);
	if ($secondarycontigmembers->{$banknamein}) {
		foreach my $contigname (sort({$a cmp $b} keys(%{$secondarycontigmembers->{$banknamein}}))) {
			my $outputname = $contigname;
			$outputname =~ s/^contig_(\d+)/amongsampleotu_$1\__$outputfolder/;
			print($filehandleoutput1 $outputname);
			foreach my $member (@{$secondarycontigmembers->{$banknamein}->{$contigname}}) {
				if ($member =~ /^(dereplicated_\d+.+)$/ || $member =~ /^(withinsampleotu_\d+.+)$/ || $member =~ /^(pastamongsampleotu_\d+.+)$/) {
					foreach my $rawmember (@{$primarycontigmembers->{$primarybank}->{$1}}) {
						print($filehandleoutput1 "\t$rawmember");
					}
				}
				else {
					print($filehandleoutput1 "\t$member");
				}
			}
			print($filehandleoutput1 "\n");
		}
	}
	if ($secondarysingletons->{$banknamein}) {
		foreach my $member (@{$secondarysingletons->{$banknamein}}) {
			if ($member =~ /^(dereplicated_\d+.+)$/ || $member =~ /^(withinsampleotu_\d+.+)$/ || $member =~ /^(pastamongsampleotu_\d+.+)$/) {
				print($filehandleoutput1 $member);
				foreach my $rawmember (@{$primarycontigmembers->{$primarybank}->{$1}}) {
					print($filehandleoutput1 "\t$rawmember");
				}
				print($filehandleoutput1 "\n");
			}
			else {
				print($filehandleoutput1 "\t$member\n");
			}
		}
	}
	close($filehandleoutput1);
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
				s/^\@(\d+)(\r?\n?)$/\@$prefix\_$1\__$outputfolder$2/;
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
				if (@deletepos) {
					foreach my $pos (@deletepos) {
						splice(@tempseq, $pos, 1);
					}
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
				s/^\@contig_(\d+)(\r?\n?)$/\@$prefix\_$1\__$outputfolder$2/;
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
				s/^\@contig_(\d+)(\r?\n?)$/\@$prefix\_$1\__$outputfolder$2/;
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

sub dumpAllContigsSingletonsfromBanktoFASTA {
	my $bankname = shift(@_);
	my $filename = shift(@_);
	my $prefix = shift(@_);
	my $trimlowcov = shift(@_);
	if (-e "$bankname/CTG.ifo") {
		my $lowcov;
		if ($trimlowcov) {
			$lowcov = &getContigLowCoveragePositions($bankname);
			unless (open($pipehandleinput1, "$bank2fasta -b $bankname -iid -g 2> $devnull |")) {
				&errorMessage(__LINE__, "Cannot run \"$bank2fasta -b $bankname -iid -g\".");
			}
		}
		else {
			unless (open($pipehandleinput1, "$bank2fasta -b $bankname -iid 2> $devnull |")) {
				&errorMessage(__LINE__, "Cannot run \"$bank2fasta -b $bankname -iid\".");
			}
		}
		unless (open($filehandleoutput1, ">> $filename")) {
			&errorMessage(__LINE__, "Cannot write \"$filename\".");
		}
		my $contigiid;
		while (<$pipehandleinput1>) {
			if (/^>/) {
				s/^>(\d+)(\r?\n?)$/>$prefix\_$1\__$outputfolder$2/;
				$contigiid = $1;
			}
			elsif ($trimlowcov && $contigiid && $lowcov->{$contigiid}) {
				s/\r?\n?$//;
				my @tempseq = split('', $_);
				foreach my $pos (@{$lowcov->{$contigiid}}) {
					splice(@tempseq, $pos, 1);
				}
				my @deletepos;
				for (my $i = scalar(@tempseq) - 1; $i >= 0; $i --) {
					if ($tempseq[$i] eq '-') {
						push(@deletepos, $i);
					}
				}
				foreach my $pos (@deletepos) {
					splice(@tempseq, $pos, 1);
				}
				$_ = join('', @tempseq) . "\n";
			}
			print($filehandleoutput1 $_);
		}
		close($filehandleoutput1);
		close($pipehandleinput1);
		if (system("$listReadPlacedStatus -S -I $bankname > $filename.singletons.iid 2> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$listReadPlacedStatus -S -I $bankname > $filename.singletons.iid\".");
		}
		unless (open($pipehandleinput1, "$dumpreads -r -e -I $filename.singletons.iid $bankname 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot run \"$dumpreads -r -e -I $filename.singletons.iid $bankname\".");
		}
		unless (open($filehandleoutput1, ">> $filename")) {
			&errorMessage(__LINE__, "Cannot write \"$filename\".");
		}
		while (<$pipehandleinput1>) {
			s/^>contig_(\d+)(\r?\n?)$/>$prefix\_$1\__$outputfolder$2/;
			print($filehandleoutput1 $_);
		}
		close($filehandleoutput1);
		close($pipehandleinput1);
		unless (unlink("$filename.singletons.iid")) {
			&errorMessage(__LINE__, "Cannot delete \"$filename.singletons.iid\".");
		}
	}
	else {
		unless (open($pipehandleinput1, "$dumpreads -r -e $bankname 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot run \"$dumpreads -r -e $bankname\".");
		}
		unless (open($filehandleoutput1, ">> $filename")) {
			&errorMessage(__LINE__, "Cannot write \"$filename\".");
		}
		while (<$pipehandleinput1>) {
			s/^>contig_(\d+)(\r?\n?)$/>$prefix\_$1\__$outputfolder$2/;
			print($filehandleoutput1 $_);
		}
		close($filehandleoutput1);
		close($pipehandleinput1);
	}
}

sub getContigMembersfromBank {
	my %contigmembers;
	my %singletons;
	foreach my $bankname (@_) {
		my $prefix = $bankname;
		$prefix =~ s/\.bnk$//;
		$prefix =~ s/\.fastq$//;
		$prefix =~ s/\.fastq\.gz$//;
		$prefix =~ s/\.afg$//;
		$prefix =~ s/\.afg\.gz$//;
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
clreclassclass options inputfolder outputfolder

Command line options
====================
--minident=DECIMAL
  Specify the minimum identity threshold. (default: 0.97)

--linkagemode=SINGLE|COMPLETE
  Specify linkage mode. (default: SINGLE)

--strand=PLUS|BOTH
  Specify search strand option for Assams. (default: PLUS)

--nsteps=1|2
  Specify the number of steps running Assams. (default: 2)

--trimlowcoverage=ENABLE|DISABLE
  Specify low coverage ends should be trimmed or not. (default: ENABLE)

--minncoverage=INTEGER
  Specify the minimum number of coverage. (default: 2)

--minpcoverage=DECIMAL
  Specify the minimum percentage of coverage (coverage / max coverage).
(default: 0.5)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

Acceptable input folder
=======================
Output folder of clclassclass
_END
	exit;
}
