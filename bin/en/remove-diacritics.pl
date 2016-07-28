#!/usr/bin/perl
#

use strict;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/../../lib";
use CorpusNormalisationEn;


while (my $f = shift(@ARGV)) {
	my $text = "";
	open(F, $f) or die("unable to open $f .\n");
	while (<F>) {
		$text .= $_;
	}
	close(F);
	
	print remove_diacritics($text);
	
}
