JASMIN=../../jasminc
JFLAGS=-lea

main: main.c lucky.s
	gcc -Wall -Wextra -Wpedantic main.c lucky.s -o $@

%.s: %.japp
	$(JASMIN) -o $@ $(JFLAGS) $^

%.japp: %.jazz
	gpp -o $@ $<

.PHONY: clean

clean:
	-rm main
