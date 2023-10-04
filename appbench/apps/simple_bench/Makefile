MPICC=mpicc
LIBS=-lmpi
SIZE=5 ##Test file size in GBs

all:
	gcc read.c -DFILESZ=$(SIZE) -DONLYOS -o read_onlyos
	gcc read.c -DFILESZ=$(SIZE) -DAPP_NATIVE_RA -o read_nativera
	gcc read.c -DFILESZ=$(SIZE) -DREADRA -o read_readra
	gcc read.c -DFILESZ=$(SIZE) -DAPP_NATIVE_RA -DONLYAPP -o read_onlyapp_nativera
	gcc read.c -DFILESZ=$(SIZE) -DREADRA -DONLYAPP -o read_onlyapp_readra
	gcc write.c -DFILESZ=$(SIZE) -o write
	gcc pread_ra_v_pread.c -DPREAD -o pread
	gcc pread_ra_v_pread.c -o pread_ra

mpi:
	$(MPICC) read.c -DFILESZ=$(SIZE) -DONLYOS -o mpi_read_onlyos $(LIBS)
	$(MPICC) read.c -DFILESZ=$(SIZE) -DAPP_NATIVE_RA -o mpi_read_nativera $(LIBS)
	$(MPICC) read.c -DFILESZ=$(SIZE) -DREADRA -o mpi_read_readra $(LIBS)
	$(MPICC) read.c -DFILESZ=$(SIZE) -DAPP_NATIVE_RA -DONLYAPP -o mpi_read_onlyapp_nativera $(LIBS)
	$(MPICC) read.c -DFILESZ=$(SIZE) -DREADRA -DONLYAPP -o mpi_read_onlyapp_readra $(LIBS)
	$(MPICC) write.c -DFILESZ=$(SIZE) -o mpi_write $(LIBS)

test:
	gcc test_readahead.c 
