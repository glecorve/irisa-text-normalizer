#!/usr/bin/perl 

# Clean stm files by removing Transcriber's indications and by keeping
# capital letters.

# S. Huet
# 
# built from the script made by François
# modified: 05/03/07: remove isolated - expressing parenthesis
#           05/19/07: add 0-9 in regular expressions 
#           07/07/07: remove format errors like !m in stm file, add 4LER option
#           07/24/07: call only once init_spell
#           11/24/07: treat real numbers

package stmclean;

use lib '/temp_dd/texmex_text_0/tools/devCorpus4ASR/lib';
use strict;
use spellnum;


use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
BEGIN {
  @EXPORT = qw(&clean);
}

use vars @EXPORT;

# strong punctuation marks
my $stPunct = '\.|\.\.\.|:|\?|\!|;';

# mark the change of sentence or utterance
my $ch = "<eos>";



# ---------------------- #
#      sub clean()
# ---------------------- #
# Clean a text
# - input text file
# - option:
#     ."inp": keep all punctuation marks
#     ."outp"" remove punctuation marks and capital letters
#     ."4LER" remove punctuation marks, capital letters but keep ( )
#     that marks absence of prononciation of words (usefule to compute
#     lemma error rate)
sub clean() {

  my $t = shift
    or die "input text file not specified in clean\n";
  my $option = shift
    or die "option not specified in clean\n";
  if ($option !~ /^(inp|outp|4LER)$/) {
    die "use inp or outp option for clean\n";
  }

  my $r = "";

  # ignore segments labelled by ignore_time_segment_in_scoring
  if ($t !~ /ignore_time_segment_in_scoring/) {
      

    # delete consecutive dots
    $t =~ s/(\.\.\.\s+)+/... /g;

    # delete indices on the prononciation of the initials
    $t =~ s/[_!]+([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ0-9]+)/$1/g;
    $t =~ s/[_!]+([a-zA-ZÀ-ÿ] )//g; # error of format in the stm file, e.g. !m

    # delete indices on bad writing
    $t =~ s/\^\^([a-zA-ZÀ-ÿ0-9][a-zA-ZÀ-ÿ0-9\'\-]*)/$1/g;

    # delete indices on bad prononciation
    $t =~ s/\*\s*([a-zA-ZÀ-ÿ0-9][a-zA-ZÀ-ÿ0-9\'\-]*)/$1/g;

    # delete indices with [ ]
    $t =~ s/\[[^\]]+\]//g;

    if ($option ne "4LER") {
    # detect brakets which mark an absence of prononciation of a word
    # When there is nothing between brackets (case of word starts), the
    # word is deleted
      $t =~ s/[^\s\)]*\(\s*\)\S*//g;
      # When the whole word is put between brackets (case of guessed words),
      # the word is also deleted
      $t =~ s/(^| )\([^\)]+\)(\s|$)/ /g;
      $t =~ s/\(([a-zA-ZÀ-ÿ0-9\'\-\. ]*)\)/$1/g;
    }

    # replace ',' by "virgule" for numbers, e.g. 0,5
    $t =~ s/([0-9]),([0-9])/$1 virgule $2/g;

    # normalize the words
    my @words = split(/\s+/,$t);
    $t = normalize($option, @words);

    if ($option eq "inp") {
      # put $ch after strong punctuations
      while ($t =~ /\s+($stPunct)\s+(|$)/) {
	$r = $r.$`." $ch ".$2;
	$t = $';
      }
      $r .= $t;

    } elsif ($option =~ /^(outp|4LER)$/) {
      # delete strong punctuations
      $t =~ s/($stPunct)(\s|$)/ /g; # to keep the '.' in expressions like rfi.com
      $t =~ s/\s($stPunct)/ /g;
      $r = $t;
    }

    # replace '.' by "point"
    $r =~ s/\./ point /g;

    # remove leading and trailing spaces and multi-spaces
    $r =~ s/^\s+//;   $r =~ s/\s+$//;
    $r =~ s/\s+/ /g;
    
  }
  return $r;

}


# --------------------------- #
# ----- sub normalize() ----- #
# adapted from the wer script
# --------------------------- #
#
# normalize vocabulary words
#
sub normalize() {
  my $option = shift;
  my $nt = "";

  init_spell();
  foreach (@_) {
    my $x = $_;
    #    foreach my $x (split /_|-/) {
    $x =~ s/^\s*//; s/\s*$//;	# remove leading and trailing blanks
    $x =~ s/([^\.])\.$/$1/; # remove trailing dot from etc., inc. (but not from ...)
    # $x =~ s/[_-]/ /g;             # replace all dashes and underscores by a space

    next if $x =~ /^$/;
    if ($option eq "outp") {
      next if $x =~ /,/;		# remove ','
      next if $x =~ /^-$/;                # remove isolated '-'
    }
    next if $x =~ /\//;		# remove '/'
    $x =~ s/"//g;		# remove '"'
    $x =~ s/\]//g;		# remove ']'

    $x =~ s/^'//;	     # remove ''' at the beginning of the word

    $x =~ s/\%/pour cent/;	# replace '%'

    if ($option eq "outp") {
      $x =~ tr/[A-ZÀ-Ý]/[a-zà-ý]/;   # lower case everything
    }

    foreach my $tok (split /\s+/, $x) {
      if (/^[0-9]+$/) {

	my $littNum = spell($tok);
	$littNum =~ s/-/ /g;
	$nt .= $littNum." ";
      } else {
	$nt .= $tok." ";
      }
    }
    #    }
  }
  return $nt;
}




