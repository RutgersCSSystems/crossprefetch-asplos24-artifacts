#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h> /* For SYS_xxx definitions */
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
//#include "crfslib.h"
typedef uint64_t u64;
#ifndef _POSIX
#define TESTDIR "/mnt/ram/dataset"
#else
#define TESTDIR "/mnt/pmemdir/dataset"
#endif

#define KB (1024)
#define MB (1024 * 1024)
#define GB (1024 * 1024 * 1024UL)

//#define FILESIZE (100 * MB)
//#define FILESIZE (1 * GB)
#define FILEPERM 0666

int BLOCKSIZE = 4096;
int FILESIZE = 100 * KB;
int ITERS = 0;
int FILENUM;

int gen_test_file(char* filename, int iters) {
    int fd = 0;
    char* buf = (char*)malloc(BLOCKSIZE);
    uint64_t i = 0;
    uint32_t crc = 0;

//    printf("create filename: %s \n", filename);
    /* Step 1: Create Testing File */

#ifndef _POSIX
    if ((fd = crfsopen(filename, O_CREAT | O_RDWR, FILEPERM)) < 0) {
#else
    if ((fd = open(filename, O_CREAT | O_RDWR, FILEPERM)) < 0) {
#endif
        perror("creat");
        goto gen_file_failed;
    }

    /* Step 2: Append 1M blocks to storage with random contents and checksum */
    for (i = 0; i < iters; i++) {
        /* memset with some random data */
        memset(buf, 0x61 + i % 26, BLOCKSIZE);

#ifndef _POSIX
        if (crfswrite(fd, buf, BLOCKSIZE) != BLOCKSIZE) {
#else
        if (write(fd, buf, BLOCKSIZE) != BLOCKSIZE) {
#endif
            printf("File data block write fail \n");
            goto gen_file_failed;
        }
    }
//    printf("file: %s, finish writing %lu blocks\n", filename, i);
#ifndef _POSIX
    crfsclose(fd);
#else
    close(fd);
#endif
    return fd;

gen_file_failed:
    free(buf);
    return -1;
}

int main(int argc, char** argv) {
    if (argc != 4) {
        printf("invalid argument\n");
        printf("./gen_file file_num file_size(KB) output_dir\n");
        return 0;
    }

#ifndef _POSIX
    crfsinit(USE_DEFAULT_PARAM, USE_DEFAULT_PARAM, DEFAULT_SCHEDULER_POLICY);
#endif
    char output_dir[256]; 

    FILENUM = atoi(argv[1]);
    FILESIZE = atoi(argv[2]);
    strcpy(output_dir, argv[3]);

    ITERS = (FILESIZE * KB) / BLOCKSIZE;
    
    mkdir(output_dir, 0755);

    for (int i = 0; i < FILENUM; i++) {

        char filename[256];
        snprintf(filename, sizeof(filename), "%s/%s%d", output_dir, "testfile", i);
        gen_test_file(filename, ITERS);        
    }
#ifndef _POSIX
    crfsexit();
#endif
    return 0;
}
