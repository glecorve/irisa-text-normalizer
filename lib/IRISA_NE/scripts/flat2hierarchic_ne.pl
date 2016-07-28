#!/usr/bin/perl

$RULES=$ARGV[0];

if(!defined($RULES)){die("use: <rules>\n");}

open(RULES,$RULES) || die("no $RULES\n");
while(<RULES>)
{
	if(/^\#/){;}
	else{
	
	if(s/(\S+)\s+\#\s+\[(.*?)\]\s+\S+\s+\[(.*?)\]\s*$//)
	{
		$pattern="(\\s+$1\\s*)<$1>([^<]+)<\\/$1>(\\s*$2)";
		$patron2{$pattern}=$1;
		#print STDERR "($pattern) ($1)\n";
	}
	elsif(s/(\S+)\s+\#\s+\[(.*?)\]\s+\S+\s*$//)
	{
		$pattern="(\\s+$2\\s*)<$1>([^<]+)<\\/$1>";
		$patron2{$pattern}=$1;
		#print STDERR "($pattern) ($1)\n";
	}
	elsif(s/(\S+)\s+\#\s+\S+\s+\[(.*?)\]\s*$//)
	{
		$pattern="<$1>([^<]+)<\\/$1>(\\s*$2\\s+)";
		$patron2{$pattern}=$1;
		#print STDERR "($pattern) ($1)\n";
	}
	else
	{
	
	s/(\S+)\s+\#\s+//;
	$sup=$1;
	
	$pattern="";
	
	
	
	while(/\S/)
	{
		if(s/^\s*\[(.*?)\]//)
		{
			$mots=$1;
			$pattern.="\\s+$mots";
		}
		elsif(s/^\s*\$(\S+)//)
		{
			$inf=$1;
			$pattern.="\\s*<$inf>[^<]+<\/$inf>";
		}
	}
	
	
	$patron{$pattern}=$sup;
	}
	}
	#print STDERR "($pattern) ($sup)\n";
}
close(RULES);

while(<STDIN>)
{
	foreach $p (keys %patron2)
	{
		if(s/$p/ <$patron{$p}> $1$2$3 <\/$patron{$p}>/g){#print STDERR "$p -> <$patron{$p}> $1$2$3 <\/$patron{$p}>\n";
		}
	}
	foreach $p (keys %patron)
	{
		if(s/$p/ <$patron{$p}> $& <\/$patron{$p}>/g){#print STDERR "FOOT:$p -> <$patron{$p}> $& <\/$patron{$p}>\n";
		}
	}
	while(s/<org>([^<]+)<\/org>\s*(<loc>[^<]+<\/loc>)\s+<org>(\s*de[^<]+)<\/org>/ <org> $1 $2 $3 <\/org>/){#print STDERR "$& ->   <org> $1 $2 $3 <\/org>\n";
	} #org loc org -> coupe d'afrique de footbal
	while(s/<org>([^<]+\s+[dl][\'eau]s?\s*)<\/org>\s+(<loc>[^<]+<\/loc>)/ <org> $1 $2 <\/org>/){#print STDERR "$& ->  <org> $1 $2 </org>\n";
	} # afaire avant le suivant -> tour de france
	while(s/<org>(\s*(athletico|fc|rc|usm|us|aj)\s*)<\/org>\s+(<loc>[^<]+<\/loc>)/ <org> $1 $2 <\/org>/){#print STDERR "$& ->  <org> $1 $3 </org>\n";
	} #us katenga (ici pas besoin de de la le les, mais pas plus d'un mot dans le premier org
	
	while(s/(<loc>[^<]+<\/loc>)\s+<org>(\s*united\s*)<\/org>/ <org> $1 $2 <\/org>/){#print STDERR "$& ->  <org> $1 $2 </org>\n";
	} #paris united -> loc org -> org loc /org
	while(s/(<loc>[^<]+\s+[dl][\'eau]s?\s*)<\/loc>\s+(<org>[^<]+<\/org>)/ $1 $2 <\/loc>/){#print STDERR "$& ->  <org> $1 $2 </org>\n";
	} #quartier general de l'otan -> loc org > loc org /loc
	#
	print STDOUT $_;
}