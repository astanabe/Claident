use strict;
use File::Spec;

my $buildno = '0.9.x';

print(STDERR <<"_END");
clblastprimer $buildno
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

# initialize variables
my $devnull = File::Spec->devnull();
my $numthreads = 1;
my $ht;
my $blastoption;

# get input file name
my $inputfile = $ARGV[-2];
# check input file
if (!-e $inputfile) {
	&errorMessage(__LINE__, "Input file does not exist.");
}

# get output file name
my $outputfile = $ARGV[-1];
# check output file
if (-e $outputfile) {
	&errorMessage(__LINE__, "Output file already exists.");
}
while (glob("$outputfile.*")) {
	if (/^$outputfile.\d+$/) {
		&errorMessage(__LINE__, "Temporary file already exists.");
	}
}

# get other arguments
{
	my $blastmode = 0;
	for (my $i = 0; $i < scalar(@ARGV) - 2; $i ++) {
		if ($ARGV[$i] =~ /^end$/i) {
			$blastmode = 0;
		}
		elsif ($blastmode) {
			$blastoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^blastn?$/i) {
			$blastmode = 1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$numthreads = $1;
		}
		elsif ($ARGV[$i] =~ /^-+(?:ht|hyperthreads?)=(\d+)$/i) {
			$ht = $1;
		}
		else {
			&errorMessage(__LINE__, "Invalid option.");
		}
	}
}

# check variables
if ($ht) {
	if ($numthreads % $ht != 0) {
		&errorMessage(__LINE__, "Multithreading with hyperthreading requires integral multiple numthreads of hyperthreads.");
	}
	else {
		$numthreads /= $ht;
	}
}
else {
	$ht = 1;
}
if ($blastoption =~ / -(?:query|out|outfmt|num_descriptions|num_alignments|num_threads) /) {
	&errorMessage(__LINE__, "The options for blastn is invalid.");
}
elsif ($blastoption !~ / -db /) {
	&errorMessage(__LINE__, "BLASTDB is not given.");
}

my $blastn;
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
		$blastn = "\"$pathto/blastn\"";
	}
	else {
		$blastn = 'blastn';
	}
}

my $blastdbpath;
if ($ENV{'BLASTDB'}) {
	$blastdbpath = $ENV{'BLASTDB'};
	$blastdbpath =~ s/^"(.+)"$/$1/;
	$blastdbpath =~ s/\/$//;
}
foreach my $temp ('.claident', $ENV{'HOME'} . '/.claident', '/etc/claident/.claident', '.ncbirc', $ENV{'HOME'} . '/.ncbirc', $ENV{'NCBI'} . '/.ncbirc') {
	if (-e $temp) {
		my $pathto;
		my $filehandle;
		unless (open($filehandle, "< $temp")) {
			&errorMessage(__LINE__, "Cannot read \"$temp\".");
		}
		while (<$filehandle>) {
			if (/^\s*BLASTDB\s*=\s*(\S[^\r\n]*)/) {
				$pathto = $1;
				$pathto =~ s/\s+$//;
				last;
			}
		}
		close($filehandle);
		$pathto =~ s/^"(.+)"$/$1/;
		$pathto =~ s/\/$//;
		if ($blastdbpath) {
			if ($^O eq 'cygwin') {
				$blastdbpath .= ';' . $pathto;
			}
			else {
				$blastdbpath .= ':' . $pathto;
			}
		}
		else {
			$blastdbpath = $pathto;
		}
	}
}

# read input file, decompose degeneracy and eliminate duplicates
my @queries;
print(STDERR "Reading query sequence file...");
{
	my %temp1;
	# open input file
	my $inputhandle;
	unless (open($inputhandle, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot read \"$inputfile\".");
	}
	my $taxon;
	while (<$inputhandle>) {
		s/\r?\n?$//;
		if (/^>\s*(\S.*?)\s*$/) {
			$taxon = $1;
		}
		elsif ($taxon && /^[^>]/) {
			my @seq = $_ =~ /\S/g;
			$temp1{$taxon} .= uc(join('', @seq));
		}
	}
	close($inputhandle);
	my %temp2;
	foreach my $taxon (keys(%temp1)) {
		foreach my $seq (&decomposeDegeneracy($temp1{$taxon})) {
			$temp2{$seq} = 1;
		}
	}
	@queries = keys(%temp2);
}
print(STDERR "done.\n\n");

# run BLAST search
print(STDERR "Running BLAST search...\nThis may take a while.\n");
{
	my $child = 0;
	$| = 1;
	$? = 0;
	for (my $i = 0; $i < scalar(@queries); $i ++) {
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
			print(STDERR "Running blastn for sequence $i...\n");
			my $pipehandle;
			unless (open($pipehandle, "| BLASTDB=\"$blastdbpath\" $blastn$blastoption -query - -out $outputfile.$i -outfmt \"6 sacc\" -num_threads $ht 2> $devnull 1> $devnull")) {
				&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query - -out $outputfile.$i -outfmt \"6 sacc\" -num_threads $ht\".");
			}
			print($pipehandle ">query$i\n$queries[$i]\n");
			close($pipehandle);
			if ($?) {
				&errorMessage(__LINE__, "Cannot run \"BLASTDB=\"$blastdbpath\" $blastn$blastoption -query - -out $outputfile.$i -outfmt \"6 sacc\" -num_threads $ht\".");
			}
			exit;
		}
	}
}

# join
while (wait != -1) {
	if ($?) {
		&errorMessage(__LINE__, 'Cannot run BLAST search correctly.');
	}
}
print(STDERR "done.\n\n");

{
	my %temp;
	my $inputhandle;
	for (my $i = 0; $i < scalar(@queries); $i ++) {
		unless (open($inputhandle, "< $outputfile.$i")) {
			&errorMessage(__LINE__, "Cannot read \"$outputfile.$i\".");
		}
		while (<$inputhandle>) {
			if (/^[A-Za-z0-9_]+/) {
				$temp{$&} = 1;
			}
		}
		close($inputhandle);
		unlink("$outputfile.$i");
	}
	my $outputhandle;
	unless (open($outputhandle, "> $outputfile")) {
		&errorMessage(__LINE__, "Cannot write \"$outputfile\"");
	}
	foreach (keys(%temp)) {
		print($outputhandle "$_\n");
	}
	close($outputhandle);
}

sub decomposeDegeneracy {
	my @candidate;
	my @seq = split(/ */, $_[0]);
	for (my $i = 0; $i < scalar(@seq); $i ++) {
		if ($seq[$i] eq 'M') {
			my @temp = @seq;
			$temp[$i] = 'A';
			push(@candidate, join('', @temp));
			$temp[$i] = 'C';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'R') {
			my @temp = @seq;
			$temp[$i] = 'A';
			push(@candidate, join('', @temp));
			$temp[$i] = 'G';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'W') {
			my @temp = @seq;
			$temp[$i] = 'A';
			push(@candidate, join('', @temp));
			$temp[$i] = 'T';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'S') {
			my @temp = @seq;
			$temp[$i] = 'C';
			push(@candidate, join('', @temp));
			$temp[$i] = 'G';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'Y') {
			my @temp = @seq;
			$temp[$i] = 'C';
			push(@candidate, join('', @temp));
			$temp[$i] = 'T';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'K') {
			my @temp = @seq;
			$temp[$i] = 'G';
			push(@candidate, join('', @temp));
			$temp[$i] = 'T';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'V') {
			my @temp = @seq;
			$temp[$i] = 'A';
			push(@candidate, join('', @temp));
			$temp[$i] = 'C';
			push(@candidate, join('', @temp));
			$temp[$i] = 'G';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'H') {
			my @temp = @seq;
			$temp[$i] = 'A';
			push(@candidate, join('', @temp));
			$temp[$i] = 'C';
			push(@candidate, join('', @temp));
			$temp[$i] = 'T';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'D') {
			my @temp = @seq;
			$temp[$i] = 'A';
			push(@candidate, join('', @temp));
			$temp[$i] = 'G';
			push(@candidate, join('', @temp));
			$temp[$i] = 'T';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'B') {
			my @temp = @seq;
			$temp[$i] = 'C';
			push(@candidate, join('', @temp));
			$temp[$i] = 'G';
			push(@candidate, join('', @temp));
			$temp[$i] = 'T';
			push(@candidate, join('', @temp));
		}
		elsif ($seq[$i] eq 'N') {
			my @temp = @seq;
			$temp[$i] = 'A';
			push(@candidate, join('', @temp));
			$temp[$i] = 'C';
			push(@candidate, join('', @temp));
			$temp[$i] = 'G';
			push(@candidate, join('', @temp));
			$temp[$i] = 'T';
			push(@candidate, join('', @temp));
		}
	}
	if (!@candidate) {
		push(@candidate, join('', @seq));
	}
	my @out;
	foreach my $candidate (@candidate) {
		if ($candidate =~ /[MRWSYKVHDBN]/) {
			push(@out, &decomposeDegeneracy($candidate));
		}
		else {
			push(@out, $candidate);
		}
	}
	return(@out);
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
clblastprimer options inputfile outputfile

Command line options
====================
blastn options end
  Specify commandline options for blastn. (default: none)

-n, --numthreads=INTEGER
  Specify the number of processes. (default: 1)

--ht, --hyperthreads=INTEGER
  Specify the number of threads of each process. (default: 1)

Acceptable input file formats
=============================
FASTA
_END
	exit;
}
