use strict;
use utf8;
use open ':encoding(utf8)';
use open ':std';

my $buildno = '0.2.x';

print(STDERR <<"_END");
clmakexml $buildno
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

# initialize variables
my $submissionid = $ARGV[-1];
# check output file
if (-e "$submissionid.Submission.xml" || -e "$submissionid.Experiment.xml" || -e "$submissionid.Run.xml") {
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

my $submissionhandle;
my $experimenthandle;
my $runhandle;
unless (open($submissionhandle, "> $submissionid.Submission.xml")) {
	&errorMessage(__LINE__, "Cannot make \"$submissionid.Submission.xml\".");
}
print($submissionhandle "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n");
unless (open($experimenthandle, "> $submissionid.Experiment.xml")) {
	&errorMessage(__LINE__, "Cannot make \"$submissionid.Experiment.xml\".");
}
print($experimenthandle "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<EXPERIMENT_SET>\n");
unless (open($runhandle, "> $submissionid.Run.xml")) {
	&errorMessage(__LINE__, "Cannot make \"$submissionid.Run.xml\".");
}
print($runhandle "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<RUN_SET>\n");
my $submissiontitle;
my $centername;
my $labname;
my $contactemail;
my $contactname;
my $bioprojectid;
my $holduntildate;
my $sampleno = '0001';
foreach my $inputfile (@inputfiles) {
	my $tsvfile;
	unless (open($tsvfile, "< $inputfile")) {
		&errorMessage(__LINE__, "Cannot read \"$inputfile\".");
	}
	my $lineno = 1;
	while (<$tsvfile>) {
		s/\r?\n?$//;
		my @element = split(/\t/, $_);
		for (my $i = 0; $i < scalar(@element); $i ++) {
			$element[$i] =~ s/^\"//;
			$element[$i] =~ s/\"$//;
		}
		if ($lineno == 2 && !$submissiontitle) {
			($submissiontitle, $centername, $labname, $contactemail, $contactname, $bioprojectid, $holduntildate) = @element;
			print($submissionhandle "<SUBMISSION center_name=\"$centername\" alias=\"$submissionid\_Submission\" lab_name=\"$labname\">\n\t<TITLE>$submissiontitle</TITLE>\n\t<CONTACTS>\n\t\t<CONTACT inform_on_error=\"$contactemail\" inform_on_status=\"$contactemail\" name=\"$contactname\"/>\n\t</CONTACTS>\n\t<ACTIONS>\n\t\t<ACTION>\n\t\t\t<ADD schema=\"experiment\" source=\"$submissionid.Experiment.xml\"/>\n\t\t</ACTION>\n\t\t<ACTION>\n\t\t\t<ADD schema=\"run\" source=\"$submissionid.Run.xml\"/>\n\t\t</ACTION>\n\t\t<ACTION>\n\t\t\t<HOLD HoldUntilDate=\"$holduntildate\"/>\n\t\t</ACTION>\n\t</ACTIONS>\n</SUBMISSION>\n");
		}
		elsif ($lineno > 4) {
			my $experimenttitle;
			my $experimentdescription;
			my $biosampleid;
			my $biosamplename;
			my $libraryname;
			my $librarystrategy;
			my $librarysource;
			my $libraryselection;
			my $librarylayout;
			my $insertlength;
			my $targetedlocusname;
			my $targetedlocusdescription;
			my $primerreference;
			my $libraryconstructionprotocol;
			my $spotlength1;
			my $spotlength2;
			my $platform;
			my $instrumentmodel;
			my $rundate;
			my $runcenter;
			my $filename1;
			my $md5_1;
			my $filename2;
			my $md5_2;
			if (scalar(@element) == 24) {
				($experimenttitle, $experimentdescription, $biosampleid, $biosamplename, $libraryname, $librarystrategy, $librarysource, $libraryselection, $librarylayout, $insertlength, $targetedlocusname, $targetedlocusdescription, $primerreference, $libraryconstructionprotocol, $spotlength1, $spotlength2, $platform, $instrumentmodel, $rundate, $runcenter, $filename1, $md5_1, $filename2, $md5_2) = @element;
			}
			elsif (scalar(@element) == 20) {
				($experimenttitle, $experimentdescription, $biosampleid, $biosamplename, $libraryname, $librarystrategy, $librarysource, $libraryselection, $librarylayout, $targetedlocusname, $targetedlocusdescription, $primerreference, $libraryconstructionprotocol, $spotlength1, $platform, $instrumentmodel, $rundate, $runcenter, $filename1, $md5_1) = @element;
			}
			else {
				&errorMessage(__LINE__, "Line $lineno of the input file is invalid.");
			}
			my ($db, $id) = split(/:/, $primerreference);
			if ($db =~ /^pmid$/i) {
				$db = 'pubmed';
			}
			elsif ($db =~ /^pmcid$/i) {
				$db = 'pubmedcentral';
			}
			elsif ($db =~ /^doi$/i) {
				$db = 'doi';
			}
			if ($librarylayout =~ /^single$/i && $filename1 && $md5_1 && !$filename2 && !$md5_2) {
				$librarylayout = "\t\t\t\t\t<SINGLE/>";
			}
			elsif ($librarylayout =~ /^paired$/i && $filename1 && $md5_1 && $filename2 && $md5_2) {
				$librarylayout = "\t\t\t\t\t<PAIRED NOMINAL_LENGTH=\"$insertlength\"/>";
			}
			else {
				&errorMessage(__LINE__, "The input file is invalid.");
			}
			my $sampledescriptor;
			if ($biosampleid =~ /^SSUB/) {
				$sampledescriptor = "\t\t\t<SAMPLE_DESCRIPTOR>\n\t\t\t\t<IDENTIFIERS>\n\t\t\t\t\t<PRIMARY_ID label=\"BioSample Submission ID\">$biosampleid : $biosamplename</PRIMARY_ID>\n\t\t\t\t</IDENTIFIERS>\n\t\t\t</SAMPLE_DESCRIPTOR>";
			}
			else {
				$sampledescriptor = "\t\t\t<SAMPLE_DESCRIPTOR accession=\"$biosampleid\">\n\t\t\t\t<IDENTIFIERS>\n\t\t\t\t\t<PRIMARY_ID label=\"BioSample ID\">$biosampleid</PRIMARY_ID>\n\t\t\t\t</IDENTIFIERS>\n\t\t\t</SAMPLE_DESCRIPTOR>";
			}
			my $studyref;
			if ($bioprojectid =~ /^PSUB/) {
				$studyref = "\t\t<STUDY_REF>\n\t\t\t<IDENTIFIERS>\n\t\t\t\t<PRIMARY_ID label=\"BioProject Submission ID\">$bioprojectid</PRIMARY_ID>\n\t\t\t</IDENTIFIERS>\n\t\t</STUDY_REF>";
			}
			else {
				$studyref = "\t\t<STUDY_REF accession=\"$bioprojectid\">\n\t\t\t<IDENTIFIERS>\n\t\t\t\t<PRIMARY_ID label=\"BioProject ID\">$bioprojectid</PRIMARY_ID>\n\t\t\t</IDENTIFIERS>\n\t\t</STUDY_REF>";
			}
			print($experimenthandle "\t<EXPERIMENT center_name=\"$centername\" alias=\"$submissionid\_Experiment_$sampleno\">\n\t\t<TITLE>$experimenttitle</TITLE>\n$studyref\n\t\t<DESIGN>\n\t\t\t<DESIGN_DESCRIPTION>$experimentdescription</DESIGN_DESCRIPTION>\n$sampledescriptor\n");
			print($experimenthandle "\t\t\t<LIBRARY_DESCRIPTOR>\n\t\t\t\t<LIBRARY_NAME>$libraryname</LIBRARY_NAME>\n\t\t\t\t<LIBRARY_STRATEGY>$librarystrategy</LIBRARY_STRATEGY>\n\t\t\t\t<LIBRARY_SOURCE>$librarysource</LIBRARY_SOURCE>\n\t\t\t\t<LIBRARY_SELECTION>$libraryselection</LIBRARY_SELECTION>\n\t\t\t\t<LIBRARY_LAYOUT>\n$librarylayout\n\t\t\t\t</LIBRARY_LAYOUT>\n\t\t\t\t<TARGETED_LOCI>\n\t\t\t\t\t<LOCUS description=\"$targetedlocusdescription\" locus_name=\"$targetedlocusname\">\n\t\t\t\t\t\t<PROBE_SET>\n\t\t\t\t\t\t\t<DB>$db</DB>\n\t\t\t\t\t\t\t<ID>$id</ID>\n\t\t\t\t\t\t</PROBE_SET>\n\t\t\t\t\t</LOCUS>\n\t\t\t\t</TARGETED_LOCI>\n\t\t\t\t<LIBRARY_CONSTRUCTION_PROTOCOL>$libraryconstructionprotocol</LIBRARY_CONSTRUCTION_PROTOCOL>\n\t\t\t</LIBRARY_DESCRIPTOR>\n");
			print($experimenthandle "\t\t\t<SPOT_DESCRIPTOR>\n\t\t\t\t<SPOT_DECODE_SPEC>\n\t\t\t\t\t<SPOT_LENGTH>");
			if ($librarylayout =~ /single/i) {
				print($experimenthandle $spotlength1);
			}
			elsif ($librarylayout =~ /paired/i) {
				print($experimenthandle ($spotlength1 + $spotlength2));
			}
			else {
				&errorMessage(__LINE__, "The input file is invalid.");
			}
			print($experimenthandle "</SPOT_LENGTH>\n");
			if ($librarylayout =~ /single/i) {
				print($experimenthandle "\t\t\t\t\t<READ_SPEC>\n\t\t\t\t\t\t<READ_INDEX>0</READ_INDEX>\n\t\t\t\t\t\t<READ_CLASS>Application Read</READ_CLASS>\n\t\t\t\t\t\t<READ_TYPE>Forward</READ_TYPE>\n\t\t\t\t\t\t<BASE_COORD>1</BASE_COORD>\n\t\t\t\t\t</READ_SPEC>\n");
			}
			elsif ($librarylayout =~ /paired/i) {
				print($experimenthandle "\t\t\t\t\t<READ_SPEC>\n\t\t\t\t\t\t<READ_INDEX>0</READ_INDEX>\n\t\t\t\t\t\t<READ_LABEL>forward</READ_LABEL>\n\t\t\t\t\t\t<READ_CLASS>Application Read</READ_CLASS>\n\t\t\t\t\t\t<READ_TYPE>Forward</READ_TYPE>\n\t\t\t\t\t\t<BASE_COORD>1</BASE_COORD>\n\t\t\t\t\t</READ_SPEC>\n\t\t\t\t\t<READ_SPEC>\n\t\t\t\t\t\t<READ_INDEX>1</READ_INDEX>\n\t\t\t\t\t\t<READ_LABEL>reverse</READ_LABEL>\n\t\t\t\t\t\t<READ_CLASS>Application Read</READ_CLASS>\n\t\t\t\t\t\t<READ_TYPE>Reverse</READ_TYPE>\n\t\t\t\t\t\t<BASE_COORD>" . ($spotlength1 + 1) . "</BASE_COORD>\n\t\t\t\t\t</READ_SPEC>\n");
			}
			else {
				&errorMessage(__LINE__, "The input file is invalid.");
			}
			print($experimenthandle "\t\t\t\t</SPOT_DECODE_SPEC>\n\t\t\t</SPOT_DESCRIPTOR>\n");
			print($experimenthandle "\t\t</DESIGN>\n\t\t<PLATFORM>\n\t\t\t<$platform>\n\t\t\t\t<INSTRUMENT_MODEL>$instrumentmodel</INSTRUMENT_MODEL>\n\t\t\t</$platform>\n\t\t</PLATFORM>\n\t</EXPERIMENT>\n");
			print($runhandle "\t<RUN center_name=\"$centername\" alias=\"$submissionid\_Run_$sampleno\" run_center=\"$runcenter\" run_date=\"$rundate\">\n\t\t<TITLE>$experimenttitle</TITLE>\n\t\t<EXPERIMENT_REF refcenter=\"$centername\" refname=\"$submissionid\_Experiment_$sampleno\"/>\n\t\t<DATA_BLOCK>\n\t\t\t<FILES>\n");
			if ($librarylayout =~ /single/i) {
				print($runhandle "\t\t\t\t<FILE checksum=\"$md5_1\" checksum_method=\"MD5\" filetype=\"generic_fastq\" filename=\"$filename1\"/>\n\t\t\t</FILES>\n");
			}
			elsif ($librarylayout =~ /paired/i) {
				print($runhandle "\t\t\t\t<FILE checksum=\"$md5_1\" checksum_method=\"MD5\" filetype=\"generic_fastq\" filename=\"$filename1\"/>\n\t\t\t\t<FILE checksum=\"$md5_2\" checksum_method=\"MD5\" filetype=\"generic_fastq\" filename=\"$filename2\"/>\n\t\t\t</FILES>\n");
			}
			else {
				&errorMessage(__LINE__, "The input file is invalid.");
			}
			print($runhandle "\t\t</DATA_BLOCK>\n\t</RUN>\n");
			$sampleno ++;
			$sampleno = sprintf("%04d", $sampleno);
		}
		$lineno ++;
	}
	close($tsvfile);
}
close($submissionhandle);
print($experimenthandle "</EXPERIMENT_SET>\n");
close($experimenthandle);
print($runhandle "</RUN_SET>\n");
close($runhandle);

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
clmakexml inputfile1 inputfile2 ... inputfileN submissionID

Acceptable input file formats
=============================
clmaketsv tab-delimited text
_END
	exit;
}
