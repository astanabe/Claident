use strict;
use warnings;
use Fcntl ':flock';
use File::Spec;

my $buildno = '0.9.x';

# options
my $clsplitseqoption;
my $reversecomplement;
my $tagfile;
my $reversetagfile;
my $replacefile;
my $append;
my $numthreads = 1;

# Input/Output
my @inputfiles;
my $outputfolder;

# other variables
my $devnull = File::Spec->devnull();
my $inputtype;
my $runname;
my %name2tag;
my %tag2name;

# file handles
my $filehandleinput1;
my $filehandleinput2;

&main();

sub main {
	# print startup messages
	&printStartupMessage();
	# get command line arguments
	&getOptions();
	# check variable consistency
	&checkVariables();
	# read tags
	&readTags();
	# execute clsplitseq
	&executeClsplitseq();
}

sub printStartupMessage {
	print(STDERR <<"_END");
cltruncprimer $buildno
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
	$outputfolder = $ARGV[-1];
	my %inputfiles;
	for (my $i = 0; $i < scalar(@ARGV) - 1; $i ++) {
		if ($ARGV[$i] =~ /^-+compress=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:g|gz|gzip|b|bz|bz2|bzip|bzip2|x|xz|disable|d|no|n|false|f)$/i) {
				$clsplitseqoption .= " $ARGV[$i]";
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:seq|sequence)namestyle=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:i|illumina|o|other|nochange)$/i) {
				$clsplitseqoption .= " $ARGV[$i]";
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?(?:r|rate|p|percentage)mismatch=(.+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+max(?:imum)?n(?:um)?mismatch=(.+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+primername=(.+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+(?:5prime|forward|f)?(?:primer|primerfile|p)=(.+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)max(?:imum)?(?:r|rate|p|percentage)mismatch=(.+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)max(?:imum)?n(?:um)?mismatch=(.+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+(?:3prime|reverse|rev|r)(?:primer|primerfile)=(.+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+need(?:3prime|reverse|rev|r)primer$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+(?:reversecomplement|revcomp)$/i) {
			$reversecomplement = 1;
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+(?:elim|eliminate)primer=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t|disable|d|no|n|false|f)$/i) {
				$clsplitseqoption .= " $ARGV[$i]";
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+(?:trunc|truncate)N=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t|disable|d|no|n|false|f)$/i) {
				$clsplitseqoption .= " $ARGV[$i]";
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+useNasUMI=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t|disable|d|no|n|false|f|\d+)$/i) {
				$clsplitseqoption .= " $ARGV[$i]";
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
		}
		elsif ($ARGV[$i] =~ /^-+addUMI=(.+)$/i) {
			my $value = $1;
			if ($value =~ /^(?:enable|e|yes|y|true|t|disable|d|no|n|false|f)$/i) {
				$clsplitseqoption .= " $ARGV[$i]";
			}
			else {
				&errorMessage(__LINE__, "\"$ARGV[$i]\" is invalid option.");
			}
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
		elsif ($ARGV[$i] =~ /^-+(?:tag|index)namereplace=(.+)$/i) {
			$replacefile = $1;
		}
		elsif ($ARGV[$i] =~ /^-+min(?:imum)?qual(?:ity)?tag=(\d+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+g(?:ap)?o(?:pen)?(?:score)?=(-?\d+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+g(?:ap)?e(?:xtension)?(?:score)?=(-?\d+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+m(?:is)?m(?:atch)?(?:score)?=(-?\d+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+m(?:atch)?(?:score)?=(-?\d+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+endgap=(nobody|match|mismatch|gap)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+(?:a|append)$/i) {
			$append = 1;
		}
		elsif ($ARGV[$i] =~ /^-+runname=(.+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
		}
		elsif ($ARGV[$i] =~ /^-+(?:n|n(?:um)?threads?)=(\d+)$/i) {
			$clsplitseqoption .= " $ARGV[$i]";
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
	if (!@inputfiles) {
		&errorMessage(__LINE__, "No input file was specified.");
	}
	{
		my @newinputfiles;
		my @tempinputfiles;
		my $paired = 0;
		my $unpaired = 0;
		foreach my $inputfile (@inputfiles) {
			if (-d $inputfile) {
				my @temp = sort(glob("$inputfile/*.fastq"), glob("$inputfile/*.fastq.gz"), glob("$inputfile/*.fastq.bz2"), glob("$inputfile/*.fastq.xz"));
				if (scalar(@temp) % 2 == 0) {
					for (my $i = 0; $i < scalar(@temp); $i += 2) {
						if (-e $temp[$i] && -e $temp[($i + 1)]) {
							my ($tempf, $tempr) = ($temp[$i], $temp[($i + 1)]);
							$tempf =~ s/\.forward\..*$//;
							$tempr =~ s/\.reverse\..*$//;
							if ($tempf eq $tempr) {
								$paired ++;
							}
							else {
								($tempf, $tempr) = ($temp[$i], $temp[($i + 1)]);
								$tempf =~ s/_R1_.*$//;
								$tempr =~ s/_R2_.*$//;
								if ($tempf eq $tempr) {
									$paired ++;
								}
								else {
									$unpaired ++;
								}
							}
							push(@newinputfiles, $temp[$i], $temp[($i + 1)]);
						}
						else {
							&errorMessage(__LINE__, "The input files \"$temp[$i]\" and \"" . $temp[($i + 1)] . "\" are invalid.");
						}
					}
				}
				else {
					$unpaired ++;
					push(@newinputfiles, @temp);
				}
			}
			elsif (-e $inputfile) {
				push(@tempinputfiles, $inputfile);
			}
			else {
				&errorMessage(__LINE__, "The input file \"$inputfile\" is invalid.");
			}
		}
		if (scalar(@tempinputfiles) % 2 == 0) {
			for (my $i = 0; $i < scalar(@tempinputfiles); $i += 2) {
				if (-e $tempinputfiles[$i] && -e $tempinputfiles[($i + 1)]) {
					my ($tempf, $tempr) = ($tempinputfiles[$i], $tempinputfiles[($i + 1)]);
					$tempf =~ s/\.forward\..*$//;
					$tempr =~ s/\.reverse\..*$//;
					if ($tempf eq $tempr) {
						$paired ++;
					}
					else {
						($tempf, $tempr) = ($tempinputfiles[$i], $tempinputfiles[($i + 1)]);
						$tempf =~ s/_R1_.*$//;
						$tempr =~ s/_R2_.*$//;
						if ($tempf eq $tempr) {
							$paired ++;
						}
						else {
							$unpaired ++;
						}
					}
					push(@newinputfiles, $tempinputfiles[$i], $tempinputfiles[($i + 1)]);
				}
				else {
					&errorMessage(__LINE__, "The input files \"$tempinputfiles[$i]\" and \"" . $tempinputfiles[($i + 1)] . "\" are invalid.");
				}
			}
		}
		else {
			$unpaired ++;
			push(@newinputfiles, @tempinputfiles);
		}
		if ($paired > 0 && $unpaired == 0) {
			$inputtype = 'paired-end';
			@inputfiles = @newinputfiles;
		}
		elsif ($paired == 0 && $unpaired > 0) {
			$inputtype = 'single-end';
			@inputfiles = @newinputfiles;
		}
		else {
			&errorMessage(__LINE__, "Both paired-end sequences and single-end sequences are given.");
		}
	}
	if ($inputtype eq 'paired-end') {
		print(STDERR "The input files will be treated as paired-end sequences.\n");
	}
	elsif ($inputtype eq 'single-end') {
		print(STDERR "The input files will be treated as single-end sequences.\n");
	}
	if (-e $outputfolder && !$append) {
		&errorMessage(__LINE__, "\"$outputfolder\" already exists.");
	}
	elsif (!mkdir($outputfolder)) {
		&errorMessage(__LINE__, 'Cannot make output folder.');
	}
	if ($tagfile && !-e $tagfile) {
		&errorMessage(__LINE__, "\"$tagfile\" does not exist.");
	}
	if ($reversetagfile && !-e $reversetagfile) {
		&errorMessage(__LINE__, "\"$reversetagfile\" does not exist.");
	}
	if ($reversetagfile && $clsplitseqoption =~ /-+(?:3prime|reverse|rev|r)(?:primer|primerfile)=/i) {
		$clsplitseqoption .= ' --needreverseprimer';
	}
	if (!$tagfile && !$reversetagfile) {
		&errorMessage(__LINE__, "Both tag/index file is not given.");
	}
	if ($runname =~ /__/) {
		&errorMessage(__LINE__, "\"$runname\" is invalid name. Do not use \"__\" in run name.");
	}
	if ($runname =~ /\s/) {
		&errorMessage(__LINE__, "\"$runname\" is invalid name. Do not use spaces or tabs in run name.");
	}
}

sub readTags {
	my $taglength;
	my $reversetaglength;
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
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.*)/s) {
				my $name = $1;
				my $tag = uc($2);
				$name =~ s/\s+$//;
				if ($tag) {
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
						if ($line =~ /^>?\s*(\S[^\r\n]*)\r?\n(.*)\r?\n?/s) {
							my $reversetag = uc($2);
							$reversetag =~ s/[^A-Z]//sg;
							if ($reversetag) {
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
								$tag .= '+' . $reversetag;
							}
						}
					}
					if (exists($tag2name{$tag})) {
						&errorMessage(__LINE__, "Tag \"$tag ($name)\" is doubly used in \"$tagfile\".");
					}
					if (exists($name2tag{$name})) {
						&errorMessage(__LINE__, "Name \"$name ($tag)\" is doubly used in \"$tagfile\".");
					}
					else {
						$tag2name{$tag} = $name;
						$name2tag{$name} = $tag;
						push(@tag, $tag);
					}
				}
			}
		}
		close($filehandleinput1);
		if ($reversetagfile) {
			close($filehandleinput2);
		}
		print(STDERR "Tag sequences\n");
		foreach (@tag) {
			print(STDERR $tag2name{$_} . " : " . $_ . "\n");
		}
	}
	elsif (!$tagfile && $reversetagfile) {
		my @reversetag;
		unless (open($filehandleinput1, "< $reversetagfile")) {
			&errorMessage(__LINE__, "Cannot open \"$reversetagfile\".");
		}
		local $/ = "\n>";
		while (<$filehandleinput1>) {
			if (/^>?\s*(\S[^\r\n]*)\r?\n(.*)/s) {
				my $name = $1;
				my $reversetag = uc($2);
				$name =~ s/\s+$//;
				if ($reversetag) {
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
					if (exists($tag2name{$reversetag})) {
						&errorMessage(__LINE__, "Tag \"$reversetag ($name)\" is doubly used in \"$tagfile\".");
					}
					else {
						$tag2name{$reversetag} = $name;
						$name2tag{$name} = $reversetag;
						push(@reversetag, $reversetag);
					}
				}
			}
		}
		close($filehandleinput1);
		print(STDERR "Reverse tag sequences\n");
		foreach (@reversetag) {
			print(STDERR $tag2name{$_} . " : " . $_ . "\n");
		}
	}
	if ($tagfile || $reversetagfile) {
		print(STDERR "done.\n\n");
	}
}

sub executeClsplitseq {
	print(STDERR "Execute clsplitseq...\n");
	
	print(STDERR "done.\n\n");
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
cltruncprimer options inputfolder outputfolder
cltruncprimer options inputfile1 inputfile2 ... inputfileN outputfolder

Command line options
====================
--runname=RUNNAME
  Specify run name. This is mandatory. (default: none)

--tagnamereplace=FILENAME
  Specify tag name replace list file name. (default:none)

--indexnamereplace=FILENAME
  Specify index name replace list file name. (default:none)

--seqnamestyle=ILLUMINA|OTHER|NOCHANGE
  Specify sequence name style. (default:ILLUMINA)

--primername=PRIMERNAME
  Specify primer name. (default: none)

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
