#!/usr/bin/perl

# Tokenize a text for the English language
#

use strict;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/../../lib";

use TokenizerEn;

TokenizerEn::initAbbr();
foreach my $f (@ARGV) {
    open(F, $f);
    while (my $t = <F>) {
	chomp;
	#$t = remove_diacritics($t);
	$t = &TokenizerEn::tok($t)."\n";

	print $t;
    }
    close(F);
}
