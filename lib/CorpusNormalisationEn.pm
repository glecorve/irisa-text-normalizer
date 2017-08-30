#!/usr/bin/perl
#
# CorpusNormalisation.pm
# Many functions to normalize texts
#
# July, 2011
# Gwénolé Lecorvé
#
########################################################


package CorpusNormalisationEn;

use File::Basename;
use Cwd 'abs_path';
use lib dirname( abs_path(__FILE__) )."/.";

use strict;

use Case;
use RulesApplication;
use Encode;
use Unicode::Normalize;
use Lingua::EN::Numbers qw(num2en num2en_ordinal);

use Exporter;


use strict;

use locale;
use POSIX qw(locale_h);
setlocale(LC_CTYPE, "UTF8");
setlocale(LC_COLLATE, "UTF8");
use open qw(:std :utf8);

#use Memoize;
#memoize('process_first_letter', 'tir_couper_ou_pas', 'decision_compact', 'variante', 'expand_unit');


use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter);
BEGIN {
  @EXPORT = qw(%lexicon %pos &load_pos &define_rule_preprocessing &undefine_rule_preprocessing &load_lexicon &load_NP &first_letter &url &currencies &units &date_and_time &roman_numbers &numbers &remove_bugs &apply_rules &apply_rules_comptes &triple_lettre &complex_abbreviations &acronyms &compact_initials &hyphenate &apostrophes &end &split_entities &telephone &tag_ne &remove_diacritics &process_ing &process_d &trim_blanks);
}


our %pos;
our %lexicon;
my %NP;

my $MONTH = "(January|February|March|April|May|June|July|August|September|October|November|December|Jan\.|Feb\.|Mar\.|Apr\.|Jun\.|Jul\.|Aug\.|Sep\.|Oct\.|Nov\.|Dec\.)";
my $DAY = "(Moday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)";
my $YEAR_MARK = "this_is_mark_for_a_year";

my $ALLOWED_TAGS = "(CURRENCY|DATE|LOCATION|ORGANIZATION|QUANTITY|PERSON|TIME|URL)";
my $NUMBER = "[0-9]+(?:[\.,\/][0-9]+)*";
my $LITTERAL_DIGIT = "(?:one|two|three|four|five|six|seven|eight|nine)";
my $LITTERAL_TEENS = "(?:ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|fourty)";
my $LITTERAL_NTY = "(?:twenty|thirty|fourty|fifty|sixty|seventy|eighty|ninety)";
my $LITTERAL_SMALL_NUMBER = "(?:$LITTERAL_NTY-$LITTERAL_DIGIT|$LITTERAL_TEENS|$LITTERAL_DIGIT)";
my $LITTERAL_NUMBER = "(?:$LITTERAL_SMALL_NUMBER (?:billion|million|thousand))*(?: and| )?(?:$LITTERAL_DIGIT hundreds?)?$LITTERAL_SMALL_NUMBER(?: point $LITTERAL_SMALL_NUMBER)?";


my %CURRENCY = ();
my %UNIT = ();
my %UNRELIABLE = ();
my %PLURAL = ();
my $END_SEP = " |\n|\$|'s? ";

#############################################################################

sub init()
{
    load_list(\%CURRENCY, dirname( abs_path(__FILE__) )."/../rsrc/en/currencies.lst");
    load_list(\%UNIT, dirname( abs_path(__FILE__) )."/../rsrc/en/units.lst");
}

##################################################################
# LOAD SUBROUTINES
##################################################################

sub define_rule_preprocessing {
	RulesApplication::define_rule_preprocessing(shift(@_));
}

sub undefine_rule_preprocessing {
	RulesApplication::undefine_rule_preprocessing();
}

sub define_rule_case_unsensitive {
	RulesApplication::define_rule_case_unsensitive();
}

sub define_rule_case_sensitive {
	RulesApplication::define_rule_case_sensitive();
}

sub load_pos {
	my $f = shift;
	open(F, "< $f") or die("Unable to open $f.\n");
	while (<F>) {
		chomp;
		if ($_ !~ /^#/) {
			my @tab = split("\t", $_);
			$tab[0] =~ s/_/ /g;
			foreach my $p (split(/ +/,$tab[1])) {
				$pos{$tab[0]} .= "_".$p;
			}
		}
	}
	close(F);
}


sub load_lexicon {
	my $f = shift;
	open(F, "< $f") or die("Unable to open $f.\n");
	while (<F>) {
		chomp;
		if ($_ !~ /^#/) {
			my @tab = split("\t", $_);
			$tab[0] =~ s/_/ /g;
			$lexicon{$tab[0]} = 1;
			if ($tab[0] =~ /^[A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]/) {
				$pos{$tab[0]} .= "_Np";
				$NP{$tab[0]} .= 1;
			}
		}
	}
	close(F);
}


sub load_NP {
	my $f = shift;
	open(F, "< $f") or die("Unable to open $f.\n");
	while (<F>) {
		chomp;
		if ($_ !~ /^#/) {
			my @tab = split(/\s/, $_);
			$tab[0] =~ s/_/ /g;
			$NP{$tab[0]} = 1;
		}
	}
	close(F);
}



sub load_list {
	my $p_hash = shift;
	my $f = shift;
	open(F, "< $f") or die("Unable to open currency file $f.\n");
	#binmode(F, ":utf8");
	while (<F>) {
		chomp;
		$_ =~ s/ *#.*$//;
		if ($_ ne "") {
			my @line = split(/[ \t]*[,\t][ \t]*/, $_);
			my ($u, $exp) = @line[0..1] or (warn("Wrong declaration '$_' in $f.\n") && next);
			$$p_hash{$u} = $exp;
			foreach my $opt (@line[2..$#line+1]) {
				if ($opt =~ /^UNRELIABLE$/i) { $UNRELIABLE{$u} = 1; }
				elsif ($opt =~ /^PLURAL=(.+)$/i) { $PLURAL{$exp} = $1; }
			}
		}
	}
	close(F);
}




#############################################################################
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#############################################################################


sub trim_blanks {
	my $P_TEXT = shift;
	$$P_TEXT =~ s/ +/ /g;
	$$P_TEXT =~ s/ $//gm;
	$$P_TEXT =~ s/^ //gm;
	return;
}
##################################################################
# URLs and email addresses
##################################################################


sub url {

	my $p_entree = shift;
	my @sortie;

	my @tab_lignes = split(/\n/,$$p_entree);



	foreach my $text (@tab_lignes) {
		my @nv_ligne = ();
		# trim blanks
		$text =~ s/\s+/ /g;
		if ($text =~ /http|www|ftp|@|\.org|\.net|\.com|\.fr|\.uk|\.gov|\.pdf|\.php3|\.co|\.be|\.de|\.ppt|\.ch|\.php|\.jpg|\.gov|\.gouv|\.asso|\.qc|\.ca|\.htm|\.asp/) {
			#1- faire le ménage
			$text =~ s/http\s*:\s*\/\/\s*/ http:\/\//g;
			$text =~ s/http\s*:\/\/\s*/ http:\/\//g;
			$text =~ s/htt\s*:\s*\/\/\s*/ http:\/\//g;
			$text =~ s/http:\/\s+/http:\/\//g;
			$text =~ s/\.www\./\. www\./g;
			$text =~ s/www\.\s+/www\./g;
			$text =~ s/www\s+\./www\./g;
			$text =~ s/ftp\.\s+/ftp\./g;
			$text =~ s/WWW\.\s+/www\./g;
			$text =~ s/\s+\//\//g;
			$text =~ s/\/\s+/\//g;
			$text =~ s/\.\s+com(\b)/\.com$1/g;
			$text =~ s/\.\s+fr(\b)/\.fr$1/g;
			$text =~ s/\.\s+org(\b)/\.org$1/g;
			$text =~ s/\.\s+ppt(\b)/\.ppt$1/g;
			$text =~ s/\.\s+jpg(\b)/\.jpg$1/g;
			$text =~ s/\.\s+pdf(\b)/\.pdf$1/g;
			$text =~ s/\s+\.org(\b)/\.org$1/g;
			$text =~ s/\.\s+gov(\b)/\.gov$1/g;
			$text =~ s/\.\s+gouv\.\s+fr(\b)/\.gouv\.fr$1/g;
			$text =~ s/\s+\.gouv\.\s+fr(\b)/\.gouv\.fr$1/g;
			$text =~ s/\.\s+co\.(\b)/\.co \.$1/g;
			$text =~ s/\.\s+uk(\b)/\.uk$1/g;
			$text =~ s/\.\s+asso\.\s+fr(\b)/\.asso\.fr$1/g;
			$text =~ s/\.\s+qc(\b)/\.qc$1/g;
			$text =~ s/\.\s+de(\b)/\.de$1/g;
			$text =~ s/\.\s+uk(\b)/\.uk$1/g;
			$text =~ s/\.\s+ca(\b)/\.ca$1/g;
			$text =~ s/\.\s+ch(\b)/\.ch$1/g;
			$text =~ s/\.\s+net(\b)/\.net$1/g;
			$text =~ s/\.\s+th(\b)/\.th$1/g;
			$text =~ s/\.\s+nasa(\b)/\.nasa$1/g;
			$text =~ s/\.\s+ibm\.com(\b)/\.ibm\.com$1/g;
			$text =~ s/\.\s+club\-internet(\b)/\.club\-internet$1/g;
			$text =~ s/\.\s+yahoo(\b)/\.yahoo$1/g;
			$text =~ s/\.\s+oleane(\b)/\.oleane$1/g;
			$text =~ s/\.\s+html(\b)/\.html$1/g;
			$text =~ s/\.\s+asp(\b)/\.asp$1/g;
			$text =~ s/\.\s+php(\b)/\.php$1/g;
			$text =~ s/\.\s+htm(\b)/\.htm$1/g;
			$text =~ s/\s+\.html(\b)/\.html$1/g;
			$text =~ s/\s+\.htm(\b)/\.htm$1/g;
			$text =~ s/\.\s+HTM(\b)/\.htm$1/g;
			$text =~ s/\s+\[at\]\s+/\@/g;
			$text =~ s/\s+\@\s+/\@/g;
			$text =~ s/http:\/\/([0-9]*[0-9]) ([0-9]*[0-9]) ([0-9]*[0-9]) ([0-9]*[0-9])/http:\/\/$1\.$2\.$3\.$4/g;
			$text =~ s/www\.([a-zA-Z]+)\- ([a-zA-Z]+)/www\.$1\-$2/g;

			$text =~ s/\s+/ /g;

#			print STDERR $text."\n";
			my @line = split(/\s+/, $text);
			for(my $i = 0; $i < scalar(@line); $i++) {
#				print STDERR $line[$i]."\n";
#	exit(0);
				if ($line[$i] =~ /http|www|ftp|[a-zA-Z0-9] *@ *[a-zA-Z0-9]|\.org|\.net|\.com|\.fr|\.uk|\.gov|\.pdf|\.php3|\.co|\.be|\.de|\.ppt/) {
					$line[$i] =~ s/([a-z])(?=[A-Z0-9][a-z0-9])/$1 /g;
					$line[$i] =~ s/([A-Z])(?=[A-Z][a-z])/$1 /g;
					$line[$i] =~ s/([A-Za-z])(?=[0-9])/$1 /g;
					$line[$i] =~ s/wwww/ www /gi;
					$line[$i] =~ s/\./ dot /g;
					$line[$i] =~ s/\/\// double slash /g;
					$line[$i] =~ s/\// slash /g;
					$line[$i] =~ s/:/ colon /g;
					$line[$i] =~ s/-/ dash /g;
					$line[$i] =~ s/_/ underscore /g;
					$line[$i] =~ s/~/ tilde /g;
					$line[$i] =~ s/@/ at /g;
					$line[$i] =~ s/([0-9]+)/ $1 /g;

					my @lc_line = ();
					foreach my $w (split(/ +/, $line[$i])) {
						if (first_letter($w) == 0) {
							push(@lc_line, lc($w));
						}
						else {
							push(@lc_line, $w);
						}
					}

					$line[$i] = join(" ", @lc_line);
 					push(@nv_ligne, "<URL>", $line[$i], "</URL>");
				} else {
					push(@nv_ligne, $line[$i]);
				}
			}
			push(@sortie, join(" ", @nv_ligne));
		}
		else {
			push(@sortie, "$text");
		}

	}

	$$p_entree = join("\n", @sortie)."\n";
	return;
}






##################################################################
# FIRST LETTERS
##################################################################


# return 1 means downcase
#        0 means don't touch
sub process_first_letter {
	my $w = shift;
	my $x = shift;
	my $retour;
	#Extract the prefix/root of the word
	# Boys' -> Boys
	# High-performance -> High
	$w =~ s/^(.*?)-[a-z].*$/$1/;
	$w =~ s/^(.*s)'$/$1/;
	$w =~ s/^(.*)'s$/$1/;
    $w =~ s/^(.*)\./$1/;

	if ($w =~ /^[B-Z]$/) {
		$retour = 0;
	}
	elsif ($w =~ /^[A-Z]\.$/) {
		$retour = 0;
	}
	#if possibly a determiner, a pronoun, a conjunction or a preposition-> downcase
	elsif ($pos{lc($w)} =~ /_(DET|PRO|P|CJ)/) {
		$retour = 1;
	}
	# Will Smith -> 0
	# Will they -> 1
	elsif (defined($lexicon{downcase($w)}) && $pos{$w} =~ /_(NP|SYM)/ && $pos{$w} !~ /_(N|ADJ)(?=_|$)/) {
		if ($x =~ /^[a-z]/) { return 1; }
		else { return 0; }
	}
	elsif ($pos{$w} =~ /_(NP|SYM)/ || defined($NP{$w})) {
		$retour = 0;
	}
	elsif ($w =~ /[\-A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]{2}/) {
		$retour = 0;
	}
	elsif ($w =~ /[0-9]/) {
		$retour = 0;
	}
	elsif ($w =~ /$DAY/i) {
		$retour = 0;
	}
	elsif (!defined($lexicon{downcase($w)})) {
		$retour = 0;
	}
	else {
		$retour = 1;
	}
}

# INPUT: single line text
sub first_letter_2 {
	my $phrase = shift;
	my @words = split(/\s/, $phrase);
	my $i;
	my $retour;
	for ($i = 0 ; $i < @words && ($words[$i] eq "" || $words[$i] !~ /^[A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝa-zàáâãäåçèéêëìíîïñòóôõöøùúûüýü]/); $i++) {
	}
#	if (!defined($deja_en_minuscule{$words[$i]]})) {
		$retour = process_first_letter($words[$i], $words[$i+1]);
#		$deja_en_minuscule{$words[$i]} = $retour;
#	}
#	else {
#		$retour = $deja_en_minuscule{$words[$i]};
#	}

	$words[$i] = ($retour == 0? $words[$i] : downcase($words[$i]));
	return join(" ", @words).($phrase=~/ $/?" ":"");
}

# INPUT: Multiline text
sub first_letter {
	my $entree = shift;
	my @sortie = ();
	my ($a,$b,$c,$d);

	my @lignes = split (/\n/, $entree);
	my $ligne_out = "";

	for (my $i = 0; $i < @lignes; $i++) {
		chomp $lignes[$i];
		my @phrases = split(/( (?:\.|\.\.\.|\?|!|:|«|»|") )/,$lignes[$i]);
		$ligne_out = "";
		foreach my $phr (@phrases) {
			$ligne_out .= first_letter_2($phr);
		}
		push(@sortie, $ligne_out);
	}

	return join("\n", @sortie);
}







##################################################################
# CURRENCY AND UNITS
##################################################################


sub plural {
	my $n = shift;
	return ($n > -2 && $n < 2?"":"s");
}



sub expand_unit {

	my $p_hash = shift;
	my $n = shift;
	my $u = shift;
	my $inter = shift;
	my $post = shift; #optional
	my $exp_u = "";

	if (defined($$p_hash{$u})) {
		$exp_u = $$p_hash{$u};
	}
	else {
		foreach my $k (keys (%{$p_hash})) {
			if ($u =~ /^$k$/) {
				$exp_u = $$p_hash{$k};
				last;
			}
		}

	}
	my $ret = "";
	my $currency = 0;

#print "$u -> $exp_u\n";
	# special case since $ is a reg exp symbol
	if ($u eq '$') {
		$exp_u = "dollar";
	}

	if ($u !~ /^ *$/) {
		#force plural
		if ($inter =~ /(?:billion|million)/) {
			if (defined($PLURAL{$exp_u})) {
				$ret = $n.$inter.$PLURAL{$exp_u}.$post;
			}
			else {
				$ret = $n.$inter.$exp_u."s".$post;
			}
		}
		else {
			if (defined($PLURAL{$exp_u}) && ($n <= -2 || $n >= 2)) {
				$ret = $n.$inter.$PLURAL{$exp_u}.$post;
			}
			else {
				$ret = $n.$inter.$exp_u.plural($n).$post;
			}
		}
	}
	else {
		$ret = $n.$inter.$u.$post;
	}
	return $ret;
}






##################################################################
# CURRENCIES
##################################################################




sub currencies {
	my $p_text = shift;

	my @tab3letters;
	my @tab2letters;
	my @tab1letter;
	my @rely;
	my @tabexpanded;
	foreach my $u (keys %CURRENCY) {
		if (length($u) == 1) {
			push(@tab1letter, $u);
			if (!defined($UNRELIABLE{$u})) {
				push(@rely, $u);
			}
		}
		elsif (length($u) == 2) {
			push(@tab2letters, $u);
		}
		else {
			push(@tab3letters, $u);
		}
		push(@tabexpanded,$CURRENCY{$u});
		if (defined($PLURAL{$CURRENCY{$u}})) {
			push(@tabexpanded,$PLURAL{$CURRENCY{$u}});
		}
		else {
			push(@tabexpanded,$CURRENCY{$u}."s");
		}
	}

	my @ereg;
	my $ereg_expanded_unit = "(?:".join("|", sort {length($b) <=> length($a)} @tabexpanded).")";
	$ereg[3] = "(".join("|", sort {length($b) <=> length($a)} @tab3letters).")";
	$ereg[2] = "(".join("|", @tab2letters).")";
	$ereg[1] = "(".join("|", @tab1letter).")";
	my $ereg_all = "(".join("|", keys(%CURRENCY)).")";
	my $reliable = "(".join("|", @rely).")";


	my %special_money = (
	"b" => "billion ",
	"m" => "million ",
	"M" => "million ",
	"" => ""
	);

	#some special cases
	# Wrong year: <DATE> 1600 </DATE> EUR -> 1600 EUR
	$$p_text =~ s/(^| )$YEAR_MARK (\d+) $ereg_all\.?(?='s| |\/|\n|$)/$1 $2 $3/gim;

foreach my $i (3,2,1) {
	if ($ereg[$i] ne "()") {
#		print STDERR "s/(^| |\b)$ereg[$i] ?([0-9]+(?:[\.,\/][0-9\-]+)*) *([bmM]?)n?\.?( |\n|$)/$1$3 $4 $2$5/gm\n";
		$$p_text =~ s/(^| |\b)$ereg[$i] ?([0-9]+(?:[\.,\/][0-9\-]+)*) *([bmM]?)(?:(?:illio)?n?)\.?( |\n|$)/$1$3 $4 $2$5/gm;
		$$p_text =~ s/(^| |\b)([0-9]+)\.?\- *$ereg[$i]($END_SEP)/"$1$2 $3$4"/giem;
	}
}
 	foreach my $i (3,2) {
 		if ($ereg[$i] ne "()") {
	 		$$p_text =~ s/(^|\b)($NUMBER) ?([bmM]?) ?$ereg[$i]\.?($END_SEP|\/)/"$1".expand_unit(\%CURRENCY, $2,uc($4),' '.$special_money{$3}).$5/giem;
 		}
 	}
	if ($reliable ne "()") {
	 	$$p_text =~ s/(^|\b)($NUMBER) ?([bmM]?) ?$reliable\.?($END_SEP|\/)/"$1".expand_unit(\%CURRENCY, $2, uc($4),' '.$special_money{$3}).$5/giem;
 	}

	#TAGGING

	$$p_text =~ s/(^| )((?:$NUMBER) (?:billion |million )?$ereg_expanded_unit)(?=$END_SEP)/$1<CURRENCY> $2 <\/CURRENCY>/gm;

	#/

	$$p_text =~ s/(^| )((?:$LITTERAL_NUMBER) $ereg_expanded_unit)(?=$END_SEP)/$1<CURRENCY> $2 <\/CURRENCY>/gm;

	#/


	trim_blanks($p_text);
	return;
}








##################################################################
# UNITS
##################################################################



sub units {
	my $p_text = shift;
	my $NUMBER = "[0-9]+(?:[\.,\/][0-9]+)*";


	my @tab3letters;
	my @tab2letters;
	my @tab1letter;
	my @rely;
	my @tabexpanded;
	foreach my $u (keys %UNIT) {
		if (length($u) == 1) {
			push(@tab1letter, $u);
			if (!defined($UNRELIABLE{$u})) {
				push(@rely, $u);
			}
		}
		elsif (length($u) == 2) {
			push(@tab2letters, $u);
		}
		else {
			push(@tab3letters, $u);
		}
		push(@tabexpanded,$UNIT{$u});
		if (defined($PLURAL{$UNIT{$u}})) {
			push(@tabexpanded,$PLURAL{$UNIT{$u}});
		}
		else {
			push(@tabexpanded,$UNIT{$u}."s");
		}

	}

	my @ereg;
	my $ereg_expanded_unit = "(?:fluid ounce|".join("|", sort {length($b) <=> length($a)} @tabexpanded).")";
	$ereg[3] = "(".join("|", sort @tab3letters).")";
	$ereg[2] = "(".join("|", @tab2letters).")";
	$ereg[1] = "(".join("|", @tab1letter).")";
	my $ereg_all = "(".join("|", keys(%UNIT)).")";
	my $reliable = "(".join("|", @rely).")";



	# Wrong year: <DATE> 1600 </DATE> km -> 1600 km
	$$p_text =~ s/(^| )$YEAR_MARK (\d+) $ereg_all\.?(?='s| |\/|\n|$)/$1 $2 $3/gim;

	#special cases
	$$p_text =~ s/(^| |\b)([0-9]+(?:[\.,\/][0-9]+)*) *° ?C($END_SEP)/"$1$2 degree".plural($2)." Celsius$3"/giem;

	$$p_text =~ s/(^| |\b)([0-9]+(?:[\.,\/][0-9]+)*) *fl ?\.? ?oz ?\.?($END_SEP)/"$1$2 fluid ounce".plural($2).$3/giem;
	$$p_text =~ s/(^| |\b)([0-9]+(?:[\.,\/][0-9]+)*)in\.?($END_SEP)/$1$2 in.$3/gim;

	#"

	$$p_text =~ s/(^| |\b)([0-9]+(?:[\.,\/][0-9]+)*) *° ?F($END_SEP)/"$1$2 degree".plural($2)." Farenheit$3"/gem;




	# floppy disks
	$$p_text =~ s/(^| |\b)3" *1\/2 /$1."3.5 inches$3"/gem;
	$$p_text =~ s/(^| |\b)5" *1\/4 /$1."5 inches and a quarter$3"/gem;

	# 1.80 m -> 1 m 80
	$$p_text =~ s/(^| |\b)(\d+)\.(\d0) ?m\.?($END_SEP)/$1$2 m $3$4/gm;
	# 1m80 -> 1 m 80
	$$p_text =~ s/(^| |\b)(\d+)m\.?(\d+)($END_SEP)/$1$2 m $3$4/gm;


	# 9x4cm -> 9 x 4 cm
	foreach my $i (3,2) {
 		if ($ereg[$i] ne "()") {
			$$p_text =~ s/(^|\b)($NUMBER) ?[xX] ?($NUMBER) ?$ereg[$i]([^[:alnum:]])/$1$2 x $3 $4$5/gm;
		}
	}
	if ($reliable ne "()") {
			$$p_text =~ s/(^|\b)($NUMBER) ?[xX] ?($NUMBER) ?$reliable([^[:alnum:]])/$1$2 x $3 $4$5/gm;
	}


	my %square_or_cubic = ("sq " => "square",
	                       "sq. " => "square",
	                       "2" => "square",
	                       "²" => "square",
	                       "cu " => "cubic",
	                       "cu. " => "cubic",
	                       "3" => "cubic",
	                       "³" => "cubic");

	foreach my $i (3,2) {
 		if ($ereg[$i] ne "()") {
			$$p_text =~ s/(^|\b)($NUMBER) ?$ereg[$i](2|²|3|³)( |\/|\n|$)/"$1$2 ".$square_or_cubic{$4}." $3.$5"/gem;
		}
	}
	if ($reliable ne "()") {
		$$p_text =~ s/(^|\b)($NUMBER) ?$reliable(2|²|3|³)( |\/|\n|$)/"$1$2 ".$square_or_cubic{$4}." $3.$5"/gem;
	}



	$$p_text =~ s/in\//In\//gm;
	foreach my $i (3,2) {
 		if ($ereg[$i] ne "()") {
			$$p_text =~ s/(^| |\b)($NUMBER) ?(sq\.? |cu\.? )$ereg[$i]\.?( |\/|\n|$)/"$1$2 ".$square_or_cubic{$3}." $4.$5"/gem;
		}
	}
	if ($reliable ne "()") {
		$$p_text =~ s/(^| |\b)($NUMBER) ?(sq\.? |cu\.? )$reliable\.?( |\/|\n|$)/"$1$2 ".$square_or_cubic{$3}." $4.$5"/gem;
	}

	# 10 m per second -> 10 meters per second
	foreach my $i (3,2,1) {
 		if ($ereg[$i] ne "()") {
			foreach my $j (3,2,1) {
		 		if ($ereg[$j] ne "()") {
					$$p_text =~ s/(^|\b)($NUMBER) ?((?:square |cubic )?)$ereg[$i]\.? ?\/ ?((?:square |cubic )?)$ereg[$j]( |\/|\n|$)/"$1 ".expand_unit(\%UNIT,$2,$4," $3 ",' per '.expand_unit(\%UNIT,'',$6," $5 ",'')).$7/gem;
					$$p_text =~ s/(^|\b)($NUMBER) ?$ereg[$i](?: \. |\.| )$ereg[$j] ?-1( |\/|\n|$)/"$1 ".expand_unit(\%UNIT,$2,$3,' ',' per '.expand_unit(\%UNIT,'',$4,'','')).$5/gem;
				}
			}
		}
	}

	foreach my $i (3,2) {
 		if ($ereg[$i] ne "()") {
			$$p_text =~ s/(^|\b)($NUMBER) ?((?:square |cubic )?)$ereg[$i]\.?( |\/|\n|$)/"$1".expand_unit(\%UNIT, $2,$4,' '.$3).$5/gem;
		}
	}
	if ($reliable ne "()") {
		$$p_text =~ s/(^|\b)($NUMBER) ?((?:square |cubic )?)$reliable\.?( |\/|\n|$)/"$1".expand_unit(\%UNIT, $2,$4,' '.$3).$5/gem;
	}


	#separate some other numbers
	$$p_text =~ s/(^| |\b)(\d+)([a-zàáâãäåçèéêëìíîïñòóôõöøùúûüý])($END_SEP)/$1.$2.uc($3).$4/gem;
	$$p_text =~ s/(^| |\b)(\d+)([a-zàáâãäåçèéêëìíîïñòóôõöøùúûüý]{4,})/$1$2 $3/gm;
	$$p_text =~ s/(^| |\b)(\d+)([A-Z][a-zàáâãäåçèéêëìíîïñòóôõöøùúûüý]{3,})/$1$2 $3/gm;

	trim_blanks($p_text);


	#TAGGING

	$$p_text =~ s/(^| )((?:(?:$NUMBER [xX] )?$NUMBER) (?:square |cubic )?$ereg_expanded_unit(?: per (?:square |cubic )?$ereg_expanded_unit)?)(?=$END_SEP)/$1<QUANTITY> $2 <\/QUANTITY>/gm;

	#/

	$$p_text =~ s/(^| )($NUMBER)-($ereg_expanded_unit)(?=$END_SEP)/$1<QUANTITY> $2 $3 <\/QUANTITY>/gm;
	#/

	$$p_text =~ s/(^| )((?:$LITTERAL_NUMBER) (?:square |cubic )?$ereg_expanded_unit(?: per (?:square |cubic )?$ereg_expanded_unit)?)(?=$END_SEP)/$1<QUANTITY> $2 <\/QUANTITY>/gm;

	#/

	#merge consecutive tags (eg, no punc in between)
	$$p_text =~ s/ <\/QUANTITY> <QUANTITY> / /g;

	$$p_text =~ s/([^<])\// /g;
	trim_blanks($p_text);
	return;

}








##################################################################
# DATES AND TIME
##################################################################





sub months2text {
        my ( $month ) = @_;
        $month =~ s/10/October/g;
        $month =~ s/11/November/g;
        $month =~ s/12/December/g;
        $month =~ s/1/January/g;
        $month =~ s/2/February/g;
        $month =~ s/3/March/g;
        $month =~ s/4/April/g;
        $month =~ s/5/May/g;
        $month =~ s/6/June/g;
        $month =~ s/7/July/g;
        $month =~ s/8/August/g;
        $month =~ s/9/September/g;
        $month =~ s/0//;
        return $month;
}

sub text2month {
        my ( $month ) = @_;
        return 1 if ($month =~ /^january$/i);
        return 2 if ($month =~ /^february$/i);
        return 3 if ($month =~ /^march$/i);
        return 4 if ($month =~ /^april$/i);
        return 5 if ($month =~ /^may$/i);
        return 6 if ($month =~ /^june$/i);
        return 7 if ($month =~ /^july$/i);
        return 8 if ($month =~ /^august$/i);
        return 9 if ($month =~ /^september$/i);
        return 10 if ($month =~ /^october$/i);
        return 11 if ($month =~ /^november$/i);
        return 12 if ($month =~ /^december$/i);
        return $month; #otherwise
}

sub year2text {
		my $year = shift;
		if ($year =~ /^2000$/) {
        	$year = "two thousand";
        }
        elsif ($year =~ /^20(\d\d)$/) {
        	$year = "two thousand ".num2en($1);
        }
        elsif ($year =~ /^(1[3-9])(00)$/) {
        	if (rand() < 0.5) {
	        	$year = num2en($1)." hundred";
        	}
        	else {
	        	$year = num2en($year);
        	}
        }
        elsif ($year =~ /^(1[3-9])(0\d)$/) {
        	$year = num2en($1)." zero ".num2en($2);
        }
        elsif ($year =~ /^(1[3-9])(\d\d)$/) {
        	$year = num2en($1)." ".num2en($2);
        }
        else {
	        $year = num2en ( $year );
	    }
	    return $year;
}


sub expand_ad_bc {
	my $x = shift;
	$x =~ /^A\.?D\.?$/ && return "AD";
	$x =~ /^B\.?C\.?$/ && return (rand()<0.8?"before Christ":"BC");
	return "";
}


sub rewrite_date {
        my ( $month, $day, $year , $bcad ) = @_;

        if ($year 	< 10) {
                $year = "20" . $year;
        }

        if ($year < 100) {
                $year = "19" . $year;
        }


        $day = num2en_ordinal ( $day );
		$year = year2text( $year );
        $month = months2text ( $month );

		my $ret = "";
		if ($day ne "") {
			if (rand() < 0.5) {
					$ret = "the " . $day . " of " . $month . " " . $year;
			}
			else {
					$ret = $month . " the " . $day . " " . $year;
			}
		}
		else {
				$ret = $month . " " . $year;
		}

		$bcad = expand_ad_bc($bcad);

		return " <DATE> $ret $bcad <\/DATE> ";
}



#	    H M
#       M past H
#       M minutes past/to H <--- if no seconds
#       H o'clock <--- if no minutes
#		AM | in the morning | nothing
#		PM | in the morning | nothing
#		half | thirty
#		quarter past H | H fifteen
#		quarter to H | H forty-five
sub rewrite_time {
        my ( $hour, $minute, $second, $ampm ) = @_;
        if ($second eq "") {
                $second = 0;
        }
	    my $ret = "";

	# special cases

        if ($minute == 0 && $second == 0 && $hour == 12) {
                if ($ampm ne "") {
                        if (uc $ampm eq "PM") {
							$ret = "noon";
                        } elsif (uc $ampm eq "AM") {
                            $ret = "midnight";
                        }
                } else {
                        $ret = "noon";
                }
        } elsif ($minute == 0 && $second == 0 && $hour == 24) {
                $ret = "midnight";
        }

	# normal process
		else {
		    my $hour_str = num2en($hour);
		    my $second_str = "";


		    if ($second != 0) {
		            my $second_str = num2en ( $second );
		    }

		    if ($minute != 0) {
		    	#prefixed version
		    		if (rand() < 0.5) {
				        if ($minute == 30) {
							$ret = "half past $hour_str";
				        }
				        elsif ($minute == 15) {
		   					$ret = "quarter past $hour_str";
				        }
				        elsif ($minute == 45) {
							$ret = "quarter to ".num2en(($hour+1) % 12);
				        }
						elsif ($minute > 30) {
							$ret = (num2en(60-$minute))." to ".num2en(($hour+1) % 12);
				        }
				        else {
		   					$ret = num2en($minute)." past $hour_str";
				        }
					}
					#suffixed version
					else {
						$ret = "$hour_str ".num2en($minute);
					}
		    }

		    # o'clock
		    else {
				if (rand() < 0.4) {
					$ret = $hour_str." o'clock";
				}
				else {
					$ret = $hour_str;
				}
		    }

		#AM/PM

		    my $ampm_str = "";
		    if ($ampm ne "") {
		    		if ($ret =~ /o'clock/) {
				        if (uc $ampm eq "PM") {
				        	if ($hour > 8) {
								$ampm_str .= (rand() < 0.67?" at night":"");
							}
							elsif ($hour > 5) {
					            $ampm_str .= (rand() < 0.67?" in the evening":"");
							}
							else {
								$ampm_str .= (rand() < 0.67?" in the afternoon":"");
							}
				        } elsif (uc $ampm eq "AM") {
							$ampm_str .= (rand() < 0.5?" in the morning":"");
				        }
		    		}
		    		else {
				        if (uc $ampm eq "PM") {
				        	if ($hour > 8) {
								$ampm_str .= (rand() < 0.67?" at night":" PM");
							}
							elsif ($hour > 5) {
					            $ampm_str .= (rand() < 0.67?" in the evening":" PM");
							}
							else {
								$ampm_str .= (rand() < 0.67?" in the afternoon":" PM");
							}
				        } elsif (uc $ampm eq "AM") {
							$ampm_str .= (rand() < 0.5?" in the morning":" AM");
				        }
			        }
		    }


			if ($second != 0) {
				$ret = $hour_str." ".num2en($minute)." and ".$second_str;
			}
			else {
				$ret .= $ampm_str;
			}
		}

        return "<TIME> $ret <\/TIME>";
}



sub date_and_time {

	my $p_text = shift;

	my $DURATION_SPACE = "XYXDURATIONSPACEXYX";

	sub rewrite_duration {
		our $DURATION_SPACE;
		my ($days, $hours, $minutes, $seconds, $milliseconds) = @_;
		my $d_str = "";
		my $h_str = "";
		my $m_str = "";
		my $s_str = "";
		my $ms_str = "";
		$d_str = "$days day".plural($days) unless ($days == 0);
		$h_str = "$hours hour".plural($hours) unless ($hours == 0);
		$m_str = "$minutes minute".plural($minutes) unless ($minutes == 0);
		$s_str = "$seconds second".plural($seconds) unless ($seconds == 0);
		$ms_str = "$milliseconds millisecond".plural($milliseconds) unless ($milliseconds == 0);
	return join($DURATION_SPACE, $d_str, $h_str, $m_str, $s_str, $ms_str);
	}



	sub process_decade {
		my $x = shift;
		$x =~ s/ty$/ties/;
		return $x;
	}

	#tag pre-formatted dates and times
#	$text =~ s/(^| )$DAY,? *([0-3]?[0-9](?:th|rd|st)?)($END_SEP)/"TOTOOOOO"/eigm;
	$$p_text =~ s/(^| )$DAY,? *((?:the)?) *([0-3][0-9](?:th|rd|st)?),? *((?:of)?) *$MONTH(?: ,)? *((?:\d{1,4})?)($END_SEP)/"$1 <DATE> $2 $3 $4 $5 $6 ".year2text($7)." <\/DATE>$8"/eigm;
	$$p_text =~ s/(^| )$MONTH (?:, )?((?:19|20)\d\d)(?=$END_SEP)/"$1 <DATE> $2 ".year2text($3)." <\/DATE>$4"/eigmo;
	$$p_text =~ s/(^| )(in|on|since|before|after|until|from|to) $MONTH (?:, )?(\d{3,4})($END_SEP)/"$1 $2 <DATE> $3 ".year2text($4)." <\/DATE>$5"/eigmo;
	$$p_text =~ s/(^| )$MONTH ?(?:, )?0?(1|2|3|4|5|6|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)(?:st|nd|rd|th)? (?:, )?(\d{3,4})(?=$END_SEP)/"$1 ".rewrite_date($2, $3, $4)/eigmo;
	$$p_text =~ s/(^| )(in|on|since|before|after|until|from|to) +([12][0-7]\d{2})($END_SEP)/"$1 $2 <DATE> ".year2text($3)." <\/DATE>$4"/eigmo;

	$$p_text =~ s/(^| )(at|since|before|after|until|from|to) (midnight|noon)($END_SEP)/"$1 $2 <TIME> $3 <\/TIME> $4"/eigm;
	$$p_text =~ s/(^| )(at|since|before|after|until|from|to) ($LITTERAL_SMALL_NUMBER) (o'clock|in the morning|in the afternoon|in the evening|in the night|in the late night|PM|AM|P\.M\.|A\.M\.)($END_SEP)/"$1 $2 <TIME> $3 $4 <\/TIME> $5"/eigm;

	#"
    # Date


	$$p_text =~ s/(^| )((?:[0-3]?[1-9]|10|20|30)?) ?( ?[\.\-\/\s] ?) ?$MONTH ?\3 ?([12]?[0-9]?[0-9]{2})($END_SEP)/$1.rewrite_date($4, $2, $5)." ".$6/giem;


	#separator is ., - or /
 	$$p_text =~ s/(^| )(0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|10|11|12)( ?[\.\-\/] ?)((?:[0-3]?[1-9]|10|20|30)?)\3([12]?[0-9]?[0-9]{2})($END_SEP)/$1.rewrite_date($2, $4, $5)." ".$6/eigm;

 	$$p_text =~ s/(^| )([0-3]?[1-9]|10|20|30) ?( ?[\.\-\/] ?) ?(0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|0?10|11|12) ?\3 ?([12]?[0-9]?[0-9]{2})($END_SEP)/$1.rewrite_date($4, $2, $5)." ".$6/giem;

	#separator is space (limitation on years)
 	$$p_text =~ s/(^| )(0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|10|11|12)( +)((?:[0-3]?[1-9]|10|20|30)?)\3(20\d{2}|1[6-9]\d{2})($END_SEP)/$1.rewrite_date($2, $4, $5)." ".$6/eigm;

 	$$p_text =~ s/(^| )([0-3]?[1-9]|10|20|30)( +)(0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|0?10|11|12)\3(20\d{2}|1[6-9]\d{2})($END_SEP)/$1.rewrite_date($4, $2, $5)." ".$6/giem;

	###

 	$$p_text =~ s/(^| )((?:18|19|20)\d\d) ?- ?((?:18|19|20)\d\d)($END_SEP)/$1.rewrite_date("", "", $2, "")." ".rewrite_date("", "", $3, "").$4/gem;

 	$$p_text =~ s/(^| )([1-9][0-9]{1,3})(A\.?D\.?|B\.?C\.?)/"$1".rewrite_date("", "", $2,$3)." "/giem;


	# catch all 60's, 70's...
	$$p_text =~ s/(^| |-)(?:19)?([2-9]0) ?'?s(?=$END_SEP|-)/" $1 <DATE> ".process_decade(year2text($2))." <\/DATE> "/eigmo;
	$$p_text =~ s/(^| |-)(1[6-8][2-9]0) ?'?s(?=$END_SEP|-)/" $1 <DATE> ".process_decade(year2text($2))." <\/DATE> "/eigmo;
	# catcb all 1887-1891
	$$p_text =~ s/(^| )(\d{3,4})-(\d{3,4})(?=$END_SEP)/"$1 <DATE> ".year2text($2)." <\/DATE> - <DATE> ".year2text($3)." <\/DATE> "/eigmo;
	#"
	# and all other remaining years (all -18xx, -19xx, -20xx)
	$$p_text =~ s/(^| |-)((?:16|17|18|19|20)\d{2})(?=$END_SEP|-)/" $1 $YEAR_MARK $2 "/eigmo;
	#"

	# rephrasing
	$$p_text =~ s/<\/DATE> -present($END_SEP)/<\/DATE> until present$1/igmo;
	$$p_text =~ s/<\/DATE> - <DATE>/<\/DATE> to <DATE>/igm;


	#"
	#Time

	$$p_text =~ s/(^| )(0?0|0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24)(\.| *: *|)((?:[0-5][0-9])?) ?(A\.?M\.?|P\.?M\.?)-(0?0|0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24)(\.| *: *|)((?:[0-5][0-9])?) ?(A\.?M\.?|P\.?M\.?)($END_SEP)/"$1$2$3$4 $5 to $6$7$8 $9$10"/iegm;


	$$p_text =~ s/(^| )(0?0|0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24)(?:\.| *: *)([0-5][0-9])(?:(?:\.| *: *)]([0-5][0-9]))?\s?([AEP])\.?([TM])\.?($END_SEP)/$1." ".sprintf('%s', rewrite_time($2, $3, $4, $5.$6))." ".$7/iegm;

	$$p_text =~ s/(^| )(0?0|0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24)((?:[0-5][0-9])?) ?(A\.?M\.?|P\.?M\.?)($END_SEP)/$1.sprintf('%s', rewrite_time($2, $3, 0, $4))." ".$5/iegm;

	$$p_text =~ s/(^| )(00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24)(?:\.| *: *)([0-5][05])($END_SEP)/$1." ".sprintf('%s', rewrite_time($2, $3, 0, $4))." ".$5/iegm;

#	$$p_text =~ s/(^| )07H30($END_SEP)/$1."toto".$6/iegm;


	#Duration
	my $d = '(?:days?|d\ \.?|d\.?)';
	my $h = '(?:hours?|h\ \.?|h\.?)';
	my $m = '(?:minutes?|min \.?|min\.?|mn ?\.?|mn\.?|\')';
	my $s = '(?:seconds?|sec\ \.?|sec\.?|s\ \.?|s\.?|\'\')';
	my $ms = '(?:milliseconds?|ms\ ?\.?)';

	#Special duration
 	# Ad Bh (Cmin Ds Ems)?
    	$$p_text =~ s/(^|\ |\b)
     	              (\d+)\ ?$d\ ?(\d+)\ ?$h
     	              (?:\ ?(\d+)\ ?$m
     	                  (?:\ ?(\d+\.?\d*)\ ?$s
     	                      (?:\ ?(\d+\.?\d*)\ ?$ms)?
     	                   )?
     	              )?
     	              (?=\ |\/|\n|$)
     	              /$1.rewrite_duration($2,$3,$4,$5,$6)/gemx;


	# Bh Cmin (Ds Ems)?
    	$$p_text =~ s/(^|\ |\b)
    	              (\d+)\ ?$h\ ?(\d+)\ ?$m
                     (?:\ ?(\d+\.?\d*)\ ?$s
                         (?:\ ?(\d+\.?\d*)\ ?$ms)?
                      )?
    	              (?=\ |\/|\n|$)
    	              /$1.rewrite_duration(0,$2,$3,$4,$5)/gemx;

 	# Cmin Ds (Ems)?
   	$$p_text =~ s/(^|\ |\b)
   	              (\d+)\ ?$m\ ?(\d+\.?\d*)\ ?$s
                        (?:\ ?(\d+\.?\d*)\ ?$ms)?
   	              (?=\ |\n|$)
   	              /$1.rewrite_duration(0,0,$2,$3,$4)/gemx;

  	# Ds Ems
    	$$p_text =~ s/(^|\ |\b)
    	              (\d+\.?\d*)\ ?$s\ ?(\d+\.?\d*)\ ?$ms
    	              (?= |\/|\n|$)
    	              /$1.rewrite_duration(0,0,0,$2,$3)/gemx;


	#Remaining XXhXX
	$$p_text =~ s/(^| )(0?0|0?1|0?2|0?3|0?4|0?5|0?6|0?7|0?8|0?9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24) *H *((?:[0-5][0-9])?) ?((?:AM|A\.?M\.?|PM|P\.?M\.?)?)($END_SEP)/$1.sprintf('%s', rewrite_time($2, $3, 0, $4))." ".$5/iegm;


	$$p_text =~ s/$DURATION_SPACE/ /g;

	trim_blanks($p_text);

	return;

}






###################################################################
# ROMAN NUMBERS
###################################################################

# sub-function
sub rom2dec {
	my $rom = shift;
	my $forced = shift;
	my $tmp = $rom;
	my $sortie = 0;
	my %valeurs;
	$tmp =~ s/IV/U/;
	$tmp =~ s/IX/W/;
	$tmp =~ s/XL/K/;
	$tmp =~ s/XC/B/;
	$tmp =~ s/CD/E/;
	$tmp =~ s/CM/O/;
	if (($forced == 1)
	||  ($tmp !~ /^(E|K|L|M|I|C|X|V|D|XXX)$/ && !($tmp =~ /I{4}/ || $tmp =~ /V{4}/ || $tmp =~ /X{4}/ || $tmp =~ /L{4}/ || $tmp =~ /C{4}/ || $tmp =~ /D{4}/ || $tmp =~ /M{4}/))
	) {

		$valeurs{"I"} = 1;
		$valeurs{"U"} = 4;
		$valeurs{"V"} = 5;
		$valeurs{"W"} = 9;
		$valeurs{"X"} = 10;
		$valeurs{"K"} = 40;
		$valeurs{"L"} = 50;
		$valeurs{"B"} = 90;
		$valeurs{"C"} = 100;
		$valeurs{"E"} = 400;
		$valeurs{"D"} = 500;
		$valeurs{"O"} = 900;
		$valeurs{"M"} = 1000;

		while ($tmp =~ /^(.)(.)(.*)$/) {
			if (defined($valeurs{$1.$2})) {
				$sortie += $valeurs{$1.$2};
				$tmp = $3;
			}
			elsif ($valeurs{$1} >= $valeurs{$2}) {
				$sortie += $valeurs{$1};
				$tmp = $2.$3;
			}
			else {
				return $rom;
			}
		}
		return $sortie+$valeurs{$tmp};
	}
	else {
		return $rom;
	}

}

sub ordinal_rom2dec {
	my $x = shift;
	my $forced = shift;
	my $y = rom2dec($x, $forced);
	if ($forced == 1) {
		$y =~ s/^I$/1/g;
	}
	if ($y eq $x) {
		return $x;
	}
	else {
		return "the ${y}th";
	}
}

sub process_AIB {
	my $A = shift;
	if (defined($lexicon{lc($A)})) {
		return "I";
	}
	elsif ($pos{$A} =~ /_NP/) {
		return "the 1st";
	}
	else {
		return "1 ";
	}
}


sub process_AIb {
	my $A = shift;
	if (defined($lexicon{lc($A)})) {
		return "1 ";
	}
	else {
		return "the 1st";
	}
}

sub process_AInothing {
	my $A = shift;
	if (defined($lexicon{lc($A)}) && $pos{$A} !~ /_(NP|SYM)/) {
		return "1 ";
	}
	else {
		return "I";
	}
}


# After a proper name -> ordinal
# Except for some cases -> cardinal
# These special cases are handled by a rules file
# they have been rewritten as cardinal(roman number)

sub roman_numbers {
	my $P_TEXT = shift;

	#Except I, V, X (too may false hits) -> handled in rom2dec
	$$P_TEXT =~ s/ROMAN_CARDINAL ([IVXLCDM]+)/" ".rom2dec($1)." "/gem;

	# <PERSON> Henry </PERSON> I -> <PERSON> Henry I </PERSON>
	$$P_TEXT =~ s/(^| |\-)([A-Z][a-z]{2,}) <\/PERSON> ([IV]+(?:'s)?)(?= |\n|$)/$1$2 $3 <\/PERSON>/gm;
	#/

	$$P_TEXT =~ s/(^| )<PERSON> ([A-Z][a-z]{2,}(?: [A-Z][a-z]{2,})?) ([IV]+)('s|\. <| <)/$1."<PERSON> $2 ".ordinal_rom2dec($3,1).$4/gem;

	$$P_TEXT =~ s/(^|\b)([A-Z][a-z]{2,}) ([IVXLCDM]+)(?='s| |$)/$1.$2." ".ordinal_rom2dec($3)/gem;

	#A I B
	$$P_TEXT =~ s/(^|\b)([A-Z][a-z]{2,}) I ([A-Z][a-z]+)(?='s| |$)/$1.$2." ".process_AIB($2)." $3"/gem;

	#A I b
	$$P_TEXT =~ s/(^|\b)([A-Z][a-z]{2,}) I ([a-z]+)(?='s| |$)/$1.$2." ".process_AIb($2)." $3"/gem;

	#A I. ...
	$$P_TEXT =~ s/(^|\b)([A-Z][a-z]{2,}) I( ?\.)(?= |\n|$)/$1.$2." ".process_AInothing($2)."$3"/gem;

	#A I
	$$P_TEXT =~ s/(^|\b)([A-Z][a-z]{2,}) I(?=\n|$)/$1.$2." ".process_AInothing($2)/gem;

	$$P_TEXT =~ s/<ORGANIZATION> ([IVXLCDM]{3,})(\.| )/<ORGANIZATION> _$1_$2/gm;

	$$P_TEXT =~ s/(^| )([IVXLCDM]{3,})(\.| |$)/$1.rom2dec($2).$3/gem;
	$$P_TEXT =~ s/<ORGANIZATION> _([IVXLCDM]{3,})_(\.| )/<ORGANIZATION> $1$2/gm;
	$$P_TEXT =~ s/(st|th)\.( <\/[A-Z]+>| |\n|$)?/$1$2 ./gm;
	$$P_TEXT =~ s/(st|th)\./$1 ./gm;
	trim_blanks($P_TEXT);
}








##################################################################
# TELEPHONE
##################################################################


sub telephone {
	my $P_TEXT = shift;
	sub exp_tel {
		my $w = shift;
		return $w if $w =~ /^(18|19|20)\d\d-(18|19|20)\d\d$/;
		return $w if (($w =~ /-.*\./) || ($w =~ /\..*-/));
		return $w if  $w =~ /^\d\{1-3\}[\.\-]\d{1,3}$/;
		return $w if  $w =~ /^[01][0-9][\.\-][0-3][0-9][\.\-]\d\d\d?\d?$/;
		return $w if  $w =~ /^[0-3][0-9][\.\-][12][0-9][\.\-]\d\d\d?\d?$/;
		$w =~ s/[-\.]/ /g;
		$w =~ s/(.)/ $1 /g;
		$w =~ s/ +/ /g;
		$w =~ s/\+/ plus /g;
		$w =~ s/[\(\)]/ /g;
		$w =~ s/(\d) \1 \1/triple $1/g;
		$w =~ s/(\d) \1/double $1/g;
		return " <PHONE> $w <\/PHONE> ";
	}
	$$P_TEXT =~ s/(^|\w )0(8\d\d)((?:[-\. ]\d)+)( |$)/$1."0 $2 ".exp_tel($3).$4/gem;
	$$P_TEXT =~ s/(^|\w )(\+? ?\d\d(?:[-\. ]\d\d){3,4})( |$)/$1.exp_tel($2).$3/gem;
	$$P_TEXT =~ s/(^|\w )(\+? ?\d{1,4}(?:\-\d{3,5}){1,3})($END_SEP)/$1.exp_tel($2).$3/gem;
	$$P_TEXT =~ s/(^|\w )(\+? ?\d{1,4}(?:\-\d{2,5}){2,4})($END_SEP)/$1.exp_tel($2).$3/gem;
	$$P_TEXT =~ s/(^|\w )(\( ?\d{1,4} ?\) \/? ?\d{1,4}(?:\-\d{3,5}){1,3})($END_SEP)/$1.exp_tel($2).$3/gem;
	$$P_TEXT =~ s/(^|\w )(\( ?\d{1,4} ?\) \/? ?\d{1,4}(?:\-\d{2,5}){1,2})($END_SEP)/$1.exp_tel($2).$3/gem;
	return;
}





##################################################################
# NUMBERS
##################################################################


sub numbers {
	my $P_TEXT = shift;


	# #3 -> number 3
#	$$P_TEXT =~ s/ #(\d+)( |\b|$)/ number $1$2/gm;


	# all remaining round years (all 18xx, 19xx, 20xx)
	$$P_TEXT =~ s/$YEAR_MARK ((?:16|17|18|19|20)\d{2})(?=$END_SEP|-)/"<DATE> ".year2text($1)." <\/DATE> "/eigmo;
	#"

#	$$P_TEXT =~ s/<DATE> +<DATE>/<DATE>/g;
#	$$P_TEXT =~ s/<\/DATE> +<\/DATE>/<\/DATE>/g;
	#"

	#year 20XX
	$$P_TEXT =~ s/(^| |\b)(in|before|after|year|until|from|to) (20\d\d)($END_SEP)/$1.$2." ".rewrite_date("","",$3).$4/giem;
	$$P_TEXT =~ s/(^| |\b)(in|before|after|year|until|from|to) (1[3-9])(\d\d)($END_SEP)/$1.$2." ".rewrite_date("","",$3.$4).$5/giem;



	#cut sequences like "40,000pages" -> "40,000 page"
#	$$P_TEXT =~ s/(\d(?:[ ,\.](?:\d+))+)([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝa-zàáâãäåçèéêëìíîïñòóôõöøùúûüý])/$1 $2/gm;
	#group "40,123" -> "40123"
	$$P_TEXT =~ s/(\d),(\d{3})(?= |$)/$1$2/gm;

	$$P_TEXT =~ s/(\d+)(st|nd|rd|th)?$MONTH/$1$2 $3/gmo;

	$$P_TEXT =~ s/(^| )-(\d)/$1 minus $2/gm;
	$$P_TEXT =~ s/\+ ?(\d)/ plus $1/gm;

	while ($$P_TEXT =~ s/(^| )($NUMBER) *[xX] *($NUMBER)(?=\/| |$)/$1$2 by $3 $4/g) { }
#	$$P_TEXT =~ s/ × (\d+)/ multiplied by $1/gm;
	$$P_TEXT =~ s/ × / times /gm;
	$$P_TEXT =~ s/ <= (\d+)/ is lower than or equal to $1/gm;
	$$P_TEXT =~ s/ >= (\d+)/ is greater than or equal to $1/gm;
	$$P_TEXT =~ s/ < (\d+)/ is lower than $1/gm;
	$$P_TEXT =~ s/ <(\d+)/ less than $1/gm;
	$$P_TEXT =~ s/ > (\d+)/ is greater than $1/gm;
	$$P_TEXT =~ s/ >(\d+)/ more than $1/gm;
	$$P_TEXT =~ s/=+/ equals /gm;


	$$P_TEXT =~ s/(^|\b)1\/2(\b|$)/$1."a half".$2/gem;
	$$P_TEXT =~ s/(^|\b)(1|2)\/3(\b|$)/$1.num2en($2)." third".plural($2).$3/gem;
	$$P_TEXT =~ s/(^|\b)1\/4(\b|$)/$1."one quarter".$3/gem;
	$$P_TEXT =~ s/(^|\b)3\/4(\b|$)/$1."three quarters".$3/gem;


	sub process_er {
		my $x = shift;
		$x =~ s/e$//;
		return $x;
	}

	$$P_TEXT =~ s/(^|\b)(\d{1,2})(ers?)(\b|$)/$1.process_er(num2en($2)).$3.$4/gem;

	$$P_TEXT =~ s/(^|\b)[I] ?st(\b|$)/$1."first".$2/gem;
	$$P_TEXT =~ s/(^|\b)(\d*1) ?st(\b|$)/$1.num2en_ordinal($2).$3/gem;
	$$P_TEXT =~ s/(^|\b)(\d*2) ?nd(\b|$)/$1.num2en_ordinal($2).$3/gem;
	$$P_TEXT =~ s/(^|\b)(\d*3) ?rd(\b|$)/$1.num2en_ordinal($2).$3/gem;
	$$P_TEXT =~ s/(^|\b)(\d+) ?-?th(s?)(\b|$)/$1.num2en_ordinal($2).$3.$4/gem;


	$$P_TEXT =~ s/(^|\b)([0-9]+) *\/ *([1-9][0-9])(\b|$)/$1.num2en($2)." ".num2en_ordinal($3).plural($2).$4/gem;
	$$P_TEXT =~ s/(^|\b)((?:[0-9]+)(?:[\.,][0-9]+)*) *\/ *((?:[0-9]+)(?:[\.,][0-9]+)*)(\b|$)/$1.num2en($2)." out of ".num2en($3).$4/gem;


	sub seq_points {
		my $w = shift;
		$w =~ s/\./ /g;
		return $w;
	}
	$$P_TEXT =~ s/(^| )((?:\d+\.){2,})(?=\d| |$)/$1.seq_points($2)/gem;

	$$P_TEXT =~ s/(^| )(\d+(?:[\.,]\d+)*)(-| |$)/$1.num2en($2).$3/gem;
	$$P_TEXT =~ s/(^| )(\d+(?:[\.,]\d+)*)\.([A-Za-z]+) /$1.num2en($2)." . ".first_letter_2($3)." "/gem;
	return;

	trim_blanks($P_TEXT);

}


sub complex_abbreviations {
	my $P_TEXT = shift;
	$$P_TEXT =~ s/(^| )([XVI]+[\.e]?) (Century|Corps)(?=$END_SEP)/$1.rom2dec($2,1)."th $3$4"/gem;
	$$P_TEXT =~ s/([A-Za-z0-9]) ?\+/$1 plus /gm;
	$$P_TEXT =~ s/plus +\+(?=$END_SEP|-|\+)/plus plus/gm;
	trim_blanks($P_TEXT);
	return;
}


##################################################################
# ACRONYMS
##################################################################


# DAF-3 -> D.A.F-3
sub acronyms {
	my $p_text = shift;
 	my $CHEM = 'Al|Br|Cd|Cl|Ca|C|Cu|Co|He|H|Fe|Pb|Li|Mg|Hg|Ni|N|Pt|Pu|K|Ra|Si|Na|Ag|S|Ti|W|U|Xe';
 	$CHEM = join("|", sort {length($b) <=> length($a)} split(/\|/ , $CHEM));

	# A-F-D -> A.F.D.
	# A. F. D. -> A.F.D.
	# A.F.D. -> A.F.D. (no change)
	sub join_acronym {
		my $acr = shift;
		$acr =~ s/[\-\.] ?/./g;
		$acr =~ s/([A-Z])$/$1./g;
		return $acr;
	}

	# AFD -> A.F.D
	# FA-18 -> F.A.-18
	# WORD -> Word (since word is in the English lexicon) /!\ only if the |word| > 3
	# W.O.R.D. -> W.O.R.D (if already written with dots, no chance because this probably means that each letter is pronounced separatly)
	sub explode_acronym {
		my $x = shift;
		my @out = ();
		return $x if ($x !~ /[A-Z]/);
		foreach my $t (split(/-/,$x)) {
			# WORD -> Word
			if ($t =~ /[aeiouy]/i && (defined($lexicon{lc($t)}) || defined($lexicon{ucfirst(lc($t))})) && length($t) >= 3) {
				#nothing
			}

			# AFD -> A.F.D.
			else {
				$t =~ s/([A-Z])/$1./g;
			}
			# Recompact long letter sequences since they can probably be
			# pronounced properly
			sub remove_dots {
				my $y = shift;
				$y =~ s/\.//g;
				return $y;
			}
			$t =~ s/((?:[A-Z]\.){6,})/remove_dots($1)/ge;
			push(@out,$t);
		}
		return join('-',@out);
	}

 	#ITunes -> I.Tunes
 	#JCDecaux -> J.C.Decaux
	sub explode_partial_acronym {
		my $x = shift;
		if ((defined($lexicon{lc($x)})
		||   defined($lexicon{lc($x)})
		||   defined($lexicon{ucfirst(lc($x))}))
		&&   length($x) >= 3
		   ) {
		   return $x;
	   }
	   elsif ($x =~ /^([A-Z])([A-Z]+[a-z].*)$/) {
	   	return "$1.".explode_partial_acronym($2);
	   }
	   else {
	   	return $x;
	   }
	}

 	#ITunes -> I.Tunes
 	#JCDecaux -> J.C.Decaux
	sub explode_chemicals {
		my $x = shift;
		our $CHEM;
		return $x if length($x) <= 3;
		my $y = $x;
		my %h = ();
		my $n_comp = 0;
		while ($y =~ s/($CHEM)\d?//) {
			if ($h{$1} == 1) { return $x; }
			else { $h{$1}++; }
			$n_comp++;
		}
		#not sure it's a chemical formula
		$x =~ s/($CHEM)(\d?)/$1.$2/g;
		return $x;
	}


	sub separate_acronyms {
		my $x = shift;
		$x =~ s/-/ /g;
		return $x;
	}

	# .xyz -> xyz
	$$p_text =~ s/(^| )\.([a-z]+)/$1$2/gm;

	# h2g2 -> H2G2
	$$p_text =~ s/(^| )((?:[a-z][0-9])+)(?=$END_SEP|s )/$1.uc($2)/gem;

	#iPad -> I.Pad
	#bTV -> B.TV
	#x3 -> X.3
	$$p_text =~ s/(^| |\b)([a-z])([A-Z0-9])/$1.uc($2).".$3"/gem;


	#Separating acronyms "AFD-CAN" => "AFD CAN"
	$$p_text =~ s/(^| |\b)([A-Z]{2,}(?:-[A-Z]{2,})+)($END_SEP|s )/$1.separate_acronyms($2).$3/gem;


 	#join letter whitin acronyms
 	$$p_text =~ s/(^| |\b)([A-Z0-9]\. ?[A-Z0-9](?:\. ?[A-Z0-9])+)(\.?)(?=$END_SEP|s )/$1.join_acronym($2.$3)/gem;
 	$$p_text =~ s/(^| |\b)([A-Z0-9]-[A-Z0-9](?:-[A-Z0-9])+)(?=$END_SEP|s )/$1.join_acronym($2)/gem;

 	sub except_interjection {
 		my $x = shift;
 		if ($x =~ /^(hm+|brr+|grr+|shh+)$/) {
 			return $x;
 		}
 		else { return uc($x); }
 	}

 	#Uppercase unpronouncable lowercased sequence
 	$$p_text =~ s/(^| |-)([bcdfghjklmnpqrstvwxz]{2,})(?=$END_SEP|s )/$1.except_interjection($2)/gem;

# 	#in order to re-explode them
 	$$p_text =~ s/(^| |\b)([A-Z0-9&]{2}(?:[\-&]?[A-Z0-9]+)*)(?=$END_SEP|-|s'?(?: |\n|$))/$1.explode_acronym($2)/gem;

 	#a&r -> A&R
 	$$p_text =~ s/(^| |-)([a-z])&([a-z])(?=$END_SEP|s )/$1.uc($2).".&".uc($3)."."/gem;

 	# (some) Chemicals
 	# NaCl3O2 -> Na.Cl.3O.2
 	$$p_text =~ s/(^| )((?:(?:$CHEM)[1-9]?){2,})(?=$END_SEP|-|s )/$1.explode_chemicals($2)/gem;

 	#ITunes -> I.Tunes
 	#JCDecaux -> J.C.Decaux
 	#XYz -> X.Yz unless XYz (or a case variant) is in the lexicon
 	$$p_text =~ s/(^| |-)([A-Z][A-Z]+[a-z]+)(?=$END_SEP|-)/$1.explode_partial_acronym($2)/gem;

 	# A-Team -> A.-Team
 	$$p_text =~ s/(^| )([A-Z])-/$1$2.-/gm;

 	# X -> X. (including X's -> X.'s)
 	# except A and I
 	$$p_text =~ s/(^| )([B-HJ-Z])(?=$END_SEP)/$1$2./gm;
 	$$p_text =~ s/(^| )([B-HJ-Z])'S(?= |\n|$)/$1$2.'s/gm;
 	$$p_text =~ s/(^| )([AI])'[sS]/$1$2.'s/gm;

 	# X.Y -> X.Y.
 	$$p_text =~ s/([A-Z]\.[A-Z])(?=$END_SEP)/$1./gm;

 	# the X.'s -> the X.s
 	$$p_text =~ s/(^| )([a-z]+) ([A-Z]\.)'s(?=$END_SEP)/$1$2 $3s/gm;

 	# A's -> A.'s
 	$$p_text =~ s/(^| )(A)'s(?=$END_SEP)/$1$2.'s/gm;


 	# Xs -> X.s
 	# except As, Es, Is, Os, Us
 	$$p_text =~ s/(^| )([B-DF-HJ-NP-TVZ])s(?=$END_SEP)/$1$2.s/gm;

# 	# Z.Y.X.s -> Z.Y.X.s
# 	$$p_text =~ s/([A-Z]\.)s(?=$END_SEP)/$1s/gm;

 	$$p_text =~ s/([A-Z0-9])\. '/$1.'/gm;

	trim_blanks($p_text);

}




##################################################################
# HYPHENATION
##################################################################



sub hyphenate {
	my $p_text = shift;
	our $DASH_SYM = "XYZDASHZYX";

	$$p_text =~ s/(^| )-([^ \d]+?)(?=$| |\n)/$1 $2/g; #no dash at the beginning of a word before hyphenation

	$$p_text =~ s/--+/ - /g;
	$$p_text =~ s/ +- +/ /g;
	$$p_text =~ s/^- +/ /gm;
	$$p_text =~ s/(\d)-(\d)/$1 $2/g;



	sub dash_cut_or_not {
		my $w = shift;
		our $DASH_SYM;

		# if bracketed by dashes, remove
		if ($w =~ /^-.*-$/) {
			return $w;
		}

		# if proper name, keep it (Abla-Bla or Ad-777 but not Asp-irine)
		elsif ($w =~ /^[A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]\.?.*-[A-Z09]/) {
			$w =~ s/-/$DASH_SYM/g;
			return $w;
		}

		# if in-vocabulary (common noun) word keep it
		elsif (defined($lexicon{$w})) {
			$w =~ s/-/$DASH_SYM/g;
			return $w;
		}

		# if split word, eg, exam-ple, remove dash
		elsif ($w =~ /^((?:.+-)*)(.+?)-(.+?)(?:'s?)?$/ && (defined($lexicon{$2.$3}) || defined($lexicon{lc($2.$3)}))
		) {
			$w = $1.$2.$3;
		}

		# suffixes ...
		if ($w !~ /^-[^-]+$/ && $w !~ /^[^-]+-$/) {
			my @tab = split(/-/,$w);
			$w = shift(@tab)." ".join(" ",reverse map {dash_cut_or_not("-".$_)} reverse @tab);
			#... and prefixes
			$w =~ /^(.*?) (.*)$/;
			@tab = split(/-/,$1);
			$w = join(" ", map {dash_cut_or_not($_."-")} @tab)." ".$2;
		}

		return $w;
	}
	#no dash at the beginning of a word
	#$$p_text =~ s/(^| |\n)-([A-Za-z])/$1$2/gm;
	#process when dash is in the middle of a word
	$$p_text =~ s/(^| |\n)([^ \n]+)((?:-[^ \n]+)+)(?=$| |\n)/$1.dash_cut_or_not($2.$3)/gem;
	#no dash at the end of proper names
#	$$p_text =~ s/([A-Z][^ \n]+)-($| |\n)/$1$2/gm;

	$$p_text =~ s/-/ /gm; #replace remaining dash with blanks

	$$p_text =~ s/ *$DASH_SYM/-/gm; #back to normal dashes
	trim_blanks($p_text);

}




sub split_entities {
	my $p_text = shift;
	my %liste;
	foreach my $f (@_) {
		open(F, "<$f") or die("Unable to open $f.\n");
		while (<F>) {
			chomp;
			s/\(/(?:/g;
			s/\+/\+/g;
			$liste{$_} = 1
		}
		close(F);
	}


	my $big_ER = join("|", keys(%liste));

	$$p_text =~ s/(^| )($big_ER)(?: ?- ?($big_ER))(?=$END_SEP)/$1$2 $3/g;
	return;
}





##################################################################
# APOSTROPHES
##################################################################


sub apostrophes {
	my $p_text = shift;
	our $APO_SYM = "XXXAPOSTROPHEXXX";
	$$p_text =~ s/([A-Za-z0-9])' s(\b)/$1's$2/g;
	$$p_text =~ s/([A-Za-z0-9]) 's(\b)/$1's$2/g;

	# ' <LOCATION> Dummy City </LOCATION> '
	#      -> <LOCATION> 'Dummy City' </LOCATION> streets
	$$p_text =~ s/(^| )' (<([A-Z]+)>) (.+) (<\/\3>) '($END_SEP)/$1$2 $4 $5 $6/gm;

	# <LOCATION> London </LOCATION> 's streets
	#      -> <LOCATION> London's </LOCATION> streets
	# but this can be broken by the specific normalisation
	$$p_text =~ s/ (<\/[A-Z]+>) +'([a-z]{1,2})($END_SEP)/'$2 $1$3/gm;
	$$p_text =~ s/ (<\/[A-Z]+>) +'( |$|\n)/' $1$2/gm;


	$$p_text =~ s/ 's(\b)/ ${APO_SYM}s$2/g;
	$$p_text =~ s/(^| )'(.+)'($END_SEP)/$1$2$3/gm;
	$$p_text =~ s/(^| )'(.+)'($END_SEP)/$1$2$3/gm;
	$$p_text =~ s/ '(d|ve|re|ll|s)($END_SEP)/ ${APO_SYM}$1$2/gm;
	$$p_text =~ s/(^| )(?:(l|d|qu)'(une?))($END_SEP)/$1$2${APO_SYM}$3$4/gm;


	sub apo_cut_or_not {
		my $w = shift;
		our $APO_SYM;
#		print STDERR "$w\n";

		#si proper name, keep it
		if ($w =~ /^[A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]/) {
			$w =~ s/'/$APO_SYM/g;
#		print STDERR "B\n";
			return $w;
		}
		#si in-vocabulary (common noun) word keep it
		elsif (defined($lexicon{$w})) {
			$w =~ s/'/$APO_SYM/g;
#		print STDERR "C\n";
			return $w;
		}
		# Saxon genitive of a word ending with a s
		# or negation contraction
		elsif ($w =~ /'[st]$/) {
#		print STDERR "D\n";
			$w =~ s/'([st])/${APO_SYM}$1/g;
			return $w;
		}
		# Saxon genitive on a plural noun
		elsif ($w =~ /s'$/) {
#		print STDERR "D\n";
			$w =~ s/s'/s${APO_SYM}/g;
			return $w;
		}
		# split
		elsif ($w !~ /^'[^']+$/) {
			my @tab = split(/'/,$w);
#		print STDERR "E\n";
			return (shift @tab)." ".join(" ",map {apo_cut_or_not("'".$_)} @tab);
		}
		else {
#				print STDERR "F\n";
			return $w;
		}
	}
	$$p_text =~ s/(^| |\n)([^^ \n]+)('[^ \n]*)+/$1.apo_cut_or_not($2.$3)/gem;
	$$p_text =~ s/'/ /gm; #replace remaining apostrophes with blanks
	$$p_text =~ s/$APO_SYM/'/gm; #back to normal apostrophes

	$$p_text =~ s/(^| )(he|she) '(d|ll|s)($END_SEP)/$1$2'$3$4/gm; #he/she
	$$p_text =~ s/(^| )(we|you|they) '(d|ll|re|ve)($END_SEP)/$1$2'$3$4/gm; #we/you/they
	$$p_text =~ s/(^| )(I) '(d|ll|m|ve)($END_SEP)/$1$2'$3$4/gm; #I

	#apostrophe at the end of the word which does not end with s
	$$p_text =~ s/S'(?= |\n|$)/S's /gm;
	$$p_text =~ s/([^Ss])'(?= |\n|$)/$1/gm;
}



##################################################################
# NAMED ENTITY TAGGING (using Stanford's NE tagger)
##################################################################

sub tag_ne {
	my $P_TEXT = shift;
# 	open(TMP,"> /tmp/tmp_in_$$");
# 	print TMP $$P_TEXT;
# 	close(TMP);
# 	system("nice bash ./tag-named-entities.sh /tmp/tmp_in_$$ > /tmp/tmp_out_$$");
# 	open(TMP,"< /tmp/tmp_out_$$");
# 	$$P_TEXT = "";
# 	while (<TMP>) {
# 		$$P_TEXT .= $_;
# 	}
# 	close(TMP);
# 	system("rm -f /tmp/tmp_in_$$ /tmp/tmp_out_$$");
	$$P_TEXT =~ s/ (<\/[A-Z]+>) +((?:XV|XI|XX|X)+V*(?:II|IV|IX|I)*)($END_SEP)/ $2$3 $1 /gm;
	$$P_TEXT =~ s/(^| )Saint +<PERSON> +([A-Z])/$1<PERSON> Saint $2/gm;
	trim_blanks($P_TEXT);
}



#######################################
# REMOVE DIACRITICS (ASCII)
#######################################
sub remove_diacritics {
	my $s = shift;

	$s =~ s/\xe4/ae/g;  ##  treat characters ä ñ ö ü ÿ
	$s =~ s/\xf1/ny/g;  ##  this was wrong in previous version of this doc
	$s =~ s/\xf6/oe/g;
	$s =~ s/\xfc/ue/g;
	$s =~ s/\xff/yu/g;



	#$s = Encode::decode( 'utf8', $s );
	$s = NFD( $s );   ##  decompose (Unicode Normalization Form D)
	$s =~ s/\pM//g;         ##  strip combining characters


	$s =~ s/\x{00df}/ss/g;  ##  German beta “ß” -> “ss”
	$s =~ s/\x{00c6}/AE/g;  ##  Æ
	$s =~ s/\x{00e6}/ae/g;  ##  æ
	$s =~ s/\x{0132}/IJ/g;  ##  Ĳ
	$s =~ s/\x{0133}/ij/g;  ##  ĳ
	$s =~ s/\x{0152}/Oe/g;  ##  Œ
	$s =~ s/\x{0153}/oe/g;  ##  œ
	$s =~ s/\x{0259}/e/g;  ## ə
	$s =~ s/\x{018f}/e/g;  ## Ə
	$s =~ s/\x{2019}/'/g;  ## ’
	$s =~ tr/\x{00d0}\x{0110}\x{00f0}\x{0111}\x{0126}\x{0127}/DDddHh/; # ÐĐðđĦħ
	$s =~ tr/\x{0131}\x{0138}\x{013f}\x{0141}\x{0140}\x{0142}/ikLLll/; # ıĸĿŁŀł
	$s =~ tr/\x{014a}\x{0149}\x{014b}\x{00d8}\x{00f8}\x{017f}/NnnOos/; # ŊŉŋØøſ
	$s =~ tr/\x{00de}\x{0166}\x{00fe}\x{0167}/TTtt/;                   # ÞŦþŧ

	# additional normalizations:
#	$s =~ s/[^[:alnum:]\.,;:\?!\-\+\*'"\$£¥%€&#=@°\(\)\/<>²³\n]/ /g;
#	$s =~ s/[^[:alnum:]\.,;:\?!\-\+\*'"\$£¥%€&#=@°\(\)\/<>²³\n ]//g;  ##  clear everything else; optional

	return $s; #Encode::encode_utf8($s);;
}


##################################################################
# SPECIAL STUFF (bugs, end of processing...)
##################################################################




# Removes some bugs common to all sources.
sub remove_bugs {
 	my $p_text = shift;
# 	return $text;

	#German character ß
	$$p_text =~ s/ ß-/ beta-/gm;
	$$p_text =~ s/(\w)ß(\w)/ss/gm;

	#uppercase some lowercase roman numerals
	$$p_text =~ s/(^| |\b)((?:xl|lx|xv|xi|xx|x)+v*(?:ii|iv|ix|i)*)($END_SEP)/$1.uc($2).$3/gem;

	#Euro sign
	$$p_text =~ s/€/ EUR /gm;
	#& sign
	$$p_text =~ s/ & / and /gm;

	# Wikipedia patch
	$$p_text =~ s/^\d{8,}([A-Z])/$1/gm;

	#
	$$p_text =~ s/'+/'/gm;

	#
	$$p_text =~ s/'sa /'s a /gm;

	$$p_text =~ s/%/ % /g;
	while ($$p_text =~ /(^| )(\d+)[xX](?=\d+(?=×|x|X|\/| |$))/) {
		$$p_text =~ s/(^| )(\d+)[xX](?=\d+(?=×|x|X|\/| |$))/$1$2 x /gm;
	}

	$$p_text =~ s/(\d)(century|army)(?= |$)/$1th $2/g;

   	$$p_text =~ s/(\w)\(/$1 (/g;			# eg. x( -> x (
   	$$p_text =~ s/\)(\w)/) $1/g;			# eg. )x -> ) x;

   	$$p_text =~ s/(\d)\((\d)/$1 ($2/g;			# \d(\d
   	$$p_text =~ s/(\d)\)(\d)/$1) $2/g;			# \d)\d;
   	$$p_text =~ s/([a-zA-Z]{2,}\.)(\d)/$1 $2/g;		# eg. Sept.30
   	$$p_text =~ s/,([a-zA-Z])/, $1/g;			# eg. 20,Smith
   	$$p_text =~ s/(\W)milion(\W)/$1million$2/g;		# spelling err

   	$$p_text =~ s/(\W&\s*)Co([^\w\.-])/$1Co.$2/g;		# "& Co" -> "& Co."
   	$$p_text =~ s/(\WU\.S)([^\.\w])/$1.$2/g;		# U.S -> U.S.

    # next block added for Broadcast News archive processing
   	$$p_text =~ s/\$ +(\d)/\$$1/g;		# e.g. "$ 5" -> "$5"
   	$$p_text =~ s/\$\#/\$/g;		# e.g. "$#5" -> "$5" (typo??)
   	$$p_text =~ s/ \#(\d+)( |\n|b)/ number $1$2/gm;		# in bc-news, "#" = "number" not "pound"
    $$p_text =~ s=([^\s</])(/+)\s=$1 $2 =g;	# e.g. "2002/ " -> "2002 / "
    $$p_text =~ s=([0-9])/1,000([^0-9,])=$1/1000$2=g; # e.g. "1/1,000" -> "1/1000"

    $$p_text =~ s/\n\. 's /'s /gm; # Wright\n\. 's -> Wright's
    $$p_text =~ s/ 's /'s /gm;

   	$$p_text =~ s/[\t ]+/ /g;
	$$p_text =~ s/^ //gm;
	$$p_text =~ s/ $//gm;

 	trim_blanks($p_text);
	return;
}



sub process_ing {
	my $p_text = shift;
	sub ing_or_not {
		my $x = shift;
		if (defined(lc($lexicon{$x."g"}))) { return $x."g"; }
		else { return $x."'"; }
	}
	$$p_text =~ s/(^| )([[:alpha:]]+in)'(?=$END_SEP)/$1.ing_or_not($2)/giem;
	$$p_text =~ s/(^| )([[:alpha:]]+)'ing(?=$END_SEP)/$1$2ing/gim;
}


sub process_d {
	my $p_text = shift;
	sub d_or_not {
		my $x = shift;
		if ($x =~ /^(I|you|he|she|we|they|one)$/i) {
			return "$1'd";
		}
		elsif ($x =~ /e$/) {
			return "${x}d";
		}
		else {
			return "${x}ed";
		}
	}
	# xyz 'd
	$$p_text =~ s/(^| )([a-z]+) ?'d(?=$END_SEP)/$1.d_or_not($2).$3/gem;
	return;
}


sub triple_lettre {
	my $p_text = shift;
	$$p_text =~ s/(\w)([a-záâãäåçèéêëìíîïñòóôõöøùúûüý])\2\2+/$1$2$2/g;
	$$p_text =~ s/([a-záâãäåçèéêëìíîïñòóôõöøùúûüý])\1\1+(\w)/$1$1$2/g;
	return;
}

sub compact_initials {
	my $p_text = shift;
	$$p_text =~ s/H \. M/H. M/g;
	$$p_text =~ s/(^|\s|-)([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]) \. ([\.,:;\-!\?])/$1$2. $3/gm;
	$$p_text =~ s/(^|\s|-)([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]) \. ([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ][a-zàáâãäåçèéêëìíîïñòóôõöøùúûüý]+)( \.| ,| :| ;| \-| !| \?|$)/$1$2. $3$4/gm;

	sub decision_compact {
		my ($a, $b) = @_;
		if (process_first_letter($b) == 1) {
			return "$a . $b";
		}
		else {
			return "$a. $b";
		}
	}
	$$p_text =~ s/(^|\s|-)([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]) \. ([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ][a-zàáâãäåçèéêëìíîïñòóôõöøùúûüý]+) (?!\.| ,|:|;|\-|!|\?)/$1.decision_compact($2,$3)." ".$4/gem;

	sub sequence_initials {
		my $seq = shift;
		$seq =~ s/([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]\.?) (\-[A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ])/$1$2/g;
		$seq =~ s/([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]) (\.)/$1$2/g;
		return $seq;
	}
	$$p_text =~ s/(^| |-)((?:\-?[A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ] ?\.(?: |$)){2,})/$1.sequence_initials($2)/gem;
	$$p_text =~ s/([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ])\. -([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]\.)(?= |$)/$1.-$2/gm;
	$$p_text =~ s/([a-zàáâãäåçèéêëìíîïñòóôõöøùúûüý]) -([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]\.)(?= |$)/$1 $2/gm;

	$$p_text =~ s/([a-zàáâãäåçèéêëìíîïñòóôõöøùúûüý]+)(,|;|!|\?)/$1 $2/gm;
	return;
}








sub remove_tags {
	my $P_TEXT =  shift;
	# misbuilt tags
	sub allowed_tags {
		my $x = shift;
		if ($x !~ /^<\/?$ALLOWED_TAGS>$/) {
			return " ";
		}
		else { return $x; }
	}
	$$P_TEXT =~ s/[<>]{2,}/ /gm;
	$$P_TEXT =~ s/( |^)<[^>]+?($END_SEP)/$1$2/gm;
	$$P_TEXT =~ s/( |^)(<\/?[^>]+>+)($END_SEP)/$1.allowed_tags($2).$3/gem;

}







sub end {
	my $P_TEXT = shift;
	$$P_TEXT =~ s/([a-zàáâãäåçèéêëìíîïñòóôõöøùúûüý]) \ ([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ])/$1 and $2/g;
	$$P_TEXT =~ s/([A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ]) \+ ?/$1 plus/g;
	$$P_TEXT =~ s/\+/ /g;
	$$P_TEXT =~ s/^%//gm;
	$$P_TEXT =~ s/&amp/ & /gm;
	$$P_TEXT =~ s/ ý/ /g;
	$$P_TEXT =~ s/^Page /page /gm;

	$$P_TEXT =~ s/(^| )(\d+)[Aa]nd /$1$2 and /g;
	$$P_TEXT =~ s/(^| )(\d+)[Tt]he /$1$2 the /g;

	$$P_TEXT =~ s/$YEAR_MARK/ /gmi;

	# .html -> dot html ; .HTM -> dot htm
	$$P_TEXT =~ s/(^| )\.([a-z]+)(?=$END_SEP)/"$1 dot ".lc($2)/gemi;
	$$P_TEXT =~ s/(^| |[^A-Za-z])\.([a-z]+)(?=$END_SEP)/"$1 . ".lc($2)/gemi;


	$$P_TEXT =~ s/(^| )\.+([^\. ]+)\.+(?=$END_SEP)/$1$2/gm;


	#remove dots at the beginning anything but space
	$$P_TEXT =~ s/(^| )\.([^\. \n])/$1$2/gm;


	#remove dots just after words (no space in between)
	$$P_TEXT =~ s/([a-z]{2,})\.(?=$END_SEP)/$1/gm;

	$$P_TEXT =~ s/;/,/g;

	$$P_TEXT =~ s/[^A-ZÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝa-zàáâãäåçèéêëìíîïñòóôõöøùúûüýÿ0-9'_"\+\-\!,;:¡¿\?\.\nß&<>\/ \(\)]/ /g;
	$$P_TEXT =~ s/(?<!<)\// /g;
	$$P_TEXT =~ s/ & / and /g;
	$$P_TEXT =~ s/ &+/ /gm;
	#$$P_TEXT =~ s/"/ /gm;
	$$P_TEXT =~ s/(^| )'([0-9a-zA-Z]\.?)(?=$END_SEP)/$1$2/gm;
	$$P_TEXT =~ s/(^| )\.([0-9])/$1$2/gm;
	$$P_TEXT =~ s/([0-9])>(?= |\n|$)/$1/gm;

	trim_blanks($P_TEXT);

	# Remove undesired characters
	#$$P_TEXT = Encode::decode_utf8($$P_TEXT);
	$$P_TEXT =~ s/( |^)[^[:alpha:]"\.\?!,;\(\) ]($END_SEP) /$1 $2/gm;
	$$P_TEXT =~ s/( |^)[^[:alnum:]"\-'<ß\.\?!,;\(\) \n]/$1/gm;
	$$P_TEXT =~ s/[^[:alnum:]"\-'>\.\?\!,; \n\(\)]( |$)/ $1/gm;
	$$P_TEXT =~ s/( |^)([^<]+)>( |\n|$)/$1$2$3/gm;
#	$$P_TEXT =~ s/( |^)<([^>]+?)( |\n|$)/$1$2$3/gm;
#	$$P_TEXT =~ s/( |^)([^< ]+?)>( |\n|$)/ $1$2/gm;
	#$$P_TEXT = Encode::encode_utf8($$P_TEXT);

	#no hyphen between spaces at the beginning/end of a proper name or number
	$$P_TEXT =~ s/(^| )- /$1/gm;
	$$P_TEXT =~ s/ -$/$1/gm;
	$$P_TEXT =~ s/(^| |\b)([A-Z0-9]\.?(?:[a-zA-Z0-9\-]\.?)+)-( |\n|$)/$1$2$3/gm;
	$$P_TEXT =~ s/(^| )-([A-Z0-9]\.?(?:[a-zA-Z0-9\-]\.?)+)( |\b|\n|$)/$1$2$3/gm;

	#make sure Saxon genitives are not segmented
	$$P_TEXT =~ s/ ([\!\?\.]) '([a-z]{1,2})($END_SEP)/'$2 $1 $3/gm;
	$$P_TEXT =~ s/ (<\/[A-Z]+>) *'([a-z]{1,2})($END_SEP)/'$2 $1 $3/gm;
	$$P_TEXT =~ s/ '([st])($END_SEP)/'$1$2/gm;
	trim_blanks($P_TEXT);

	# /xXx -> slash xXx
	$$P_TEXT =~ s/(^| )\//$1 slash/gm;

	#xXxtv -> xXx-T.V.
	$$P_TEXT =~ s/(^| )([[:alnum:]]+)[Tt]][Vv](?=$END_SEP)/$1$2T.V./gm;

	# digits 2 letters if remaining single numbers
	$$P_TEXT =~ s/(^| )(\d+(?:[\.,]\d+)*)(?=$END_SEP)/$1.num2en($2)/gem;

	#double dots are replaced by single dots
	$$P_TEXT =~ s/([^\.])\.\.([^\.])/$1.$2/gm;
	#uppercase every single letter (except 'a') : b -> B.
	$$P_TEXT =~ s/(^| )([b-z])(?=$END_SEP)/"$1".uc($2)."."/gem;
	#uppercase every single letter followed by a dot (no exception) : a. -> A.
	$$P_TEXT =~ s/(^| )([a-z]\.)(?=$END_SEP)/"$1".uc($2)/gem;
	#add a dot after every single uppercase letter (except A and I) : B -> B.
	$$P_TEXT =~ s/(^| |-)([B-HJ-Z])(?=$END_SEP)/$1$2./gm;
	#lowercase acronyms along with numbers
	# 09rwt -> 09R.W.T.
	sub f {
		my $x = shift;
		$x =~ s/([A-Z])/$1./g;
		return $x;
	}
	$$P_TEXT =~ s/(^| )(\d+)([a-z]+)(?=$END_SEP)/"$1$2".f(uc($3))/gem;

	# A\.' -> A\.
	# A' -> A\.
	$$P_TEXT =~ s/(^| )([A-Z]\.)'(?= |\n|$)/$1$2./gm;
	$$P_TEXT =~ s/(^| )([A-Z])'(?= |\n|$)/$1$2./gm;

	$$P_TEXT =~ s/ - / /g;
	$$P_TEXT =~ s/ -$//gm;
	$$P_TEXT =~ s/^- //gm;

	trim_blanks($P_TEXT);
}





1;
