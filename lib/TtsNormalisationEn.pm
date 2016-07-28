#!/usr/bin/perl
#
# Normalization script
#
# Gwenole Lecorve
# June, 2011
# Damien Lolive
# April 2016

package TtsNormalisationEn;

use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/.";
use CorpusNormalisationEn;

use POSIX qw(strftime locale_h);
use locale;
setlocale(LC_CTYPE, "UTF8");
setlocale(LC_COLLATE, "UTF8");
use strict;

my $RSRC = dirname( abs_path(__FILE__) )."/../rsrc/en";
my $WIKTIONARY_WORD_POS = "$RSRC/word_pos.lst";
my $LEXIQUE_FILE = "$RSRC/lexicon_en";

$|++; #autoflush

sub load_rules_en()
{
    CorpusNormalisationEn::load_rules("SPECIAL", "$RSRC/special.rules");
    CorpusNormalisationEn::load_rules("HESITATIONS", "$RSRC/hesitations.rules");
    CorpusNormalisationEn::load_rules("MISSPELL", "$RSRC/misspellings.wiktionary.rules", "$RSRC/alternative_spellings.wiktionary.rules", "$RSRC/alternative_forms.wiktionary.rules");
    CorpusNormalisationEn::load_rules("UK2US", "$RSRC/uk2us.rules");
    CorpusNormalisationEn::load_rules("ABBRV", "$RSRC/abbreviations.rules");

    CorpusNormalisationEn::load_rules("PROPER1", "$RSRC/propername-apostrophe-removal.wikipedia.rules", "$RSRC/propername-apostrophe-blanking.wikipedia.rules");
    CorpusNormalisationEn::load_rules("PROPER2", "$RSRC/propername-hyphen-removal.wikipedia.rules", "$RSRC/propername-hyphen-blanking.wikipedia.rules");
    CorpusNormalisationEn::load_rules("PROPER3", "$RSRC/propername-recasing.wikipedia.rules", "$RSRC/propername-word-splitting.wikipedia.rules", "$RSRC/propername-disambig.rules");
    CorpusNormalisationEn::load_rules("CASE", "$RSRC/case.rules");
    CorpusNormalisationEn::load_rules("HYPHEN", "$RSRC/hyphen.wikipedia.rules", "$RSRC/hyphen_latin_locutions.rules");
    CorpusNormalisationEn::load_rules("APOST", "$RSRC/apostrophes.rules");
    CorpusNormalisationEn::load_rules("ROMAN_NUM", "$RSRC/roman_numbers.rules");
    CorpusNormalisationEn::load_rules("ACRONYMS", "$RSRC/acronyms.rules");
    #	CorpusNormalisationEn::load_rules("MAJ_UNIGRAM", "$RSRC/majuscule_unigrammes.rules");
    #	CorpusNormalisationEn::load_rules("MAJ_BIGRAM", "$RSRC/majuscule_bigrammes.rules");
    #   CorpusNormalisationEn::load_rules("MULTIWORD", "$RSRC/multiwords.rules");
    CorpusNormalisationEn::load_rules("FINAL", "$RSRC/final.rules");    
}

sub init_norm_en()
{
    load_pos($WIKTIONARY_WORD_POS);
    load_lexicon($LEXIQUE_FILE);
    load_rules_en();
    CorpusNormalisationEn::init();
}


sub process_norm_en($$$$$)
{
    my $TEXT = shift;
    my $KEEP_PARA = shift;
    my $KEEP_PUNC = shift;
    my $ESTER = shift;
    my $VERBOSE = shift;
    #$VERBOSE = 1;
    my $weak_punc = "[\",;:¡¿\(\)]";
    my $STEP = 0;


    #############################################################
    # particularités
    #############################################################    
    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." --Preliminary special processes.";
    remove_bugs(\$TEXT);
    #137
    process_ing(\$TEXT);
    process_d(\$TEXT);
    apply_rules(\$TEXT, "SPECIAL");
    triple_lettre(\$TEXT);
    compact_initials(\$TEXT);
    $TEXT =~ s/($weak_punc) / $1 /mg;
    $TEXT =~ s/([a-z]) - ([A-Za-z])/$1\n$2/mg;
    $TEXT =~ s/ \(/ ( /mg;
    $TEXT =~ s/(\b)(«|»|")/ $1 $2 /mg; #take care with unicode characters, do not use [ab] but (a|b)
    $TEXT =~ s/(«|»|")(\n|\b)/ $1 $2 /mg;
    trim_blanks(\$TEXT);

    #143.945

    #############################################################
    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Transformation to an English compliant form.";
    $TEXT = remove_diacritics($TEXT);
    define_rule_preprocessing("perl ".dirname( abs_path(__FILE__) )."/../bin/fr/remove-diacritics.pl");
    apply_rules(\$TEXT, "HESITATIONS");
    $TEXT = first_letter($TEXT);
    apply_rules(\$TEXT, "MISSPELL");
    apply_rules(\$TEXT, "UK2US");

    #183
    
    
    #############################################################
    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Expansion and tagging.";
    apply_rules(\$TEXT, "ABBREV");
    complex_abbreviations(\$TEXT);
    url(\$TEXT);
    $TEXT =~ s/_/ /mg;
    date_and_time(\$TEXT);
    # #271
    currencies(\$TEXT);
    units(\$TEXT);
    telephone(\$TEXT);

    #342
    
    #############################################################
    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Proper names processing.";
    apply_rules(\$TEXT, "PROPER1");
    apply_rules(\$TEXT, "PROPER2");
    apply_rules(\$TEXT, "PROPER3");
    split_entities(\$TEXT,"$RSRC/countries.lst");
    split_entities(\$TEXT,"$RSRC/cities.lst");
    split_entities(\$TEXT,"$RSRC/planets.lst");
    $TEXT =~ s/( | )+/ /gm;
    $TEXT =~ s/ $//gm;
    $TEXT =~ s/^ //gm;
    
    tag_ne(\$TEXT);
    apply_rules(\$TEXT, "CASE");

    #395/371

    
    #############################################################
    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Hyphenation and processing of apostrophes for all the words";
    apply_rules(\$TEXT, "HYPHEN");
    hyphenate(\$TEXT);
    apostrophes(\$TEXT);
    apply_rules(\$TEXT, "APOST");

    #############################################################
    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Processing uppercase words.";
    apply_rules(\$TEXT, "ROMAN_NUM");
    roman_numbers(\$TEXT);
    acronyms(\$TEXT);
    apply_rules(\$TEXT, "ACRONYMS");

    $TEXT =~ s/ +/ /gm;
    $TEXT =~ s/^ //gm;
    $TEXT =~ s/ $//gm;

    #############################################################
    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Conversion of digits into letters.";
    numbers(\$TEXT);

    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Modification de la casse.\n";
    #	apply_rules(\$TEXT, "MAJ_UNIGRAM");
    #	apply_rules(\$TEXT, "MAJ_BIGRAM");

    #############################################################
    #   $TEXT =~ s/_/ /gm; #remove previous multiwords
    #	apply_rules(\$TEXT, "MULTIWORD");

    #############################################################
    # Remove weak punctuation signs
    #############################################################
    if ($KEEP_PUNC == 0) {
	$TEXT =~ s/$weak_punc/ /gm;
    }

    #############################################################
    # One sentence per line + removal of all punctuation signs
    #############################################################
    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Final processings.";
    
    $TEXT =~ s/El Cid/El-Cid/;

    # replace ( and ) by ,
    #print STDERR $TEXT."\n";
    $TEXT =~ s/[\(\)]/,/g;
    $TEXT =~ s/($weak_punc) *\,/$1/g;

    $TEXT = remove_diacritics($TEXT);      
    apply_rules(\$TEXT, "FINAL");
    end(\$TEXT);
    #print STDERR $TEXT."\n";
    

    $TEXT =~ s/(^| )['\-](?= |\n|$)/$1/mg;
    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Splitting into sentences (1 per line).\n";
    if ($KEEP_PUNC == 0) {
	$TEXT =~ s/$weak_punc/ /mgo;
	if ($ESTER == 1 || $KEEP_PARA == 1) {
	    $TEXT =~ s/( )(\.|\.\.\.|\?|!)( |$)/$3/mg;
	}
	else {
	    $TEXT =~ s/( )(\.|\.\.\.|\?|!)( |$)/\n/mg;
	}
	$TEXT =~ s/(\.\.+|\?+|!+)/ /mg;
	$TEXT =~ s/^\.+//mg;
	$TEXT =~ s/ \.+$//mg;
    }
    else {
	if ($ESTER == 1 || $KEEP_PARA == 1) {
	    $TEXT =~ s/( )(\.|\.\.\.|\?|!)( |$)/$1$2$3/mg;
	}
	else {
	    $TEXT =~ s/( )(\.|\.\.\.|\?|!)( |$)/$1$2\n/mg;
	}
	$TEXT =~ s/^\.+//mg;
    }

    $TEXT =~ s/( | )+/ /mg;
    if ($KEEP_PARA == 0 ) {
	$TEXT =~ s/(\r+)//gm;
	$TEXT =~ s/(\n)+ /$1/gm;
	$TEXT =~ s/(\n)+/$1/gm;
    }
    $TEXT =~ s/ +$//g;
    $TEXT =~ s/^ +//g;

    # Remove all tags
    my $END_SEP = " |\n|\$|'s? ";
    $TEXT =~ s/[<>]{2,}/ /gm;
    $TEXT =~ s/( |^)<[^>]+?($END_SEP)/$1$2/gm;
    $TEXT =~ s/( |^)(<\/?[^>]+>+)($END_SEP)/$3/gem;
    $TEXT =~ s/[<>]{2,}/ /gm;
    $TEXT =~ s/( |^)<[^>]+?($END_SEP)/$1$2/gm;
    $TEXT =~ s/( |^)(<\/?[^>]+>+)($END_SEP)/$3/gem;

    #extra return character if needed
    if ($TEXT !~ /\n$/) {
	$TEXT .= "\n";
    }
    return $TEXT;
}

1;
