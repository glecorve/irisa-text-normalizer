#!/usr/bin/perl
#
# NormalisationOptions.pm
# Many functions to process a vocabulary and counts
#
# July, 2011
# Gwénolé Lecorvé
# 
########################################################

package NormalisationOptions;


use strict;
#use CorpusNormalisation;
#use Lingua::EN::Numbers qw(num2en num2en_ordinal);
use List::Util qw[min max];
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter);
BEGIN {
  @EXPORT = qw(%OPTIONS &read_config &read_vocab &is_active_option);
}

our %OPTIONS = (
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
	"ACRONYMS_DOT" => ["Unpronoucable acronyms are considered as single words whose letters are separated with dots."],
	"ACRONYMS_JOINT" => ["Acronyms are joint into plain words (eg, P.C.A. -> PCA)"],
	"ACRONYMS_EXPLODED" => ["Acronyms are exploded into single letters (eg, P.C.A. -> P. C. A.)."],
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


1;
	
