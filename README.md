# irisa-text-normalizer
Text normalisation tools from IRISA lab

## Synopsis

The tools provided here are split into 3 steps:
1. Tokenisation (adding blanks around punctation marks, dealing with special cases like URLs, etc.)
2. General normalisation (leading to homogeneous texts where (almost) information have been lost and where tags have been added for some entities)
3. Specific normalisation (projection the generic texts into specific forms)


## Supported languages:

- English
- French

## Configuration

See INSTALL file

## Commands

> LANGUAGE="en"
> # (or "fr")

### Tokenisation

    perl bin/$LANGUAGE/basic-tokenizer.pl examples/$LANGUAGE/text.raw > examples/$LANGUAGE/text.tokenized

### Generic normalisation

    perl bin/$LANGUAGE/start-generic-normalisation.pl examples/$LANGUAGE/text.tokenized > examples/$LANGUAGE/text.norm.step1
    bash bin/$LANGUAGE/tag-named-entities.sh examples/$LANGUAGE/text.norm.step1 > examples/$LANGUAGE/text.norm.step2
    perl bin/$LANGUAGE/end-generic-normalisation.pl examples/$LANGUAGE/text.norm.step2 > examples/$LANGUAGE/text.norm.step3
    
or simply:

    bash bin/$LANGUAGE/generic-normalisation.sh text-normalisation/examples/$LANGUAGE/text.tokenized

### 2 examples of specific normalisations

    perl bin/$LANGUAGE/specific-normalisation.pl cfg/$LANGUAGE/asr.cfg examples/$LANGUAGE/text.norm.step3 > examples/$LANGUAGE/text.asr
    perl bin/$LANGUAGE/specific-normalisation.pl cfg/$LANGUAGE/indexing.cfg examples/$LANGUAGE/text.norm.step3 > examples/$LANGUAGE/text.indexing

