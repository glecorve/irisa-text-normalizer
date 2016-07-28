#!/usr/bin/perl -n
#
# Compact exploded acronyms. E.g., I. B. M. becomes I.B.M. (1 word)
#
# Usage: perl compact-acronyms.pl <text_file>
#

sub clean {
	my $x = shift;
	$x =~ s/ //g;
	return $x;
}

s/(^| )((?:[A-Z]\. ?)+(?:[A-Z]\.[Ss]?))(?='s|'S|'| |$)/$1.clean($2)/ge; #COMPACT ACRONYMS
print $_;



