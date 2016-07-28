#!/bin/bash
#
# $Id: $
#
# Named Entities Tagger

if [ $# -lt 1 ]
then
echo "*** Error *** : usage is irisa_ne.bash  <FST/CRF> [-h]  <STDIN>"
echo irisa_ne.bash: a Named Entities Tagger
exit -1
fi

if [ "$1" = "-h" ]
then
echo "usage is irisa_ne.bash  <FST/CRF> [-f2h]  <STDIN>"
echo irisa_ne.bash: a Named Entities Tagger
exit -1
fi

if (( ${#IRISA_NE} == 0 )); 
then
echo "You must set the variable IRISA_NE to the path where the tagger is installed"
exit -1
fi

if [ "$1" = "CRF" ] || [ "$1" = "FST" ]
then
TAGGER=$1;
else
echo first parameter must be CRF or FST
exit -1
fi

if [ $# == 2 ] && [ "$2" != "-f2h" ]
then
echo only -f2h is knew
exit -1
fi


TRANSFORMED=`mktemp tmp.XXXXXX` || exit 1
ORIGINAL=`mktemp tmp.XXXXXX` || exit 1



if [ "$1" == "FST" ]
then

${IRISA_NE}/scripts/txt2trans.pl ${IRISA_NE}/data/modeles/fst/lexique_en.syms 2> $ORIGINAL >$TRANSFORMED

if [ "$2" = "-f2h" ]
then
cat $TRANSFORMED | farcompilestrings -i ${IRISA_NE}/data/modeles/fst/lexique_en.syms  |\
farfilter "fsmcompose - ${IRISA_NE}/data/modeles/fst/mot2posen.fsa | fsmcompose - ${IRISA_NE}/data/modeles/fst/trigram.fsa  |farprintstrings -o ${IRISA_NE}/data/modeles/fst/lexique_en.syms " |\
perl -pe '{s/(\S+)<(\S+)>/$2\n/g}' |\
paste $ORIGINAL - |\
${IRISA_NE}/scripts/crf2txttagge.pl |\
${IRISA_NE}/scripts/flat2hierarchic_ne.pl ${IRISA_NE}/data/flat2hierarchic.rules
else
cat $TRANSFORMED | farcompilestrings -i ${IRISA_NE}/data/modeles/fst/lexique_en.syms  |\
farfilter "fsmcompose - ${IRISA_NE}/data/modeles/fst/mot2posen.fsa | fsmcompose - ${IRISA_NE}/data/modeles/fst/trigram.fsa  |farprintstrings -o ${IRISA_NE}/data/modeles/fst/lexique_en.syms " |\
perl -pe '{s/(\S+)<(\S+)>/$2\n/g}' |\
paste $ORIGINAL - |\
${IRISA_NE}/scripts/crf2txttagge.pl
fi
fi

if [ "$1" = "CRF" ]
then
${IRISA_NE}/scripts/txt2trans.pl ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms 2> $ORIGINAL >$TRANSFORMED

if [ "$2" = "-f2h" ]
then
cat $TRANSFORMED | farcompilestrings -i ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms  |\
farfilter "fsmcompose - ${IRISA_NE}/data/modeles/postagger/mot2pos.fsa | fsmcompose - ${IRISA_NE}/data/modeles/postagger/posgram.fsa |fsmbestpath | fsmrmepsilon |fsmprint -i ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms -o ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms " |\
awk '{if(NF>2){print $3" "$4;}else{print "";}}' |\
${IRISA_NE}/scripts/precise4morph+mt.pl 5 ${IRISA_NE}/data/modeles/crf/mots.agarder.30.train+dev+test |\
wapiti label -p -m ${IRISA_NE}/data/modeles/crf/train+dev+test.precise+mot.corrige.model.light 2> /dev/null |\
awk '{print $3}' |\
paste $ORIGINAL - |\
${IRISA_NE}/scripts/crf2txttagge.pl |\
${IRISA_NE}/scripts/flat2hierarchic_ne.pl ${IRISA_NE}/data/flat2hierarchic.rules
else
cat $TRANSFORMED | farcompilestrings -i ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms  |\
farfilter "fsmcompose - ${IRISA_NE}/data/modeles/postagger/mot2pos.fsa | fsmcompose - ${IRISA_NE}/data/modeles/postagger/posgram.fsa |fsmbestpath | fsmrmepsilon |fsmprint -i ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms -o ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms " |\
awk '{if(NF>2){print $3" "$4;}else{print "";}}' |\
${IRISA_NE}/scripts/precise4morph+mt.pl 5 ${IRISA_NE}/data/modeles/crf/mots.agarder.30.train+dev+test |\
wapiti label -p -m ${IRISA_NE}/data/modeles/crf/train+dev+test.precise+mot.corrige.model.light 2> /dev/null |\
awk '{print $3}' |\
paste $ORIGINAL - |\
${IRISA_NE}/scripts/crf2txttagge.pl
fi
fi

rm $TRANSFORMED;
rm $ORIGINAL;
