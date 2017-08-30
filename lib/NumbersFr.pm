#!/usr/bin/perl --  # -*-Perl-*-
#
# NumbersFr.pm	-- Francois Yvon
#
# $Id: NumbersFr.pm,v 1.4 2005/02/07 10:27:38 yvon Exp $
#
########################################################

package NumbersFr;

use Exporter;
@ISA=qw(Exporter);
BEGIN {
  @EXPORT = qw(&init_spell &spell &test);
}

use vars @EXPORT;
use vars qw($intmax);

# -----------
# Constantes
# -----------
# Maximum utilisable
my $intmax=999999999;

# Définition des chiffres
my @s;
my @wrd;

sub init_spell {

    my $i;
    my $wrd;
    $wrd[0] = "zéro";
    $wrd[1] = "un";
    $wrd[2] = "deux";
    $wrd[3] = "trois";
    $wrd[4] = "quatre";
    $wrd[5] = "cinq";
    $wrd[6] = "six";
    $wrd[7] = "sept";
    $wrd[8] = "huit";
    $wrd[9] = "neuf";
    $wrd[11] = "onze";
    $wrd[12] = "douze";
    $wrd[13] = "treize";
    $wrd[14] = "quatorze";
    $wrd[15] = "quinze";
    $wrd[16] = "seize";
    $wrd[17] = "dix-sept";
    $wrd[18] = "dix-huit";
    $wrd[19] = "dix-neuf";
    $wrd[10] = "dix";
    $wrd[20] = "vingt";
    $wrd[22] = "vingt-deux";	# Added by Hemant
    $wrd[30] = "trente";
    $wrd[40] = "quarante";
    $wrd[50] = "cinquante";
    $wrd[60] = "soixante";
    $wrd[70] = "soixante-dix";
    $wrd[80] = "quatre-vingt";
    $wrd[90] = "quatre-vingt-dix";
    $wrd[100] = "cent";
    $wrd[1000] = "mille";
    $wrd[1000000] = "million";

    for $i (2..6)    { $k = 10 * $i; $j = $k + 1; $wrd[$j] = $wrd[$k] . "-et-" . $wrd[1];}        # vingt-et-un ...
    for $i (8)       { $k = 10 * $i; $j = $k + 1; $wrd[$j] = $wrd[$k] . "-" . $wrd[1];}           # quatre-vingt-un ...
    for $i (2..6, 8) { for $l (2..9) { $k = 10 * $i; $j = $k + $l; $wrd[$j] = $wrd[$k] . "-" . $wrd[$l];}}
    for $i (7)       { $k = ($i-1)*10; $j = 10*$i + 1; $wrd[$j] = $wrd[$k] . "-et-" . $wrd[11];}  # soixante-et-onze ...
    for $i (9)       { $k = ($i-1)*10; $j = 10*$i + 1; $wrd[$j] = $wrd[$k] . "-" . $wrd[11];}     # quatre-vingt-onze ...
    for $i (7,9)     { for $l (2..9) { $k = 10*($i-1); $j = 10 *$i + $l; $wrd[$j] = $wrd[$k] . "-" . $wrd[10 + $l];}}

    return (1);
}

#
# spell(): fonction d'interface
#
sub spell {

    my $num = shift;
    my $int, $dec, $plur;


#     print $num."\n";
    if ($num =~ /^[0-9]+$/) {
      if ($num =~ /^0([0-9])$/) {
	return ($wrd[0] ." " . int2let( $1 ));
      }
      else {
	return (int2let ($num));
      }
    }
    if ($num =~ /^([0-9]+)(e|\x{E8}me|eme)(s*)$/) {
      $spell = int2let($1);
      $plur  = $3;
      if ($spell =~ /(.*)e$/) {
	  $spell = $1 . "ième" . $plur;
      }
      elsif ($spell =~ /(.*)f$/) {
	  $spell = $1 . "vième" . $plur;
      }
      elsif ($spell =~ /(.*)cents$/) {
	  $spell = $1 . "centième" . $plur;
      }
      else {
	  ($spell .= "ième" . $plur)
      }
      return ($spell);
    }
    elsif ($num =~ /^[0-9]+\,[0-9]+$/) {
      ($int, $dec) = split(/\,/, $num);
      return ( int2let ($int) . " virgule " . int2let ($dec));
    }
    elsif ($num =~ /^[0-9]+\.[0-9]+$/) {
      ($int, $dec) = split(/\./, $num);
      return ( int2let ($num) . " point " . int2let ($dec));
    }
    #more than one comma
    elsif ($num =~ /^[0-9]+(\,[0-9]+)+$/) {
	my @tab = split(/,/, $num);
	my $str = "";
	$str .= int2let ($_)." , " foreach (@tab);
	chop $str; chop $str; chop $str;
	return $str;

    }
    else {
#      print STDERR "$num is not a valid digit\n";
     my @tab = split(/([,\.])/, $num);
     my $str = "";
     foreach my $n (@tab) {
	if ($n eq ".") {
		$str .= "point ";
	}
	elsif ($n eq ",") {
		$str .= "virgule ";
	}
	else {
		$str .= int2let($n)." ";
	}
     }
     return ($str);
    }
  }

#
# test(): fonction de test et de validation
#
sub test {

   for $i (0..100) {
     $int = int (rand 1000);
     print "$int --> ", int2let($int), "\n";
   }
   for $i (0..10) {
     $int = int (rand 600);
     print $int+1500,  "--> ", int2let($int+1500), "\n";
   }
   for $i (0..100) {
     $int = int (rand $intmax);
     print "$int --> ", int2let($int), "\n";
   }

   for $i (0..100) {
     print "$ --> ", int2let($i), "\n";
   }
}

#
# intlet() : convertit un int en lettres
#
sub int2let {

  my $int    = shift;
  my $spell  = "";

  if ($int > $intmax) { print STDERR "sorry, can't spell out $int (bigger than $intmax)\n"; return ($spell);}
  if ($int == 0)      { return $wrd[0]; }

  for $m (1000000, 1000, 1) {
    $div  = int($int / $m);     # le resultat de la division entière
    $rest = $int - $m * $div;   # le reste
    if ($div) {
      if ($div != 1 || $m != 1000) { $spell .= " " . num2let($div); }
      if ($m > 1) {$spell .=  " " . $wrd[$m];}
    }
    $int = $rest;
  }
  $spell =~ s/^[ ]*//g;
  $spell =~ s/ [ ]*/ /g;
  return $spell;
}

#
# convertit un nombre entre 1 et 999
#
sub num2let ($)
{
  my $num   = shift;
  my $spell = "";

  $c = int($num / 100);
  # centaines
  if ($c != 0) {
    if ($c > 1) {$spell .= $wrd[$c] . " " ;}
    $spell .= "cent";
  }
  # dizaines et unités
  if ($num - $c * 100 > 0) {
    $spell .= " " . $wrd[$num - $c * 100];
  }
  # sinon c'est un multiple de 100 - accord en nombre
  else {
    if ($c > 1) { $spell .= "s";}
  }
  return ($spell);
}

return 1;
