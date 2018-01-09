#!/usr/bin/perl
#
# Normalization script
#
# Gwenole Lecorve
# June, 2011
#

use Cwd 'abs_path';
use File::Basename;
use File::Spec qw/abs2rel/;
use lib dirname( abs_path(__FILE__) )."/../../lib";
use CorpusNormalisationFr;
use Getopt::Long;
use File::Basename;
# use utf8;
# use POSIX qw(strftime locale_h);
# use locale;
# setlocale(LC_CTYPE, "UTF8");
# setlocale(LC_COLLATE, "UTF8");
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

my $weak_punc = '(?:,|;|:|\(|\)|¡|¿)';

load_pos($WIKTIONARY_WORD_POS);
load_lexicon($LEXIQUE_FILE);

foreach my $f (@FILES) {
	$VERBOSE && print STDERR "Reading $f...\n";
	my $TEXT = "";
	open(INPUT, "< $f") or die("Unable to open file $f.\n");
	while(<INPUT>) {
		$TEXT .= $_;
	}
	close(INPUT);

	my $STEP = 0;

		tag_ne(\$TEXT);
	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/case-special.rules");

	$VERBOSE && print STDERR ".\n";

	#395/371

	#############################################################
	$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Hyphenation and processing of apostrophes for all the words";
		apply_rules(\$TEXT, "$RSRC/hyphenation-remove.rules", "$RSRC/hyphenation-add.rules", "$RSRC/hyphenation-general.rules", "$RSRC/hyphenation-latin_locutions.rules");
	$VERBOSE && print STDERR ".";
		hyphenate(\$TEXT);
	$VERBOSE && print STDERR ".";
		apostrophes(\$TEXT);
		apply_rules(\$TEXT, "$RSRC/apostrophes.rules");
	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/case-accent.rules");
	$VERBOSE && print STDERR ".\n";
	  $TEXT = first_letter($TEXT);
	$VERBOSE && print STDERR ".\n";



	#############################################################
	$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Processing uppercase words.";
		apply_rules(\$TEXT, "$RSRC/roman_numbers.rules");
		roman_numbers(\$TEXT);
	$VERBOSE && print STDERR ".";
		acronyms(\$TEXT);
		apply_rules(\$TEXT, "$RSRC/acronyms.rules");
	$VERBOSE && print STDERR ".\n";


	$TEXT =~ s/ +/ /gm;
	$TEXT =~ s/^ //gm;
	$TEXT =~ s/ $//gm;


	#############################################################
	$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Conversion of digits into letters.";
		numbers(\$TEXT);

	$VERBOSE && print STDERR ".\n";


	#$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Modification de la casse.\n";
	#	apply_rules(\$TEXT, "$RSRC/majuscule_unigrammes.rules");
	#	apply_rules(\$TEXT, "$RSRC/majuscule_bigrammes.rules");
	$VERBOSE && print STDERR ".\n";

	#############################################################
	#   $TEXT =~ s/_/ /gm; #remove previous multiwords
	#	apply_rules(\$TEXT, "$RSRC/multiwords.rules");
	#$VERBOSE && print STDERR ".\n";


	#############################################################
	# One sentence per line + removal of all punctuation signs
	#############################################################
	$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Final processings.";

		$TEXT = remove_diacritics($TEXT);


	$VERBOSE && print STDERR ".";
		apply_rules(\$TEXT, "$RSRC/final.rules");
	$VERBOSE && print STDERR ".";
		end(\$TEXT);
	$VERBOSE && print STDERR ".";

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
    normalize-text.pl [options] <input>

Synopsis:
    Normalize the content of the input file or input directory.
    The result is returned in STDOUT or to the output provided as an option.

Options:
    -h, --help
                 Print this help ;-)
	  -o, --output=file|directory
		             Output text to the given file or directory.
    -v, --verbose
                 Verbose
EOF
	exit 0;
}

#e#o#f#
