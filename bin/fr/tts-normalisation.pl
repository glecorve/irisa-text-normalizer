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
use TtsNormalisationFr;
use Encode;
use Getopt::Long;
use File::Basename;
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

TtsNormalisationFr::init_norm_fr();

$TEXT = TtsNormalisationFr::process_norm_fr($TEXT, $KEEP_PARA, $KEEP_PUNC, $ESTER, $VERBOSE);

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
    Normalize the content of the input (from STDIN).
    The result is returned in STDOUT.

Options:
    -h, --help
                 Print this help ;-)
    -v, --verbose
                 Verbose
EOF
	exit 0;
}

#e#o#f#


