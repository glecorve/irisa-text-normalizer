#!/usr/bin/perl

%ent2color=("loc","red",
"amount","purple",
"fonc","green",
"org","orange",
"pers","blue",
"prod","green",
"time","springgreen"
);

$entete=`cat $ENV{IRISA_NE}/data/entete.html`;

print STDOUT $entete;
while(<STDIN>)
{
   s/<([a-z\.]+)>([^<]+)<\/\1>/&color($1,$2)/ge;
   print STDOUT "$_\n";#<HR>
}

print STDOUT "\n</body>\n</html>\n";

sub color()
{
   my $ent=$_[0];
   my $mots=$_[1];
   my $entbas=$ent;
   $entbas=~s/\..*//;
   return "<span style=\"color: $ent2color{$entbas};\"  onmouseover=\"this.style.fontSize=\'150%\';montre(\'$ent\');\" onmouseout=\"this.style.fontSize=\'100%\';cache();\">$mots</span>";
}
