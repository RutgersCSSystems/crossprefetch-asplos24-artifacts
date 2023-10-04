all: shared_posixio

CC=gcc
LIB_S=-lpthread -lrt 

shared_posixio: shared_posixio.c
	$(CC) shared_posixio.c -o shared_posixio -lpthread

clean:
	rm -rf *.o
	rm -rf *.so
	rm -rf shared_posixio
	

