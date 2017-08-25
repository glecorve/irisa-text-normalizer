#!/bin/bash
#
# Wrapper for long texts in order to avoid OutOfMemory exceptions
#
#

# ROOTDIR=`dirname $0`/../..
# STANFORD_NER=$ROOTDIR/lib/stanford-ner

TMP_BASE=/tmp/stanford-ner
mkdir -p $TMP_BASE
TMP_DIR=`mktemp -d --tmpdir=$TMP_BASE`
split $1 "$TMP_DIR/"
# java -mx600m -cp "$STANFORD_NER/stanford-ner.jar:$STANFORD_NER/lib/*" edu.stanford.nlp.ie.crf.CRFClassifier -loadClassifier $STANFORD_NER/classifiers/english.all.3class.distsim.crf.ser.gz -textFile $TMP_DIR/*
# java -Xmx256m -cp "$ROOTDIR/lib/:$STANFORD_NER/stanford-ner.jar" StanfordNETagger $STANFORD_NER/classifiers/all.3class.distsim.crf.ser.gz $TMP_DIR/* | perl -ne '$_ =~ s/>/> /g ; $_ =~ s/</ </g ; print $_;'
cat $TMP_DIR/* | perl -ne '$_ =~ s/>/> /g ; $_ =~ s/</ </g ; print $_;'
rm -fR $TMP_DIR
