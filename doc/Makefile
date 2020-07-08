OTT_FLAGS = -tex_wrap false -tex_show_meta false 

LATEX = pdflatex

all : lang.pdf

lang.pdf : lang.tex Makefile plang.ott
	ott $(OTT_FLAGS) -tex_filter lang.tex lang_ott.tex plang.ott -o plang.tex
	$(LATEX) lang_ott.tex
	$(LATEX) lang_ott.tex
	mv lang_ott.pdf lang.pdf

clean :
	rm -f lang_ott.* plang.tex plang.aux
