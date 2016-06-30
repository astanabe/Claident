use strict;
use File::Spec;
use File::Copy::Recursive ('fcopy', 'rcopy', 'dircopy');
use Cwd 'getcwd';

my $buildno = '0.2.x';

my $devnull = File::Spec->devnull();

# options
# vsearch option for within-sample dereplication
my $vsearch1option = ' --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --strand plus --sizeout';
# vsearch option for among-sample dereplication
my $vsearch2option = ' --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --strand plus --sizein --sizeout';
# vsearch option for primary clustering
my $vsearch3option = ' --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --strand plus --sizein --sizeout --qmask none --fulldp --wordlength 12 --cluster_size';
# vsearch option for secondary clustering
my $vsearch4option = ' --fasta_width 999999 --maxseqlength 50000 --minseqlength 32 --notrunclabels --strand plus --sizein --sizeout --qmask none --fulldp --wordlength 12 --cluster_size';
my $mincleanclustersize = 0;
my $pnoisycluster = 0.5;
my $runname;
my $primarymaxnmismatch = 0;
my $secondarymaxnmismatch = 1;
my $minnreplicate = 2;
my $minpreplicate = 1;
my $minnpositive = 1;
my $minppositive = 0;
my $numthreads = 1;
my $derepmode = 'prefix';
my $nodel;

# input/output
my $outputfolder;
my @inputfiles;
my $replicatelist;

# commands
my $vsearch;

# global variables
my $root = getcwd();
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
	# run clustering for each sample
	&runVSEARCHExactEach();
	# run noise detection
	&runNoiseDetection();
	# delete noisy sequences
	&deleteNoisySequences();
	# compress text files
	&compressTXTs();
	# compress fasta files
	&compressFASTAs();
	# change working directory
	unless (chdir($root)) {
		&errorMessage(__LINE__, 'Cannot change working directory.');
	}
	exit(0);
}

sub printStartupMessage {
	print(STDERR <<"_END");
clcleanseqv $buildno
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
	$outputfolder = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+(?:derep|dereplication)mode=(.+)$/i) {
			if ($1 =~ /^(?:full|fulllen|fulllength)$/i) {
				$derepmode = 'full';
			}
			elsif ($1 =~ /^(?:pre|prefix)$/i) {
				$derepmode = 'prefix';
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+primarymax(?:imum)?n(?:um)?(?:mismatch|mismatches)=(\d+)$/i) {
			$primarymaxnmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+secondarymax(?:imum)?n(?:um)?(?:mismatch|mismatches)=(\d+)$/i) {
			$secondarymaxnmismatch = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:r|rate|p|percentage)noisycluster=(\d(?:\.\d+)?)/i) {
			$pnoisycluster = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?cleanclustersize=(\d+)$/i) {
			$mincleanclustersize = $1;
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
	if ($minnpositive < 1) {
		&errorMessage(__LINE__, "The minimum number of true positive for noisy/chimeric OTU detection is invalid.");
	}
	if ($minppositive > 1) {
		&errorMessage(__LINE__, "The minimum percentage of true positive for noisy/chimeric OTU detection is invalid.");
	}
	if ($derepmode eq 'prefix') {
		$vsearch1option .= ' --derep_prefix';
		$vsearch2option .= ' --derep_prefix';
	}
	elsif ($derepmode eq 'full') {
		$vsearch1option .= ' --derep_fulllength';
		$vsearch2option .= ' --derep_fulllength';
	}
	if ($primarymaxnmismatch == 0) {
		$vsearch3option = " --id 1" . $vsearch3option;
	}
	else {
		$vsearch3option = " --id 0.9 --maxdiffs $primarymaxnmismatch" . $vsearch3option;
	}
	if ($secondarymaxnmismatch == 0) {
		&errorMessage(__LINE__, "The maximum number of acceptable mismatches for secondary clustering must not be zero.");
	}
	elsif ($secondarymaxnmismatch <= $primarymaxnmismatch) {
		&errorMessage(__LINE__, "The maximum number of acceptable mismatches for secondary clustering must be larger than that for primary clustering.");
	}
	else {
		$vsearch4option = " --id 0.9 --maxdiffs $secondarymaxnmismatch" . $vsearch4option;
	}
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

sub runVSEARCHExactEach {
	# run first vsearch in parallel
	print(STDERR "Running dereplication by VSEARCH at each file...\n");
	my @newinput;
	foreach my $inputfile (@inputfiles) {
		print(STDERR "Processing $inputfile...\n");
		my $filename = $inputfile;
		$filename =~ s/^.+(?:\/|\\)//;
		$filename =~ s/\.(?:gz|bz2|xz)$//;
		$filename =~ s/\.[^\.]+$//;
		push(@newinput, $filename);
		my $tempinputfile;
		{
			my $inputpath;
			if ($inputfile =~ /^\//) {
				$inputpath = $inputfile;
			}
			else {
				$inputpath = "$root/$inputfile";
			}
			if ($runname) {
				if ($inputfile =~ /\.(?:fq|fastq)(?:\.gz|\.bz2|\.xz)?$/) {
					&convertFASTQtoFASTA($inputpath, "$filename.renamed.fasta");
				}
				else {
					&renameRunName($inputpath, "$filename.renamed.fasta");
				}
				$tempinputfile = "$filename.renamed.fasta";
			}
			elsif ($inputfile =~ /\.(?:fq|fastq)(?:\.gz|\.bz2|\.xz)?$/) {
				&convertFASTQtoFASTA($inputpath, "$filename.fasta");
				$tempinputfile = "$filename.fasta";
			}
			elsif ($inputfile =~ /\.xz$/) {
				if (system("xz -dc $inputpath > $filename.fasta")) {
					&errorMessage(__LINE__, "Cannot run \"xz -dc $inputpath > $filename.fasta\".");
				}
				$tempinputfile = "$filename.fasta";
			}
			else {
				$tempinputfile = $inputpath;
			}
		}
		if (system("$vsearch$vsearch1option $tempinputfile --threads $numthreads --output $filename.dereplicated.fasta --uc $filename.dereplicated.uc 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearch1option $tempinputfile --threads $numthreads --output $filename.dereplicated.fasta --uc $filename.dereplicated.uc\".");
		}
		&convertUCtoOTUMembers("$filename.dereplicated.uc", "$filename.dereplicated.otu.gz");
		unless ($nodel) {
			unlink($tempinputfile);
		}
	}
	@inputfiles = @newinput;
	print(STDERR "done.\n\n");
}

sub runNoiseDetection {
	print(STDERR "Running noise detection...\n");
	# merge cluster
	if (@inputfiles > 1) {
		my @otufiles;
		# join all dereplicated FASTA files
		unless (open($filehandleoutput1, "> temp1.fasta")) {
			&errorMessage(__LINE__, "Cannot write \"temp1.fasta\".");
		}
		foreach my $inputfile (@inputfiles) {
			push(@otufiles, "$inputfile.dereplicated.otu.gz");
			unless (open($filehandleinput1, "< $inputfile.dereplicated.fasta")) {
				&errorMessage(__LINE__, "Cannot read \"$inputfile.dereplicated.fasta\".");
			}
			while (<$filehandleinput1>) {
				print($filehandleoutput1 $_);
			}
			close($filehandleinput1);
		}
		close($filehandleoutput1);
		# merge
		if (system("$vsearch$vsearch2option temp1.fasta --threads $numthreads --output temp2.fasta --uc temp2.uc 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearch2option temp1.fasta --threads $numthreads --output temp2.fasta --uc temp2.uc\".");
		}
		unless ($nodel) {
			unlink("temp1.fasta");
		}
		&convertUCtoOTUMembers("temp2.uc", "temp2.otu.gz", @otufiles);
	}
	else {
		unless (fcopy("$inputfiles[0].dereplicated.fasta", "temp2.fasta")) {
			&errorMessage(__LINE__, "Cannot copy \"$inputfiles[0].dereplicated.fasta\" to \"temp2.fasta\".");
		}
		unless (fcopy("$inputfiles[0].dereplicated.otu.gz", "temp2.otu.gz")) {
			&errorMessage(__LINE__, "Cannot copy \"$inputfiles[0].dereplicated.otu.gz\" to \"temp2.otu.gz\".");
		}
	}
	unless ($nodel) {
		foreach my $inputfile (@inputfiles) {
			unlink("$inputfile.dereplicated.fasta");
			unlink("$inputfile.dereplicated.otu.gz");
		}
	}
	# primary clustering and make consensus for canceling errors out
	if ($primarymaxnmismatch == 0) {
		if (system("$vsearch$vsearch3option temp2.fasta --threads $numthreads --centroids primarycluster.fasta --uc primarycluster.uc 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearch3option temp2.fasta --threads $numthreads --centroids primarycluster.fasta --uc primarycluster.uc\".");
		}
	}
	else {
		if (system("$vsearch$vsearch3option temp2.fasta --threads $numthreads --msaout primarycluster_msa.fasta --consout primarycluster.fasta --cons_truncate --uc primarycluster.uc 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearch3option temp2.fasta --threads $numthreads --msaout primarycluster_msa.fasta --consout primarycluster.fasta --cons_truncate --uc primarycluster.uc\".");
		}
		if (system("perl -i.bak -npe 's/^>centroid=/>/;s/seqs=\\d+;//' primarycluster.fasta 1> $devnull")) {
			&errorMessage(__LINE__, "Cannot run \"perl -i.bak -npe 's/^>centroid=/>/;s/seqs=\\d+;//' primarycluster.fasta\".");
		}
		unless ($nodel) {
			unlink("primarycluster.fasta.bak");
		}
	}
	&convertUCtoOTUMembers("primarycluster.uc", "primarycluster.otu.gz", "temp2.otu.gz");
	unless ($nodel) {
		unlink("temp2.fasta");
		unlink("temp2.otu.gz");
	}
	# members of primarycluster
	my ($primaryotumembers, $primarysingletons) = &getOTUMembers("primarycluster.otu.gz");
	my %primaryclustersize;
	if (%{$primaryotumembers}) {
		my @tempotu = keys(%{$primaryotumembers});
		if (@tempotu) {
			foreach my $primaryotu (@tempotu) {
				$primaryclustersize{$primaryotu} = scalar(@{$primaryotumembers->{$primaryotu}});
			}
		}
	}
	else {
		&errorMessage(__LINE__, "\"primarycluster.otu.gz\" is invalid.");
	}
	if ($mincleanclustersize == 0) {
		# cluster primarycluster to secondarycluster
		if (-e 'primarycluster.otu.gz' && -e 'primarycluster.fasta') {
			if (system("$vsearch$vsearch4option primarycluster.fasta --threads $numthreads --centroids secondarycluster.fasta --uc secondarycluster.uc 1> $devnull")) {
				&errorMessage(__LINE__, "Cannot run \"$vsearch$vsearch4option primarycluster.fasta --threads $numthreads --centroids secondarycluster.fasta --uc secondarycluster.uc\".");
			}
			&convertUCtoOTUMembers("secondarycluster.uc", "secondarycluster.otu.gz");
		}
		else {
			&errorMessage(__LINE__, "Cannot find \"primarycluster.otu.gz\" and/or \"primarycluster.fasta\".");
		}
		# read clustering result
		my ($secondaryotumembers, $secondarysingletons) = &getOTUMembers("secondarycluster.otu.gz");
		# determine threshold
		if (%{$secondaryotumembers}) {
			my @primaryclustersize;
			foreach my $secondaryotu (keys(%{$secondaryotumembers})) {
				my @tempclustersize;
				foreach my $primaryotu (@{$secondaryotumembers->{$secondaryotu}}) {
					if ($primaryclustersize{$primaryotu}) {
						push(@tempclustersize, $primaryclustersize{$primaryotu});
					}
				}
				@tempclustersize = sort({$b <=> $a} @tempclustersize);
				#print(STDERR "Sorted primary cluster sizes of $secondaryotu : @tempclustersize\n");
				# drop largest cluster size
				shift(@tempclustersize);
				if (@tempclustersize) {
					push(@primaryclustersize, @tempclustersize);
				}
			}
			#print(STDERR "Unsorted primary cluster sizes : @primaryclustersize\n");
			@primaryclustersize = sort({$a <=> $b} @primaryclustersize);
			#print(STDERR "Sorted primary cluster sizes : @primaryclustersize\n");
			$mincleanclustersize = $primaryclustersize[int(scalar(@primaryclustersize) * $pnoisycluster)];
		}
		if ($mincleanclustersize < 2) {
			&errorMessage(__LINE__, "There are no secondary cluster. This data seems too noisy for this setting.");
		}
		print(STDERR "The minimum clean cluster size has been determined as $mincleanclustersize.\n");
	}
	# save sequence names for elimination
	if ($mincleanclustersize > 2) {
		foreach my $primaryotu (sort({$a cmp $b} keys(%{$primaryotumembers}))) {
			if ($primaryclustersize{$primaryotu} < $mincleanclustersize) {
				foreach my $member (@{$primaryotumembers->{$primaryotu}}) {
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
	# save singleton names for elimination
	foreach my $member (sort({$a cmp $b} keys(%{$primarysingletons}))) {
		my $prefix = $member;
		$prefix =~ s/^.+?__//;
		unless (open($filehandleoutput1, ">> $prefix.singletons.txt")) {
			&errorMessage(__LINE__, "Cannot write \"$prefix.singletons.txt\".");
		}
		print($filehandleoutput1 $member . "\n");
		close($filehandleoutput1);
		if ($mincleanclustersize > 1) {
			unless (open($filehandleoutput1, ">> $prefix.noisyreads.txt")) {
				&errorMessage(__LINE__, "Cannot write \"$prefix.noisyreads.txt\".");
			}
			print($filehandleoutput1 $member . "\n");
			close($filehandleoutput1);
		}
	}
	# additional noise and/or chimera detection based on replicate list
	if ($replicatelist && %replicate) {
		print(STDERR "Running additional chimera detection using replicates...\n");
		my %table;
		my %otusum;
		my @otunames;
		foreach my $primaryotu (keys(%{$primaryotumembers})) {
			push(@otunames, $primaryotu);
			foreach my $member (@{$primaryotumembers->{$primaryotu}}) {
				my @temp = split(/__/, $member);
				if (scalar(@temp) == 3) {
					my ($temp, $temprunname, $primer) = @temp;
					$table{"$temprunname\__$primer"}{$primaryotu} ++;
					$otusum{$primaryotu} ++;
					
				}
				elsif (scalar(@temp) == 4) {
					my ($temp, $temprunname, $tag, $primer) = @temp;
					$table{"$temprunname\__$tag\__$primer"}{$primaryotu} ++;
					$otusum{$primaryotu} ++;
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
				foreach my $member (@{$primaryotumembers->{$otuname}}) {
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
	if ($replicatelist && %replicate) {
		print(STDERR "Deleting noisy and/or chimeric sequences...\n");
	}
	else {
		print(STDERR "Deleting noisy sequences...\n");
	}
	# save parameter
	{
		unless (open($filehandleoutput1, "> parameter.txt")) {
			&errorMessage(__LINE__, "Cannot write \"parameter.txt\".");
		}
		print($filehandleoutput1 "minimum clean cluster size: $mincleanclustersize\n");
		close($filehandleoutput1);
	}
	# get noisy/chimeric/notclean information
	my %chimeric;
	my %noisy;
	my %notclean;
	foreach my $inputfile (@inputfiles) {
		# read the results of noisy reads detection
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
		if ($replicatelist && %replicate && -e "$inputfile.chimericreads.txt") {
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
			if (-e "$inputfile.singletons.txt") {
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
	}
	# make results for each input file
	{
		my $prefix = 'primarycluster';
		my ($exactotumembers, $exactsingletons) = &getOTUMembers("$prefix.otu.gz");
		# output filtered primarycluster FASTA
		if ($replicatelist && %replicate) {
			$filehandleoutput1 = &writeFile("$prefix.chimeraremoved.fasta.gz");
			$filehandleoutput3 = &writeFile("$prefix.cleaned.fasta.gz");
		}
		$filehandleoutput2 = &writeFile("$prefix.denoised.fasta.gz");
		my $chimeric = 0;
		my $noisy = 0;
		my $notclean = 0;
		# otus
		if (%{$exactotumembers}) {
			unless (open($filehandleinput1, "< $prefix.fasta")) {
				&errorMessage(__LINE__, "Cannot read \"$prefix.fasta\".");
			}
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				s/;size=\d+;?//g;
				if (/^>(.+)/) {
					$chimeric = 0;
					$noisy = 0;
					$notclean = 0;
					my $otuname = $1;
					if ($exactotumembers->{$otuname}) {
						my $ab = scalar(@{$exactotumembers->{$otuname}});
						foreach my $member (@{$exactotumembers->{$otuname}}) {
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
							print($filehandleoutput1 ">$otuname;size=$ab;\n");
						}
						if (!$noisy && $filehandleoutput2) {
							print($filehandleoutput2 ">$otuname;size=$ab;\n");
						}
						if (!$notclean && $filehandleoutput3) {
							print($filehandleoutput3 ">$otuname;size=$ab;\n");
						}
					}
					elsif ($exactsingletons->{$otuname}) {
						if ($chimeric{$otuname}) {
							$chimeric = 1;
						}
						if ($noisy{$otuname}) {
							$noisy = 1;
						}
						if ($notclean{$otuname}) {
							$notclean = 1;
						}
						if (!$chimeric && $filehandleoutput1) {
							print($filehandleoutput1 ">$otuname;size=1;\n");
						}
						if (!$noisy && $filehandleoutput2) {
							print($filehandleoutput2 ">$otuname;size=1;\n");
						}
						if (!$notclean && $filehandleoutput3) {
							print($filehandleoutput3 ">$otuname;size=1;\n");
						}
					}
					else {
						&errorMessage(__LINE__, "Unknown error.\n");
					}
				}
				else {
					if (!$chimeric && $filehandleoutput1) {
						print($filehandleoutput1 $_ . "\n");
					}
					if (!$noisy && $filehandleoutput2) {
						print($filehandleoutput2 $_ . "\n");
					}
					if (!$notclean && $filehandleoutput3) {
						print($filehandleoutput3 $_ . "\n");
					}
				}
			}
			close($filehandleinput1);
		}
		if ($filehandleoutput1) {
			close($filehandleoutput1);
		}
		if ($filehandleoutput2) {
			close($filehandleoutput2);
		}
		if ($filehandleoutput3) {
			close($filehandleoutput3);
		}
		# output filtered OTUMembers
		if ($replicatelist && %replicate) {
			$filehandleoutput1 = &writeFile("$prefix.chimeraremoved.otu.gz");
			$filehandleoutput3 = &writeFile("$prefix.cleaned.otu.gz");
		}
		$filehandleoutput2 = &writeFile("$prefix.denoised.otu.gz");
		# otus
		if (%{$exactotumembers}) {
			$filehandleinput1 = &readFile("$prefix.otu.gz");
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				if (/^>(.+)/) {
					$chimeric = 0;
					$noisy = 0;
					$notclean = 0;
					my $otuname = $1;
					if ($exactotumembers->{$otuname}) {
						foreach my $member (@{$exactotumembers->{$otuname}}) {
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
							print($filehandleoutput1 ">$otuname\n");
						}
						if (!$noisy && $filehandleoutput2) {
							print($filehandleoutput2 ">$otuname\n");
						}
						if (!$notclean && $filehandleoutput3) {
							print($filehandleoutput3 ">$otuname\n");
						}
					}
					elsif ($exactsingletons->{$otuname}) {
						if ($chimeric{$otuname}) {
							$chimeric = 1;
						}
						if ($noisy{$otuname}) {
							$noisy = 1;
						}
						if ($notclean{$otuname}) {
							$notclean = 1;
						}
						if (!$chimeric && $filehandleoutput1) {
							print($filehandleoutput1 ">$otuname\n");
						}
						if (!$noisy && $filehandleoutput2) {
							print($filehandleoutput2 ">$otuname\n");
						}
						if (!$notclean && $filehandleoutput3) {
							print($filehandleoutput3 ">$otuname\n");
						}
					}
					else {
						&errorMessage(__LINE__, "Unknown error.\n");
					}
				}
				else {
					if (!$chimeric && $filehandleoutput1) {
						print($filehandleoutput1 $_ . "\n");
					}
					if (!$noisy && $filehandleoutput2) {
						print($filehandleoutput2 $_ . "\n");
					}
					if (!$notclean && $filehandleoutput3) {
						print($filehandleoutput3 $_ . "\n");
					}
				}
			}
			close($filehandleinput1);
		}
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
	print(STDERR "done.\n\n");
}

sub compressTXTs {
	print(STDERR "Compressing TXT files...\n");
	&compressByGZIP(glob("*.txt"));
	print(STDERR "done.\n\n");
}

sub compressFASTAs {
	print(STDERR "Compressing FASTA files...\n");
	&compressByGZIP(glob("*.fasta"));
	print(STDERR "done.\n\n");
}

sub getOTUMembers {
	my $otufile = shift(@_);
	my %otumembers;
	my %singletons;
	{
		my %cluster;
		$filehandleinput1 = &readFile($otufile);
		{
			my $centroid;
			while (<$filehandleinput1>) {
				s/\r?\n?$//;
				s/;size=\d+;?//g;
				if (/^>(.+)$/) {
					$centroid = $1;
					push(@{$cluster{$centroid}}, $1);
				}
				elsif ($centroid && /^([^>].*)$/) {
					push(@{$cluster{$centroid}}, $1);
				}
				else {
					&errorMessage(__LINE__, "\"$otufile\" is invalid.");
				}
			}
		}
		close($filehandleinput1);
		foreach my $centroid (keys(%cluster)) {
			if (scalar(@{$cluster{$centroid}}) > 1) {
				foreach my $member (@{$cluster{$centroid}}) {
					push(@{$otumembers{$centroid}}, $member);
				}
			}
			else {
				foreach my $member (@{$cluster{$centroid}}) {
					push(@{$singletons{$member}}, $member);
				}
			}
		}
	}
	return(\%otumembers, \%singletons);
}

sub convertUCtoOTUMembers {
	my @subotufile = @_;
	my $ucfile = shift(@subotufile);
	my $otufile = shift(@subotufile);
	my %subcluster;
	foreach my $subotufile (@subotufile) {
		$filehandleinput1 = &readFile($subotufile);
		my $centroid;
		while (<$filehandleinput1>) {
			s/\r?\n?$//;
			s/;size=\d+;?//g;
			if (/^>(.+)$/) {
				$centroid = $1;
			}
			elsif ($centroid && /^([^>].*)$/) {
				push(@{$subcluster{$centroid}}, $1);
			}
		}
		close($filehandleinput1);
	}
	my %cluster;
	$filehandleinput1 = &readFile($ucfile);
	while (<$filehandleinput1>) {
		s/\r?\n?$//;
		s/;size=\d+;?//g;
		my @row = split(/\t/, $_);
		if ($row[0] eq 'S') {
			push(@{$cluster{$row[8]}}, $row[8]);
			if (exists($subcluster{$row[8]})) {
				foreach my $submember (@{$subcluster{$row[8]}}) {
					if ($submember ne $row[8]) {
						push(@{$cluster{$row[8]}}, $submember);
					}
					else {
						&errorMessage(__LINE__, "\"$ucfile\" is invalid.");
					}
				}
			}
		}
		elsif ($row[0] eq 'H') {
			push(@{$cluster{$row[9]}}, $row[8]);
			if (exists($subcluster{$row[8]})) {
				foreach my $submember (@{$subcluster{$row[8]}}) {
					if ($submember ne $row[8] && $submember ne $row[9]) {
						push(@{$cluster{$row[9]}}, $submember);
					}
					else {
						&errorMessage(__LINE__, "\"$ucfile\" is invalid.");
					}
				}
			}
		}
	}
	close($filehandleinput1);
	unless ($nodel) {
		unlink($ucfile);
	}
	$filehandleoutput1 = &writeFile($otufile);
	foreach my $centroid (keys(%cluster)) {
		print($filehandleoutput1 ">$centroid\n");
		foreach my $member (@{$cluster{$centroid}}) {
			if ($member ne $centroid) {
				print($filehandleoutput1 "$member\n");
			}
		}
	}
	close($filehandleoutput1);
}

sub renameRunName {
	my $filenamein = shift(@_);
	my $filenameout = shift(@_);
	$filehandleinput1 = &readFile($filenamein);
	$filehandleoutput1 = &writeFile($filenameout);
	while (<$filehandleinput1>) {
		if (/^>(.+)/) {
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
			print($filehandleoutput1 ">$seqname");
		}
		else {
			print($filehandleoutput1 "$_");
		}
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

sub convertFASTQtoFASTA {
	my $fastqfile = shift(@_);
	my $fastafile = shift(@_);
	$filehandleinput1 = &readFile($fastqfile);
	$filehandleoutput1 = &writeFile($fastafile);
	while (<$filehandleinput1>) {
		my $nameline = $_;
		my $seqline = <$filehandleinput1>;
		my $sepline = <$filehandleinput1>;
		my $qualline = <$filehandleinput1>;
		if (substr($nameline, 0, 1) ne '@') {
			&errorMessage(__LINE__, "\"$fastqfile\" is invalid.");
		}
		if (substr($sepline, 0, 1) ne '+') {
			&errorMessage(__LINE__, "\"$fastqfile\" is invalid.");
		}
		if ($runname) {
			my $seqname = substr($nameline, 1);
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
			print($filehandleoutput1 ">$seqname");
		}
		else {
			print($filehandleoutput1 '>' . substr($nameline, 1));
		}
		print($filehandleoutput1 $seqline);
	}
	close($filehandleoutput1);
	close($filehandleinput1);
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
clcleanseqv options inputfiles outputfolder

Command line options
====================
--derepmode=FULL|PREFIX
  Specify dereplication mode for VSEARCH. (default: PREFIX)

--primarymaxnmismatch=INTEGER
  Specify the maximum number of acceptable mismatches for primary clustering.
(default: 0)

--secondarymaxnmismatch=INTEGER
  Specify the maximum number of acceptable mismatches for secondary clustering.
(default: 1)

--mincleanclustersize=INTEGER
  Specify minimum size of clean cluster. 0 means automatically
determined (but this will take a while). (default: 0)

--pnoisycluster=DECIMAL
  Specify the percentage of noisy cluster. (default: 0.5)

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
(Quality values will be ignored.)
FASTA (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
