#!/usr/bin/perl
#
# Gather usefull functions for text and prompt tokenization
# Gwenole Lecorve
#

# ================================================================= #
# ================================================================= #
# ================================================================= #

package RulesApplication;

# use locale;
# use POSIX qw(locale_h);
# setlocale(LC_CTYPE, "ISO-8859-1");

use strict;
use warnings;
use Data::Dumper;
# use locale;
use File::Temp qw/ tempfile /;
# use POSIX qw(strftime locale_h);
# use locale;
# setlocale(LC_CTYPE, "UTF8");
# setlocale(LC_COLLATE, "UTF8");
use strict;

require Exporter;

our @ISA=qw/Exporter/;
our @EXPORT = qw/%maps &define_rule_preprocessing &undefine_rule_preprocessing  &define_rule_case_unsensitive &define_rule_case_sensitive reset_token_map load_token_map map_string map_string_on_counts &load_rules &apply_rules &apply_rules_counts/;

our $debug = 0;
my $END_SEP = " |\n|\$|'[sS]? ";

our %maps = ();
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
	# 	warn "RulesApplication::load_token_map() -- multiple mapping rules for $1 (ignoring)\n";
	#       }
	if ($w1 =~ /^\s*$/) {
		warn "RulesApplication::load_token_map() -- empty mapping rules for NULL => $w2 (ignoring)\n";
	}
	elsif ($w2 =~ /^\s*$/) {
		warn "RulesApplication::load_token_map() -- empty mapping rules for $w1 => NULL (ignoring)\n";
	}
	elsif ($w1 eq $w2) {
#		warn "RulesApplication::load_token_map() -- useless mapping $w1 => $2 (ignoring)\n";
	}
	elsif (defined($all_rules{$w1}) && $all_rules{$w1} ne $w2) {
		warn "RulesApplication::load_token_map() -- multiple mapping rules for $w1 => $w2 | $all_rules{$w1} (ignoring)\n";
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
    print STDERR "RulesApplication::load_token_map() -- $_->{original} => $_->{rewrite}\n" foreach @{$mapp};
  }
  	return;
}


##################################################################
# APPLY MAPPING RULES (generic function: read a mapping file)
##################################################################

sub load_rules {
	my $KEY = shift;
	my @rule_files = @_;

	my @map;
	reset_token_map();

	for my $i (0 .. $#rule_files) {
	RulesApplication::load_token_map(\@map, $rule_files[$i]);
	}

	$maps{$KEY} = \@map;
	return;
}

sub apply_rules {
	my $P_TEXT = shift;
	my @rule_files = @_;
	for my $i (0 .. $#rule_files) {
     if (!defined($maps{$rule_files[$i]})) {
       load_rules($rule_files[$i], $rule_files[$i]);
     }
	   map_string($P_TEXT, $maps{$rule_files[$i]});
   }
	return;
}

sub apply_rules_counts {
	my $TEXT = shift;
	my @rule_files = @_;

	my @map;
	reset_token_map();

	for my $i (0 .. $#rule_files) {
	RulesApplication::load_token_map(\@map, $rule_files[$i]);
	}

	return RulesApplication::map_string_on_counts($TEXT, \@map);

}

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


1;
