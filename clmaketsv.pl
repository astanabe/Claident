use strict;
use utf8;
use open ':encoding(utf8)';
use open ':std';
use Digest::MD5;
use File::Spec;

my $buildno = '0.9.x';

my $devnull = File::Spec->devnull();

print(STDERR <<"_END");
clmaketsv $buildno
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

# initialize variables
my $outputfile = $ARGV[-1];
# check output file
if (-e $outputfile) {
	&errorMessage(__LINE__, "Output file already exists.");
}
my @inputfiles;

{
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
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

print(STDERR "Calculating MD5...\n");

my %prefix;
my %filename;

for (my $i = 0; $i < scalar(@inputfiles); $i ++) {
	my $filename = $inputfiles[$i];
	$filename =~ s/^.+\///;
	$filename{$filename} = &calcAverageLength($inputfiles[$i]);;
	my $prefix = $filename;
	$prefix =~ s/\.(?:gz|bz2|xz)$//;
	$prefix =~ s/\.[^\.]+$//;
	$prefix =~ s/\.(?:forward|reverse)$//;
	my $fastqfile;
	unless (open($fastqfile, "< $inputfiles[$i]")) {
		&errorMessage(__LINE__, "Cannot read \"$inputfiles[$i]\".");
	}
	binmode($fastqfile);
	my $md5 = Digest::MD5->new->addfile(*$fastqfile)->hexdigest;
	close($fastqfile);
	$prefix{$prefix}{$filename} = $md5;
}

my @prefix = sort({$a cmp $b} keys(%prefix));
my @filename = keys(%filename);

print(STDERR "Generating tab-delimited text...\n");
my $filehandle;
unless (open($filehandle, "> $outputfile")) {
	&errorMessage(__LINE__, "Cannot make \"$outputfile\".");
}
print($filehandle "Submission Title\tCenter Name\tLab Name\tContact E-mail\tContact Name\tBioProject ID\tHold Until Date\n");
print($filehandle "<Submission Title>\t<Center Name e.g. FISHRA>\t<Lab Name e.g. Metagenomics Group, Research Center for Aquatic Genomics, National Research Institute of Fisheries Science, Fisheries Research Agency>\t<Your E-mail address>\t<Your Name>\t<BioProject ID>\tYYYY-MM-DD+00:00\n\n");
if (scalar(@prefix) < scalar(@filename)) {
	print($filehandle "Experiment Title\tExperiment Decription\tBioSample ID\tSample Name\tLibrary Name\tLibrary Strategy\tLibrary Source\tLibrary Selection\tLibrary Layout\tInsert Length\tTargeted Locus Name\tTargeted Locus Description\tPrimer Reference\tLibrary Construction Protocol\tSpot Length 1\tSpot Length 2\tPlatform\tInstrument Model\tRun Date\tRun Center\tFile Name 1\tMD5 Checksum 1");
	print($filehandle "\tFile Name 2\tMD5 Checksum 2\n");
}
elsif (scalar(@prefix) == scalar(@filename)) {
	print($filehandle "Experiment Title\tExperiment Decription\tBioSample ID\tSample Name\tLibrary Name\tLibrary Strategy\tLibrary Source\tLibrary Selection\tLibrary Layout\tTargeted Locus Name\tTargeted Locus Description\tPrimer Reference\tLibrary Construction Protocol\tSpot Length\tPlatform\tInstrument Model\tRun Date\tRun Center\tFile Name 1\tMD5 Checksum 1");
	print($filehandle "\n");
}
else {
	&errorMessage(__LINE__, "The input files are invalid.");
}
undef(@filename);

foreach my $prefix (@prefix) {
	@filename = sort({$a cmp $b} keys(%{$prefix{$prefix}}));
	if (scalar(@filename) == 1) {
		my $avglen = int($filename{$filename[0]} + 0.5);
		print($filehandle "$prefix\t<How DNA extrected?>\t<BioSample ID>\t<BioSample sample_name>\t$prefix\tAMPLICON\tMETAGENOMIC\tPCR\tSINGLE\t[16S rRNA,18S rRNA,RBCL,matK,COX1,ITS1-5.8S-ITS2,exome,other]\t<Locus Description e.g. ITS2 partial sequence>\t<Primer Reference PMID,PMCID,DOI e.g. PMID:22808280, PMCID:PMC3395698, DOI:10.1371/journal.pone.0040863>\t<How Library constructed?>\t$avglen\t[LS454,ILLUMINA,ION_TORRENT]\t[454 GS FLX,454 GS FLX+,454 GS FLX Titanium,454 GS Junior,Illumina HiSeq 1000,Illumina HiSeq 1500,Illumina HiSeq 2000,Illumina HiSeq 2500,Illumina MiSeq,Ion Torrent PGM]\tYYYY-MM-DDT00:00:00+00:00\t<Run Center Name e.g. FISHRA , Note that run center name need to be registered to DRA.>\t$filename[0]\t$prefix{$prefix}{$filename[0]}\n");
	}
	elsif (scalar(@filename) == 2) {
		my $favglen = int($filename{$filename[0]} + 0.5);
		my $ravglen = int($filename{$filename[1]} + 0.5);
		print($filehandle "$prefix\t<How DNA extrected?>\t<BioSample ID>\t<BioSample sample_name>\t$prefix\tAMPLICON\tMETAGENOMIC\tPCR\tPAIRED\t<Insert Length between Paired-Read>\t[16S rRNA,18S rRNA,RBCL,matK,COX1,ITS1-5.8S-ITS2,exome,other]\t<Locus Description e.g. ITS2 partial sequence>\t<Primer Reference PMID,PMCID,DOI e.g. PMID:22808280, PMCID:PMC3395698, DOI:10.1371/journal.pone.0040863>\t<How Library constructed?>\t$favglen\t$ravglen\t[LS454,ILLUMINA,ION_TORRENT]\t[454 GS FLX,454 GS FLX+,454 GS FLX Titanium,454 GS Junior,Illumina HiSeq 1000,Illumina HiSeq 1500,Illumina HiSeq 2000,Illumina HiSeq 2500,Illumina MiSeq,Ion Torrent PGM]\tYYYY-MM-DDT00:00:00+00:00\t<Run Center Name e.g. FISHRA , Note that run center name need to be registered to DRA.>\t$filename[0]\t$prefix{$prefix}{$filename[0]}\t$filename[1]\t$prefix{$prefix}{$filename[1]}\n");
	}
	else {
		&errorMessage(__LINE__, "The number of \"$prefix\" files are invalid.");
	}
	undef(@filename);
}
close($filehandle);
print(STDERR "done.\n\n");

sub calcAverageLength {
	my $filename = shift(@_);
	my $nseqs = 0;
	my $len = 0;
	my $seqfilehandle = &readFile($filename);
	my $tempnline = 1;
	$| = 1;
	$? = 0;
	while (<$seqfilehandle>) {
		s/\r?\n?$//;
		if ($tempnline % 4 == 1 && /^\@\S/) {
			undef;
		}
		elsif ($tempnline % 4 == 2) {
			s/[^a-zA-Z]//g;
			$len += length($_);
			$nseqs ++;
		}
		elsif ($tempnline % 4 == 3 && /^\+/) {
			undef;
		}
		elsif ($tempnline % 4 == 0) {
			undef;
		}
		else {
			&errorMessage(__LINE__, "Invalid FASTQ.\nFile: $filename\nLine: $tempnline");
		}
		$tempnline ++;
	}
	close($seqfilehandle);
	if ($nseqs == 0) {
		&errorMessage(__LINE__, "Invalid FASTQ.\nFile: $filename");
	}
	return($len / $nseqs);
}

sub readFile {
	my $filehandle;
	my $filename = shift(@_);
	if ($filename =~ /\.gz$/i) {
		unless (open($filehandle, "pigz -dc $filename 2> $devnull |")) {
			&errorMessage(__LINE__, "Cannot open \"$filename\".");
		}
	}
	elsif ($filename =~ /\.bz2$/i) {
		unless (open($filehandle, "lbzip2 -dc $filename 2> $devnull |")) {
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
clmaketsv options inputfile1 inputfile2 ... inputfileN outputfile

Acceptable input file formats
=============================
FASTQ (uncompressed, gzip-compressed, bzip2-compressed, or xz-compressed)
_END
	exit;
}
