#!/usr/bin/perl
##############################################################
# Christian Raymond
# 4 octobre 2010
# transforme texte en transcription
# verifie l'appartenance des mots au vocabulaire du systeme ne
##############################################################
$LEX=$ARGV[0];

if(!defined($LEX)){die("use: <lexique.syms>\n");}

open(LEX,$LEX) || die("Can't open lex $LEX\n");
while(<LEX>)
{	
	/\S+/;
	$lexique{$&}++;
}
close(LEX);

open(LOG,">irisa_ne.log");

sub chiffre2lettre()
{
	my $avant=$_[0];
	my $chiffre=$_[1];
	my $apres=$_[2];
	my $res="";
	if($chiffre=~s/[\:\!\?\.\;\,\"]$//) {$apres="$&$apres";} #des fois que le chiffre soit suivi d'un signe de ponctuation
	
	$chiffre=~s/\.//g; 
	#print LOG "chiffre:$chiffre\n";
	if($chiffre=~s/([0-9]+),([0-9]+)//)
	{
		$res=$avant.`chiffres2lettres.pl $1`." virgule " .`chiffres2lettres.pl $2`.$apres;
		#$res=~s/\-/ /g;
		return $res;
	}
	#if($chiffre=~/^[0-9]+$/)
	$res=$avant.`chiffres2lettres.pl $chiffre`.$apres;
	#$res=~s/\-/ /g;
	return $res;
	
}

sub chiffres2lettres()
{
	my $chiffres=$_[0];
	$chiffres=~s/([^\S])([0-9][0-9\:\!\?\.\;\,\"]+)([^\S])/&chiffre2lettre($1,$2,$3)/ge;
	return $chiffres;
}

$ponctuation="\:\!\?\.\;\,\"\«\»\(\)";

while(<STDIN>)
{
	if(/^\s*$/){next;} #élimine lignes vides
	$result="";
	s/^\s+//;
	s/\s+$//;
	s/\s+[\-]\s+/ /g;
	s/([0-9])\s+(0+\s+)/$1$2/g; #200 000
	s/(^|[\s\"])([ldctmnjs]|qu|jusqu|puisqu)[’']([^\s])/$1$2' $3/gi; #décolle les mots avec apostrophe
	s/([^\s])(-t-il|-t-elle)/$1 $2/g; 
	s/([^\s\-][^\s\-]+)\-([^\s\-][^\s\-]+)/$1 $2/g;#enlève les tirets sauf celui d'avant
	$_=&chiffres2lettres($_);
	
	s/\(\.*\)//g;#(...)
	s/(\«)\s+([^$ponctuation])/$1$2/g;#ponctuation ouvrante on colle à mot d'après
	s/\s+([$ponctuation]+)\s+/$1 /g; #astuce pour garder la ponctuation en sortie, je colle au mot précédent, je l'enleve pour le tagger, mais et je décolle en sortie
	 
	$input=$_;
	$input=~s/[$ponctuation]//g;
	while($input=~s/\S+//)
	{
		$mot=lc($&); #mise en minuscule
		$mot=~s/À/à/g;
		if(!exists($lexique{$mot})){$mot2="OOV";print LOG "Warning the word is not know par the Named Entity tagger:$mot\n";}
		else{$mot2=$mot;}
		$result.="$mot2 ";
	}
	#print LOG "normal:$_\n";
	s/\s+/\n/g; #met la sortie un mot par ligne
	#print LOG "cleaned:$result\n";
	
	print STDOUT $result."\n";
	print STDERR $_."\n";
	
}
close(LOG);