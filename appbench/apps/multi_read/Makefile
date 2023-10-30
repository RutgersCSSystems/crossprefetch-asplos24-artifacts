CC=gcc
CXX=g++
LIBS=-lrt -lpthread -lm
SIZE=50 ##Test file size in GBs
NR_READ_PAGES=40 ##Nr of pages to req in one read syscall
NR_THREADS=4 ## Nr of readers 
NR_STRIDE=64
NR_RA_PAGES=256 #nr of pages
BIN_DIR=./bin

COMPOPT=-O3


#DEBUG=-DDEBUG
FLAGS=-DFILESZ=$(SIZE) -DNR_PAGES_READ=$(NR_READ_PAGES) -DNR_THREADS=$(NR_THREADS) -DNR_STRIDE=$(NR_STRIDE) -DNR_RA_PAGES=$(NR_RA_PAGES) $(DEBUG) $(COMPOPT)

SHARED_FLAGS=-DFILESZ=$(SIZE) -DNR_PAGES_READ=$(NR_READ_PAGES) 

all: read_pvt write_pvt

read_pvt: read.cpp utils/thpool.c
	mkdir bin
	$(CXX) $^ $(FLAGS) $(DEBUG) -DREAD_SEQUENTIAL -o $(BIN_DIR)/read_pvt_seq $(LIBS)
	$(CXX) $^ $(FLAGS) $(DEBUG) -DREAD_SEQUENTIAL -DGLOBAL_TIMER -o $(BIN_DIR)/read_pvt_seq_global $(LIBS)
	$(CXX) $^ $(FLAGS) $(DEBUG) -DREAD_SEQUENTIAL -DENABLE_MINCORE_RA -o $(BIN_DIR)/read_pvt_seq_mincore $(LIBS)
	$(CXX) $^ $(FLAGS) $(DEBUG) -DAPP_SINGLE_PREFETCH -DREAD_SEQUENTIAL -o $(BIN_DIR)/read_pvt_seq_vanilla $(LIBS)
	$(CXX) $^ $(FLAGS) $(DEBUG) -DAPP_OPT_PREFETCH -DREAD_SEQUENTIAL -o $(BIN_DIR)/read_pvt_seq_vanilla_opt $(LIBS)
	$(CXX) $^ $(FLAGS) $(DEBUG) -DREAD_SEQUENTIAL -DSTRIDED_READ -o $(BIN_DIR)/read_pvt_strided $(LIBS)
	$(CXX) $^ $(FLAGS) $(DEBUG) -DREAD_RANDOM -o $(BIN_DIR)/read_pvt_rand $(LIBS)



write_pvt: write.cpp utils/thpool.c
	$(CXX) $^ $(FLAGS) $(DEBUG) -o $(BIN_DIR)/write_pvt $(LIBS)

clean:
	rm -rf bigfakefile*
	rm $(BIN_DIR)/*
