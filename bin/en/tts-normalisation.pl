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
use TtsNormalisationEn;
use Getopt::Long;
use File::Basename;
use POSIX qw(strftime locale_h);
use locale;
setlocale(LC_CTYPE, "UTF8");
setlocale(LC_COLLATE, "UTF8");
use strict;

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


(@ARGV == 0) or usage();
if ($HELP == 1) { usage(); }



# open the input file
#my $f = shift;
my $TEXT = "";
#open(INPUT, "< $f") or die("Unable to open file $f.\n");
while(<STDIN>) {
	$TEXT .= $_;
}
#close(INPUT);

TtsNormalisationEn::init_norm_en();

$TEXT = TtsNormalisationEn::process_norm_en($TEXT, $KEEP_PARA, $KEEP_PUNC, $ESTER, $VERBOSE);
print $TEXT;
print STDERR "\n";


#############################################################
# USAGE
#############################################################



sub usage {
	warn <<EOF;
Usage:
    tts-normalisation.pl [options] <input >output

Synopsis:
    Normalize the content of the input (read from stdin).
    The result is returned to STDOUT.

Options:
    -h, --help
                 Print this help ;-)
    -v, --verbose
                 Verbose
EOF
	exit 0;
}

#e#o#f#


