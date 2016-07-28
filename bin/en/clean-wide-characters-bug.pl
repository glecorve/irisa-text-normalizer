#!/usr/bin/perl -n
#
# Remove some problemr due to wide characters in raw texts
#
# Usage: perl clean-wide-character.pl <text_file>
#

s/\?(?! [0-9A-Z])/ /g;
s/(?<=[,;\-\.\?!])\?/ /g;
s/ +/ /g;
s/^ //gm;
s/ $//gm; 
print $_;

