package TextInputSAXHandler;

use strict;

use utf8;

use Cwd 'abs_path';
use File::Basename;
use lib dirname( abs_path(__FILE__) )."/../lib";

use XML::LibXML;
use XML::LibXML::SAX;

use Data::Dumper;

use base qw(XML::SAX::Base);

use roots;

my $DEBUG = 0;
my $currentString = "";
my $currentAttributes; 
my $currentWord = 0;
my $currentWordRaw = 0;
my $currentVoidIndex = 0;
my $currentNssIndex = 0;
my $currentDurationIndex = 0;
my $currentPhIndex = 0;

# TODO elements to take into account : voice, emphasis, prosody
my @utterances = ();

my $utterance;
my $sequenceWordRaw;
my $seqGraphemeRaw;
my $sequenceWordText;
my $seqGrapheme;
my $seqVoid;
my $seqFiller;
my $seqDuration;
my $seqPhoneme;
my $seqTag;

# TODO accessors
my $roots_wordSep               = " ";
my $rootsLabel_wordRawSeq       = 'Word Original';
my $rootsLabel_graphemeRawSeq   = 'Grapheme Original';
my $rootsLabel_wordSeq          = 'Word Text';
my $rootsLabel_graphemeSeq      = 'Grapheme Text';
my $rootsLabel_orderSeq         = 'Ordering';    
my $rootsLabel_fillerSeq        = 'NSS';    
my $rootsLabel_durationSeq      = 'Duration';
my $rootsLabel_phonemeSeq       = 'Phoneme';  
my $rootsLabel_tag              = 'Tag Text';  
my $language                    = "fr";
my $tagToAdd = "";

my $outputAlphabet = roots::phonology_ipa_LiaphonAlphabet::get_instance();
my $outputNsAlphabet = roots::phonology_nsa_LiaphonNsAlphabet::get_instance();

# TODO emphasis + prosody
    
# TODO Add Nss sequence + Number Sequence (for all segments with defined duration)
# + Phoneme Sequence + Void Sequence
# TODO Add relations : Void->NSS, Void->Word, Word->Phoneme

# Hash tables to keep related elements
my %voidWordHash = ();
my %voidNssHash = ();
my %voidDurationHash = ();
my %voidPhHash = ();
my %tagGraphemeHash = ();
my %wordRawWordHash = ();

# Hash table of lists to keep the last index of word when a tag begins
# Essential to treat properly the recursivity of xml tags (imbrication)
# used for p, s, voice, emphasis, prosody
my %indexHash = ();
#    "p" => [],
#    "s" => [],
#    "voice" => (),
#    "emphasis" => (),
#    "prosody" => (),
#    );
#$indexHash{"p"} = {};
#$indexHash{"s"} = ;

my $RSRC = undef;
my $WIKTIONARY_WORD_POS = undef;
my $LEXIQUE_FILE = undef;


sub start_document {
    my ($self, $doc) = @_;
    
}

sub start_element {
    my ($self, $el) = @_;
    my $elementName = $el->{LocalName};
    
    $currentString =~ s/^\s*//g;
    $currentString =~ s/\s*$//g;
    print STDERR "VOICEXML ".$currentString."\n" if($DEBUG and $currentString ne "");    
        
    $currentAttributes = $el->{Attributes};
        
    # Adds the previous words to the utterance
    add_words_to_utterance($currentString);
    
    print STDERR "VOICEXML BEGIN ".$elementName."\n" if($DEBUG);
    
    # Keep position of the start element    
    
    if($elementName eq "speak"){
        # Initialize the first utterance
        initialize_utterance();
        
    }elsif($elementName eq "p" or $elementName eq "s"){
        #if($elementName eq "p")
        #{
        #    $indexHash{"p"} = () if(!exists $indexHash{"p"});
        #    push(@{$indexHash{"p"}}, $currentVoidIndex);
        #}
        #
        #if($elementName eq "s")
        #{
        #    $indexHash{"s"} = () if(!exists $indexHash{"s"});
        #    push(@{$indexHash{"s"}}, $currentVoidIndex);
        #}
        
        # Begin a new utterance (if we have already treated some words)        
        if($currentWord != 0)        
        {
            # Finish utterance construction
            finish_utterance();
            
            # Add utterance
            push(@utterances, $utterance);
                        
            initialize_utterance();
        }

    }elsif(($elementName eq "sub")){
        # Replace the words by the given words
        # Nothing to do in start element
    }elsif($elementName eq "say-as"){
        # Ignore for the moment 
        # Nothing to do in start element
    }elsif($elementName eq "phoneme"){
        # Add a Phoneme sequence related to the word or group of words
    
    }elsif($elementName eq "break"){
        # Add a NSS after current word (take into account duration?)
        # Nothing to do in start element
    }elsif($elementName eq "voice"){
        #push(@{$indexHash{"voice"}}, $currentVoidIndex);
    }elsif($elementName eq "emphasis"){
        #push(@{$indexHash{"voice"}}, $currentVoidIndex);
    }elsif($elementName eq "prosody"){
        #push(@{$indexHash{"voice"}}, $currentVoidIndex);
    }else{
        warn "element $elementName not supported!";
    }
        
    # LET'S BEGIN A NEW STRING
    $currentString = "";
}

sub end_element {
    my ($self, $el) = @_;
    
    # TODO reset position of the element that ends here
    $currentString =~ s/^\s*//g;
    $currentString =~ s/\s*$//g;
    print STDERR "VOICEXML".$currentString."\n" if($DEBUG and $currentString ne "");
    
    my $elementName = $el->{LocalName};

    print STDERR "VOICEXML END ".$elementName."\n" if($DEBUG);
    
    if($elementName eq "speak"){
        
        if($currentString ne "")
        {
            add_words_to_utterance($currentString);
        }        
        
        if($currentWord != 0)
        {
            # Finish utterance construction
            finish_utterance();
            
            # Add utterance
            push(@utterances, $utterance);
            
            $currentWord = 0;   
        }
        
    }if($elementName eq "p" or $elementName eq "s"){
        #pop(@{$indexHash{"p"}}) if($elementName eq "p");
        #pop(@{$indexHash{"s"}}) if($elementName eq "s");

        if($currentString ne "")
        {
            add_words_to_utterance($currentString);
        } 
        
        if($currentWord != 0)
        {
            # Finish utterance construction
            finish_utterance();
            
            # Add utterance
            push(@utterances, $utterance);
            
            initialize_utterance();
        }
        
    }elsif($elementName eq "sub"){
        # Replace the words by the given words
        my $alias = $currentAttributes->{'{}alias'}->{'Value'};
        
        print STDERR "VOICEXML sub text=\"$alias\" for text=\"$currentString\"\n" if($DEBUG);
        
        if($alias eq "")
        {
            die "the alias attribute is mandatory in a sub element!";            
        }
        
        if($currentString eq "")
        {
            die "a sub element has to contain text to replace!";            
        }
        
        # Replace the words
        add_words_to_utterance($alias);
        
    }elsif($elementName eq "say-as"){
        # Ignore for the moment 
        
        my $interpretAs = $currentAttributes->{'{}interpret-as'}->{'Value'};
        my $format = $currentAttributes->{'{}format'}->{'Value'};
        my $detail = $currentAttributes->{'{}detail'}->{'Value'};
        
        print STDERR "VOICEXML say-as with interpret-as=$interpretAs format=$format detail=$detail\n" if($DEBUG);
        
        add_words_to_utterance($currentString);
        
    }elsif($elementName eq "phoneme"){
        # Add a Phoneme sequence related to the word or group of words
        my $alphabet = $currentAttributes->{'{}alphabet'}->{'Value'};
        my $ph = $currentAttributes->{'{}ph'}->{'Value'};    
        
        print STDERR "VOICEXML phoneme with alphabet=$alphabet ph=\"$ph\"\n" if($DEBUG);
        
        die "alphabet value unknown!" if(($alphabet ne "") and ($alphabet !~ /x-/));
        
        $alphabet =~ s/^x-//g;
        
        die "the ph attribute is mandatory in a phoneme element!" if($ph eq "");            
               
				if($alphabet eq "")
				{
						$alphabet = $outputAlphabet;
				}
				else
				{
						$alphabet = roots::phonology_ipa_Alphabet::get_alphabet($alphabet);
				}
				
				print STDERR "VOICEXML Alphabet=".$alphabet->get_name()."\n" if($DEBUG);
				
        # text may be empty !
        my $beginIndex = $currentVoidIndex;
        if($currentString ne "")
        {
            add_words_to_utterance($currentString);
        }
        my $endIndex = $currentVoidIndex;
        
        if($beginIndex == $endIndex)
        {
            my $rootsVoid = new roots::Void();
            $seqVoid->add($rootsVoid);
            $rootsVoid->destroy();
        
            ++$currentVoidIndex;
            $endIndex = $currentVoidIndex;
        }
        
        # Add phonemes to the phoneme sequence / Relates it to a group of void
        my @phonemes = split(/ /, $ph);
        for(my $pidx=0 ; $pidx<@phonemes; ++$pidx)
        {
	    my $pho = $phonemes[$pidx];
	    my @ipas = @{$alphabet->extract_ipas($pho)};
	    my $tmpPhoneme = new roots::phonology_Phoneme(\@ipas, $alphabet);
	    map { $_->destroy() } @ipas;
	    @ipas = @{$outputAlphabet->extract_ipas($outputAlphabet->approximate_phoneme($tmpPhoneme))};
	    my $phItem = new roots::phonology_Phoneme(\@ipas, $outputAlphabet);	
	    map { $_->destroy() } @ipas;

            print STDERR "VOICEXML PHONEME: ".$phItem->to_string(0)."\n" if($DEBUG);
            
            $seqPhoneme->add($phItem);
            $phItem->destroy();

            for(my $lidx=$beginIndex; $lidx<$endIndex; ++$lidx)
            {
                add_entry($lidx, $currentPhIndex, \%voidPhHash);
            }

            ++$currentPhIndex;
        }
                
    }elsif($elementName eq "break"){
        # Add a NSS after current word (take into account duration?)
        # !! Ignore strength !!
        my $time = $currentAttributes->{'{}time'}->{'Value'};    
        my $strength = $currentAttributes->{'{}strength'}->{'Value'};    
        
        print STDERR "VOICEXML break with time=$time strength=$strength\n" if($DEBUG);                        
        # Add a Void element
        my $rootsVoid = new roots::Void();
        $seqVoid->add($rootsVoid);
        $rootsVoid->destroy();
        
        # Add a NSS
        my $nsaLabel = $outputNsAlphabet->get_label_from_symbol("silence");
				print STDERR "VOICEXML FILLER=$nsaLabel\n" if($DEBUG);

        my $rootsNss = new roots::linguistic_filler_Nsa(new roots::phonology_nsa_NsaCommon($outputNsAlphabet, $nsaLabel));        
        $seqFiller->add($rootsNss);
        $rootsNss->destroy();
        
        add_entry($currentVoidIndex, $currentNssIndex, \%voidNssHash);
        
        # Add a Duration
        $time = "0s" if($time eq "");
        if($time =~ /[1-9][0-9]*ms$/ )
        {
            $time =~ s/ms//g;
            $time /= 1000.0;
        }elsif($time =~ /[0-9][0-9]*s$/ )
        {
            $time =~ s/s//g;
        }else{
            die "wrong format for break time (only sec or msec, i.e. 1s or 100ms)!";
        }
        my $durationItem = new roots::Number($time);
        $seqDuration->add($durationItem);
        $durationItem->destroy();
        
        add_entry($currentVoidIndex, $currentDurationIndex, \%voidDurationHash);
        
        $currentNssIndex += 1;
        $currentDurationIndex += 1;
        $currentVoidIndex += 1;
    }  
    
    $currentString = "";
}

sub characters {
    my ($self, $el) = @_;
    $currentString .= $el->{Data};
}



sub initialize_utterance()
{
    $currentWord = 0;   
    $currentVoidIndex = 0;
    $currentNssIndex = 0;
    $currentDurationIndex = 0;
    $currentPhIndex = 0;
    
    $utterance = new roots::Utterance();
    $sequenceWordRaw = new roots::WordSequence();
    $seqGraphemeRaw = new roots::GraphemeSequence();    
    $sequenceWordText = new roots::WordSequence();
    $seqGrapheme = new roots::GraphemeSequence();
    $seqVoid = new roots::VoidSequence();
    $seqFiller = new roots::FillerSequence();
    $seqDuration = new roots::NumberSequence();
    $seqPhoneme = new roots::PhonemeSequence();
    $seqTag = new roots::SymbolSequence();

    my $rootsTag = new roots::Symbol($tagToAdd);
    $seqTag->add($rootsTag);
    $rootsTag->destroy();
}

sub finish_utterance()
{
    $utterance->add_sequence($sequenceWordRaw, $rootsLabel_wordRawSeq);
    $utterance->add_sequence($seqGraphemeRaw, $rootsLabel_graphemeRawSeq);    
    $utterance->add_sequence($sequenceWordText, $rootsLabel_wordSeq);
    $utterance->add_sequence($seqGrapheme, $rootsLabel_graphemeSeq);
    $utterance->add_sequence($seqVoid, $rootsLabel_orderSeq);
    $utterance->add_sequence($seqFiller, $rootsLabel_fillerSeq);
    $utterance->add_sequence($seqDuration, $rootsLabel_durationSeq);
    $utterance->add_sequence($seqPhoneme, $rootsLabel_phonemeSeq);
    $utterance->add_sequence($seqTag, $rootsLabel_tag);
    
    # Add relation
    my $relationWordChar = new roots::Relation(
            $utterance->get_sequence($rootsLabel_graphemeSeq),
            $utterance->get_sequence($rootsLabel_wordSeq),
            $seqGrapheme->make_mapping($sequenceWordText)
        );
		
    $utterance->add_relation($relationWordChar);

    my $relationWordCharRaw = new roots::Relation(
            $utterance->get_sequence($rootsLabel_graphemeRawSeq),
            $utterance->get_sequence($rootsLabel_wordRawSeq),
            $seqGraphemeRaw->make_mapping($sequenceWordRaw)
        );
		
    $utterance->add_relation($relationWordCharRaw);

    my $relationWordRawWord = $sequenceWordRaw->align_m_to_n($sequenceWordText);
    $utterance->add_relation($relationWordRawWord);
    
    
    my $voidWordRel = new roots::Relation(
            $utterance->get_sequence($rootsLabel_orderSeq),
            $utterance->get_sequence($rootsLabel_wordSeq)
            );
    add_links($voidWordRel, \%voidWordHash); 
    $utterance->add_relation($voidWordRel);
 
    my $voidNssRel = new roots::Relation(
            $utterance->get_sequence($rootsLabel_orderSeq),
            $utterance->get_sequence($rootsLabel_fillerSeq)
            );
    add_links($voidNssRel, \%voidNssHash); 
    $utterance->add_relation($voidNssRel);

    my $voidDurationRel = new roots::Relation(
	$utterance->get_sequence($rootsLabel_orderSeq),
	$utterance->get_sequence($rootsLabel_durationSeq)
	);
    add_links($voidDurationRel, \%voidDurationHash); 
    $utterance->add_relation($voidDurationRel);
 
    my $voidPhRel = new roots::Relation(
            $utterance->get_sequence($rootsLabel_orderSeq),
            $utterance->get_sequence($rootsLabel_phonemeSeq)
            );
    add_links($voidPhRel, \%voidPhHash); 
    $utterance->add_relation($voidPhRel);

    my $tagGraphemeRel = new roots::Relation(
            $utterance->get_sequence($rootsLabel_tag),
            $utterance->get_sequence($rootsLabel_graphemeSeq)
            );
    add_links($tagGraphemeRel, \%tagGraphemeHash); 
    $utterance->add_relation($tagGraphemeRel);
    
    %voidWordHash = ();
    %voidNssHash = ();
    %voidDurationHash = ();
    %voidPhHash = ();
    %tagGraphemeHash = ();
}

sub add_words_to_utterance()
{
    my $currentString = shift;        

    return if($currentString eq "");

    # Adding raw text and graphemes
    my @words = split(/\s/, $currentString);
    foreach my $word (@words)
    {        
        if($currentWord != 0)
        {
            my $emptyChar = new roots::linguistic_Grapheme($roots_wordSep);
            $seqGrapheme->add($emptyChar);
            $emptyChar->destroy();

            add_entry(0, $seqGrapheme->count()-1, \%tagGraphemeHash);
        }
        
        my $rootsWord = new roots::linguistic_Word($word);
        $sequenceWordRaw->add($rootsWord);
        $rootsWord->destroy();
        
        foreach my $char (split (//, $word))  # . is never a newline here
        {
            my $rootsChar = new roots::linguistic_Grapheme($char); 
            $seqGraphemeRaw->add($rootsChar);
            $rootsChar->destroy();

            add_entry(0, $seqGrapheme->count()-1, \%tagGraphemeHash);
        }
    }

    if(1){
	# Adding raw text and graphemes
	#print STDERR $currentString." XXXXX\n";
	if($language eq "en")
	{
	    use basicTokenizerEn;
	    basicTokenizerEn::initAbbr();
	    my $tokenString = basicTokenizerEn::tok($currentString);
	    #print STDERR $tokenString." YYYYY\n";
	    my $normString = TtsNormalisationEn::process_norm_en($tokenString, 0, 1, 0, 0);
	    #print STDERR $normString."\n";
	    $currentString = $normString;	
	}elsif($language eq "fr")
	{
	    use basicTokenizerFr;
	    basicTokenizerFr::initAbbr();
	    my $tokenString = basicTokenizerFr::tok($currentString);
	    #print STDERR $tokenString."\n";
	    my $normString = TtsNormalisationFr::process_norm_fr($tokenString, 1, 1, 0, 0);
	    #print STDERR $normString."\n";
	    $currentString = $normString;
	}    

    
	my @words = split(/\s/, $currentString);
	foreach my $word (@words)
	{        
	    if($currentWord != 0)
	    {
		my $emptyChar = new roots::linguistic_Grapheme($roots_wordSep);
		$seqGrapheme->add($emptyChar);
		$emptyChar->destroy();
		
		add_entry(0, $seqGrapheme->count()-1, \%tagGraphemeHash);
	    }
	    
	    my $rootsWord = new roots::linguistic_Word($word);
	    $sequenceWordText->add($rootsWord);
	    $rootsWord->destroy();
	    
	    foreach my $char (split (//, $word))  # . is never a newline here
	    {
		my $rootsChar = new roots::linguistic_Grapheme($char); 
		$seqGrapheme->add($rootsChar);
		$rootsChar->destroy();
		
		add_entry(0, $seqGrapheme->count()-1, \%tagGraphemeHash);
	    }
	    
	    my $rootsVoid = new roots::Void();
	    $seqVoid->add($rootsVoid);
	    $rootsVoid->destroy();      
	    
	    add_entry($currentVoidIndex, $currentWord, \%voidWordHash);
	    
	    $currentWord += 1;
	    $currentVoidIndex += 1;
	}
    }
}
    
sub get_utterances()
{
    return \@utterances;
}
    
sub init
{
    my $options = shift;

    $roots_wordSep          = $options->{roots_wordSep} if(defined $options->{roots_wordSep});
    $rootsLabel_wordRawSeq  = $options->{rootsLabel_wordRawSeq} if(defined $options->{rootsLabel_wordRawSeq});
    $rootsLabel_graphemeRawSeq = $options->{rootsLabel_graphemeRawSeq} if(defined $options->{rootsLabel_graphemeRawSeq});    
    $rootsLabel_wordSeq     = $options->{rootsLabel_wordSeq} if(defined $options->{rootsLabel_wordSeq});
    $rootsLabel_graphemeSeq = $options->{rootsLabel_graphemeSeq} if(defined $options->{rootsLabel_graphemeSeq});
    $rootsLabel_orderSeq         = $options->{rootsLabel_orderSeq} if(defined $options->{rootsLabel_orderSeq});    
    $rootsLabel_fillerSeq           = $options->{rootsLabel_fillerSeq} if(defined $options->{rootsLabel_fillerSeq});    
    $rootsLabel_durationSeq       = $options->{rootsLabel_durationSeq} if(defined $options->{rootsLabel_durationSeq});
    $rootsLabel_phonemeSeq       = $options->{rootsLabel_phonemeSeq} if(defined $options->{rootsLabel_phonemeSeq}); 
    $rootsLabel_tag              = $options->{rootsLabel_tag} if(defined $options->{rootsLabel_tag});

    $tagToAdd = $options->{tagToAdd} if(defined $options->{tagToAdd});

    $outputAlphabet = $options->{outputAlphabet} if(defined $options->{outputAlphabet});
    $outputNsAlphabet = $options->{outputNsAlphabet} if(defined $options->{outputNsAlphabet});
    $language = $options->{language} if(defined $options->{language});

    if($language eq "en")
    {
	use TtsNormalisationEn;
	TtsNormalisationEn::init_norm_en();	
    }elsif($language eq "fr"){
	use TtsNormalisationFr;
	TtsNormalisationFr::init_norm_fr();
    }
    
}
    
    
# add a relation between the ith and the jth element of the sequence
sub add_entry
{
	my $iSeq = shift;
	my $jSeq = shift;
	my $rel = shift;

	if ((defined $rel->{"row"}) and $rel->{"row"} <= $iSeq)
	{
		$rel->{"row"} = $iSeq+1;
	}
	if ((defined $rel->{"col"}) and $rel->{"col"} <= $jSeq)
	{
		$rel->{"col"} = $jSeq+1;	
	}
	$rel->{$iSeq."_".$jSeq} = 1;
}

# add the relations "a la roots"
sub add_links
{
	my $rel = shift;
	my $relHash = shift;

	foreach my $k (keys %$relHash)
	{
		if ($k ne "row" and $k ne "col")
		{
			$k =~ m/^(\d+)_(\d+)$/;
			my $i = $1;
			my $j = $2;

			if($relHash->{$k} == 1)
			{
				$rel->link($i, $j);
			}
		}
	}
}
    
1;
