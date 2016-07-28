# irisa-text-normalizer
# Text normalisation tools from IRISA lab

# Synopsis

The tools provided here are split into 3 steps:
1. Tokenisation (adding blanks around punctation marks, dealing with special cases like URLs, etc.)
2. General normalisation (leading to homogeneous texts where (almost) information have been lost and where tags have been added for some entities)
3. Specific normalisation (projection the generic texts into specific forms)


# Supported languages:

- English
- French

# Configuration

See INSTALL file

# Commands

## Tokenisation

    perl bin/basic-tokenizer.pl examples/text.raw > examples/text.tokenized

## Generic normalisation

    perl bin/start-generic-normalisation.pl examples/text.tokenized > examples/text.norm.step1
    bash bin/tag-named-entities.sh examples/text.norm.step1 > examples/text.norm.step2
    perl bin/end-generic-normalisation.pl examples/text.norm.step2 > examples/text.norm.step3
    
or simply:

    bash bin/generic-normalisation.sh text-normalisation/examples/text.tokenized

## 2 examples of specific normalisations

    perl bin/specific-normalisation.pl cfg/asr.cfg examples/text.norm.step3 > examples/text.asr
    perl bin/specific-normalisation.pl cfg/indexing.cfg examples/text.norm.step3 > examples/text.indexing

