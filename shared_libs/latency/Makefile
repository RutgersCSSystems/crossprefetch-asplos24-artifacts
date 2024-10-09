CXX = g++
CC = gcc
MAKE = make
SOURCE = *.cpp

LIBS = -lrt -ldl
FLAGS = -fPIC -shared -std=c++14 -O3 -Wno-unused-result
override EXFLAGS += -DGET_LATENCY

.PHONY: clean test


latency: $(SOURCE)
	$(CC) $(FLAGS) $(EXFLAGS) $(LIBS) $^ -o liblatency.so

clean: 
	$(MAKE) clean -C ./test
	rm *.so *.text
	

install: latency
	sudo cp *.so /usr/local/lib
	sudo cp *.so /usr/lib

test: $(SOURCE) 
	$(CC) $(FLAGS) -DGET_LATENCY -DLATENCY_DEBUG -DLATENCY_SAMPLE=1 $(LIBS) $^ -o liblatency.so
	$(MAKE) -C ./test
<<<<<<< HEAD
	$(MAKE) run -C ./test
=======
>>>>>>> abca209882160fcdb68ca605e29b3ba4313f894b

