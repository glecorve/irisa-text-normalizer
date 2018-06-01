# irisa-text-normalizer
Text normalisation tools from IRISA lab ( https://github.com/glecorve/irisa-text-normalizer )

## Synopsis

The tools provided here are split into 3 steps:
1. Tokenisation (adding blanks around punctation marks, dealing with special cases like URLs, etc.)
2. Generic normalisation (leading to homogeneous texts where (almost) information have been lost and where tags have been added for some entities)
3. Specific normalisation (projection of the generic texts into specific forms)

## How to cite
	@misc{lecorve2017normalizer,
	  title={The IRISA Text Normalizer},
	  author={Lecorv{\'e}, Gw{\'e}nol{\'e}},
	  howpublished={\url{https://github.com/glecorve/irisa-text-normalizer}},
	  year={2017}
	}


## Supported languages:

- English
- French

## Commands

> LANGUAGE="en"
> \# (or "fr")

### Tokenisation

    perl bin/$LANGUAGE/basic-tokenizer.pl examples/$LANGUAGE/text.raw > examples/$LANGUAGE/text.tokenized.txt

### Generic normalisation

    perl bin/$LANGUAGE/start-generic-normalisation.pl examples/$LANGUAGE/text.tokenized > examples/$LANGUAGE/text.norm.step1
    # <-- Here you may wish to run some extra tool -->
    perl bin/$LANGUAGE/end-generic-normalisation.pl examples/$LANGUAGE/text.norm.step1.txt > examples/$LANGUAGE/text.norm.step2.txt

or simply:

    bash bin/$LANGUAGE/generic-normalisation.sh text-normalisation/examples/$LANGUAGE/text.tokenized.txt

### 2 examples of specific normalisations

    perl bin/$LANGUAGE/specific-normalisation.pl cfg/asr.cfg examples/$LANGUAGE/text.norm.step2 > examples/$LANGUAGE/text.asr.txt
    perl bin/$LANGUAGE/specific-normalisation.pl cfg/tts.cfg examples/$LANGUAGE/text.norm.step2 > examples/$LANGUAGE/text.tts.txt

### Create your own configuration for specific normalisation
    perl bin/$LANGUAGE/specific-normalisation.pl -h
