#!/usr/bin/perl
#
# CountProcessing.pm
# Many functions to process a vocabulary and counts
#
# July, 2011
# Gwénolé Lecorvé
# 
########################################################

package CountProcessingFr;

use strict;
use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/.";
use CorpusNormalisationFr;
#use Lingua::EN::Numbers qw(num2en num2en_ordinal);
use List::Util qw[min max];
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter);
BEGIN {
  @EXPORT = qw(&protect &is_protected &project_dash &project_apostrophe &project_case &letter_nb &safe_print &load_1g_counts &load_2g_counts &set_vocab_size &build_classes &find_within_eq_class &list_words &entering_vocab &try_hyphenate &try_apostrophe &explode_acronym &transform_oov &loop_over_oovs &one_oov &transform_bigram &loop_over_bigrams &remove_conflicts &apply_mapping &add_new_rules &update_counts &update_in_vocabulary &update_uni_counts_in_bigrams &union &compute_measures &same_vocab &is_in_vocabulary &get_count_of &list_common_cased_words &print_debug &reset_class_names &set_class_names);
}


#################################

my %uni_counts_in_bigrams = (); #counts of unigrams in bigrams
my %eq_class = (); #equivalence classes
my %max_potential = (); #maximum number of occurrence that a word could expect
my %counts = (); # counts of unigrams
my %in_vocabulary = (); # list of in vocabulary words (wrt to the size of the vocabulary)
my $vocab_size = 0; # size of the vocabulary in number of words
my %letters_ng = (); #counts of sequences of letters
my @class_names = ();
my %in_class = ();




#################################

my %simplication_deadlock = ();


sub protect {
	my $to_be_protected = shift;
	$simplication_deadlock{$to_be_protected} = 1;
}


sub is_protected {
	my $x = shift;
	return defined($simplication_deadlock{$x});
}

#################################

sub log2 {
	return log(shift)/log(2);
}

sub project_dash {
	my $a = shift;
	$a =~ s/\-( |$)/$1/g;
	$a =~ s/(^| )\-/$1/g;
	$a =~ s/\-/ /g;
	return $a;
}

sub project_apostrophe {
	my $a = shift;
	$a =~ s/'( |$)/$1/g;
	$a =~ s/(^| )'/$1/g;
	$a =~ s/'/ /g;
	return $a;
}

sub project_case {
	my $x = shift;
	$x =~ s/(^| |-)([A-Z])(.*)/$1.$2.lc($3)/ge;
	return $x;
}

sub letter_nb {
	my $x = shift;
	$x =~ s/[^A-Za-z0-9]//g;
	return length($x);
}


sub safe_print {
	my $k = shift;
	my $v = shift;
	my $n = letter_nb($k);
	if ($k ne $v #useless rules
	&& $k ne ""
	&& $v ne ""
	&& $k !~ /,/
	&& $k !~ /\(.*\)/
	&& $v !~ /\(.*\)/
	&& $n < 21 #no more than 20 letters (useless)
	&& $k !~ / .* .* /) { #no more that 3 words (useless)
		#escape special characters
		$k =~ s/\./\\./g;
		$k =~ s/\?/\\?/g;
		$k =~ s/\*/\\*/g;
		$k =~ s/\+/\\+/g;
		my $extra = "";
		if (!is_protected('saxon')) {
			$extra = " #watch out: space (saxon genitive splitting)";
		}
		if (is_protected('uppercase')) {
			$k = uc($k);
			$v = uc($v);
		}
		return "$k => $v$extra\n";
	}
}


#################################

sub load_1g_counts {
	my $f = shift;
	my $min = shift;
	my $w = "";
	my $c = "";
	open(F,"< $f");
	print STDERR "Loading... ";
	while (<F>) {
		chomp;
		#unigrams only
		next if ($_ =~ / /);
		($w, $c) = $_ =~ /^(.*)\t(\d+)$/;
		# count word
		if ($c >= $min) {
			$counts{$w} += $c;
			build_classes($w);
		}
	}
	close(F);
}

sub load_2g_counts {
	my $f = shift;
	my $min = shift;
	my $w = "";
	my $c = "";
	open(F,"< $f");
	print STDERR "Loading... ";
	while (<F>) {
		chomp;
		#unigrams and bigrams only
		next if ($_ =~ /^.* .* /);
		($w, $c) = $_ =~ /^(.*)\t(\d+)$/;
		# count word
		if ($w =~ / / || $c >= $min) {
			$counts{$w} += $c;
		}
		# and build classes if unigram
		if ($w !~ / /) {
			build_classes($w) if $c >= $min;
		}
		#bigrams
		else {
			foreach my $t (split(/ +/,$w)) {
				$uni_counts_in_bigrams{$t} += $c;
			}
		}
	}
	close(F);
}

sub load_letters_ng {
 	my @tab = @_;
 	%letters_ng = ();
 	my $x = "";
 	foreach my $w (@tab) {
 		my $n = max(2, min(9, length($w)))-1;
 		for (my $i = 1; $i <= $n; $i++ ) {
 			$x = $w;
 			if (length($x) >= $i+1) {
 				while ($x =~ s/^(.)(.{${i}})/$2/g) {
 					$letters_ng{$1.$2} = 1;
 				}
 			}
  		}
	}
}

sub set_vocab_size {
	$vocab_size = shift;
}

sub build_classes {
	my $x =shift;
	my $proj_dash = project_dash($x);
	my $proj_apo = project_apostrophe($x);
	my $proj_case = project_case($x);
	#print "\nBUILD_CLASSES\t$x = $proj_dash $proj_apo $proj_case\n";
	if (!defined($eq_class{$proj_dash}{"dash"})) {
		@{$eq_class{$proj_dash}{"dash"}} = ();
	}
	push(@{$eq_class{$proj_dash}{"dash"}}, $x);
	
	if (!defined($eq_class{$proj_apo}{"apostrophe"})) {
		@{$eq_class{$proj_apo}{"apostrophe"}} = ();
	}
	push(@{$eq_class{$proj_apo}{"apostrophe"}}, $x);
	
	if (!defined($eq_class{$proj_case}{"case"})) {
		@{$eq_class{$proj_case}{"case"}} = ();
	}
	push(@{$eq_class{$proj_case}{"case"}}, $x);
	
	#compute potentials
	$max_potential{$x} += $counts{$x};
	if ($x =~ /^(.+?)-(.+)$/) {
		$max_potential{$1} += $counts{$x};
		$max_potential{"$1-"} += $counts{$x};
		$max_potential{$2} += $counts{$x};
		$max_potential{"-$2"} += $counts{$x};
	}

}

sub find_within_eq_class {
	my $x = shift;
	return $x if ($x =~ /'(?:s|t|d|ve|ll|m)$/);
	my @sorted= sort {$counts{$b} <=> $counts{$a}} @_;
	if ($counts{$sorted[0]} == $counts{$sorted[1]} && lc($sorted[0]) eq lc($sorted[1])) {
		return $x;
	}
	return $sorted[0];
}



####################################################
# output
####################################################

sub list_words {
	my $p_tab = shift;
	foreach my $w (keys(%counts)) {
		if ($w !~ / / && $w ne "") {
			if ($counts{$w} > 0) {
				push(@{$p_tab}, $w);
			}
			else {
#			print "Strange count : $w : $$p_counts{$w}\n";
				delete($counts{$w});
			}
		}
	}
	@{$p_tab} = sort {$counts{$b} <=> $counts{$a}} @{$p_tab};
}

sub is_in_lexicon {
	my $x = shift;
	if (is_protected('uppercase')) {
		return defined($lexicon{lc($x)});
	}
	else {
		return defined($lexicon{$x});
	}
}

sub is_in_vocabulary {
	my $x = shift;
	return defined($in_vocabulary{$x});
}

sub entering_vocab {
	my $w1 = shift;
	my $w2 = shift;
	return 1;
#	return $counts{$w1} + $counts{$w2} > $counts{$words[$vocab_size-1]};
}

#hyphenate a-b
#if a- is in lexicon, then a- b
#if -b is in lexicon, then 
#else a b
sub try_hyphenate {
	my $x = shift;

	
	# a-
	if ($x =~ /^(.*)-$/) {
		#remove dash if becomes IV
		if (entering_vocab($x, $1)) {
			return $1;
		}
		else { return $x; }
	}
	
	# -b
	if ($x =~ /^-(.*)$/) {
		#remove dash if becomes IV
		if (entering_vocab($x, $1)) {
			return $1;
		}
		else { return $x; }
	}
	
	my ($a,$b) = $x =~ /^(.*?)-(.*)$/;
	if ($max_potential{"$a-"} > $max_potential{"-$b"}) {
		return "$a- $b";
	}
	else {
		return "$a -$b";
	}
	
	if (defined($in_vocabulary{"$a-"}) && defined($in_vocabulary{"-$b"})) {
		return (($counts{"$a-"}<$counts{"-$b"})?"$a -$b":"$a- $b");
		}
	elsif (defined($in_vocabulary{"$a-"})) { return "$a- $b"; }
	elsif (defined($in_vocabulary{"-$b"})) { return "$a -$b"; }
	elsif (entering_vocab($x, "$a-")) { return "$a- $b"; }
	elsif (entering_vocab($x, "-$b")) { return "$a -$b"; }
	#elsif (defined($in_vocabulary{"$b"})) { return "$a- $b"; }
#	elsif (defined($in_vocabulary{"$a"})) { return "$a -$b"; }
#	elsif ($counts{"$a"} < $counts{"$b"}) { return "$a- $b"; }
#	elsif ($counts{"$a"} > 0) { return "$a -$b"; }
	else { return "$a- $b"; }
}

#apostrophe a'b
#if 'b is in lexicon, then  a 'b
#if a' is in lexicon, then a' b
#...
sub try_apostrophe {
	my $x = shift;
	
	#don't touch Saxon genetives if asked so
	if (is_protected('saxon')) {
		if (is_protected('uppercase') && $x =~ /(?:'S|S')$/) {
			return $x;
		}
		elsif ($x =~ /(?:'s|s')$/) {
			return $x;
		}
	}
	
	#Saxon genitive
	if ($x =~ /^(.*)'s$/i || $x =~ /^(.*s)'$/i) {
		if (is_protected('uppercase')) {
			return "$1 'S";	
		}
		else {
			return "$1 's";
		}
	}
	# verbal contraction
	if ($x =~ /^(?:.*)'(?:t|d|re|ll|m|ve)$/i) {
		return $x;
	}
	# 'b
	if ($x =~ /^'(.*)$/) {
		my $end = $1;
		#remove if becomes IV
		if ($end !~ /^(d|ve|re|ll|m|s|t)$/i) {
			return $end;
		}
		else { return $x; }
	}
	# a'
	if ($x =~ /^(.*)'$/) {
			return $1;
	}
	# Ab'c -> Abc
	if (!is_protected('uppercase') && $x =~ /^([A-Z][a-z]+)'([a-rtz]+)$/) {
		my ($beg, $end) = ($1,$2);
		if ($end !~ /^(d|ve|re|ll|m|s|t)$/i) {
			return $beg.$end;
		}
		else { return $x; }
	}
	
	
	my ($a,$b) = $x =~ /^(.*)'(.*)$/;
	if (defined($in_vocabulary{"$a'"}) && defined($in_vocabulary{"'$b"})) {
		return (($counts{"$a'"}<$counts{"'$b"})?"$a '$b":"$a' $b");
	}
	elsif (defined($in_vocabulary{"'$b"})) { return "$a '$b"; }
	elsif (defined($in_vocabulary{"$a'"})) { return "$a' $b"; }
	elsif (defined($in_vocabulary{"$a"})) { return "$a '$b"; }
	elsif (defined($in_vocabulary{"$b"})) { return "$a' $b"; }
	elsif ($counts{"$a"} < $counts{"$b"}) { return "$a' $b"; }
	elsif ($counts{"$a"} > 0) { return "$a '$b"; }
	else { return "$a $b"; }
}

sub explode_acronym {
	my $x = shift;
#	print STDERR "ACRONYM $x\n";

	#separates numbers first
	# and return
	if ($x =~ /[0-9]/) {
		$x =~ s/([0-9])\1\1\1/ four $1 /g;
		$x =~ s/([0-9])\1\1/ triple $1 /g;
		$x =~ s/([0-9])\1/ double $1 /g;
		$x =~ s/([0-9])\.([0-9])/$1 point $2/g;
		while ($x =~ s/(\d+)(\d{2})/"$1 ".num2en($2)." "/ge) {}
		while ($x =~ s/(\d{2})/" ".num2en($1)." "/ge) {}
		while ($x =~ s/(\d)/" ".num2en($1)." "/ge) {}
		while ($x =~ s/(\d)/" ".num2en($1)." "/ge) {}
		$x =~ s/ty s$/ties/g;
	}
	elsif ($x =~ /^(.*)&(.*)$/) {
		$x = "$1 and $2";
	}
	# if no number left
	# process letters
	else {
		$x =~ s/([A-Z]\.)\1\1\1/ four $1 /g;
		$x =~ s/([A-Z]\.)\1\1/ triple $1 /g;
		while ($x =~ s/([A-Z]\.)(?! |$)/$1 /g) {}
		$x =~ s/([0-9]\.)(?>!\.)/$1/g;
		$x =~ s/([A-Z])(?>!\.)/$1./g;
	}

	$x =~ s/-+/ /g;
	$x =~ s/ +/ /g;
	$x =~ s/^ //g;
	$x =~ s/ $//g;
	$x =~ s/ s$/s/g;

	if (is_protected('uppercase')) {
		$x = uc($x);
	}
	return $x;
}

sub transform_oov {
	my $w = shift;
	my $prev_w = $w;
	my $changed = 0;
	
	
	# DASH
	if (!is_protected('uppercase') && $w =~ /^([A-Z].+?)-([a-z].+)$/ && is_in_lexicon(lc($1)) && is_in_lexicon($2)) {
		return lc($1)."-$2";
	}
	
	if ($w =~ /-/ && $w =~ /^[a-z]/) {
#		print STDERR "A\n" if $w eq "R.'s";
		$w = try_hyphenate($w);
		$changed = ($prev_w ne $w);
	}
	
	# APOSTROPHE
	if ($changed == 0 && $w =~ /'/) {
		$w = try_apostrophe($w);
		$changed = ($prev_w ne $w);
	}
	
	if ($changed == 0 && $w =~ /'/) {
		$w = find_within_eq_class($w, @{$eq_class{project_apostrophe($w)}{"apostrophe"}});
		return $w;
	}
	
	#ACRONYMS	

	#words beginning with a dot
	if ($changed == 0 && $w =~ /^\.(.*)$/) {
		return "dot $1";
	}
	
	#Single uppercase letters => add a dot
	if (!is_protected('uppercase') && $w =~ /^[A-Z]$/) {
#	print STDERR "D\n" if $w eq "R.'s";
		return "$w.";
	}
	
	#Single lowercase letters => upcase it (except a) and add a dot
	if (!is_protected('uppercase') && $w =~ /^[b-z]\.?$/) {
		return uc($w).".";
	}

	#All uppercased real words	
	if (!is_protected('uppercase') && $w =~ /^([A-Z])([A-Z]+)$/) {
		if (entering_vocab($1.$2, $1.lc($2))) {
			return $1.lc($2);
		}
#		print "C\n";
		else {
			$w = find_within_eq_class($w, @{$eq_class{project_case($w)}{"case"}});
		}
		$changed = ($prev_w ne $w);
	}
	
	if (!is_protected('uppercase') && $changed == 0 && $w =~ /^([BCDFGHJKLMNPQRSTVWXZ])([bcdfghjklmnpqrstvwxz])$/ && $w ne "Mc") {
		return "$1.".uc($2).".";
	}
	
	# php -> P.H.P.
	if (!is_protected('uppercase') && $changed == 0 && $w =~ /^[bcdfghjklmnpqrstvwxz]{2,}$/ && $w !~ /^(hm+|brr+|grr+|shh+)$/) {
		$w =~ s/(.)/$1./g;
		return uc($w);
	}
	
	#OOV letter acronyms without dots
	if (!is_protected('uppercase') && $changed == 0 && $w =~ /^[A-Z]+s'?s?$/) {
		if ($w =~ /[BCDFGHJKLMNPQRSTVWXZ]{2}/) {
			$w =~ s/([A-Z])/$1./g;
		}
		$changed = ($prev_w ne $w);
	}
	
	#Partial acronyms
	# IsT.V. -> Is T.V.
	# DDAT.V. -> DDA T.V.
	if ($changed == 0 && $w =~ /(?:[A-Z0-9]\.)+/ && $w =~ /[a-z]/) {
		$w =~ s/((?:[A-Z0-9]\.)+)/ $1 /g;
		$w =~ s/^ //g;
		$w =~ s/ $//g;
		$changed = ($prev_w ne $w);
	}
	
	
	#OOV acronyms
	if (!is_protected('uppercase') && $changed == 0 && $w =~ /^[A-Z0-9]\.?(?:[-&]?[A-Z0-9\-]+\.?)+s?'?[s]?$/) {
		$w = explode_acronym($w);
		$changed = ($prev_w ne $w);
	}
	if (is_protected('uppercase') && $w =~ /^(?:[A-Z]\.|[0-9])(?:[-&]?(?:[A-Z]\.|[0-9])+\.?)+S?'?[S]?$/) {
		$w = explode_acronym($w);
		$changed = ($prev_w ne $w);
	}

	#OOV Xxx012th
	if ($changed == 0 && $w =~ /^([[:alpha:]]+)(\d+(?:\.\d+)?)(?:st|nd|rd|th)$/i) {
		if (is_protected('uppercase')) {
			return uc("$1 ".num2en_ordinal($2));
		}
		else {
			return "$1 ".num2en_ordinal($2);
		}
	}
	
	#OOV Xxx012.34
	if ($changed == 0 && $w =~ /^([[:alpha:]]+)(\d+(?:\.\d+)?)$/i) {
		if (is_protected('uppercase')) {
			return uc("$1 ".num2en($2));
		}
		else {
			return "$1 ".num2en($2);
		}
	}
	
	#OOV XxxYyy
	if ($changed == 0 && $w =~ /^([A-Z][a-z]+)([A-Z][[:alpha:]]+)$/) {
		return "$1 $2";
	}

	#Single ordinal
	if ($changed == 0 && $w =~ /^(?:1st|2nd|3rd|\d+th)$/) {
		if (is_protected('uppercase')) {
			return uc(num2en_ordinal($w));
		}
		else {
			return num2en_ordinal($w);
		}
	}
	
	#Single numbers
	if ($changed == 0 && $w =~ /^\d+(?:\.\d+)?$/) {
		if (is_protected('uppercase')) {
			return uc(num2en($w));
		}
		else {
			return num2en($w);
		}
	}
	


	if ($changed == 0 && $w =~ /-/) {
		$w =~ s/-/ /g;
		$changed = ($prev_w ne $w);
	}
	if ($changed == 0 && $w =~ /^[^A-Z]/ && $w =~ /'/) {
#	print "E\n";
		$w =~ s/'/ /g;
		$changed = ($prev_w ne $w);
	}
	return $w;
			
}


sub loop_over_oovs {
	my $p_new_rules = shift;
	my %new_projection = ();
	foreach my $w (sort {$counts{$a} <=> $counts{$b}} keys(%counts)) {
	next if ($w =~ / /);
	next if (is_in_vocabulary($w));
		# if still something to do with the word
		if (!defined($new_projection{$w})) {
			my $new_w = transform_oov($w);
#			if ($w =~ /\./) { print STDERR "$new_w instead of $w\n"; }
			$new_w =~ s/ +/ /g;
			$new_w =~ s/ $//g;
			$new_w =~ s/^ //g;
			
#			if (is_protected('uppercase')) {
#				$new_w = uc($new_w);
#			}
			
			#if transformed
			#then store the rule
			if ($w ne $new_w) {
				# To prevent further changes before the current changes haven't been registered
				$new_projection{$new_w} = 1;
				foreach my $t (split(/ /,$new_w)) {
					$new_projection{$t} = 1;
				}
				$$p_new_rules{$w} = $new_w;
				build_classes($new_w);
			}
		}
	}
}

sub one_oov {
	my @tab = split(/ +/, shift(@_));
	foreach my $t (@tab) {
		if (!defined($in_vocabulary{$t})) {
			return 1;
		}
	}
	return 0;
}

sub transform_bigram {
	my $seq = shift;
	my $prev_seq = $seq;
	my $changed = 0;
	
	if ($seq =~ /^([A-Z])([^ \-\']+) ([A-Z])([^ \-\']+)$/i) {
	
		my ($U,$u,$V,$v) = ($1,$2,$3,$4);
		my ($Aa,$aa,$Bb,$bb);
		if ($U =~ /[A-Z]/) {
			$Aa = uc($U).$u;
			$aa = lc($U).$u;
		}
 		else {
 			$Aa = lc($U).$u;
 			$aa = uc($U).$u;		
 		}
		if ($V =~ /[A-Z]/) {
			$Bb = uc($V).$v;
			$bb = lc($V).$v;
		}
 		else {
 			$Bb = lc($V).$v;
 			$bb = uc($V).$v;
 		}
		my %four_counts = ();
		my @candidates = ();
		if (defined($in_vocabulary{$Aa})) {
			if (defined($in_vocabulary{$Bb})) {
				push(@candidates, "$Aa $Bb");
			}
			else {
				push(@candidates, "$Aa $Bb", "$Aa $bb");
			}
		}
		else {
			if (defined($in_vocabulary{$Bb})) {
				push(@candidates, "$Aa $Bb", "$aa $Bb");
			}
			else {
				push(@candidates, "$Aa $Bb", "$Aa $bb", "$aa $Bb", "$aa $bb");
			}		
		}
		my @sorted = sort {$counts{$b} <=> $counts{$a}} @candidates;
		
		#change if there is a big difference, otherwise meaning that the different forms are all correct.
		if ($counts{$sorted[0]} > 5*$counts{$seq}) {
			return $sorted[0];
		}
		else {
			return $seq;
		}
	}
	
	return $seq;
}

sub loop_over_bigrams {
	my $p_new_rules = shift;
	foreach my $seq (keys %counts) {
		if ($seq =~ /^[^ ]+ [^ ]+$/) {
			if (one_oov($seq) == 1) {
			# if still something to do with the word
				my $new_seq = transform_bigram($seq);
				#if transformed
				#then store the rule
				if ($seq ne $new_seq) {
					$$p_new_rules{$seq} = $new_seq;
				}
			}
		}
	}
}

sub remove_conflicts {
	my $p_rules = shift;
	my %affected_by_rules = ();
	
	#priority to long rules
	foreach my $k (sort { length($b) <=> length($a) } (keys %{$p_rules})) {
		foreach my $t (split(/ +/,$$p_rules{$k})) {
			$affected_by_rules{$t}++;
		}
	}
	
	#try to remove some rules by starting with shortest ones
	foreach my $k (sort { length($a) <=> length($b) } (keys %{$p_rules})) {
		if ($affected_by_rules{$k} > 0) {
			delete($$p_rules{$k});
			$affected_by_rules{$k}--;
		}
	}
}

sub apply_mapping {
	my $new = shift; #pointer to a hash
	my $all = shift; #pointer to an other hash
	my $reverse = shift; #pointer to the reverse of $$all

	foreach my $k (keys (%{$all})) {
		my $v = $$all{$k};
		my @tokens = ();
		foreach my $t (split(/ +/, $v)) {
			if (defined($$new{$t})) {
				push(@tokens, $$new{$t});
			}
			else {
				push(@tokens, $t);
			}
		}
		my $new_k = join(" ", @tokens);
		$new_k =~ s/ +/ /g;
		$new_k =~ s/ $//g;
		$new_k =~ s/^ //g;
		delete($$reverse{$$all{$k}}{$k});
#		if ($new_k ne $k) {
			$$reverse{$new_k}{$k} = 1;
			$$all{$k} = $new_k;
#		}
	}
}


sub add_new_rules {
	my $new = shift; #pointer to a hash
	my $all = shift; #pointer to an other hash
	my $reverse = shift; #pointer to the reverse of $$all
	foreach my $k (keys(%{$new})) {
		$$all{$k} = $$new{$k};
		$$reverse{$$new{$k}}{$k} = 1;
	}
}


sub update_counts {
	my $p_reverse_rules = shift; #pointer to the reverse of all current rules
	my $total = 0;
	foreach my $v (keys (%{$p_reverse_rules})) {
		foreach my $k (keys (%{$$p_reverse_rules{$v}})) {
			my $c = $counts{$k};
			next if (!($c > 0));
			$counts{$k} -= $c;
			$counts{$v} += $c;

			# if A B -> A C, 
			#otherwise, adjust count(B) to the total of C's in bigrams
			if ($v =~ / / && $k =~ / /) {
				my @tabv = split(/ +/,$v);
				my @tabk = split(/ +/,$k);
				
				if ($#tabv != $#tabk) { die("$k and $v: not the same size"); }
				
				for (my $i = 0; $i < @tabv+0; $i++) {
					my $tv = $tabv[$i];
					my $tk = $tabk[$i];
					next if ($tk eq $tv);
					 my $ck = 0;
					$ck = int( $counts{$tk} * $c / $uni_counts_in_bigrams{$tk} );
					$counts{$tv} += $ck;					
					$counts{$tk} -= $ck;
				}

			}
			elsif ($v =~ / /) {
				foreach my $t (split(/ +/,$v)) {
					if ($counts{$t} == 0) {
						build_classes($t);
					}
					$total += $c;
					$counts{$t} += $c;

				}
			}
			
		delete($$p_reverse_rules{$v}{$k});
		delete($counts{$k});
		}
		delete($$p_reverse_rules{$v});
	}
}

sub update_in_vocabulary {
	my $p_tab = shift;
	%in_vocabulary  = ();
	for (my $i = 0; $i < $vocab_size; $i++) {
		if ($counts{${$p_tab}[$i]} > 0) {
			$in_vocabulary{${$p_tab}[$i]} = 1;
		}
	}
}

sub update_uni_counts_in_bigrams {
	%uni_counts_in_bigrams = ();
	foreach my $seq (keys(%counts)) {
		if ($seq =~ / / && $seq !~ / .* /) {
			foreach my $t (split(/ +/,$seq)) {
				$uni_counts_in_bigrams{$t} += $counts{$seq};
			}
		}
	}
}






sub union {
	my %h;
	map {$h{$_} = 1} @_;
	return keys %h;
}


sub same_vocab {
	my $a = shift; #pointer to an array
	my $b = shift; #pointer to an other array
	for (my $i = 0; $i < $vocab_size; $i++) {
		if ($$a[$i] ne $$b[$i]) { return 0; }
	}
	return 1;
}




sub get_count_of {
	return $counts{shift}+0;
}


sub list_common_cased_words {
	my $p_words = shift;
	my $n = 0;
	my $n_both = 0;
	my $n_one = 0;
	my $n_none = 0;
	foreach my $w (@{$p_words}) {
		if ($w =~ /^[A-Z]/ && is_in_lexicon(lc($w)) && get_count_of(lc($w)) > 0) {
			print STDERR "$w\t(".get_count_of($w)." / ";
			print STDERR ((is_in_vocabulary($w) == 1)?"IV":"OOV");
			print STDERR ")\t".lc($w)."\t(".get_count_of(lc($w))." / ";
			print STDERR ((is_in_vocabulary(lc($w)) == 1)?"IV":"OOV");
			print STDERR ")\n";
			if (is_in_vocabulary($w) && is_in_vocabulary(lc($w))) { $n_both++; }
			elsif (is_in_vocabulary($w) || is_in_vocabulary(lc($w))) { $n_one++; }
			else { $n_none++; }
		}
	}
	print STDERR "TOTAL: $n cases ($n_both both IV ; $n_one only one IV ; $n_none zero IV)\n";
	
}



 
 sub print_debug {
 	my $p_new = shift;
 	my $p_all = shift;
 	my $p_rev = shift;
 	my @words = @_;
 
 	print "\n\n	------------------------\n\n";
 	print "\nNEW RULES\n";
 	foreach my $k (keys %{$p_new}) {
 		print "$k => $$p_new{$k}\n";
 	}
 
 	print "\nALLL RULES\n";
 	foreach my $k (keys %{$p_all}) {
 		print "$k => $$p_all{$k}\n";
 	}
 
 	print "\nREVERSE RULES\n";	
 	foreach my $v (keys %{$p_rev}) {
 		print "$v <= ".join(" , ", keys %{$$p_rev{$v}})."\n";
 	}
#  
#  	print "\nCOUNTS\n";	
#  	foreach my $k (sort {$counts{$b} <=> $counts{$a}} keys %counts) {
#  		print "$k = $counts{$k}\n";
#  	}
 
 
 	print "\nWORDS ($vocab_size)\n";	
 	print join("\n", map {"$_\t($counts{$_})"} @words[0..($vocab_size-1)])."\n";
 	
# 	print "\nOOVs ".($#words-$vocab_size+1)."\n";	
# 	print join("\n", map {"$_\t($counts{$_})"} @words[($vocab_size)..($#words)])."\n";
 	
 	print "\n";	
 #	print join(" --- ",compute_measures(\@words))."\n";
 
 }




sub prefix {
	my $p_new = shift;
	my $x = shift;
	my $p_h = shift;
	my $max = shift;
	foreach my $y (@_) {
		my $n = length($x)+length($y);
		if ($n <= $max && ($n > 9 || defined($letters_ng{$n}{$x.$y}))) {
			$$p_new{$x.$y} += $$p_h{$x}*$$p_h{$y};
		}
	}
}



sub concat_all_ngrams {
	my $n = shift;
	my $max_length = shift;
	my @wrds = @_;
	my %out = ();
	my %h_wrds = ();
	my %real_wrds = ();
	my $n_prefix = 0;

	sub try_to_chunk {
		my $x = shift;
		my @tab = ();
		my $n = length($x);
		for (my $i = 1; $i < $n; $i++) {
			my $m = max(1,$n-$i);
			$x =~ /^(.{${m}})(.{${i}})$/;
			my ($u, $v) = ($1,$2);
			if (defined($h_wrds{$u}) && defined($h_wrds{$v}) && defined($real_wrds{$v}) && $u =~ /[aeiou\.]/ && $v =~ /[aeiou\.]/) {
					push(@tab,"$u/$v");
			}
		}
		return @tab;
	}
	
	sub prod {
		if (@_ == ()) {
			return 1;
		}
		else {
			return shift(@_)*prod(@_);
		}
	}

	
	for (my $i = 0; $i < @wrds+0; $i++) {
#		print $wrds[$i];
		$wrds[$i] =~ s/^([EI])-/$1./gi;
		$wrds[$i] =~ s/[\-'_]//g;
		$wrds[$i] =~ s/([AOU])\./$1/g;
		$wrds[$i] = lc($wrds[$i]);
		$real_wrds{$wrds[$i]} = 1;
		$h_wrds{$wrds[$i]}++;
		
#		print " becomes ".$wrds[$i]." = $h_wrds{$wrds[$i]}\n";
	}
	load_letters_ng(@wrds);

	my @iv = sort {length($a) <=> length($b)} keys(%h_wrds);
	foreach my $w (@iv) {
		if ($w =~ /[aeiouy\.]/) {
			foreach my $chunk (try_to_chunk($w)) {
#				print "$w can be $chunk\n";
				foreach my $c (split("/",$chunk)) {
#					print "$c = $h_wrds{$c}\n";
				}
				$h_wrds{$w} += prod(map {$h_wrds{$_}} split("/",$chunk));
			}
			foreach my $v (@iv) {
				if ($v =~ /[aeiouy\.]/) {
					if (!defined($h_wrds{$v.$w}) && defined($letters_ng{$v.$w})) {
						$h_wrds{$v.$w} += $h_wrds{$v}*$h_wrds{$w};
					}
					if (!defined($h_wrds{$w.$v}) && defined($letters_ng{$w.$v})) {
						$h_wrds{$w.$v} += $h_wrds{$v}*$h_wrds{$w};
					}
				}
			}
		}
	}
	return %h_wrds;
}

sub compute_confusability {
	my %conf = ();
	my $x;
	my $max_length = 0;
	my $total = 0;
	map {$max_length = max($max_length, length($_))} @_;
	%conf = concat_all_ngrams(20, $max_length, @_);
	foreach my $w (@_) {
		$x = $w;
		$x =~ s/^([EI])-/$1./g;
		$x =~ s/[\-'_]//g;
		$x =~ s/([AOU])\./$1/g;
		$x = lc($x);
#		print "- $w\t$x\t$conf{$x}\n";
		$total += $conf{$x};
	}
	return $total/($#_+1);
}



# Vocab size
# OOV Rate
# Number of OOVs
# Entropy
# Entropy ratio
# Unigram perplexity
# Ratios on acronyms
# Ratios on 1-char words
# Ratios on hyphenated words
# Ratios on prefixes
# Ratios on suffixes
# Ratios on apostrophes
# Ratios on saxon genitives
# Ratios on cased words
# OOV rates / class
sub compute_measures {
	my $p_tab = shift;
	my $p_classes = shift;
	my $total = 0;
	my $total_words = 0;

	my $iv_counts = 0;
	my $iv_words = 0;
	my $iv_rate = 0;
	
	my $oov_counts = 0;
	my $oov_words = 0;
	my $oov_rate = 0;


	my %iv_x_counts = ();
	my %iv_x_words = ();
	my %iv_x_rate = ();	
	my %oov_x_counts = ();
	my %oov_x_words = ();
	my %oov_x_rate = ();
	
	my $total_entropy = 0;
	my $V_entropy = 0;
	
	my $ER_ACRONYM = '';
	my $ER_ONE_CHAR = '';
	if (is_protected('uppercase')) {
		$ER_ACRONYM = '^([A-Z]\.|\d)([A-Z]\.|\d|&|\-)+(?:S\'?|\'S)?$';
		$ER_ONE_CHAR = '^(?:\d+|[A-Z]\.)(?:S\'?|\'S)?$';
	}
	else {
		$ER_ACRONYM = '^[A-Z0-9][\.\-]?[A-Z0-9\.\-&]+(?:s\'?|\'s)?$';
		$ER_ONE_CHAR = '^(?:\d+|\w\.?)(?:s\'?|\'s)?$';
	}
	
	
	for (my $i = 0; $i < @{$p_tab}+0; $i++) {
		my $w = ${$p_tab}[$i];
		my $c = $counts{$w};
		if ($counts{$w} > 0) {
		
			#IN VOCABULARY
			if ($i < $vocab_size) {
				$iv_words++;
				$iv_counts += $c;
				#acronyms
				my $w2 = $w;
				# $w2 =~ s/[\.\-]//g;
				if ($w2 =~ /$ER_ACRONYM/) {
					$iv_x_words{"Acronyms"}++;	
					$iv_x_counts{"Acronyms"} += $c;
				}
				elsif ($w =~ /$ER_ONE_CHAR/) {
					$iv_x_words{"1-char words"}++;	
					$iv_x_counts{"1-char words"} += $c;
				}
				if ($w =~ /[a-z0-9]-[a-z0-9]/i) {
					$iv_x_words{"Hyphenated words"}++;
					$iv_x_counts{"Hyphenated words"} += $c;
				}
				elsif ($w =~ /^-[a-z0-9]/i) {
					$iv_x_words{"Suffixes"}++;
					$iv_x_counts{"Suffixes"} += $c;
				}
				elsif ($w =~ /^[a-z0-9]-/i) {
					$iv_x_words{"Prefixes"}++;
					$iv_x_counts{"Prefixes"} += $c;
				}
				if ($w =~ /'s?$/i) {
					$iv_x_words{"Saxon genitive"}++;
					$iv_x_counts{"Saxon genitive"} += $c;
				}
				if ($w =~ /[a-z0-9]'[a-z0-9]/i) {
					$iv_x_words{"With apostrophe"}++;
					$iv_x_counts{"With apostrophe"} += $c;
				}
				if ($w =~ /^[A-Z][a-z]/) {
					$iv_x_words{"Cased words"}++;
					$iv_x_counts{"Cased words"} += $c;
				}
				
				foreach my $class (keys(%{$p_classes})) {
					if (defined($$p_classes{$class}{$w})) {
						$iv_x_words{"<$class>"}++;
						$iv_x_counts{"<$class>"} += $c;
					}
				}
				
			}
			
			#OUT OF VOCABULARY
			else {
				$oov_words++;
				$oov_counts += $c;
#				print STDERR "OOV $w\n";
				if ($w =~ /$ER_ACRONYM/) {
#				print STDERR "$w ACRO OOV $ER_ACRONYM\n";
					$oov_x_words{"Acronyms"}++;	
					$oov_x_counts{"Acronyms"} += $c;
				}
				elsif ($w =~ /$ER_ONE_CHAR/) {
					$oov_x_words{"1-char words"}++;	
					$oov_x_counts{"1-char words"} += $c;
				}
				if ($w =~ /[a-z0-9]-[a-z0-9]/i) {
					$oov_x_words{"Hyphenated words"}++;
					$oov_x_counts{"Hyphenated words"} += $c;
				}
				elsif ($w =~ /^-[a-z0-9]/i) {
					$oov_x_words{"Suffixes"}++;
					$oov_x_counts{"Suffixes"} += $c;
				}
				elsif ($w =~ /^[a-z0-9]-/i) {
					$oov_x_words{"Prefixes"}++;
					$oov_x_counts{"Prefixes"} += $c;
				}
				if ($w =~ /'s?$/i) {
					$oov_x_words{"Saxon genitive"}++;
					$oov_x_counts{"Saxon genitive"} += $c;
				}
				if ($w =~ /[a-z0-9]'[a-z0-9]/i) {
					$oov_x_words{"With apostrophe"}++;
					$oov_x_counts{"With apostrophe"} += $c;
				}
				if ($w =~ /^[A-Z][a-z]/) {
					$oov_x_words{"Cased words"}++;
					$oov_x_counts{"Cased words"} += $c;
				}
				
				foreach my $class (@class_names) {
					if (defined($in_class{$class}{$w})) {
						$oov_x_words{"<$class>"}++;
						$oov_x_counts{"<$class>"} += $c;
					}
				}
				
			}
			
			#ALL
			$total_words++;
			$total += $c;
			
			#is acronym
		}
	}
	
	if ($total != 0) {
		$oov_rate = $oov_counts/$total;
	}
	
	for (my $i = 0; $i < @{$p_tab}+0; $i++) {
		my $w = ${$p_tab}[$i];
		if ($counts{$w} > 0) {
			my $c = $counts{$w};
			if ($i < $vocab_size) {
				$V_entropy += ($c / $total) * log2($c/$total);
			}
			$total_entropy += ($c / $total) * log2($c/$total);
		}
	}
	
	my $output = "";
	my $c = 0;
	my $d = 0;
	$output .=         "                          | #occurrences     rate   | #tokens     rate   |\n";
	$output .= "--------------------------+-------------------------+--------------------|\n";
	$output .= sprintf(" Total                    | %12s  100.000 %% | %7s  100.000 %% |\n", $total, $total_words);
	$output .= sprintf(" IV words                 | %12s   %6.3f %% | %7s   %6.3f %% |\n", $iv_counts, 100*$iv_counts/$total, $iv_words, 100*$iv_words/$total_words);
	$output .= sprintf(" OOV words                | %12s   %6.3f %% | %7s   %6.3f %% |\n", $oov_counts, 100*$oov_counts/$total, $oov_words, 100*$oov_words/$total_words);
	$output .= "--------------------------+-------------------------+--------------------|\n";
	
	
	# classes
	foreach my $k (sort {$a cmp $b} union(keys %oov_x_counts, keys %iv_x_counts)) {
	$c = $oov_x_counts{$k} + $iv_x_counts{$k};
	$d = $oov_x_words{$k} + $iv_x_words{$k};
	$output .= sprintf(" %-17s | All  | %12s   %6.3f %% | %7s   %6.3f %% |\n", $k, $c, 100*$c/$total, $d, 100*$d/$total_words);

	$c = $iv_x_counts{$k}+0;
	$d = $iv_x_words{$k}+0;
	$output .= sprintf("                   | %-4s | %12s   %6.3f %% | %7s   %6.3f %% |\n", "IVs", $c, 100*$c/$total, $d, 100*$d/$total_words);

	$c = $oov_x_counts{$k}+0;
	$d = $oov_x_words{$k}+0;	
	$output .= sprintf("                   | %-4s | %12s   %6.3f %% | %7s   %6.3f %% |\n", "OOVs", $c, 100*$c/$total, $d, 100*$d/$total_words);
	
	$output .= "--------------------------+-------------------------+--------------------|\n";
	}

	#	confusability
  	$c = compute_confusability(@{$p_tab}[0..($vocab_size-1)]);
  	$output .= sprintf(" Avg. word confusability  |   %6.3f decomposition variants per IV word  |\n", $c);
  	$output .= sprintf("   (graphemic level)      |                                              |\n", $c);
  	$output .= "--------------------------+----------------------------------------------|\n";
	
	#	entropies
	$output .= sprintf(" %-24s | %8.3f                                     |\n", "Unigram (IV) perplexity", 2**(-1.0 * $V_entropy));
	$output .= sprintf(" %-24s | %8.3f bits                                |\n", "Entropy of IV words", -1.0 * $V_entropy);
	$output .= sprintf(" %-24s | %8.3f bits                                |\n", "Entropy of all the words", -1.0 * $total_entropy);
	$output .= sprintf(" %-24s | %8.3f %%                                   |\n", "IV/All entropy ratio", 100*($V_entropy / $total_entropy));
	$output .= "--------------------------+----------------------------------------------+\n";
		
	
	return $output;
	
}



1;

