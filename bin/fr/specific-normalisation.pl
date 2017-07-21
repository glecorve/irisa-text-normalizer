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
use File::Basename;
use Lingua::FR::Numbers qw(number_to_fr ordinate_to_fr);
use File::Temp qw/ tempfile tempdir /;
use capLetter;
# use POSIX qw(strftime locale_h);
# use locale;
# setlocale(LC_CTYPE, "UTF8");
# setlocale(LC_COLLATE, "UTF8");
use strict;
use CorpusNormalisationFr;
use NormalisationOptions;

my $RSRC = dirname( abs_path(__FILE__) )."/../../rsrc/fr";

my $HELP;
my $CLASSPATH=".";
my $KEEP_PARA = 0;
my $TMPDIR="/tmp";
my $VERBOSE=0;
my $TEXT = "";
my $END_SEP = " |\n|\$|'s? ";
my $VOCAB = "";
my @protected = ();
	
$|++; #autoflush

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


my %option2function = (
	"TAG_NO_TIME" => "NO_X_TAG('TIME')",
	"TAG_NO_DATE" => "NO_X_TAG('DATE')",
	"TAG_NO_QUANTITY" => "NO_X_TAG('QUANTITY')",
	"TAG_NO_CURRENCY" => "NO_X_TAG('CURRENCY')",
	"TAG_NO_PERSON" => "NO_X_TAG('PERSON')",
	"TAG_NO_LOCATION" => "NO_X_TAG('LOCATION')",
	"TAG_NO_URL" => "NO_X_TAG('URL')",
	"TAG_NO_PHONE" => "NO_X_TAG('PHONE')",
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

sub ACRONYMS_DOT {
	#nothing
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

sub CASE_ON {
	# nothing to do
}


sub CASE_OFF {
	$TEXT = upcase($TEXT);
}


sub CASE_LOW {
	$TEXT = downcase($TEXT);
}


sub SPELLING_BRITISH {
	if (is_active_option('CASE_OFF')) {
		define_rule_case_unsensitive();
	}
	apply_rules(\$TEXT, "$RSRC/us2uk.rules");
}

sub SPELLING_AMERICAN {
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

#e#o#f#


