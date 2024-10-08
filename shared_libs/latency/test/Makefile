CC = gcc
SOURCE = *.c


latency_test.o: latency_test.c
	$(CC) $^ -o $@

run: latency_test.o
	LD_PRELOAD=../liblatency.so ./$^

clean: FORCE
	rm *.o *.text

FORCE:
