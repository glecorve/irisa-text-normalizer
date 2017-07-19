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
use CorpusNormalisationEn;
use Getopt::Long;
use File::Basename;
use POSIX qw(strftime locale_h);
use locale;
setlocale(LC_CTYPE, "UTF8");
setlocale(LC_COLLATE, "UTF8");
use strict;

my $RSRC = dirname( abs_path(__FILE__) )."/../../rsrc/en";
my $WIKTIONARY_WORD_POS = "$RSRC/word_pos.lst";
my $LEXIQUE_FILE = "$RSRC/lexicon_en";

my $HELP=0;
my $VERBOSE=0;
my $ESTER=0;
my $KEEP_PARA = 0;
my $KEEP_PUNC = 0;

$|++; #autoflush

#
# Process command line
#
Getopt::Long::config("no_ignore_case");
GetOptions(
	"ester|e" => \$ESTER,
	"help|h" => \$HELP,
	"keep-par|P" => \$KEEP_PARA,
	"keep-punc|p" => \$KEEP_PUNC,
	"verbose|v" => \$VERBOSE,
)
or usage();


(@ARGV == 1) or usage();
if ($HELP == 1) { usage(); }



# open the input file
my $f = shift;
my $TEXT = "";
open(INPUT, "< $f") or die("Unable to open file $f.\n");
while(<INPUT>) {
	$TEXT .= $_;
}
close(INPUT);

my $weak_punc = "[,;:¡¿\(\)]";




load_pos($WIKTIONARY_WORD_POS);
load_lexicon($LEXIQUE_FILE);
my $STEP = 0;
#  	$TEXT =~ s/($weak_punc) / $1 /mg;
#  	$TEXT =~ s/ \(/ ( /mg;
# 	trim_blanks(\$TEXT);
# 	acronyms(\$TEXT);
#	date_and_time(\$TEXT);
#	units(\$TEXT);
# 	tag_ne(\$TEXT);
#	apostrophes(\$TEXT);
#  	print $TEXT."\n";
#  	exit;


#106
 		
#############################################################
# particularités
#############################################################

$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." --Preliminary special processes.";
	remove_bugs(\$TEXT);
	#137
$VERBOSE && print STDERR ".";
	process_ing(\$TEXT);
$VERBOSE && print STDERR ".";
	process_d(\$TEXT);
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

#143.945

#############################################################
$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Transformation to an English-compliant form.";
	$TEXT = remove_diacritics($TEXT);
	define_rule_preprocessing("perl ".dirname( abs_path(__FILE__) )."/remove-diacritics.pl");
$VERBOSE && print STDERR ".";
	apply_rules(\$TEXT, "$RSRC/hesitations.rules");
$VERBOSE && print STDERR ".";
	$TEXT = first_letter($TEXT);
$VERBOSE && print STDERR ".";
	apply_rules(\$TEXT, "$RSRC/misspellings.wiktionary.rules", "$RSRC/alternative_spellings.wiktionary.rules", "$RSRC/alternative_forms.wiktionary.rules");
	apply_rules(\$TEXT, "$RSRC/uk2us.rules");
$VERBOSE && print STDERR ".\n";

#183


  	
#############################################################
$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Expansion and tagging.";
	apply_rules(\$TEXT, "$RSRC/abbreviations.rules");
	complex_abbreviations(\$TEXT);
$VERBOSE && print STDERR ".";
	url(\$TEXT);
	$TEXT =~ s/_/ /mg;
	date_and_time(\$TEXT);
$VERBOSE && print STDERR ".";
# #271
	currencies(\$TEXT);
$VERBOSE && print STDERR ".";
	units(\$TEXT);
$VERBOSE && print STDERR ".";
	telephone(\$TEXT);
$VERBOSE && print STDERR ".\n";

#342






  	
#############################################################
$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Proper names processing.";
	apply_rules(\$TEXT, "$RSRC/propername-apostrophe-removal.wikipedia.rules", "$RSRC/propername-apostrophe-blanking.wikipedia.rules");
$VERBOSE && print STDERR ".";
	apply_rules(\$TEXT, "$RSRC/propername-hyphen-removal.wikipedia.rules", "$RSRC/propername-hyphen-blanking.wikipedia.rules");
$VERBOSE && print STDERR ".";
	apply_rules(\$TEXT, "$RSRC/propername-recasing.wikipedia.rules", "$RSRC/propername-word-splitting.wikipedia.rules", "$RSRC/propername-disambig.rules");
$VERBOSE && print STDERR ".";
	split_entities(\$TEXT,"$RSRC/countries.lst");
	split_entities(\$TEXT,"$RSRC/cities.lst");
	split_entities(\$TEXT,"$RSRC/planets.lst");
$VERBOSE && print STDERR ".";
	$TEXT =~ s/( | )+/ /gm;
	$TEXT =~ s/ $//gm;
	$TEXT =~ s/^ //gm;
	#tag_ne(\$TEXT); # Named entity tagging using Stanford's tagger

print $TEXT;
print STDERR "\n";


#############################################################
# USAGE
#############################################################



sub usage {
	warn <<EOF;
Usage:
    normalize-text.pl [options] <input>

Synopsis:
    Normalize the content of the input file.
    The result is returned in STDOUT.

Options:
    -h, --help
                 Print this help ;-)
    -v, --verbose
                 Verbose
EOF
	exit 0;
}

#e#o#f#


