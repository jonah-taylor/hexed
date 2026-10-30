CC = gcc
OBJ = main.o lexer.o parser.o ast.o cgops.o cgleaf.o cgparent.o rtstack.o

OUT = maniac
all: $(OUT) cleanrr

$(OUT): $(OBJ)
	$(CC) $(OBJ) -o $(OUT)

%.o: ../src/%.c
	$(CC) -c $< -o $@

clean:
	rm -f $(OBJ)

