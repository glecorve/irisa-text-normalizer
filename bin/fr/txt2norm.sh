#!/bin/bash
# bash txt2norm.sh [-s <spec_norm_cfg_file>] <file>
# Normalizes the input text file and outputs the nromalized form

NORMA=`dirname $0`/../..
SPEC_NORM=$NORMA/cfg/none.cfg
while getopts ":s:" opt; do
  case $opt in
    s)
      SPEC_NORM=$NORMA/cfg/$OPTARG.cfg
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

shift $(( OPTIND-1 ))

$NORMA/bin/fr/basic-tokenizer.pl $1 | $NORMA/bin/fr/generic-normalisation.sh - | $NORMA/bin/fr/specific-normalisation.pl $SPEC_NORM -

