JASMIN=../../jasminc
JFLAGS=-lea

main: main.c encrypt.s
	gcc -Wall -Wextra -Wpedantic main.c encrypt.s -o $@

%.s: %.japp
	$(JASMIN) -o $@ $(JFLAGS) $^

%.japp: %.jazz
	gpp -o $@ $<

.PHONY: clean

clean:
	-rm main
