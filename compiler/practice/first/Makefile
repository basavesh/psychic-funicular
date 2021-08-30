JASMIN=../../jasminc
JFLAGS=-lea

main: main.c addvec.s
	gcc -Wall -Wextra -Wpedantic main.c addvec.s -o $@

%.s: %.japp
	$(JASMIN) -o $@ $(JFLAGS) $^

%.japp: %.jazz
	gpp -o $@ $<

.PHONY: clean

clean:
	-rm main
