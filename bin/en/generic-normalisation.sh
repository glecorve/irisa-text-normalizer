#!/bin/bash
$ROOTDIR=`dirname $O`
perl $ROOTDIR/start-generic-normalisation.pl -v $1 | bash $ROOTDIR/tag-named-entities.sh - | perl $ROOTDIR/end-generic-normalisation.pl -v -

