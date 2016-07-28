#!/usr/bin/perl
#
# Clean raw texts extracted from PDF files.
# This script is absolutely not exhaustive.
#
# Usage: perl clean-pdf-text.pl <text_file>
#

while (<>) {
	s/^(?:\d\.)+(?: |\n|$)//gm;
	s/^\w\.(?: |\n|$)//gm;
	s/^\(?[0-9i]+\)?(?: |\n|$)//gm;
	s/^ +o +//gm;
	s/^(?:\d\.)+(?: |\n|$)//gm;
	s/^\w\.(?: |\n|$)//gm;
	s/^\(?[0-9i]+\)?(?: |\n|$)//gm;
	s/^ +o +//gm;
	print $_;
}


