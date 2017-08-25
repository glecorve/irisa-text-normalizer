#!/usr/bin/perl
#
# Gather usefull functions for text and prompt tokenization
# Gwenole Lecorve
#

# ================================================================= #
# ================================================================= #
# ================================================================= #

package tokenize;

# use locale;
# use POSIX qw(locale_h);
# setlocale(LC_CTYPE, "ISO-8859-1");

# use strict;
use warnings;
# use locale;
use File::Temp qw/ tempfile /;
# use POSIX qw(strftime locale_h);
# use locale;
# setlocale(LC_CTYPE, "UTF8");
# setlocale(LC_COLLATE, "UTF8");
use strict;

require Exporter;

our @ISA=qw/Exporter/;
our @EXPORT = qw/&define_rule_preprocessing &undefine_rule_preprocessing reset_token_map load_token_map map_string map_string_on_counts &downcase/;

# BEGIN {
#   print "Module \"tokenize\" version 0.1 (revision to be defined)\n";
# }

our $debug = 0;
my $END_SEP = " |\n|\$|'[sS]? ";


my %all_rules;
my $preprocessing = undef;
my $case_sensitivity = 1;

# ================================================================= #
# ================================================================= #
# ================================================================= #




# -------------------------------- #
# ----- sub reset_token_map() ----- #
# -------------------------------- #
#
# Reset the history of read rules
#

sub reset_token_map {
	undef(%all_rules);
	%all_rules = ();
}


sub define_rule_preprocessing {
	$preprocessing = shift;
}

sub undefine_rule_preprocessing {
	$preprocessing = undef;
}

sub define_rule_case_unsensitive {
	$case_sensitivity = 0;
}

sub define_rule_case_sensitive {
	$case_sensitivity = 1;
}


# -------------------------------- #
# ----- sub load_token_map() ----- #
# -------------------------------- #
#
# Load a map for tokenization. Maps are actually rewrite rules of the
# form 'initial token => rewrite', with one entry per line. The map is
# returned as a table where each entry is a hash containing the two
# keys 'original' and 'rewrite'.
#
# Input   -- list of map filenames
# Update  --
# Output  -- map
sub load_token_map {
  my $mapp = shift;
  my ($w1, $w2);

  my $i = scalar @{$mapp};
  my ($tmp_f_handler, $tmp_f)	 = tempfile(UNLINK => 1);

  foreach my $fn (@_) {

	if (defined($preprocessing)) {
		system("$preprocessing $fn > $tmp_f");
		$fn = $tmp_f;
	}

    open(F, $fn) or die "cannot open word mapping file $fn";

    foreach ( <F> ) {
      chomp;
# 	print "$_\n";

      # kill comments and remove leading and trailing blanks
#       s/#.*$//;
#       s/^\s*//;
#       s/\s*$//;

      next if /^$/;
      next if /^ *#/;

      s/\s+/ /;

      if ($_ =~ /^(.*?) => (.*?)(\r|\n|#|$)/) {
	($w1, $w2) = ($1, $2);

	#       if (grep $_ eq "$1", @{$mapp}) {
	# 	warn "tokenize::load_token_map() -- multiple mapping rules for $1 (ignoring)\n";
	#       }
	if ($w1 =~ /^\s*$/) {
# 		print "A $w1 -> $w2\n";
		warn "tokenize::load_token_map() -- empty mapping rules for NULL => $w2 (ignoring)\n";
	}
	elsif ($w2 =~ /^\s*$/) {
# 		print "B $w1 -> $w2\n";
		warn "tokenize::load_token_map() -- empty mapping rules for $w1 => NULL (ignoring)\n";
	}
	elsif ($w1 eq $w2) {
# 		print "B $w1 -> $w2\n";
#		warn "tokenize::load_token_map() -- useless mapping $w1 => $2 (ignoring)\n";
	}
	elsif (defined($all_rules{$w1}) && $all_rules{$w1} ne $w2) {
# 		print "C $w1 -> $w2\n";
		warn "tokenize::load_token_map() -- multiple mapping rules for $w1 => $w2 | $all_rules{$w1} (ignoring)\n";
	}
	else {
# 		print "D $w1 -> $w2\n";
		$all_rules{$w1} = $w2;
		$$mapp[$i]{original} = $w1;
		$$mapp[$i]{rewrite} = $w2;
		$i++;

		#kind of hack for case unsensitivity w/o slowing down the process to much
		if ($case_sensitivity == 0) {
			# abc => def -> Abc => Def
			$w1 =~ s/^(.)/uc($1)/ge;
			$w2 =~ s/^(.)/uc($1)/ge;
			$$mapp[$i]{original} = $w1;
			$$mapp[$i]{rewrite} = $w2;
			$i++;
#			print STDERR "$w1 -> $w2\n";

			# abc => def -> ABC => DEF
			$w1 =~ s/^(.*)$/uc($1)/ge;
			$w2 =~ s/^(.*)$/uc($1)/ge;
			$$mapp[$i]{original} = $w1;
			$$mapp[$i]{rewrite} = $w2;
			$i++;
#			print STDERR "$w1 -> $w2\n";
		}

	}
      }
    }

    close(F);
  }

  if (defined($preprocessing)) {
  	system("rm -f $tmp_f");
  }

  if ($debug) {
    print STDERR "tokenize::load_token_map() -- $_->{original} => $_->{rewrite}\n" foreach @{$mapp};
  }
  	return;
}

# ---------------------------- #
# ----- sub map_string() ----- #
# ---------------------------- #
#
# Map words in a string according to the specified map.
#
sub map_string {
  my $p_s = shift;
  my $i=0;
  #foreach map
	foreach (@_) {
#	  my $n = @{$_}+0;
		for my $r (@{$_}) { #foreach rule in the current map
		# print STDERR $r."\n";
			if (defined($$p_s)) {
#					print STDERR "$i / $n\n"; $i++;
					$$p_s =~ s/(?:^| )\K$r->{original}(?=$END_SEP)/$r->{rewrite}/gm;
			}
		}
	}
	return;

}

# ----------------------------------------- #
# ----- sub map_string_line_by_line() ----- #
# ----------------------------------------- #
#
# Map words in a string according to the specified map.
# BUT 1 pattern <=> 1 full line
#
sub map_string_on_counts {
  my $s = shift;
  my $i=0;
  #foreach map
  foreach (@_) {
   for my $r (@{$_}) { #foreach rule in the current map
#     print STDERR $i++."\n";
    $s =~ s/^$r->{original}\t/$r->{rewrite}\t/gm;
   }
  }

  return $s;
}

# -------------------------- #
# ----- sub downcase() ----- #
# -------------------------- #
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

1;
