MLKIT?=mlkit
FUTHARK?=futhark
FUTHARK_BACKEND?=multicore
CC?=cc
CFLAGS?=-Wall -Wextra -pedantic -O3

sandstorm: sandstorm.mlb main.sml libsandstorm.a
	$(MLKIT) -o sandstorm -libdirs . -libs "c,dl,m,sandstorm" -no_gc sandstorm.mlb

libsandstorm.a: termios.o sandstorm.o sandstorm.smlfut.o
	ar rcs $@ $^

%.o: %.c
	$(CC) -c $^ $(CFLAGS)

sandstorm.smlfut.c: sandstorm.c
	smlfut --target=mlkit sandstorm.json --structure-name=Sandstorm

sandstorm.c: sandstorm.fut
	$(FUTHARK) $(FUTHARK_BACKEND) --library sandstorm.fut

clean:
	rm -rf *.smlfut.* sandstorm *.o *.a sandstorm.c sandstorm.h sandstorm.json sandstorm.sig sandstorm.sml MLB
