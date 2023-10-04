CC=gcc
CXX=g++
LIBS=-lrt -lpthread -lm
SIZE=10 ##Test file size in GBs
NR_READ_PAGES=40 ##Nr of pages to req in one read syscall
NR_THREADS=4 ## Nr of readers 
NR_STRIDE=64
NR_RA_PAGES=256 #nr of pages
BIN_DIR=./bin

COMPOPT=-O3


#DEBUG=-DDEBUG
FLAGS=-DFILESZ=$(SIZE) -DNR_PAGES_READ=$(NR_READ_PAGES) -DNR_THREADS=$(NR_THREADS) -DNR_STRIDE=$(NR_STRIDE) -DNR_RA_PAGES=$(NR_RA_PAGES) $(DEBUG) $(COMPOPT)

SHARED_FLAGS=-DFILESZ=$(SIZE) -DNR_PAGES_READ=$(NR_READ_PAGES) 

all: write_shared read_mmap_shared

read_mmap_shared: read-mmap.cpp utils/thpool.c
	$(CXX) $^ $(FLAGS) -DSHARED_FILE $(DEBUG) -DREAD_SEQUENTIAL -o $(BIN_DIR)/read_shared_mmap_seq $(LIBS)
	$(CXX) $^ $(FLAGS) -DSHARED_FILE $(DEBUG) -DREAD_RANDOM -o $(BIN_DIR)/read_shared_mmap_rand $(LIBS)
	$(CXX) $^ $(FLAGS) -DSHARED_FILE $(DEBUG) -DREAD_SEQUENTIAL -DOSONLY -o $(BIN_DIR)/read_shared_mmap_seq_osonly $(LIBS)
	$(CXX) $^ $(FLAGS) -DSHARED_FILE $(DEBUG) -DREAD_RANDOM  -DOSONLY -o $(BIN_DIR)/read_shared_mmap_rand_osonly $(LIBS)
	#$(CXX) $^ $(FLAGS) -DSHARED_FILE $(DEBUG) -DAPP_SINGLE_PREFETCH -DREAD_SEQUENTIAL -o $(BIN_DIR)/read_shared_mmap_seq_vanilla $(LIBS)
	#$(CXX) $^ $(FLAGS) -DSHARED_FILE $(DEBUG) -DAPP_SINGLE_PREFETCH -DMODIFIED_RA -DREAD_SEQUENTIAL -o $(BIN_DIR)/read_shared_mmap_seq_vanilla_mra $(LIBS)
	#$(CXX) $^ $(FLAGS) -DSHARED_FILE $(DEBUG) -DAPP_OPT_PREFETCH -DREAD_SEQUENTIAL -o $(BIN_DIR)/read_shared_mmap_seq_vanilla_opt $(LIBS)

write_shared: write.cpp utils/thpool.c
	$(CXX) $^ $(SHARED_FLAGS) -DNR_THREADS=1 $(DEBUG) -o $(BIN_DIR)/write_shared $(LIBS)

clean:
	rm bigfakefile*
	rm $(BIN_DIR)/*
