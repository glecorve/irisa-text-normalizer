# library to upcase, downcase or remove diacritics of letters
#

package Case;

use strict;

use Exporter;

use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter);
BEGIN {
  @EXPORT = qw(&downcase &upcase &rmDiacritics);
}

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



#
# Substitute lc() functions not dependant on locale.
#
sub downcase {
  my $w = shift;
  if (defined($w)) {
	$w =~ tr/ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÈÉÊËÌÍÎÏÒÓÔÕÖØÙÚÛÜÝÇ/abcdefghijklmnopqrstuvwxyzàáâãäåæèéêëìíîïòóôõöøùúûüÿç/;
  }

  return $w;
}

#
# Substitute uc() functions not dependant on locale.
#
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
