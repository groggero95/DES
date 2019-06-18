SOURCE_DOCS		= 	$(wildcard *.md)
EXPORTED_DOCS 	=  	$(SOURCE_DOCS:.md=.pdf)

%.pdf: %.md
	pandoc -o $@ $<

.PHONY: all clean unite

all: $(EXPORTED_DOCS)

clean:
	-rm -rf $(EXPORTED_DOCS)
