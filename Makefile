build:
	nasm -f elf64 -o arkanoid.o arkanoid.asm -g -l arkanoid.lst -F dwarf
	ld -o arkanoid arkanoid.o

clean:
	rm arkanoid .*.swp
