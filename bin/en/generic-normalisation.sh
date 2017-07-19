#!/bin/bash
ROOTDIR=`dirname "$0"`
# perl $ROOTDIR/start-generic-normalisation.pl -v $1 | bash $ROOTDIR/tag-named-entities.sh - | perl $ROOTDIR/end-generic-normalisation.pl -v -
perl $ROOTDIR/start-generic-normalisation.pl -v $1 |  perl $ROOTDIR/end-generic-normalisation.pl -v -

