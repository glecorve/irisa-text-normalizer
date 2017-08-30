#!/usr/bin/perl
#
# Derive rules for OOV minimization from counts
#
# Gwénolé Lecorvé <gwenole.lecorve@idiap.ch>
# July, 2011
#

use strict;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/../../lib";
use CorpusNormalisationFr;
use CountProcessingFr;
use PostProcessing;
use Getopt::Long;



$|++; #autoflush

my %all_rules = ();
my %new_rules = ();
my %reverse_rules = ();
my $VOCAB_SIZE = 1;

my @words = ();
my @new_words = ();
my $STEP = 1;
my $RSRC = dirname( abs_path(__FILE__) )."/../../rsrc/fr";
my $LEXICON = "$RSRC/lexicon_en";
my $OUTDIR = ".";
my $MINCOUNT = 0;
my @CLASSES = ();
my $VERBOSE = 0;
my $CONFIG = "";
my $HELP = 0;
my $KEY = "";
my $SKIP_BIGRAMS = 0;



$|++; #autoflush

#
# Process command line
#
Getopt::Long::config("no_ignore_case");
GetOptions(
	"help|h" => \$HELP,
	"config|c=s" => \$CONFIG,
	"min-count|m=i" => \$MINCOUNT,
	"skip-bigrams|B" => \$SKIP_BIGRAMS,
	"verbose|v" => \$VERBOSE
)
or usage();
$#ARGV > 0 or usage();

if ($KEY ne "" && $KEY !~ /^\./) {
	$KEY =".$KEY";
}

usage() if $HELP;


# Read config file in order to prevent from some graphemic modifications

if ($CONFIG ne "") {
	my @cf = read_config($CONFIG);
	if (is_active_option("CASE_OFF")) {
		protect('uppercase');
	}
	if (is_active_option("SAXON_GENITIVES_JOINT")) {
		protect('saxon');
	}
}






sub print_output {
	print STDERR "------------------------\n" if $VERBOSE;
	print STDERR "WRITING ALL RULES\n" if $VERBOSE;
	foreach my $k (keys %all_rules) {
		print safe_print($k,$all_rules{$k});
	}
}


##############


load_lexicon($LEXICON);
$VOCAB_SIZE = shift(@ARGV);
set_vocab_size($VOCAB_SIZE);
load_2g_counts(shift(@ARGV), $MINCOUNT);
list_words(\@words);
foreach my $cl (@CLASSES) {

}
update_in_vocabulary(\@words);
if ($VOCAB_SIZE > $#words+1) {
	$VOCAB_SIZE = $#words+1;
}

while ($STEP) {

	print STDERR `date "+%d/%m/%y %H:%M:%S"`." ----------------- STEP $STEP -------- \n\n";
	%new_rules = ();

	#loop over oovs
	loop_over_oovs(\%new_rules);

	# if rules AB -> AC and C -> D during the same pass
	# just apply AB -> AC and discard C -> D for this pass
	remove_conflicts(\%new_rules);

	#map new rules onto the old ones and update counts at the same time
	# old = A -> B ; new = B -> C ; result is all = { A -> C ; B -> C }
	apply_mapping(\%new_rules, \%all_rules, \%reverse_rules);
	add_new_rules(\%new_rules, \%all_rules, \%reverse_rules);

	#compute new voc
	update_counts(\%reverse_rules);
	@new_words = ();
	list_words(\@new_words);

	update_in_vocabulary(\@new_words);



	#if new rules have been found
	if (keys(%new_rules)+0 > 0) {
		#then redo
		$STEP++;
		@words = @new_words;
	}
	else {
		#else return all the rules
		last;
	}
}

if ($SKIP_BIGRAMS == 0) {
 print STDERR " ============= NOW BIGRAMS =========== \n\n";
update_uni_counts_in_bigrams();
 while ($STEP) {
 	print STDERR `date "+%d/%m/%y %H:%M:%S"`." ----------------- STEP $STEP -------- \n\n";

 	#loop over oovs
 	loop_over_bigrams(\%new_rules);


 	# if rules AB -> AC and C -> D during the same pass
 	# just apply AB -> AC and discard C -> D for this pass
 	remove_conflicts(\%new_rules);

 	#map new rules onto the old ones and update counts at the same time
 	# old = A -> B ; new = B -> C ; result is all = { A -> C ; B -> C }
 	apply_mapping(\%new_rules, \%all_rules, \%reverse_rules);
 	add_new_rules(\%new_rules, \%all_rules, \%reverse_rules);

 	#compute new voc
 	update_counts(\%reverse_rules);
	update_uni_counts_in_bigrams();
 	@new_words = ();
 	list_words(\@new_words);

 	update_in_vocabulary(\@new_words);



 	%new_rules = ();

 	#if new voc != old voc
 	if (same_vocab(\@new_words, \@words) == 0) {
 		#then redo
 		$STEP++;
 		@words = @new_words;
 	}
 	else {
 		#else return all the rules
 		last;
 	}
 }
}
# list_common_cased_words(\@new_words);



#############################################################
# OUTPUT
#############################################################

	print STDERR "\n\n".`date "+%d/%m/%y %H:%M:%S"`."---------------- FINAL ----------------\n\n";
	print_output();
	print STDERR "\n\n".`date "+%d/%m/%y %H:%M:%S"`."---------------- END ----------------\n\n";

#############################################################
# USAGE
#############################################################



sub usage {
	warn <<EOF;
Usage:
    oov-minimisation.pl [OPTIONS] <vocab_size> <2g_count_file> [ <class_file_1>  [...] ]

Synopsis:
    Return a set of rewritting rules enabling the user to build a vocabulary with
    a minimum OOV rate for the requested size.
    To ensure not to break some normalization rules previously defined, it is
    advised to set a configuration file through the option --config.

Options:
    -h, --help         Print the help message.
    -c, --config=file  Read a specific normalisation configuration file in order to
                       prevent from some undesired word simplications.
    -B, --skip-bigrams Skip the processing of bigrams (recapitalisation)
    -m, --min-count=N  Filter words appearing less than N times
    -v, --verbose      Print information at runtime.
EOF
	exit;
}

#e#o#f#
