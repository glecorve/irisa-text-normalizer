#!/usr/bin/perl

# Tokenize a text for the French language
#
package TokenizerFr;

use strict;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/.";
use CorpusNormalisationFr;
require Encode;
use utf8;
# use locale;
use POSIX qw(locale_h);
setlocale(LC_CTYPE, "UTF8");
setlocale(LC_COLLATE, "UTF8");

#
# constants
#

my $dirRessources = dirname( abs_path(__FILE__) )."/../rsrc/fr";


# file with a list of abbreviations
my $fileAbbr = "$dirRessources/abbrev.lst";

my $quotes = "\"|\xC2\xAB|\xC2\xBB";
my $paren = "[\\(\\)\\{\\}\\[\\]]";
my $operators  = "[+=÷×\/]";
my $plusminus = "±";
my $punct1 = ",|;|:|\\?|!|\x{C2}\x{A1}|\x{C2}\x{BF}";
my $punct2 = "[\-_]";
my $punct = ",|;|:|\\?|!|\_|\\.|\-|\x{C2}\x{A1}|\x{C2}\x{BF}";
my $webdomain = "com|net|org|co\.uk|fr|gov|de|ch|es|it|info|io";


# Separate strings at the beginning of words
my $beginString='[dcjlmnstDCJLMNST]\'|[Qq]u\'|[Jj]usqu\'|[Ll]orsqu\'|[Pp]uisqu\'|[[Pp]resqu\'|[Qq]uelqu\'|[Qq]uoiqu\'';


# Separate strings at the end of words
my $endString='-t-elles?|-t-ils?|-t-on|-t-en|-ce|-elles?|-ils?|-je|-la|-les?|-leur|-lui|-mêmes?|-m\'|-moi|-nous|-on|-toi|-tu|-t\'|-vous|-en|-y|-ci|-là';
# exceptions where the words musn't be split
my $endExcept = '-t-elles?|-t-ils?|-t-on|-t-en|[rR]endez-vous|[eE]ntre-lui|[cC]hez-[mts]oi|[cC]hez-nous';


my %abbr = ();
my %begExcept = ();
# for latin-9 (ISO 8859-15)
our $alphanum = "[0-9a-zA-ZÀ-ÖØ-öø-ÿŠšŽžŒœŸ]";
our $letter = "[a-zA-ZÀ-ÖØ-öø-ÿŠšŽžŒœŸ]";
our $upper = "[A-ZÀ-ÖØ-ÞŠŽŒŸ]";
our $downer = "[a-zà-öø-ÿŠŽŒŸ]";


# ---------------------- #
#     sub initAbbr()
# ---------------------- #
sub initAbbr {
  open(ABBR, "<$fileAbbr")
    or die "couldn't open $fileAbbr\n";
  while (<ABBR>) {
    chomp;
    s/\#.*$//; # remove comments
    s/\s+$//; # remove trailing blanks
    $abbr{$_} = 1;
  }

  close(ABBR);
}



# ---------------------- #
#      sub tok()
# ---------------------- #
# parameter:
# - string to tokenize
sub tok {

  my $intok = shift;
  my $res = "";

  #  if your data comes in Latin-1, then uncomment:
  $intok =~ s/α/alpha/g;
  $intok =~ s/β/beta/g;
  $intok =~ s/γ/gamma/g;
  $intok =~ s/δ/delta/g;
  $intok =~ s/Δ/delta/g;
  $intok =~ s/μ/micro/g;
  $intok =~ s/ρ/rho/g;
  $intok =~ s/λ/lambda/g;
  $intok =~ s/Λ/lambda/g;
  #$intok = Encode::decode( 'utf8', $intok );
  # $intok =~ s/\x{e4}/ae/g;  ##  treat characters ä ñ ö ü ÿ
  # $intok =~ s/\x{f1}/ny/g;  ##  this was wrong in previous version of this doc
  # $intok =~ s/\x{f6}/oe/g;
  # $intok =~ s/\x{fc}/ue/g;
  # $intok =~ s/\x{ff}/yu/g;
  $intok =~ s/\x{c3}\x{df}/ss/g;  ##  German beta “ß” -> “ss”
  $intok =~ s/\x{c3}\x{c6}/AE/g;  ##  Æ
  $intok =~ s/\x{c3}\x{e6}/ae/g;  ##  æ
  $intok =~ s/\x{c4}\x{B2}/IJ/g;  ##  Ĳ
  $intok =~ s/\x{c4}\x{B3}/ij/g;  ##  ĳ
  $intok =~ s/\x{c5}\x{92}/Oe/g;  ##  Œ
  $intok =~ s/\x{c5}\x{93}/oe/g;  ##  œ
  $intok =~ s/\x{c9}\x{99}/e/g;  ## ə
  $intok =~ s/\x{c6}\x{8f}/e/g;  ## Ə
  $intok =~ s/\x{e2}\x{80}\x{99}/'/g;  ## ’
  $intok =~ s/\x{e2}\x{80}\x{06}/.../g;  ## …
  # ÐðđĦħ
  $intok =~ s/(?:\x{c3}\x{90}|\x{c4}\x{90})/D/g;
  $intok =~ s/(?:\x{c3}\x{b0}|\x{c4}\x{91})/d/g;
  $intok =~ s/\x{c4}\x{a6}/H/g;
  $intok =~ s/\x{c4}\x{a7}/h/g;
  # ıĸĿŁŀł
  $intok =~ s/\x{c4}\x{b1}/i/g;
  $intok =~ s/\x{c4}\x{b8}/k/;
  $intok =~ s/(?:\x{c4}\x{bf}|\x{c5}\x{81})/L/g;
  $intok =~ s/(?:\x{c5}\x{80}|\x{c5}\x{82})/l/g;
  # ŊŉŋØøſ
  $intok =~ s/\x{c5}\x{8a}/N/g;
  $intok =~ s/(?:\x{c5}\x{89}|\x{c5}\x{8b})/n/g;
  $intok =~ s/\x{c3}\x{98}/O/g;
  $intok =~ s/\x{c3}\x{b8}/o/g;
  $intok =~ s/\x{c5}\x{bf}/s/g;
  # ÞŦþŧ
  $intok =~ s/(?:\x{c3}\x{9e}|\x{c5}\x{a6})/T/g;
  $intok =~ s/(?:\x{c3}\x{be}|\x{c5}\x{a7})/t/g;
  # ﾣ
  $intok =~ s/ﾣ//g;


  $intok =~ s/\|/ /g;
  $intok =~ s/^\d+([\.:\-\/\\]\d+)+: ?//gm; #skip time stamp at beginning of lines

  #Remove HTML tags
  $intok =~ s/( |^)<[^>]+?('s|'| |\n|$)/$1$2/gm;
  $intok =~ s/( |^)([^< ]+?)>( |\n|$)/$1$2$3/gm;
  $intok =~ s/<\/?[^>]+>/ /g;
  $intok =~ s/[<>]{2,}/ /g;

  #Space single quotes
  $intok =~ s/(^| )'(.*?[^s])'( |\n|$)/$1 ' $2 ' $3/g;

  # treat independently each line of the token
  my @lin = split(/\n/, $intok);
  foreach my $str (@lin) {
      while ($str =~ /([0-9]),([0-9]{3})\b/) {
	  $str = $`.$1.$2.$'; #'
      }


      #process parentheses ( X )
      # if X contains a number and no letter-> remove
      # if |X| <= 2 -> remove
      # otherwise, keep it
      sub proc_par {
	  my $x = shift;
	  if ($x =~ /\d/ && $x !~ /\w/) { return ""; }
	  elsif (length($x) <= 2) { return ""; }
	  return "($x)";
      }
      $str =~ s/\(at\)/ @ /g;
      $str =~ s/\(([^\)]+)\)/" ".proc_par($1)." "/ge;

      #split items
      $str =~ s/ ?(?:■|•) ?/\n- /g;

      #remove long (5+) sequence of single letters and number
      $str =~ s/ (?:(?:[a-zA-Z]|-?[0-9][0-9\.]*) ){5,}/\n/g;

      # remove / at the end of Web addresses to avoid that this script
      # joins the address with the following word
      # e.g. www.nodo50.org/mareanegra/ sans oublier
      $str =~ s/(http:\/\/|www\.)(\S+)\/( |$punct1|\.|$quotes|$)/$1$2$3/g;




      # put spaces around punctuation marks
      $str =~ s/($plusminus|$paren|$quotes|$operators|$punct1)/ $1 /g;
      $str =~ s/--+/ -- /g;

      # remove blank between Canal and +
      $str =~ s/Canal(\s+)\+/Canal+/g;


      # correct numeric sequences

      # large numbers can have ., e.g. : 100.000
      while($str =~ s/([0-9]),([0-9]{3})([^0-9])/$1$2$3/) { }

      $str =~ s/([0-9]+)($operators)/$1 $2/og;
      $str =~ s/($operators)([0-9]+)/$1 $2/og;
#   $str =~ s/([0-9]+) +\-/$1-/g;
#    $str =~ s/\- +([0-9]+)/-$1/g;
      while($str =~ s/([0-9]+) +([\.,]) +([0-9]+)/$1$2$3/g) { } # decimal numbers

      # split numbers around , for lists and years
      # e.g. 8,11,12 et 13 juillet> 8, 11 , 12 et 13 juillet
      #... JO de 1992,1996 et 2004 ... -> JO de 1992 , 1996 et 2004
      $str =~ s/(^|\b)([0-9]+),([0-9]+),([0-9]+)((?:,[0-9]+)*) +(et|ou) ([0-9])/$1.$2." , ".$3." , ".$4.treatLstNb($5)." ".$6." ".$7/ge;
      $str =~ s/(^|\b)([0-9]+),([0-9]+),([0-9]+)((?:,[0-9]+)*)/$1.$2." , ".$3." , ".$4.treatLstNb($5)/ge;
      while($str =~ s/(^|\b)([0-9]+),([0-9]+)(\b|$)/$1.&checkYrs($2,$3).$4/ge) { }
      $str =~ s/¶¶¶/,/g;

      # minutes, seconds or inches
      $str =~ s/([0-9]) +(\'|\'\') */$1$2 /g;
      $str =~ s/([0-9]) +(\'|\'\') +([0-9]{1,2})/$1$2$3/g;

      # for acronyms with several ., put an extra . at the end of the
      # word if it is the end of a sentence
      $str =~ s/(${upper})\.(${upper})\.(${upper})\. +(${upper})/$1.$2.$3. . $4/g;

      # delete spaces between http and www for Web addresses
      $str =~ s/http +: +\/ +\//http:\/\//g;


      # delete spaces around / for Web addresses
      while ($str =~ s/(http:\/\/|www\.)(\S+) +\/ +(\S)/$1$2\/$3/) { }
      while ($str =~ s/(http:\/\/|www\.)(\S+) +\/(\S)/$1$2\/$3/) { }
      while ($str =~ s/(http:\/\/|www\.)(\S+)\/ +(\S)/$1$2\/$3/) { }


      # Delete ending "/" and "\"
#   $str =~ s/(?<!http:\/)[\/\\]( |\n|$)/$1/gim;
      # NB: ? remains with spaces around them for Web adresses but they
      # are rare
      # treat ' and -
      my @lstr = split(/ +/, $str);
      foreach my $w (@lstr) {
	  # Web address and e-mails address
	  if ($w =~ /^http:\/\/\S+$/) {
	      if ($w =~ /\.$/) {
		  $w = $`." .";
	      }
	      $res .= $w." ";
	  } elsif ($w =~ /^www\.\S+$/) {
	      if ($w =~ /\.$/) {
		  $w = $`." .";
	      }
	      $res .= $w." " ;
	  } elsif ($w =~ /^\S+@\S+\.\S+$/) {
	      if ($w =~ /\.$/) {
		  $w = $`." .";
	      }
	      $res .= $w." " ;

	      # other words
	  }
	  else {
	      $res .= &treatDot($w)." ";
	  }
      }


      $res .= "\n";
  }
  $res =~ s/ +/ /g;
  $res =~ s/ $//g;
  $res =~ s/^ //g;
  return $res;

#
#   # remove leading and trailing blanks for each line
#   $res =~ s/(^|\n) +/$1/g;
#   $res =~ s/ +($|\n)/$1/g;
#
#   # remove void lines
#   $res =~ s/\n+/\n/g;
#   $res =~ s/^\n+//;
#
#   # keep only 1 consecutive blank
#   $res =~ s/ +/ /g;
#
#   #remove long sequences of numbers
#   #while ($res =~ s/ (-?[^A-Za-z][0-9\.]* )(-?[0-9\.]+ ){2,}(-?[^A-Za-z][0-9\.]*)/\n/g) {}
#   #$res =~ s/[^[:alnum:]\.,;:\?!\-\+\*'"\$£¥%\x{20AC}&#=@°\(\)\/<>²³\n]/ /g;
#   $res =~ s/ \.( \.){2,}/ .../g;
#   $res =~ s/ +/ /g;
#   $res =~ s/ $//g;
#   $res =~ s/^ //g;
#
#   #downcase sequence of 4+ uppercase words
#   $res =~ s/(^| )([A-Z][A-Z0-9'-]*) ((?:[A-Z0-9][A-Z0-9'-]* ?,? ){1,})([A-Z][A-Z0-9'-]+)/$1.ucfirst(lc($2)).lc(" $3 $4")/gem;
#
#   $res =~ s/\n\n+/\n/gm;
#   #$res = Encode::encode_utf8($res);
#
#   return $res;
}


# ---------------------- #
#   sub checkYrs
# ---------------------- #
# Check that a token with a comma contains a year
# parameter:
# - token to process
sub checkYrs {
  my $a = shift;
  my $b = shift;
  if ($a =~ /^(17|18|19|20)[0-9]{2}$/ || $b =~ /^(17|18|19|20)[0-9]{2}$/) {
    return "$a , $b";
  }
  else {
    return "$a¶¶¶$b"; # to avoid an infinite loop when calling this function
  }
}


# ---------------------- #
#   sub treatLstNb
# ---------------------- #
# Put blank between , for list of numbers
# parameter:
# - token to process
sub treatLstNb {
  my $itok = shift;
  while ($itok =~ s/,([0-9]+)/ , $1/g) {}
  return $itok;
}



# ---------------------- #
#     sub treatDot()
# ---------------------- #
# parameter:
# - word to process
sub treatDot {
  my $w = shift;
  # $w is segmented by . except
  # ...
  # in a number
  # in acronyms
  # in a known abbreviation
  # in an ending abbreviation
  # an isolated capital letter
  # a sequence of capital letters
  if ($w =~ s/(${alphanum}*)(\.{3})\.*/$1 $2/og) { }
  if ($w =~ s/(\.{3})\.*(${alphanum}*)/$1 $2/og) { }
  if ($w =~ /[0-9]\.$/) { $w =~ s/\.$/ ./g; }
  if ($w =~ /^\./) { $w =~ s/^\./. /g; }
  elsif ($w =~ /(?:${alphanum}*)\.(?:$webdomain)/i) { }
  elsif ($w =~ /[0-9]\.[0-9]/) { }
  elsif (defined $abbr{$w}) {}
  elsif ($w =~ /(${upper})\.(${upper})\.(${upper})\.?$/o) {
    # normalize acronyms with . e.g., O.N.U.=>ONU (at least 3 letters as there can be first names with 2 capital letters, e.g. J.C. Tricher)
    $w =~ s/\.//g;
  }
  elsif ($w =~ /^(${upper})\.\-(${upper})\.*$/o) {}
  elsif ($w =~ /^(${upper})\.$/o) {}
  elsif ($w =~ /^(${upper})\.(${upper})\.$/o) {}
  elsif ($w =~ s/(${alphanum}{2,})(\.)$/$1 $2/) {}
  else {
    $w =~ s/(?!${punct})(\.)(?!${punct})/$1 $2 $3/og;
  }

  return $w;

}

1;
