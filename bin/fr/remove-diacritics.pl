#!/usr/bin/perl
#

use strict;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/../../lib";
use CorpusNormalisationFr;


while (my $f = shift(@ARGV)) {
	my $text = "";
	open(F, $f) or die("unable to open $f .\n");
	while (<F>) {
		print remove_diacritics($_);
	}
	close(F);
	
# 	print $text;
	
}
