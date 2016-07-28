# library to upcase, downcase or remove diacritics of letters
#

package capLetter;

use strict;

use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter);
BEGIN {
  @EXPORT = qw(&downcase &upcase &rmDiacritics);
}


# for latin-9 (ISO 8859-15)
our $alphanum = "[0-9a-zA-ZÀ-ÖØ-öø-ÿŠšŽžŒœŸ]";
our $letter = "[a-zA-ZÀ-ÖØ-öø-ÿŠšŽžŒœŸ]"; 
our $upper = "[A-ZÀ-ÖØ-ÞŠŽŒŸ]";
our $downer = "[a-zà-öø-ÿŠŽŒŸ]";



# ---------------------- #
#     sub downcase()
# for ISO 8859-15 (latin-9)
# ---------------------- #
sub downcase {
  my $w = shift;
  $w =~ s/É/é/g;
  $w =~ tr/ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÈÉÊËÌÍÎÏÒÓÔÕÖØÙÚÛÜÝŸÇÐÑÞŽŒ/abcdefghijklmnopqrstuvwxyzàáâãäåæèéêëìíîïòóôõöøùúûüýÿçðñþžœ/;

  return $w;
}


# ---------------------- #
#     sub upcase()
# for ISO 8859-15 (latin-9)
# ---------------------- #
sub upcase {
  my $w = shift;

  $w =~ tr/abcdefghijklmnopqrstuvwxyzàáâãäåæèéêëìíîïòóôõöøùúûüýÿçðñþšžœ/ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÈÉÊËÌÍÎÏÒÓÔÕÖØÙÚÛÜÝŸÇÐÑÞŠŽŒ/;

  return $w;
}


# ---------------------- #
#     sub rmDiacritics()
# for ISO 8859-15 (latin-9)
# ---------------------- #
sub rmDiacritics {
  my $w = shift;

  $w =~ tr/àáâãäåèéêëìíîïòóôõöùúûüýÿñšžÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝŸÑŠŽ/aaaaaaeeeeiiiiooooouuuuyynszAAAAAAEEEEIIIIOOOOOUUUUYYNSZ/;

  return $w;
}

return 1;
