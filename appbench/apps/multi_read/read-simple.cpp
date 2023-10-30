/*/
 * This program will have NR_THREADS + 1 threads.
 * Each worker Thread is going to read a pvt file Sequentially/Randomly using pread syscall.
 */
#define _LARGEFILE64_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <aio.h>
#include <pthread.h>
#include <stdbool.h>
#include <fcntl.h>
#include <errno.h>
#include <stdbool.h>
#include <limits.h>
#include <signal.h>
#include <math.h>
#include <time.h>

#include <sys/sysinfo.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/mman.h>

#include <iostream>
#include <vector>
#include <random>
#include <atomic>

#include "util.h"
#include "utils/thpool.h"

std::atomic<long> total_nr_syscalls(0);
std::atomic<long> total_bytes_ra(0);

using namespace std;


void os_constructors(){

        start_cross_trace(ENABLE_FILE_STATS, 0);

        char a;
#if 0
#ifdef SET_READ_UNLIMITED
	a = '1';
#else
	a = '0';
#endif
	set_read_limits(a);

#ifdef UNSET_2MB_RA_LIMIT
	a = '1'; //disables 2mb limit in readahead
#else
	a = '0'; //enables 2mb limit in readahead
#endif
	set_readahead_2mb_limit(a);
#endif

	//Set bitmap size inside the OS
	a = CROSS_BITMAP_SHIFT;
	set_cross_bitmap_shift(a);
}

struct thread_args{
        int fd; //fd of opened file
        long size; //bytes to fetch from this thread
        long nr_read_pg; //nr of pages to read each req
        size_t offset; //Offset of file where RA to start from
        unsigned long read_time; //Return value, time taken to read the file in microsec
        char filename[FILENAMEMAX]; //filename for opening that file

        /*
         * To be used by mincore to update the 
         * misses and hits
         */
        unsigned long nr_total_read_pg;
        unsigned long nr_total_misses_pg;
};


//Given an array, it shuffles it
//using Fisher–Yates shuffle (also known as Knuth's Shuffle)
//To be used for Random Reads
void shuffle(long int array[], size_t n) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    int usec = tv.tv_usec;
    srand48(usec);

    if (n > 1) {
        size_t i;
        for (i = n - 1; i > 0; i--) {
            size_t j = (unsigned int) (drand48()*(i+1));
            int t = array[j];
            array[j] = array[i];
            array[i] = t;
        }
    }
}


off_t check_cache_update_offset(unsigned char *mincore_arr, off_t ra_offset, off_t filesize){

        off_t pg_ra_offset = ra_offset >> PAGESHIFT;
        off_t pg_filesize = filesize >> PAGESHIFT;

        off_t uchar_nr;

        while(pg_ra_offset < pg_filesize){

                uchar_nr = pg_ra_offset >> 3;
                if(mincore_arr[uchar_nr] == 0)
                        break;

                pg_ra_offset += 1 << 3;
        }

        return pg_ra_offset << PAGESHIFT;
}


//Will be reading one pvt file per thread
#ifdef THPOOL
void reader_th(void *arg){
#else
void *reader_th(void *arg){
#endif

        struct thread_args *a = (struct thread_args*)arg;
        struct timeval start, end;
        struct timeval open_start, open_end;
        void *mem = NULL;
        size_t buff_sz = (PG_SZ * a->nr_read_pg);
        char *buffer = (char*) malloc(buff_sz);
        size_t readnow, bytes_read, offset, ra_offset;
        off_t filesize;
        struct stat st;
        long tid = gettid();

#if SHARED_FILE
        a->fd = open(a->filename, O_RDWR);
        if (a->fd == -1){
                printf("\n File %s Open Unsuccessful: TID:%ld\n", a->filename, tid);
                exit(0);
        }
#endif //SHARED_FILE

#if defined(MODIFIED_RA) || defined(ENABLE_MINCORE_RA)
        printf("%s: First ra_info for fd=%d\n", __func__, a->fd);
        struct read_ra_req ra;
	ra.data = NULL;
	readahead_info(a->fd, 0, 0, &ra);
        start_cross_trace(ENABLE_FILE_STATS, 0);
#endif //MODIFIED_RA or ENABLE_MINCORE_RA
        //Report about the thread
        debug_printf("TID:%ld: going to fetch from %ld for size %ld on file %d, read_pg = %ld\n",
                        tid, a->offset, a->size, a->fd, a->nr_read_pg);

#ifdef READ_SEQUENTIAL
        gettimeofday(&start, NULL);
        bytes_read = 0UL;
        offset = a->offset;

#ifdef APP_SINGLE_PREFETCH

#ifdef MODIFIED_RA
	ra.data = NULL;
	readahead_info(a->fd, 0, NR_RA_PAGES << PAGESHIFT, &ra);
#else //NORMAL_RA
	readahead(a->fd, offset, a->size);
#endif //MODIFIED_RA

	debug_printf("%s: readahead called for fd:%d, offset=%ld, bytes=%ld\n",
                        __func__, a->fd, offset, a->size);

#elif defined(APP_OPT_PREFETCH)
	ra_offset = a->offset;
#endif //APP_SINGLE_PREFETCH

        while(bytes_read < a->size){

                debug_printf("%s:%ld fd=%d bytes_read=%ld, offset=%ld, size=%ld\n", __func__, tid, a->fd, bytes_read, offset, buff_sz);

#ifdef APP_OPT_PREFETCH
		if(offset >= ra_offset){
			ra_offset = offset;
#ifdef MODIFIED_RA
	                ra.data = NULL;
			readahead_info(a->fd, ra_offset, NR_RA_PAGES << PAGESHIFT, &ra);
#else //NORMAL_RA
			readahead(a->fd, ra_offset, NR_RA_PAGES << PAGESHIFT);
#endif //MODIFIED_RA
			ra_offset += NR_RA_PAGES << PAGESHIFT;

			debug_printf("%s: readahead called for fd:%d, offset=%ld, bytes=%ld\n",
					__func__, a->fd, ra_offset, NR_RA_PAGES << PAGESHIFT);
		}
#endif //APP_OPT_PREFETCH
                readnow = pread(a->fd, ((char *)buffer),
                                        buff_sz, offset);
                if(readnow < 0){
                        printf("\nRead Unsuccessful\n");
                        free(buffer);
                        goto exit;
                }
                bytes_read += readnow;

                offset += readnow;
#ifdef STRIDED_READ
                offset += NR_STRIDE * PG_SZ;
#endif //STRIDED_READ
        }
        gettimeofday(&end, NULL);

#elif READ_RANDOM
        size_t nr_file_portions = a->size/buff_sz;
        long *read_sequence = (long*)malloc(sizeof(long)*nr_file_portions);

        for(long i=0; i<nr_file_portions; i++){
                read_sequence[i] = i;
        }
        shuffle(read_sequence, nr_file_portions);

        gettimeofday(&start, NULL);

        for(long i=0; i<nr_file_portions; i++){

                //Checks mincore to determine the number of misses
                readnow = pread(a->fd, ((char *)buffer),
                                        buff_sz, (read_sequence[i]*buff_sz)+a->offset);
        }

        gettimeofday(&end, NULL);

#endif //READ_SEQUENTIAL
        a->read_time = usec_diff(&open_start, &open_end) + usec_diff(&start, &end);

exit:
#ifdef THPOOL
        return;
#else
        return NULL;
#endif
}



int main(int argc, char **argv)
{

        os_constructors();

#ifdef GLOBAL_TIMER
        struct timeval global_start, global_end;
        gettimeofday(&global_start, NULL);
#endif

        long size = FILESIZE;

        /*
         * Open all the files and save their fds
         */
        vector<int> fd_list;
        char filename[FILENAMEMAX];
        int fd = -1;

        for(int i=0; i<NR_THREADS; i++){
#ifdef SHARED_FILE
                file_name(i, filename, 1);
                goto skip_open;
#else
                file_name(i, filename, NR_THREADS);
#endif
                fd = open(filename, O_RDWR);
                if (fd == -1){
                        printf("\nFile %s Open Unsuccessful\n", filename);
                        exit (0);
                }
                fd_list.push_back(fd);
                fd = -1;
#ifdef SHARED_FILE
                //Open just one file since shared
                break;
#endif
        }
skip_open:
//Disables OS pred
//#if defined(ONLYAPP) && !defined(SHARED_FILE)
        for(int i=0; i<NR_THREADS; i++){
                posix_fadvise(fd_list[i], 0, 0, POSIX_FADV_SEQUENTIAL);
        }
//#endif

#ifdef THPOOL
        threadpool thpool;
        thpool = thpool_init(NR_THREADS); //spawns a set of worker threads
        if(!thpool){
                printf("FAILED: creating threadpool with %d threads\n", NR_THREADS);
        }
#else
        pthread_t pthreads[NR_THREADS];
#endif
        //Preallocating all the thread_args to remove overheads
        struct thread_args *req = (struct thread_args*)
                                malloc(sizeof(struct thread_args)*NR_THREADS);

        for(int i=0; i<NR_THREADS; i++){

                req[i].size = FILESIZE/NR_THREADS;
                req[i].nr_read_pg = NR_PAGES_READ;
                req[i].read_time = 0UL;

                req[i].nr_total_read_pg = 0UL;
                req[i].nr_total_misses_pg = 0UL;
#ifdef SHARED_FILE
                //req[i].fd = fd_list[0];
                req[i].fd = -1;
                strcpy(req[i].filename, filename);
                req[i].offset = req[i].size*i; //Start at different position
#else
                req[i].fd = fd_list[i]; //assign one file to each worker thread
                req[i].offset = 0;
#endif

#ifdef THPOOL
                thpool_add_work(thpool, reader_th, (void*)&req[i]);
#else
                pthread_create(&pthreads[i], NULL, reader_th, (void*)&req[i]);
#endif
        }

#ifdef THPOOL
        thpool_wait(thpool);
#else
        for(int i=0; i<NR_THREADS; i++){
                pthread_join(pthreads[i], NULL);
        }
#endif


#ifdef GLOBAL_TIMER
        gettimeofday(&global_end, NULL);
        float global_max_time = 0.f; //in sec
#endif
        //Print the Throughput
        long size_mb;
        float max_time = 0.f; //in sec
        float time;

#ifdef STRIDED_READ
        long nr_file_pg = FILESIZE/PG_SZ;
        long nr_read_stride_blocks = nr_file_pg/(NR_PAGES_READ+NR_STRIDE);
        size_mb = (nr_read_stride_blocks * NR_PAGES_READ * PG_SZ)/(1024L*1024L);
#else
        size_mb = FILESIZE/(1024L*1024L);
#endif

        printf("Total File size = %ld MB\n", size_mb);
        for(int i=0; i<NR_THREADS; i++){
                time = req[i].read_time/1000000.f;
                if(max_time < time)
                        max_time = time;
        }

#ifdef GLOBAL_TIMER
        global_max_time = usec_diff(&global_start, &global_end)/1000000.f;
#endif

#if defined(READ_SEQUENTIAL) && defined(STRIDED_READ)
        printf("READ_STRIDED Bandwidth = %.2f MB/sec\n", size_mb/max_time);
#elif defined(READ_SEQUENTIAL) && !defined(STRIDED_READ)
        printf("READ_SEQUENTIAL Bandwidth = %.2f MB/sec\n", size_mb/max_time);
#elif READ_RANDOM
        printf("READ_RANDOM Bandwidth = %.2f MB/sec\n", size_mb/max_time);
#endif

#ifdef GLOBAL_TIMER
        printf("GLOBAL Bandwidth = %.2f MB/sec\n", size_mb/global_max_time);
#endif

#ifdef ENABLE_MINCORE_RA
        printf("Total Syscalls Done = %ld , total bytes ra= %ld\n", total_nr_syscalls.load(), total_bytes_ra.load());

        printf("Total nr_ra = %ld mincore\n", total_nr_syscalls.load());
        printf("Total nr_bytes_ra= %ld mincore\n", total_bytes_ra.load());
        start_cross_trace(PRINT_GLOBAL_STATS, 0);
#endif
        return 0;
}
