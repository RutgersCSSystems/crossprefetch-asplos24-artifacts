#define _LARGEFILE64_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/syscall.h>
#include <sys/stat.h>
#include <errno.h>

#include <iostream>
#include <vector>

#include "util.h"
#include "utils/thpool.h"

using namespace std;

struct thread_args{
        long size; //bytes to write from this thread
        char filename[FILENAMEMAX];
};

void prefetcher_th(void *arg){
        long tid = gettid();
        struct thread_args *a = (struct thread_args*)arg;
        printf("TID:%ld: size=%ld on file %s\n", 
                        tid, a->size, a->filename);

        FILE *fp;
        fp=fopen(a->filename, "w");

        if(!fp){
                printf("Unable to open file\n");
                return;
        }

	int write_size = PG_SZ * NR_PAGES_READ;
	char *buffer = (char *)malloc(write_size);
	memset(buffer, 'C', write_size);
        /*for(long i=0; i < a->size; i++) {
                fprintf(fp, "C");
        }*/
	long i = 0, bytes;
	while(i < a->size) {
		 bytes += fwrite(buffer, write_size, 1, fp);
		 i = i + write_size;	
	}
     	printf("TID:%ld: size=%ld, bytes=%ld\n", tid, a->size, bytes);

        fclose(fp);
        return;
}

int main() {
        double i;
        int fileno=0;
        vector<FILE *> filp_list;

        char filename[FILENAMEMAX];
        char foldername[FILENAMEMAX];

        folder_name(foldername, NR_THREADS);

        mkdir(foldername, S_IRWXU);

        threadpool thpool;
        thpool = thpool_init(NR_THREADS);
        if(!thpool){
                printf("FAILED: creating threadpool with %d threads\n", NR_THREADS);
        }
        else
                printf("Created %d bg threads\n", NR_THREADS);

        for(int i=0; i<NR_THREADS; i++){
                struct thread_args *req = (struct thread_args*)malloc(sizeof(struct thread_args));
                //file_name(str1, i, filename);
                file_name(i, filename, NR_THREADS);
                req->size = FILESIZE/NR_THREADS;
                strcpy(req->filename, filename);
                thpool_add_work(thpool, prefetcher_th, (struct thread_args*)req);
        }

        thpool_wait(thpool);

        return 0;
}
