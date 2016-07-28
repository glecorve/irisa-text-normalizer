# library to upcase, downcase or remove diacritics of letters
#

package capLetter;

use strict;


# for latin-9 (ISO 8859-15)
our $alphanum = "[0-9a-zA-ZÀ-ÖØ-öø-ÿ¦¨´¸¼½¾]";
our $letter = "[a-zA-ZÀ-ÖØ-öø-ÿ¦¨´¸¼½¾]"; 
our $upper = "[A-ZÀ-ÖØ-Ş¦´¼¾]";
our $downer = "[a-zà-öø-ÿ¦´¼¾]";



# ---------------------- #
#     sub downcase()
# for ISO 8859-15 (latin-9)
# ---------------------- #
sub downcase() {
  my $w = shift;

  $w =~ tr/ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÈÉÊËÌÍÎÏÒÓÔÕÖØÙÚÛÜİ¾ÇĞÑŞ¦´¼/abcdefghijklmnopqrstuvwxyzàáâãäåæèéêëìíîïòóôõöøùúûüıÿçğñş¨¸½/;

  return $w;
}


# ---------------------- #
#     sub upcase()
# for ISO 8859-15 (latin-9)
# ---------------------- #
sub upcase() {
  my $w = shift;

  $w =~ tr/abcdefghijklmnopqrstuvwxyzàáâãäåæèéêëìíîïòóôõöøùúûüıÿçğñş¨¸½/ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÈÉÊËÌÍÎÏÒÓÔÕÖØÙÚÛÜİ¾ÇĞÑŞ¦´¼/;

  return $w;
}


# ---------------------- #
#     sub rmDiacritics()
# for ISO 8859-15 (latin-9)
# ---------------------- #
sub rmDiacritics() {
  my $w = shift;

  $w =~ tr/àáâãäåèéêëìíîïòóôõöùúûüıÿñ¨¸ÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜİ¾Ñ¦´/aaaaaaeeeeiiiiooooouuuuyynszAAAAAAEEEEIIIIOOOOOUUUUYYNSZ/;

  return $w;
}

return 1;
