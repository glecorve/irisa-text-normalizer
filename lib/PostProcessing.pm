#!/usr/bin/perl
#
# Many functions to post-process generically normalized texts
#
# July, 2011
# Gwénolé Lecorvé
#
########################################################

package PostProcessing;


use strict;
#use CorpusNormalisation;
#use Lingua::EN::Numbers qw(num2en num2en_ordinal);
use List::Util qw[min max];
use Exporter;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/../../lib";
use RulesApplication;
use File::Temp qw/ tempfile tempdir /;

use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter);
BEGIN {
  @EXPORT = qw($TEXT $VERBOSE $CLASSPATH $TMPDIR @protected %OPTIONS %option2function &read_config &read_vocab &is_active_option &protect_words &unprotect_words &write_tags &PUNCTUATION_ON &PUNCTUATION_OFF &WEAK_PUNCTUATION_OFF &BREAK_LINES &TAGS_ON &TAGS_OFF &TAGS_INLINE &HYPHENS_ON &HYPHENS_INTERNAL &HYPHENS_OFF &pronounceable_acronym &ACRONYMS_DOTTED &ACRONYMS_JOINT &LETTER_DOTS_ON &LETTER_DOTS_OFF &SAXON_GENITIVES_JOINT &SAXON_GENITIVES_JOINT_IF_POSSIBLE &SAXON_GENITIVES_EXPLODED &SPELLING_BRITISH &SPELLING_AMERICAN &CASE_ON &EXTERNAL_SCRIPT);
}

our $TEXT = "";

our $VERBOSE = 0;
our @protected = ();
our $CLASSPATH=".";
our $TMPDIR="/tmp";

my $EN_RSRC = dirname( abs_path(__FILE__) )."/../rsrc/en";

my $weak_punct = "\x{C2}\x{A1}|\x{C2}\x{BF}|,|;|:|\\\"|\\)|\\(";
my $strong_punct = "\\.\\.\\.|\\?|!|\_|\\.";
my $all_punct = "\\.\\.\\.|\x{C2}\x{A1}|\x{C2}\x{BF}|,|;|:|\\\"|\\)|\\(|\\?|!|\_|\\.";

our %OPTIONS = (
  "PUNCTUATION_ON" => ["Keep all punctuation marks."],
  "PUNCTUATION_OFF" => ["Get rid of all punctuation marks"],
  "WEAK_PUNCTUATION_OFF" => ["Get rid of weak punctuation marks (',', ';', ':', '('; ')', '¡', '¿')"],
  "BREAK_LINES" => ["Break lines at sentences boundaries (strong punctuation marks)"],
	"TAG_ON" => ["The body of tags is replaced by the sole tag. These bodies are stored in separate files, one file per tag."],
	"TAGS_OFF" => ["All the tags are removed (only the tags, not their body)"],
	"TAGS_INLINE" => ["Tags and bodies are kept without any further processing."],
	"TAGS_NO_TIME" => ["Time tags are removed."],
	"TAGS_NO_DATE" => ["Date tags are removed."],
	"TAGS_NO_QUANTITY" => ["Quantity tags are removed."],
	"TAGS_NO_CURRENCY" => ["Currency tags are removed."],
	"TAGS_NO_PERSON" => ["Person tags are removed."],
	"TAGS_NO_LOCATION" => ["Location tags are removed."],
	"TAGS_NO_URL" => ["URL tags are removed."],
	"TAGS_NO_PHONE" => ["Phone number tags are removed."],
	"TAGS_NO_ORGANIZATION" => ["Organization tags are removed."],
	"HYPHENS_ON" => ["All the hyphens are kept."],
	"HYPHENS_INTERNAL" => ["Only middle-of-words hyphens of common words (ie, not proper names) are kept, others are removed."],
	"HYPHENS_OFF" => ["All the hyphenations are removed."],
	"ACRONYMS_READABLE_JOINT" => ["Unpronoucable acronyms are considered as sequences of letters."],
  "ACRONYMS_READABLE_EXPLODED" => ["Unpronoucable acronyms are considered as single words whose letters are separated with dots."],
  "ACRONYMS_DOTTED" => ["Acronyms are kept as single words whose letters are separated by dots (eg, P.C.A.)"],
	"ACRONYMS_JOINT" => ["Acronyms are joint into plain words (eg, P.C.A. -> PCA)"],
	"ACRONYMS_EXPLODED" => ["Acronyms are exploded into single letters (eg, P.C.A. -> P. C. A.)."],
  "LETTER_DOTS_ON" => ["Keep dots along with single letters (B. -> B)."],
  "LETTER_DOTS_OFF" => ["Single letters are not followed by a dot (B. -> B)."],
	"SAXON_GENITIVES_JOINT" => ["Saxon genitives are kept along with their basis. By using this option, Saxon genitives will NEVER be split even during OOV minimisation."],
	"SAXON_GENITIVES_JOINT_IF_POSSIBLE" => ["Saxon genitives are kept along with their basis, except for tokens which are out of vocabulary. In this case, split it."],
	"SAXON_GENITIVES_EXPLODED" => ["Saxon genitives are separated from their basis (foo's -> foo 's ; United States' -> United States 's)."],
	"CASE_ON" => ["Keep the case."],
	"CASE_OFF" => ["Capitalize everything."],
	"CASE_LOW" => ["Downcase everything."],
	"SPELLING_BRITISH" => ["Use British spellings."],
	"SPELLING_AMERICAN" => ["Use American spellings."],
	"EXTERNAL_SCRIPT=.*" => ["Use an external script to process the text. Refer to the text as {TEXT} within your command line. Eg, 'perl /my/script.pl {TEXT} | cut -f2'"]
	);


my %activated_options = ();


sub read_config {
	my $f = shift;
	my @config = ();
	my $i = 0;
	my $regexp = join("|",sort keys %OPTIONS);
	open(INPUT, "< $f") or die("Unable to open file $f.\n");
	while(<INPUT>) {
		chomp;
		if ($_ ne "" && $_ !~ /^\s*#/) {
			if ($_ =~ /^$regexp$/i) {
				push(@config,$_);
				my $opt = $_;
				$opt =~ s/^(.*?)( .*)$/$1/;
				$activated_options{$opt} = 1;
				$i++;
			}
			else {
				warn("Wrong option $_. Ignored.\n");
			}
		}
	}
	close(INPUT);
	return @config;
}


sub read_vocab {
	my $f = shift;
	my @words = ();
	open(V, "< $f") or die("Unable to open vocabulary file $f.\n");
	while(<V>) {
		chomp;
		push(@words, $_);
	}
	close(V);
	return @words;
}


sub is_active_option {
	my $opt = shift;
	return defined($activated_options{$opt});
}



our %option2function = (
	"TAG_NO_TIME" => "NO_X_TAG('TIME')",
	"TAG_NO_DATE" => "NO_X_TAG('DATE')",
	"TAG_NO_QUANTITY" => "NO_X_TAG('QUANTITY')",
	"TAG_NO_CURRENCY" => "NO_X_TAG('CURRENCY')",
	"TAG_NO_PERSON" => "NO_X_TAG('PERSON')",
	"TAG_NO_LOCATION" => "NO_X_TAG('LOCATION')",
	"TAG_NO_URL" => "NO_X_TAG('URL')",
	"TAG_NO_PHONE" => "NO_X_TAG('PHONE')",
	"TAG_NO_ORGANIZATION" => "NO_X_TAG('ORGANIZATION')",
	"TAG_NO_ORGANIZATION" => "NO_X_TAG('ORGANIZATION')",
	);




sub trim_blanks {
	$TEXT =~ s/ +/ /g;
	$TEXT =~ s/ $//gm;
	$TEXT =~ s/^ //gm;
}

sub protect_words {
	foreach my $w (@protected) {
		if (is_active_option('CASE_OFF')) {
			$TEXT =~ s/(^| |\n)($w)(?= |\n|$)/$1_$2_/gim;
		}
		else {
			$TEXT =~ s/(^| |\n)($w)(?= |\n|$)/$1_$2_/gm;
		}
	}
}

sub unprotect_words {
	foreach my $w (@protected) {
		if (is_active_option('CASE_OFF')) {
			$TEXT =~ s/(^| |\n)_($w)_(?= |\n|$)/$1$2/gim;
		}
		else {
			$TEXT =~ s/(^| |\n)_($w)_(?= |\n|$)/$1$2/gm;
		}
	}
}

sub compact_saxon_genitive {
	$TEXT =~ s/ 's/'s/g;
}

my %class = ();

sub write_tags {
	foreach my $k (keys %class) {
		$VERBOSE && print STDERR "Writing class $k into $CLASSPATH/".lc($k).".class...";
		open(F, "> $CLASSPATH/".lc($k).".class") or die ("Unable to open $CLASSPATH/".lc($k).".class\n");
		my $i = 0;
		foreach my $seq (@{$class{$k}}) {
			print F $seq."\n";
			$i++;
		}
		close(F);
		$VERBOSE && print STDERR " OK ($i elements written).\n";
	}
}

####################################################
# OPTION FUNCTIONS
####################################################

sub PUNCTUATION_ON {
  # Nothing to do
}

sub PUNCTUATION_OFF {
  $TEXT =~ s/ ($all_punct)(?= )/ /g;
  $TEXT =~ s/^($all_punct)(?= )//gm;
  $TEXT =~ s/ ($all_punct)$//gm;
  trim_blanks();
}

sub WEAK_PUNCTUATION_OFF {
  $TEXT =~ s/ ($weak_punct)(?= )/ /g;
  $TEXT =~ s/^($weak_punct)(?= )//gm;
  $TEXT =~ s/ ($weak_punct)$//gm;
  trim_blanks();
}

sub BREAK_LINES {
  while ($TEXT =~ s/( (?:${strong_punct})) / $1\n /) { }
  $TEXT =~ s/^ +//gm;
  while ($TEXT =~ s/($strong_punct)\n($strong_punct)/$1 $2/g) { }
  trim_blanks();
}

sub TAGS_ON {
	sub store {
		my $c = shift;
		my $w = shift;
		if (!defined($class{$c})) {
			@{$class{$c}} = ();
		}
		push(@{$class{$c}}, $w);
		return "";
	}
	$TEXT =~ s/<([A-Z]+)> (.*?) <\/\1>/"<$1>".store($1,$2)/ge;
}


sub TAGS_OFF {
	$TEXT =~ s/ ?<\/?[A-Z]+> ?/ /g;
	compact_saxon_genitive();
}


sub TAGS_INLINE {
	#nothing to do
}


sub NO_X_TAG {
	my $x = shift;
	$TEXT =~ s/ ?<\/?$x> ?/ /g;
	compact_saxon_genitive();
}



sub HYPHENS_ON {
	#nothing to do
}


sub HYPHENS_OFF {
	$TEXT =~ s/-/ /g;
}


sub HYPHENS_INTERNAL {
	$TEXT =~ s/(^| )-/$1/gm;
	$TEXT =~ s/-( |\n|$)/$1/gm;
}

# Check if an acronym is (easily) readable
sub pronounceable_acronym {
  my $w = shift;
  my $V = "[AEIOUY]";
  my $C = "[BCDFGHJKLMNPQRSTVWXZ]";
  my $C_cluster = "[PBGKCF][LR]|[TD][RW]|SK[RW]?|S[LMN]|SP[LR]?|[STDKCG]W|S?CH|SH";
  my $C_cluster_final = "[FKCLP]T|L[DKPBJM]|LCH|M[PF]|N[TD]|P[ST]|S[KTP]";
  # Remove dots
  $w =~ s/\.//g;
  # No vowel => not prounuceable
  if (length($w) > 1 && $w !~ /$V/) { return 0; }
  # Too short => not prounuceable
  elsif (length($w) < 3) { return 0; }
  # Too long => assume it's a word => prounuceable
  elsif (length($w) > 6) { return 0; }
  return ($w =~ /^(?:(?:$C_cluster|$C)?$V$V?)+(?:$C_cluster_final|$C)?$/);
}

sub ACRONYMS_DOTTED {
  # Nothing to do
}

sub ACRONYMS_JOINT {
	sub rejoin {
		my $x = shift;
		$x =~ s/\.//g;
		return $x;
	}
	$TEXT =~ s/((?:[A-Z]\.\-?|[0-9]\-?|){2,})/rejoin($1)/ge;
	$TEXT =~ s/([A-Z])\.(\-?[A-Z])/$1$2/g;
}

sub LETTER_DOTS_ON {
  # Nothing to do
}

sub LETTER_DOTS_OFF {
  $TEXT =~ s/(^| )([^\.])\.(?= |$)/$1$2/gm;
}

sub SAXON_GENITIVES_JOINT {
	#nothing to do
}

sub SAXON_GENITIVES_JOINT_IF_POSSIBLE {
	#nothing to do
}


sub SAXON_GENITIVES_EXPLODED {
	if (is_active_option('CASE_OFF')) {
		$TEXT =~ s/'s( |\n|$)/ 'S$1/gim;
		$TEXT =~ s/s'( |\n|$)/ 'S$1/gim;
	}
	else {
		$TEXT =~ s/'s( |\n|$)/ 's$1/gim;
		$TEXT =~ s/s'( |\n|$)/ 's$1/gim;
	}
}


sub SPELLING_BRITISH {
	if (is_active_option('CASE_OFF')) {
		define_rule_case_unsensitive();
	}
	apply_rules(\$TEXT, "$EN_RSRC/us2uk.rules");
}

sub SPELLING_AMERICAN {
	# nothing to do
}


sub CASE_ON {
	# nothing to do
}

sub EXTERNAL_SCRIPT {
	my $cmd = shift;
	my ($fh, $filename) = tempfile("spec-norm.XXXXXX", DIR => $TMPDIR, UNLINK => 1);
	print $fh $TEXT;
	close($fh);
	if ($cmd =~ /{TEXT}/) {
		$cmd =~ s/{TEXT}/$filename/g;
	}
	else { $cmd .= " $filename" }
	$VERBOSE && print STDERR "Running external script '$cmd'...";
	eval { $TEXT = `$cmd`};
	die("Error while applying external script '$cmd':\n$@\n") if ($@);
}


1;
