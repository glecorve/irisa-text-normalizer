#!/usr/bin/perl
#
# Accentueur.pm -- Gw�nol� Lecorv�
#
#
########################################################

package Accents;

use Exporter;
use strict;


my $IN_LEX = 1;
my $RESOLVED = 2;
my $AMBIG = 3;
my $NOT_RESOLVED = 4;


sub new {
	my $class = shift;
	my $this = {};

	bless $this;

# 	my %deja_calcules;
	my $lex_path = shift;
	my $lex_path_2 = shift;
	my $lex_path_3 = shift;



	open(LEX, "< $lex_path") or die("Unable to open $lex_path.\n");
	while(<LEX>) {
		chomp;
		$this->{deja_calcules}{$_} = $_;
		$this->{deja_calcules_statut}{$_} = $IN_LEX;
		$this->{lexique}{$_} = 1;
	}
	close(LEX);

	open(LEX, "< $lex_path_2") or die("Unable to open $lex_path_2.\n");
	while(<LEX>) {
		chomp;
		$this->{lexique2}{$_} = 1;
	}
	close(LEX);
	open(LEX, "< $lex_path_3") or die("Unable to open $lex_path_3.\n");
	while(<LEX>) {
		chomp;
		$this->{lexique3}{$_} = 1;
	}
	close(LEX);
	return $this;
}



my %equivalence = (
"a" => ["a","�","�","�"],
"�" => ["a","�","�","�"],
"�" => ["a","�","�","�"],
"�" => ["a","�","�","�"],
"b" => ["b"],
"c" => ["c","�"],
"�" => ["c","�"],
"d" => ["d"],
"e" => ["e","�","�","�","�"],
"�" => ["e","�","�","�","�"],
"�" => ["e","�","�","�","�"],
"�" => ["e","�","�","�","�"],
"�" => ["e","�","�","�","�"],
# "�" => ["�","e","�","�","�","�"],
# "e" => ["�","e","�","�","�","�"],
# "�" => ["�","e","�","�","�","�"],
# "�" => ["�","e","�","�","�","�"],
# "�" => ["�","e","�","�","�","�"],
# "�" => ["�","e","�","�","�","�"],
"f" => ["f"],
"g" => ["g"],
"h" => ["h"],
"i" => ["i","�","�"],
"�" => ["i","�","�"],
"�" => ["i","�","�"],
"j" => ["j"],
"k" => ["k"],
"l" => ["l"],
"m" => ["m"],
"n" => ["n"],
"o" => ["o","�","�"],
"�" => ["o","�","�"],
"�" => ["o","�","�"],
"p" => ["p"],
"q" => ["q"],
"r" => ["r"],
"s" => ["s"],
"t" => ["t"],
"u" => ["u","�","�","�"],
"�" => ["u","�","�","�"],
"�" => ["u","�","�","�"],
"�" => ["u","�","�","�"],
"v" => ["v"],
"w" => ["w"],
"x" => ["x"],
"y" => ["y","�"],
"�" => ["y","�"],
"z" => ["z"]
);




my @class_eq = (
"a���",
"b",
"c�",
"d",
"e����",
"f",
"g",
"h",
"i��",
"j",
"k",
"l",
"m",
"n",
"o��",
"p",
"q",
"r",
"s",
"t",
"u���",
"v",
"w",
"x",
"y�",
"z"
);

sub ecrire_hash {
	my $this = shift;
	for (my $i =0; $i < @class_eq; $i++) {
		my @paquet = split(//, $class_eq[$i]);
		foreach my $p (@paquet) {
			print "\"$p\" => [\"".(join("\",\"",@paquet))."\"],\n";
		}
	}
}




sub une_variante {
	my $this = shift;
	my $voyelle = shift;
	return $equivalence{$voyelle};
}

sub prefixer {
	my $this = shift;
	my $str = shift;
	my $p_tab = shift;
	my @ret = ();
	my $len = 0;
# 	print "--- pr�fixer $str\n";
# 	print STDERR "\n";
	if (!defined($p_tab) || @$p_tab == 0) { push(@ret, $str); }
	else {
		$len = length($$p_tab[0]);
		my $prem = "";
		my $deux = "";
		for (my $i = 0; $i < @$p_tab; $i++) {
# 			print $$p_tab[$i]."<---\n";
			if ($len == 1) {
				$$p_tab[$i] =~ /^(.)/;
				$prem = $1;
# 				print $str.$1."\n";
				if ($this->{lexique2}{$str.$prem} == 1) {
# 					print "\toui\n";
					push(@ret,$str.$$p_tab[$i]);
				}
				else {
# 					print "\tnon\n";
				}
			}
			else {
				$$p_tab[$i] =~ /^(..)/;
				$prem = $1;
# 				print $str.$1."\n";
				if ($this->{lexique3}{$str.$prem} == 1) {
# 					print "/".$str.$prem."/\toui\n";
					push(@ret,$str.$$p_tab[$i]);
				}
				else {
# 					print "/".$str.$prem."/\tnon\n";
				}
			}
		}
	}
	return \@ret;
}

sub build_variantes {
	my $this = shift;
	my $w = shift;
	my $prec = shift;
	my $p_res = ();
	my $p_v_var;
	if ($w ne "") {
		$w =~ /^(.)(.*)$/;
		my ($tete, $queue) = ($1,$2);
		my @v_var;
		my $i = 0;
		my $p_tmp_var;
		my $p_queues = $this->build_variantes($queue);
		if ($tete =~ /^[aeiouyc���������������������������]$/) {
			$p_v_var = $equivalence{$tete};
			if (defined($p_v_var)) {
				@v_var = @{$p_v_var};
	# 			print join(", ", @v_var)."\n";
				for (my $i = 0; $i < @{$equivalence{$tete}}; $i++) {
					$p_tmp_var = $this->prefixer($v_var[$i], $p_queues);
					foreach my $v (@{$p_tmp_var}) {
						push(@$p_res, $v);
					}
				}
			}
		}
		else {
			$p_res = $this->prefixer($tete, $p_queues);
		}
	}
	return $p_res;
}


sub accentue {
	my $this = shift;
	my $w = shift;
	my @variantes = ();
	if ($w =~ /^[a-z���������������������������]+$/ && $this->{lexique}{$w} != 1) {
		@variantes = @{$this->build_variantes($w)}
	}
	return \@variantes;
}

sub nb_diff_char {
	my $w1 = shift;
	my $w2 = shift;
	my $nb_diff = 0;
	my ($w,$b);
	while (($a = chop($w1)) && ($b = chop($w2))) {
		if ($a ne $b) { $nb_diff++; }
	}
	return $nb_diff;
}

sub accentuer_si_necessaire {
	my $this = shift;
	my $w = shift;
	my $retour = $w;
	my $trouve = 0;
	my $len = length($w);
	my $p_variantes;
	$|++;
# 	print "-- $w --\n";
	my $closest_variant = 0;
	if (!defined($this->{deja_calcule}{$w})) {
		#seulement si le mot est en minuscules
		# (le cas des mots avec une majuscule est trop compliqu�)
		#et le mot n'est pas dans le lexique
		if ($w =~ /^[a-z���������������������������\-_]+$/ && $this->{lexique}{$w} != 1) {
	# 		print "$w -- ";
			$p_variantes = $this->build_variantes($w);
			if (defined($p_variantes)) {
				my @variantes = @{$p_variantes};
# 			print join(" ", @variantes)."\n";
				my $mot_maj;
				my $mot_tt_maj;
				for (my $i = 0; $i < @variantes; $i++) {
# 					print "$w -> $variantes[$i]\n";
					if (length($variantes[$i]) == $len) {
						if ($this->{lexique}{$variantes[$i]} == 1) {
							my $dist = nb_diff_char($variantes[$i], $w);
#							print $variantes[$i]." $dist\n";
							if ( $trouve == 0 ) {
								$retour = $variantes[$i];
								$closest_variant = $dist;
								$trouve++;
								$this->{deja_calcules_statut}{$w} = $RESOLVED;
							}
							# des qu'il y a plusieurs solutions envisageables
							# on retourne la variante avec le moins de modif
							# si toujours �galit�
							# on retourne le mot d'origine
							elsif ($dist < $closest_variant) {
								$retour = $variantes[$i];
								$closest_variant = $dist;
								$this->{deja_calcules_statut}{$w} = $RESOLVED;
							}
							elsif ($dist == $closest_variant) {
								$retour = $w;
								$this->{deja_calcules_statut}{$w} = $AMBIG;
							}
						}
					}
				}
				if ( $trouve == 0 ) {
					$this->{deja_calcules_statut}{$w} = $NOT_RESOLVED;
				}
			}
		}
		else {
			$this->{deja_calcules_statut}{$w} = $IN_LEX;
		}
		$this->{deja_calcules}{$w} = $retour;
	}

	return ($this->{deja_calcules}{$w}, $this->{deja_calcules_statut}{$w});

}

1;
