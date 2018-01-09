#!/usr/bin/perl
#
# Normalization script
#
# Gwenole Lecorve
# June, 2011
#

use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/../../lib";
use CorpusNormalisationFr;
use Encode;
use Getopt::Long;
use File::Basename;
use strict;


my $RSRC = dirname( abs_path(__FILE__) )."/../../rsrc/fr";
my $WIKTIONARY_WORD_POS = "$RSRC/word_pos.lst";
my $LEXIQUE_FILE = "$RSRC/lexicon_fr";

my $HELP=0;
my $OUTPUT;
my $INPUT_EXTENSION;
my $OUTPUT_EXTENSION;
my $VERBOSE=0;

$|++; #autoflush

#
# Process command line
#
Getopt::Long::config("no_ignore_case");
GetOptions(
	"help|h" => \$HELP,
	"output|o=s" => \$OUTPUT,
	"input-extension|e=s" => \$INPUT_EXTENSION,
	"output-extension|E=s" => \$OUTPUT_EXTENSION,
	"verbose|v" => \$VERBOSE
)
or usage();

(@ARGV == 1) or usage();
if ($HELP == 1) { usage(); }

###########################################

# open the input files
my @FILES = ();
my $INPUT = shift;

if (-d $INPUT) {
	opendir(DIR, $INPUT);
	if ($INPUT_EXTENSION) {
		foreach $_ (sort(grep {-f "$INPUT/$_" && /\.${INPUT_EXTENSION}$/ && ! /^\.{1,2}$/} readdir(DIR))) {
			push(@FILES, "$INPUT/$_");
		}
	}
	else {
		foreach $_ (sort(grep {-f "$INPUT/$_" && ! /^\.{1,2}$/} readdir(DIR))) {
			push(@FILES, "$INPUT/$_");
		}
	}
	closedir(DIR);
}
else {
	push(@FILES, $INPUT);
}

# Make output file empty
if (-f $OUTPUT) {
		open(O, "> $OUTPUT") or die("Could not open file $OUTPUT");
		close(O);
}

###########################################

load_pos($WIKTIONARY_WORD_POS);
load_lexicon($LEXIQUE_FILE);

# open the input file
foreach my $f (@FILES) {
	$VERBOSE && print STDERR "Reading $f...\n";
	my $TEXT = "";
	open(INPUT, "< $f") or die("Unable to open file $f.\n");
	while(<INPUT>) {
		$TEXT .= $_;
	}
	close(INPUT);

	my $weak_punc = "[,;:¡¿\(\)]";

	my $STEP = 0;

	#############################################################
	# particularités
	#############################################################

	$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." --Preliminary special processes.";
		remove_bugs(\$TEXT);
	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/special.rules");
	$VERBOSE && print STDERR ".";
		triple_lettre(\$TEXT);
	$VERBOSE && print STDERR ".";
		compact_initials(\$TEXT);
	$VERBOSE && print STDERR ".\n";
	$TEXT =~ s/($weak_punc) / $1 /mg;

	$TEXT =~ s/([a-z]) - ([A-Za-z])/$1\n$2/mg;
	$TEXT =~ s/ \(/ ( /mg;
	$TEXT =~ s/(\b)(«|»|")/ $1 $2 /mg; #take care with unicode characters, do not use [ab] but (a|b)
	$TEXT =~ s/(«|»|")(\n|\b)/ $1 $2 /mg;
		trim_blanks(\$TEXT);

	#############################################################

	$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Transformation to a French-compliant form.";
		$TEXT = remove_diacritics($TEXT);
		define_rule_preprocessing("perl ".dirname( abs_path(__FILE__) )."/remove-diacritics.pl");
	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/hesitations.rules");
	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/case-accent.rules");
	$VERBOSE && print STDERR ".";
		$TEXT = first_letter($TEXT);
	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/accent-no_case.rules");
	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/misspellings.rules", "$RSRC/alternative_spellings.rules", "$RSRC/alternative_forms.rules");
	$VERBOSE && print STDERR ".\n";

	#############################################################
	$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Expansion and tagging.";
		apply_rules(\$TEXT, "$RSRC/abbreviations.rules");
		complex_abbreviations(\$TEXT);
	$VERBOSE && print STDERR ".";
		url(\$TEXT);
		$TEXT =~ s/_/ /mg;
		date_and_time(\$TEXT);
	$VERBOSE && print STDERR ".";
		currencies(\$TEXT);
	$VERBOSE && print STDERR ".";
		units(\$TEXT);
	$VERBOSE && print STDERR ".";
		telephone(\$TEXT);
	$VERBOSE && print STDERR ".\n";

	###################################################

	$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Proper names processing.";
	# 	apply_rules(\$TEXT, "$RSRC/propername-apostrophe-removal.wikipedia.rules", "$RSRC/propername-apostrophe-blanking.wikipedia.rules");
	# $VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/propername-hyphen-remove.rules", "$RSRC/propername-hyphen-add.rules");
	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/propername-case.rules", "$RSRC/propername-disambig.rules");
	$VERBOSE && print STDERR ".";
		split_entities(\$TEXT,"$RSRC/countries.lst");
		split_entities(\$TEXT,"$RSRC/cities.lst");
		split_entities(\$TEXT,"$RSRC/planets.lst");
	$VERBOSE && print STDERR ".";
		$TEXT =~ s/( | )+/ /gm;
		$TEXT =~ s/ $//gm;
		$TEXT =~ s/^ //gm;

	if ($OUTPUT && -f $OUTPUT) {
		open(O, ">> $OUTPUT") or die("Could not open file $OUTPUT .\n");
		print O $TEXT;
		close(O);
	}
	elsif ($OUTPUT && -d $OUTPUT) {
		my $bn = File::Spec->abs2rel($f, $INPUT);
		if ($OUTPUT_EXTENSION) {
			if ($INPUT_EXTENSION) {
				$bn =~ s/\.$INPUT_EXTENSION$/\.$OUTPUT_EXTENSION/;
			}
			else {
				$bn = "$bn.$OUTPUT_EXTENSION";
			}
		}
		open(O, "> $OUTPUT/$bn") or die("Unable to open $f .\n");
		print O $TEXT;
		close(O);
	}
	if (@FILES > 0 && (!defined($OUTPUT) || -f $OUTPUT)) {
		print STDOUT $TEXT;
		print STDOUT "\n";
	}

}

#############################################################
# USAGE
#############################################################



sub usage {
	warn <<EOF;
Usage:
    start-generic-normalization.pl [options] <input>

Synopsis:
    Normalize the content of the input file.
    The result is returned in STDOUT.

Options:
    -h, --help
                 Print this help ;-)
		-o, --output=file|directory
                 Output file or directory instead of STDOUT
    -v, --verbose
                 Verbose
EOF
	exit 0;
}

#e#o#f#
