#!/usr/bin/perl


$tag_precedent="";
$ponctuation="\:\!\?\.\;\,\"\«\»\(\)";
$paold="";
$ppold="";

while(<STDIN>)
{
   
  if(s/\#\s+(\S+)//){$confiance=$1;}
  s/(\S+)\/[0-9\.]+\s*$/$1/;
  if(/(\S+).*\s+(\S+)/)
  {
	$mot=$1;
	$tag=$2;
	$mot=~s/([$ponctuation]*)([^$ponctuation]+)([$ponctuation]*)/$2/;
	$paold=$pa;
	$ppold=$pp;
	$pa=$1;
	$pp=$3;
	
	if($tag=~s/(\S+)[\_\-][Bb]/$1/)
	{
	  if($tag_precedent eq "")
	  {
	    $result.="$pa<$1>$mot ";
	  }
	  else
	  {
	    $result.="</$tag_precedent>$ppold $pa<$1>$mot ";
	  }  
	}
	elsif($tag=~s/(\S+)[\_\-][iI]/$1/) 
	{
	  if($tag eq $tag_precedent) #normalement oui, sinon un I en debut de concept, mais c possible
	  {
	    $result.=" $pa$mot ";
	  }
	  elsif($tag_precedent eq "") #ici un I en debut de concept sur le premier mot
	  {
	    $result.="$pa<$1>$mot ";
	  }
	  else#ici un I en début de concept
	  {
		$result.="</$tag_precedent>$ppold $pa<$1>$mot ";
	  }
	}
	elsif($tag ne $tag_precedent) #ici le cas ou ya pas de modelisation en chunk et on change concept
	{
	  if($tag_precedent eq "")
	  {
	    $result.="$pa<$tag>$mot ";
	  }
	  else
	  {
	    $result.="</$tag_precedent>$ppold $pa<$tag>$mot ";
	  }
	}
	else
	{
		$result.=" $mot ";
	}
	$tag_precedent=$tag;
  }
  else
  {
	if($result ne "")
	{$result.="</$tag_precedent>$pp";
	$result=~s/<\/?null>//g;
	$result=~s/\s+/ /g;
	$result=~s/^\s+//;
	$result=~s/\s+$//;
	$result=~s/\s+(<\/)/$1/g;
	$result=~s/\s+([$ponctuation])/$1/g;
	if(!defined($ARGV[0])){print STDOUT "$result\n";}
	else{print STDOUT "$result $confiance\n";}
	}
	$result="";
	$tag_precedent="";
  }
}


