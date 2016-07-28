if (( ${#IRISA_NE} == 0 )); then
echo "You must set the variable IRISA_NE to the path where the tagger is installed"
exit
fi


fsmcompile -i ${IRISA_NE}/data/modeles/fst/lexique_en.syms -o ${IRISA_NE}/data/modeles/fst/lexique_en.syms -t ${IRISA_NE}/data/modeles/fst/mot2posen.fsm > ${IRISA_NE}/data/modeles/fst/mot2posen.fsa
fsmcompile -i ${IRISA_NE}/data/modeles/fst/lexique_en.syms ${IRISA_NE}/data/modeles/fst/trigram.fsm > ${IRISA_NE}/data/modeles/fst/trigram.fsa


fsmcompile -i ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms -o ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms -t ${IRISA_NE}/data/modeles/postagger/mot2pos.fsm > ${IRISA_NE}/data/modeles/postagger/mot2pos.fsa
fsmcompile -i ${IRISA_NE}/data/modeles/postagger/lexique_pos.syms ${IRISA_NE}/data/modeles/postagger/posgram.fsm > ${IRISA_NE}/data/modeles/postagger/posgram.fsa
