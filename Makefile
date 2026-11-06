CC = gcc
SRCS = $(wildcard src/*.c)
FLAGS = -Wall -Wextra -Wpedantic \
	-Wno-missing-field-initializers \
	-fsanitize=address,undefined \
	-g \
	-std=c23 -I include

all: make_build
	$(CC) $(FLAGS) $(SRCS) -o build/hex

make_build:
	mkdir -p build/

clean:
	rm -rf build/*
