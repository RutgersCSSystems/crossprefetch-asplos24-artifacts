SIZE=1
#OBJS=../frontend.o ../bitarray.o ../thpool.o
FLAGOBJ=-std=gnu++11 -Wno-unused-result -g -lpthread -lrt -ldl
all:
	gcc readahead_info_oslimit.c ../utils/bitarray.c
	g++ read.c -DFILESZ=$(SIZE) $(FLAGOBJ) -DONLYOS -o read_onlyos $(OBJS) 
	g++ read.c -DFILESZ=$(SIZE) $(FLAGOBJ) -DAPP_NATIVE_RA -o read_nativera $(OBJS)
	g++ read.c -DFILESZ=$(SIZE) $(FLAGOBJ) -DREADRA -o read_readra $(OBJS)
	g++ read.c -DFILESZ=$(SIZE) $(FLAGOBJ) -DAPP_NATIVE_RA -DONLYAPP -o read_onlyapp_nativera $(OBJS)
	g++ read.c -DFILESZ=$(SIZE) $(FLAGOBJ) -DREADRA -DONLYAPP -o read_onlyapp_readra $(OBJS)
	g++ write.c -DFILESZ=$(SIZE) $(FLAGOBJ) -o write $(OBJS)
	g++ pread_ra_v_pread.c -DPREAD $(FLAGOBJ) -o pread $(OBJS)
	g++ pread_ra_v_pread.c $(FLAGOBJ) -o pread_ra $(OBJS)
	
clean: 
	rm read_onlyos read_nativera read_readra read_onlyapp_nativera read_onlyapp_readra write pread pread_ra a.out
