#!/usr/bin/perl
# Apply mappings to a text file
#
# Usage: perl map-rules.pl <text> <mapping_file_1> [ <mapping_file_2> [...] ]
# 

use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/../../lib";
use CorpusNormalisationFr;

my $text_f = shift(@ARGV);
my $text = "";
open(F, "< $text_f") or die("Unable to read file $text_f.\n");
while (<F>) {
	$text .= $_;
}
close(F);

foreach my $m (@ARGV) {
	apply_rules(\$text, $m);
}

print $text;

