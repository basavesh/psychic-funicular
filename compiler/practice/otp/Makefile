JASMIN=../../jasminc
JFLAGS=-lea

main: main.c
	gcc -Wall -Wextra -Wpedantic main.c -o $@

%.s: %.japp
	$(JASMIN) -o $@ $(JFLAGS) $^

%.japp: %.jazz
	gpp -o $@ $<

.PHONY: clean

clean:
	-rm main
