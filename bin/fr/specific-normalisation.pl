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
use Getopt::Long;
use Lingua::FR::Numbers qw(number_to_fr ordinate_to_fr);
use Case;
# use POSIX qw(strftime locale_h);
# use locale;
# setlocale(LC_CTYPE, "UTF8");
# setlocale(LC_COLLATE, "UTF8");
use strict;
use PostProcessing;
use CorpusNormalisationFr;


my $HELP;
my $KEEP_PARA = 0;
my $END_SEP = " |\n|\$|'s? ";
my $VOCAB = "";


$|++; #autoflush



#############################################################
# USAGE
#############################################################



sub usage {
	warn <<EOF;
Usage:
    specific-normalization.pl [OPTIONS] <config_file> <text_file>

Synopsis:
    Applying some basic modifications to the text according to what is specified in the config file. This config file is made of basic commands (see below), one command per line. These commands are applied in same order as listed in the config file. The processed text is output to STDOUT.

Options:
    -cp, --classpath=dir
                     Directory where class-specific files are created.
                     Default is the working directory.
    -h, --help       Print the help message.
    -P, --keep-par   Do not remove emty lines
    -t, --temp=dir   Set the directory to store temporary files when using external scripts.
    -v, --verbose    Print information at runtime.
    -V, --vocab=file List of words that cannot be modified.

Config File Format:
EOF
	foreach my $k (sort keys %OPTIONS) {
		warn "   $k\n       -- ".$OPTIONS{$k}[0]."\n";
	}
	exit 0;
}



#
# Process command line
#
Getopt::Long::config("no_ignore_case");
GetOptions(
	"classpath|cp=s" => \$CLASSPATH,
	"help|h" => \$HELP,
	"keep-par|P" => \$KEEP_PARA,
	"temp|t=s" => \$TMPDIR,
	"verbose|v" => \$VERBOSE,
	"vocab|V=s" => \$VOCAB
)
or usage();


(@ARGV == 2) or usage();
if ($HELP == 1) { usage(); }



#####################################################################
# FUNCTIONS
#####################################################################

sub ACRONYMS_EXPLODED_UNLESS_READABLE {
	my $OLD_TEXT = "";
	while ($OLD_TEXT ne $TEXT) {
		my @NEW_WORDS = ();
		foreach my $w (split(/ /,$TEXT)) {
			my $changed = 1;
			if ($w =~ /^([A-Z]\.?){2,}$/) {
				my $pronunceable_prefix = "";
				while (!pronounceable_acronym($w)) {
					if ($w =~ /^((?:[A-Z])\.?)/) {
						$w =~ s/^([A-Z])\.?//g;
						$pronunceable_prefix .= "$1. ";
					}
					else { last; }
				}
				# print ">> $w is readable\n";
				$w =~ s/\.//g;
				$w = $pronunceable_prefix . $w;
			}
			push(@NEW_WORDS, $w);
		}
		$OLD_TEXT = $TEXT;
		$TEXT = join(" ", @NEW_WORDS);
		ACRONYMS_EXPLODED();
	}
}

sub ACRONYMS_EXPLODED {

	sub explode {
		my $x = shift;
		$x =~ s/&/ et /g;

		#separates numbers first
		$x =~ s/([0-9])\1\1\1/ quatre $1 /g;
		$x =~ s/([0-9])\1\1/ trois $1 /g;
		$x =~ s/([0-9])\1/ deux $1 /g;
		$x =~ s/([0-9])\.([0-9])/$1 point $2/g;
		while ($x =~ s/(\d+)0(\d)/"$1 zéro ".number_to_fr($2)." "/ge) {}
		while ($x =~ s/(\d+)(\d{2})/"$1 ".number_to_fr($2)." "/ge) {}
		while ($x =~ s/0(\d)/" zéro ".number_to_fr($1)." "/ge) {}
		while ($x =~ s/(\d{2})/" ".number_to_fr($1)." "/ge) {}
		while ($x =~ s/0/ zéro /g) {}
		while ($x =~ s/(\d)/" ".number_to_fr($1)." "/ge) {}
# 		$x =~ s/ty s$/ties/g;
		$x =~ s/ \.(.)/ point /g;
		$x =~ s/ \.//g;

		# if no number left
		# process letters
		while ($x =~ s/([A-Za-z]\.)(?! )/$1 /g) {}
		$x =~ s/([0-9]\.)(?>!\.)/$1/g;
		$x =~ s/([A-Z])(?>!\.)/$1./g;
		$x =~ s/(^| )([a-z]) /$1.upcase($2).". "/ge;


		$x =~ s/-+/ /g;
		$x =~ s/ +/ /g;
		$x =~ s/^ //g;
		$x =~ s/ $//g;
		$x =~ s/ s$/s/g;

		return $x;
	}

	$TEXT =~ s/(^| )([A-Z0-9]\.?(?:[-&]?[A-Za-z0-9\-]+\.?)+)(?='s|s|'| |\n|$)/$1.explode($2)/gem;
	$TEXT =~ s/(^| )([a-z]+(?:[-&]?[A-Za-z0-9\-]+\.?)+)(?='s|s|'| |\n|$)/$1.explode($2)/gem;
}


sub CASE_OFF {
	$TEXT = upcase($TEXT);
}


sub CASE_LOW {
	$TEXT = downcase($TEXT);
}


sub final {
	$TEXT =~ s/(^| )(\d+(?:\.\d*)?)(?= |\n|$)/$1.number_to_fr($2)/gem;
	#uppercase every single letter (except 'a') : b -> B.
	$TEXT =~ s/(^| )([b-z])(?=$END_SEP)/"$1".uc($2)."."/gem;
	#uppercase every single letter followed by a dot (no exception) : a. -> A.
	$TEXT =~ s/(^| )([a-z]\.)(?=$END_SEP)/"$1".uc($2)/gem;
	#add a dot after every single uppercase letter (except A and I) : B -> B.
	$TEXT =~ s/(^| |-)([B-HJ-Z])(?=$END_SEP)/$1$2./gm;
	if (is_active_option('CASE_OFF')) {
		$TEXT = uc($TEXT);
	}
}





#####################################################################
# MAIN
#####################################################################




# read config file
my $f = shift;
my @CONFIG = ();
$VERBOSE && print STDERR "Reading options...";
@CONFIG = read_config($f);
$VERBOSE && print STDERR " OK\n";

if ($VOCAB ne "") {
	$VERBOSE && print STDERR "Reading vocabulary...";
	@protected = read_vocab($VOCAB);
	$VERBOSE && print STDERR " OK\n";
}


# open the input file
my $f = shift;
my $i = 0;
$VERBOSE && print STDERR "Reading text file...";
open(INPUT, "< $f") or die("Unable to open file $f.\n");
while(<INPUT>) {
	$TEXT .= $_;
	$i++;
}
close(INPUT);
$VERBOSE && print STDERR " OK ($i lines)\n";

if (@protected+0 > 0) {
	$VERBOSE && print STDERR "Protect vocabulary...";
	protect_words();
	$VERBOSE && print STDERR " OK\n";
}

foreach my $processing (@CONFIG) {
	if (defined($option2function{$processing})) {
		$VERBOSE && print STDERR "Applying ".$option2function{$processing}."...";
		eval $option2function{$processing}; warn $@ if $@;

	}
	elsif ($processing =~ /^EXTERNAL_SCRIPT=(.*)$/) {
		EXTERNAL_SCRIPT($1);
	}
	else {
		$VERBOSE && print STDERR "Applying $processing...";
		eval "$processing()"; warn $@ if $@;
	}
	$VERBOSE && print STDERR " OK\n";
}

if (@protected+0 > 0) {
	$VERBOSE && print STDERR "Unprotect vocabulary...";
	unprotect_words();
	$VERBOSE && print STDERR " OK\n";
}

#final();
trim_blanks();
if ($KEEP_PARA == 0) {
	$TEXT =~ s/^\n+$//gm;
}

$VERBOSE && print STDERR "Printing output...";
print $TEXT;
$VERBOSE && print STDERR " OK\n";
write_tags();




#e#o#f#
