#!/usr/bin/perl
#
# Normalization script
#
# Gwenole Lecorve
# June, 2011
# Damien Lolive
# April 2016
package TtsNormalisationFr;

use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/.";
use CorpusNormalisationFr;
use Encode;
use strict;


my $RSRC = dirname( abs_path(__FILE__) )."/../rsrc/fr";
my $WIKTIONARY_WORD_POS = "$RSRC/word_pos.lst";
my $LEXIQUE_FILE = "$RSRC/lexicon_fr";

$|++; #autoflush

sub load_rules_fr()
{
    CorpusNormalisationEn::load_rules("SPECIAL", "$RSRC/special.rules");
    CorpusNormalisationEn::load_rules("HESITATIONS", "$RSRC/hesitations.rules");
    CorpusNormalisationEn::load_rules("ACCENT_CASE", "$RSRC/case-accent.rules");
    CorpusNormalisationEn::load_rules("ACCENT_NOCASE", "$RSRC/accent-no_case.rules");  
    CorpusNormalisationEn::load_rules("MISSPELL", "$RSRC/misspellings.rules", "$RSRC/alternative_spellings.rules", "$RSRC/alternative_forms.rules");
    CorpusNormalisationEn::load_rules("ABBRV", "$RSRC/abbreviations.rules");
    #CorpusNormalisationEn::load_rules("PROPER1", "$RSRC/propername-apostrophe-removal.wikipedia.rules", "$RSRC/propername-apostrophe-blanking.wikipedia.rules");
    CorpusNormalisationEn::load_rules("PROPER2", "$RSRC/propername-hyphen-remove.rules", "$RSRC/propername-hyphen-add.rules");
    CorpusNormalisationEn::load_rules("PROPER3", "$RSRC/propername-case.rules", "$RSRC/propername-disambig.rules");
    CorpusNormalisationEn::load_rules("CASE_SPECIAL", "$RSRC/case-special.rules");
    CorpusNormalisationEn::load_rules("HYPHEN", "$RSRC/hyphenation-remove.rules", "$RSRC/hyphenation-add.rules", "$RSRC/hyphenation-general.rules", "$RSRC/hyphenation-latin_locutions.rules");	
    CorpusNormalisationEn::load_rules("APOST", "$RSRC/apostrophes.rules");
    CorpusNormalisationEn::load_rules("ROMAN_NUM", "$RSRC/roman_numbers.rules");
    CorpusNormalisationEn::load_rules("ACRONYMS", "$RSRC/acronyms.rules");
    #	CorpusNormalisationEn::load_rules("MAJ_UNIGRAM", "$RSRC/majuscule_unigrammes.rules");
    #	CorpusNormalisationEn::load_rules("MAJ_BIGRAM", "$RSRC/majuscule_bigrammes.rules");
    #   CorpusNormalisationEn::load_rules("MULTIWORD", "$RSRC/multiwords.rules");
    CorpusNormalisationEn::load_rules("FINAL", "$RSRC/final.rules");    
}

sub init_norm_fr()
{
    load_pos($WIKTIONARY_WORD_POS);
    load_lexicon($LEXIQUE_FILE);
    load_rules_fr();
}

sub process_norm_fr($$$$$)
{
    my $TEXT = shift;
    my $KEEP_PARA = shift;
    my $KEEP_PUNC = shift;
    my $ESTER = shift;
    my $VERBOSE = shift;
    
    my $weak_punc = "[\",;:¡¿\(\)]";
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


    # Insert space between numbers and letters
    $TEXT =~ s/(\d+)(\w+)/$1 $2/g;
    $TEXT =~ s/(\w+)(\d+)/$1 $2/g;

    #106
    
    #############################################################
    # particularités
    #############################################################

    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." --Preliminary special processes.";
    remove_bugs(\$TEXT);
    #137
    $VERBOSE && print STDERR ".";
    # 	process_ing(\$TEXT);
    # $VERBOSE && print STDERR ".";
    # 	process_d(\$TEXT);
    # $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "SPECIAL");
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
    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Transformation to a French compliant form.";
    $TEXT = remove_diacritics($TEXT);
    define_rule_preprocessing("perl ".dirname( abs_path(__FILE__) )."/../bin/fr/remove-diacritics.pl");
    $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "HESITATIONS");
    $VERBOSE && print STDERR ".";    
    apply_rules(\$TEXT, "ACCENT_CASE"); 
    $VERBOSE && print STDERR ".";
    $TEXT = first_letter($TEXT);
    $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "ACCENT_NOCASE");
    $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "MISSPELL");
    $VERBOSE && print STDERR ".\n";

    #183

    #############################################################
    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Expansion and tagging.";
    apply_rules(\$TEXT, "ABBRV");
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
    # 	apply_rules(\$TEXT, "PROPER1");
    # $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "PROPER2");
    $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "PROPER3");
    $VERBOSE && print STDERR ".";
    split_entities(\$TEXT,"$RSRC/countries.lst");
    split_entities(\$TEXT,"$RSRC/cities.lst");
    split_entities(\$TEXT,"$RSRC/planets.lst");
    $VERBOSE && print STDERR ".";
    $TEXT =~ s/( | )+/ /gm;
    $TEXT =~ s/ $//gm;
    $TEXT =~ s/^ //gm;

    tag_ne(\$TEXT);
    $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "CASE_SPECIAL");

    $VERBOSE && print STDERR ".\n";

    #395/371

    #############################################################
    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Hyphenation and processing of apostrophes for all the words";
    apply_rules(\$TEXT, "HYPHEN");	
    $VERBOSE && print STDERR ".";
    hyphenate(\$TEXT);
    $VERBOSE && print STDERR ".";
    #print STDERR $TEXT."\n";
    apostrophes(\$TEXT);
    apply_rules(\$TEXT, "APOST");
    $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "ACCENT_CASE");
    $VERBOSE && print STDERR ".\n";

    #############################################################
    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Processing uppercase words.";
    apply_rules(\$TEXT, "ROMAN_NUM");
    roman_numbers(\$TEXT);
    $VERBOSE && print STDERR ".";
    acronyms(\$TEXT);
    apply_rules(\$TEXT, "ACRONYMS");
    $VERBOSE && print STDERR ".\n";

    $TEXT =~ s/ +/ /gm;
    $TEXT =~ s/^ //gm;
    $TEXT =~ s/ $//gm;


    #############################################################
    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Conversion of digits into letters.";    
    numbers(\$TEXT);
    $VERBOSE && print STDERR ".\n";

    #$VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Modification de la casse.\n";
    #	apply_rules(\$TEXT, "MAJ_UNIGRAM");
    #	apply_rules(\$TEXT, "MAJ_BIGRAM");
    $VERBOSE && print STDERR ".\n";

    #############################################################
    #   $TEXT =~ s/_/ /gm; #remove previous multiwords
    #	apply_rules(\$TEXT, "MULTIWORD");
    #$VERBOSE && print STDERR ".\n";



    #############################################################
    # Remove weak punctuation signs
    #############################################################
    if ($KEEP_PUNC == 0) {
	$TEXT =~ s/$weak_punc/ /gm;
    }
    
    
    #############################################################
    # One sentence per line + removal of all punctuation signs
    #############################################################
    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Final processings.";

    $TEXT = remove_diacritics($TEXT);

    $VERBOSE && print STDERR ".";
    apply_rules(\$TEXT, "FINAL");
    $VERBOSE && print STDERR ".";
    end(\$TEXT);
    $VERBOSE && print STDERR ".";

    $TEXT =~ s/(^| )['\-](?= |\n|$)/$1/mg;
    $VERBOSE && print STDERR `date "+%d/%m/%y %H:%M:%S"`." -- Splitting into sentences (1 per line).\n";
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


    # Specificités
    #####

    #####

    $TEXT =~ s/-(\w')/ $1/g;
    $TEXT =~ s/([A-Z])\.'/$1'/g;

    $TEXT =~ s/( | )+/ /mg;
    if ($KEEP_PARA == 0 ) {
	$TEXT =~ s/(\r+)//gm;
	$TEXT =~ s/(\n)+ /$1/gm;
	$TEXT =~ s/(\n)+/$1/gm;
    }

    $VERBOSE && print STDERR ".";

    # Remove all tags
    my $END_SEP = " |\n|\$|'s? ";
    $TEXT =~ s/[<>]{2,}/ /gm;
    $TEXT =~ s/( |^)<[^>]+?($END_SEP)/$1$2/gm;
    $TEXT =~ s/( |^)(<\/?[^>]+>+)($END_SEP)/$3/gem;
    $TEXT =~ s/[<>]{2,}/ /gm;
    $TEXT =~ s/( |^)<[^>]+?($END_SEP)/$1$2/gm;
    $TEXT =~ s/( |^)(<\/?[^>]+>+)($END_SEP)/$3/gem;

    $TEXT =~ s/\.\.\./SUPER_CHAINE_PPP/g;
    $TEXT =~ s/\.\.//g;
    $TEXT =~ s/SUPER_CHAINE_PPP/.../g;

    $TEXT =~ s/P\.-S\./P.S./g;

    # Transform acronyms containing dots into separate letters
    #$TEXT =~ s/(\W)(\w)\.(\w)(\W)/$1$2 $3$4/g;
    $TEXT =~ s/([A-Z])\.([A-Z])(\.|)/$1 $2 /g;


    $TEXT =~ s/ +/ /g;    
    $TEXT =~ s/ +$//g;
    $TEXT =~ s/^ +//g;    


    #extra return character if needed
    if ($TEXT !~ /\n$/) {
	$TEXT .= "\n";
    }
    return $TEXT;
}

1;
