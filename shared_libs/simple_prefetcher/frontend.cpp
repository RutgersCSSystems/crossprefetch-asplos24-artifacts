#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <dlfcn.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>
#include <sched.h>
#include <stdarg.h>
#include <errno.h>
#include <time.h>

#include <iostream>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <algorithm>
#include <map>
#include <deque>
#include <unordered_map>
#include <string>
#include <iterator>
#include <atomic>

#include <sys/sysinfo.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <sys/resource.h>


#ifdef ENABLE_MPI
#include <mpi.h>
#endif

#ifdef MAINTAIN_UINODE
#include "uinode.hpp"
#include "hashtable.h"
struct hashtable *i_map;
std::atomic_flag i_map_init;
#endif

#ifndef MAINTAIN_UINODE
#include "util.hpp"
#endif

#include "utils/robin_hood.h"

#ifdef THPOOL_PREFETCH
//threadpool workerpool[8];
threadpool workerpool = NULL;
#endif

#ifdef ENABLE_EVICTION
threadpool evict_pool = NULL;
#endif


#ifdef PREDICTOR
//Maps fd to its file_predictor, global ds
//std::unordered_map<int, file_predictor*> fd_to_file_pred;
#include "predictor.hpp"
robin_hood::unordered_map<int, file_predictor*> fd_to_file_pred;
std::atomic_flag fd_to_file_pred_init;
std::mutex fp_mutex;
#endif


#include <assert.h>
#include "utils/thpool-simple.h"
#define THREAD NR_WORKERS
#define SIZE   2000 //NR_QSIZE
#define QUEUES 32 //NR_NQUEUES

#define BITS_TO_CHARS(bits)   ((((bits) - 1) / LONG_BIT) + 1)

threadpool_t *pool[QUEUES];
int g_next_queue=0;
pthread_mutex_t lock;

#include "frontend.hpp"

#ifdef PREDICTOR
#define MIN_FD 4
#else
#define MIN_FD 3
#endif
int g_min_fd = MIN_FD;


#ifdef ENABLE_MPI
struct hashtable *mpi_map;
#endif

struct file_desc {
	int fd;
	const char *filename;
	struct u_inode *uinode;

#ifdef ENABLE_MPI
	MPI_File fh;
#endif
};

#ifdef ENABLE_MPI
robin_hood::unordered_map<MPI_File *, int> mpi_hadle_fd;
#endif


#ifdef ENABLE_LIB_STATS
// Initializing global stats
std::atomic<long> total_nr_ra(0);
std::atomic<long> total_bytes_ra(0);
#endif


//enables per thread constructor and destructor
thread_local per_thread_ds ptd;

static void con() __attribute__((constructor));
static void dest() __attribute__((destructor));

void print_affinity() {
	cpu_set_t mask;
	long nproc, i;

	if (sched_getaffinity(0, sizeof(cpu_set_t), &mask) == -1) {
		perror("sched_getaffinity");
	}
	nproc = sysconf(_SC_NPROCESSORS_ONLN);
	printf("sched_getaffinity = ");
	for (i = 0; i < nproc; i++) {
		printf("%d ", CPU_ISSET(i, &mask));
	}
	printf("\n");
}

#if 0
/*
 * Handle signals from application to wind-up a
 * bunch of things. For example, filebench does
 * not terminate unless the worker threads terminate
 */
void handle_app_sig_handler(int signum){

	//fprintf(stderr, "Inside handler function\n");
	dest();
#ifdef THPOOL_PREFETCH
	if(workerpool) {
		thpool_destroy(workerpool);
		workerpool = NULL;
	}
#endif
	//fprintf(stderr, "Finished destruction\n");
	return;
}

void reg_app_sig_handler(void){

	//fprintf(stderr, "Regsitering signal handler \n");
	//signal(SIGUSR2,handle_app_sig_handler);
}

#endif


/*
 * Initialize fd_to_file_pred
 */
void init_global_ds(void){

#ifdef PREDICTOR
	if(!fd_to_file_pred_init.test_and_set()){
		debug_printf("%s:%d Allocating fd_to_file_pred\n", __func__, __LINE__);
		//fd_to_file_pred = new std::unordered_map<int, file_predictor*>;
	}
#endif

#ifdef MAINTAIN_UINODE
	if(!i_map_init.test_and_set()){
		debug_printf("%s:%d Allocating hashmap\n", __func__, __LINE__);
		i_map = init_inode_fd_map();
		if(!i_map){
			fprintf(stderr, "%s:%d Hashmap alloc failed\n", __func__, __LINE__);
                        goto exit;
		}

#ifdef ENABLE_EVICTION
       thpool_add_work(evict_pool, evict_inactive_inodes, (void*)i_map);
#endif
	}
exit:
#endif

    return;
}


long get_prefetch_pages() {

#ifdef ENABLE_EVICTION
	if(is_memory_low()) {
		return (NR_RA_PAGES/4) * PAGESIZE;
	}
#endif
	return NR_RA_PAGES * PAGESIZE;
}

//PREFETCH SYSCALLS
long readahead_info_wrap(int fd, off64_t offset, size_t count, struct
		read_ra_req *ra, struct u_inode *uinode) {
        long err = -1; 
#ifdef ENABLE_EVICTION
	/* We are dangerously low on memory 
	 * So time to evict
	 */
	if(is_memory_danger_low()) {
		//fprintf(stderr, "turning off everything \n");
		return err;
	}
	else if(is_memory_low()) {
		/*Can we still use readahead? */
		//fprintf(stderr, "using readahead \n");
		//err = readahead(fd, offset, count);
		return err;
	}else 
#endif
	{
		err = readahead_info(fd, offset, count, ra);
#ifdef ENABLE_EVICTION
		update_prefetch_bytes(count, 1);
#endif
	}
#ifdef ENABLE_EVICTION
        update_lru(uinode);
#endif
        return err;
}




/*
 * Set unbounded_read to 0 or 1
 */
void set_read_limits(char a){

	debug_printf("%s: Setting Read Limits to %c\n", __func__, a);
	int fd = real_open(UNBOUNDED_PROCFS_FILE, O_RDWR, 0);
	pwrite(fd, &a, sizeof(char), 0);
	real_close(fd);
	debug_printf("Exiting %s\n", __func__);
}

/*
 * Set disable_2mb_limits to 0 or 1
 */
void set_readahead_2mb_limit(char a){
	debug_printf("%s: Setting Readahead 2MB Limit to %c\n", __func__, a);
	int fd = real_open(RA_2MB_LIMIT_PROCFS_FILE, O_RDWR, 0);
	pwrite(fd, &a, sizeof(char), 0);
	real_close(fd);
	debug_printf("Exiting %s\n", __func__);
}

/*
 * Set cross_bitmap_shift
 */
void set_cross_bitmap_shift(char a){
	debug_printf("%s: Setting cross_bitmap_shift to %c\n", __func__, a);
	int fd = real_open(CROSS_BITMAP_SHIFT_FILE, O_RDWR, 0);
	pwrite(fd, &a, sizeof(char), 0);
	real_close(fd);
	debug_printf("Exiting %s\n", __func__);
}


void con(){

	char a;

	g_min_fd = MIN_FD;
        fprintf(stderr, "Setting g_min_fd %d \n", g_min_fd);

#ifdef ENABLE_OS_STATS
	fprintf(stderr, "ENABLE_FILE_STATS in %s\n", __func__);
	start_cross_trace(ENABLE_FILE_STATS, 0);

	/* look at Makefile:CLEAR_STATS
	fprintf(stderr, "CLEAR_GLOBAL_STATS in %s\n", __func__);
        start_cross_trace(CLEAR_GLOBAL_STATS, 0);
	 */
#endif

	debug_printf("CONSTRUCTOR GETTING CALLED \n");
	/*
	 * Sometimes, if dlsym is called with thread spawn
	 * glibc incurres an error.
	 */
	link_shim_functions();

#ifdef THPOOL_PREFETCH
	workerpool = thpool_init(NR_WORKERS);
	if(!workerpool){
		printf("%s:FAILED creating thpool with %d threads\n", __func__, NR_WORKERS);
	}else{
		debug_printf("Created %d bg_threads\n", NR_WORKERS);
	}

    for(int i = 0; i < QUEUES; i++) {
            pool[i] = threadpool_create(THREAD, SIZE, 0);
            assert(pool[i] != NULL);
    }
#endif

#ifdef ENABLE_EVICTION
	evict_pool = thpool_init(NR_EVICT_WORKERS);
	if(!evict_pool){
		printf("%s:FAILED creating thpool with %d threads\n", __func__, NR_EVICT_WORKERS);
	}else{
		printf("Created %d bg_threads in EVICTION pool\n", NR_EVICT_WORKERS);
	}
#endif


	init_global_ds();

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


	//Set bitmap size inside the OS
	a = CROSS_BITMAP_SHIFT;
	set_cross_bitmap_shift(a);

	//print_affinity();

	/* register application specific handler */
	//reg_app_sig_handler();
    
#ifdef DISABLE_RWLOCK
    syscall(__DISABLE_RW_LOCK, 1);
#endif
}


void dest(){

	/*
	 * Reset the IO limits to normal
	 * Reset readahead 2MB limit
	 */
	char a;
	a = '0';
	set_read_limits(a);
	set_readahead_2mb_limit(a);
	debug_printf("DESTRUCTOR GETTING CALLED \n");

#ifdef ENABLE_OS_STATS
	fprintf(stderr, "PRINT_GLOBAL_STATS in %s\n", __func__);
	start_cross_trace(PRINT_GLOBAL_STATS, 0);
	start_cross_trace(CLEAR_GLOBAL_STATS, 0);
#endif

#ifdef DISABLE_RWLOCK
    syscall(__DISABLE_RW_LOCK, 0);
#endif

#ifdef ENABLE_LIB_STATS
	fprintf(stderr, "PRINT_GLOBAL_LIB_STATS in %s\n", __func__);
	fprintf(stdout, "Total nr_ra = %ld\n", total_nr_ra.load());
	fprintf(stdout, "Total nr_bytes_ra = %ld\n", total_bytes_ra.load());

#if 0
#if defined(PREDICTOR) && defined(ENABLE_PRED_STATS)
	print_seq_stats();
#endif
#endif

#endif

}


int evict_advise(int fd){
	//fprintf(stderr,"evicting inode \n");
	return real_posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);
}

bit_array_t *allocate_bitmap(struct thread_args *a) {

	bit_array_t *page_cache_state = NULL;

#if defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE) && !defined(PREDICTOR) && !defined(PER_INODE_BITMAP)
	page_cache_state = BitArrayCreate(NR_BITS_PREALLOC_PC_STATE);
	BitArrayClearAll(page_cache_state);
#elif defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE) && (defined(PREDICTOR) || defined(PER_INODE_BITMAP))
	page_cache_state = a->page_cache_state;
#else
	page_cache_state = NULL;
#endif
	return page_cache_state;
}


void release_bitmap(bit_array_t *page_cache_state) {

#if defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE) && !defined(PREDICTOR) && !defined(PER_INODE_BITMAP)
	debug_printf("%s: destroying the page cache\n", __func__);
	if(page_cache_state != NULL)
		BitArrayDestroy(page_cache_state);
#endif

}



void update_ra_stats_if_enabled(long nr_ra_done, long nr_bytes_ra_done) {
#ifdef ENABLE_LIB_STATS
	total_nr_ra += nr_ra_done;
	total_bytes_ra += nr_bytes_ra_done;

	debug_printf("%s:%ld: total_nr_ra=%ld, tot_bytes_ra=%ld\n", __func__, tid,
			nr_ra_done, nr_bytes_ra_done);
#endif
}




/*
 * Checks and updates the request before prefetching
 * based on the pc bitmap
 */
void check_pc_bitmap(void *arg){

	if(!arg)
		return;

	struct thread_args *a = (struct thread_args*)arg;

	bit_array_t *page_cache_state = NULL;

#if (defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE)) && (defined(PREDICTOR) || defined(PER_INODE_BITMAP))
	page_cache_state = a->page_cache_state;
#else
	page_cache_state = NULL;
#endif

	if(!page_cache_state){
		printf("No pcbitmap\n");
		return;
	}

	off_t start_pg = a->offset >> PAGE_SHIFT;
	off_t curr_pg = start_pg;
	off_t prefetch_limit_pg = a->prefetch_limit >> PAGE_SHIFT;

	if(prefetch_limit_pg == 0)
		prefetch_limit_pg = 1;

	//uinode_bitmap_lock(a->uinode);
	while(curr_pg < (start_pg + prefetch_limit_pg)){

		if(BitArrayTestBit(page_cache_state, curr_pg)){
			curr_pg += 1;
		}else{
			break;
		}
	}
	//uinode_bitmap_unlock(a->uinode);

	a->offset = curr_pg << PAGE_SHIFT;
	debug_printf("%s: changing offset from pg %ld to %ld fd:%d\n", __func__, start_pg, curr_pg, a->fd);
}


/*
 * Updates the offset for the next RA
 * Takes uinode lock
 * TODO: Make sure this works even without UINODE enabled
 */
long update_offset_pc_state(struct u_inode *uinode, bit_array_t *page_cache_state, long file_pos, off_t prefetch_size){

	off_t start_pg; //start from here in page_cache_state
	off_t zero_pg; //end of bitmap search
	off_t check_pg; //checking the bitmap a bit further
	off_t pg_diff = 0;
	off_t ulong_nr = 0;
	unsigned long *pc_array;

	if(!page_cache_state || !uinode){
		goto exit;
	}

	start_pg = file_pos >> PAGE_SHIFT;
	zero_pg = start_pg;
	check_pg = start_pg;

	if(start_pg > page_cache_state->numBits){
		printf("ERR: %s Using small bitmap; unable to support "
		"large file size %zu, bitmap bits %lu\n",
		__func__, uinode->file_size, page_cache_state->numBits);
		goto exit;
	}

#ifndef _PERF_OPT_EXTREME
	uinode_bitmap_lock(uinode);
#endif

	pc_array = page_cache_state->array;

#ifndef _PERF_OPT_EXTREME
	uinode_bitmap_unlock(uinode);
#endif

	while((check_pg << PAGE_SHIFT) < uinode->file_size) {

		ulong_nr = check_pg >> 6;
		if(pc_array[ulong_nr] == 0){
			break;
		}
		check_pg += 1 << 6;
	}
	pg_diff = check_pg - start_pg;

#ifndef _PERF_OPT_EXTREME
	uinode_bitmap_lock(uinode);
#endif

	uinode->prefetched_bytes += (pg_diff << PAGE_SHIFT);

	if(uinode->prefetched_bytes > uinode->file_size){
		uinode->fully_prefetched.store(true);
	}
	uinode_bitmap_unlock(uinode);
exit:
	return pg_diff;
}

//returns microsecond time difference
unsigned long usec_diff(struct timeval *a, struct timeval *b)
{
	unsigned long usec;

	usec = (b->tv_sec - a->tv_sec)*1000000;
	usec += b->tv_usec - a->tv_usec;
	return usec;
}


int shoud_stop_prefetch(struct thread_args *a, off_t file_pos) {

	/*
	 * Stop prefetching if the prefetch limit is reached
	 */
	if((file_pos - a->offset) >= a->prefetch_limit){
		debug_printf("%s: offset > prefetch_limit\n", __func__);
		goto stop_prefetch;
	}

	/*
	 * If the file is closed, dont do any prefetching
	 */
	if(is_file_closed(a->uinode, a->fd)){
		goto stop_prefetch;
	}

	return 0;

stop_prefetch:
	return -1;
}


int check_mem_and_stop(struct read_ra_req *ra, struct thread_args *a) {

#ifndef ENABLE_EVICTION_DISABLE
	return 0;
#endif
	/*
	 * if the memory is less NR_REMAINING
	 * the prefetcher stops
	 */
	if(ra->nr_free < NR_REMAINING)
	{
		debug_printf("%s: Not prefetching any further: fd=%d\n", __func__, a->fd);
		return -1;
	}
	return 0;
}

void debug_print_thread_args(struct thread_args *a, long tid) 
{
	printf("%s: TID:%ld: going to fetch from offset %ld for prefetch_limit "
		"%ld on file %d of prefetch limit file_size=%ld,"
                "rasize = %ld, stride = %ld bytes, ino=%d, inode=%p\n", __func__, tid,
                 a->offset, a->prefetch_limit, a->fd, a->file_size, a->prefetch_size,
                 a->stride, a->uinode->ino, a->uinode);
}


inline off_t update_prefetch_limit(struct thread_args *a) {

	off_t tot_prefetch = 0;
#ifdef _PERF_OPT
	if(a->prefetch_limit < a->file_size) {
		tot_prefetch = a->prefetch_limit;
	} else {
		tot_prefetch = a->file_size;
	}
	a->prefetch_limit = tot_prefetch;
#else
        tot_prefetch = a->file_size;
#endif
	return tot_prefetch;
}

void prefetcher_interval_th(void *arg) {

    int i = 0;
    long err = 0;
    off_t file_pos;
    struct read_ra_req ra;
    int states_num = 0;
    struct cache_state_node *cache_state = NULL;
    struct thread_args *a = (struct thread_args*)arg;
    struct cache_state_node* state_bitmaps[MAX_STATES];
    ra.data = NULL;
    off_t tot_prefetch = 0;
    long real_prefetch_size = 0;
    int len = 0;
    bit_array_t *temp_cache_state = NULL;

    tot_prefetch = update_prefetch_limit(a);
    file_pos = a->offset;

    // temp_cache_state = BitArrayCreate(NR_BITS_PREALLOC_PC_STATE);
    temp_cache_state = allocate_bitmap(a);
    // BitArrayClearAll(temp_cache_state);

    // printf("prefetcher_interval_th get called\n");
    /*
     * If the file is completely prefetched, dont prefetch
     */
    if(a->uinode && a->uinode->fully_prefetched.load()){
        printf("Aborting prefetch fd:%d since fully prefetched\n", a->fd);
        goto exit_prefetcher_th;
    }

    /*
     * If the file prefetch offset is almost towards the end of file
     * dont prefetch
     */
    if(((a->file_size >> PAGE_SHIFT) - (file_pos >> PAGE_SHIFT)) < 1){
        goto exit_prefetcher_th;
    }

    while (file_pos < tot_prefetch){
        if(shoud_stop_prefetch(a, file_pos))
            goto exit_prefetcher_th;

        real_prefetch_size = a->prefetch_limit;
        // printf("cache query, ino: %ld, offset: %ld, size: %ld, prefetch size: %ld\n", a->uinode->ino, a->offset, a->prefetch_limit, a->prefetch_size);

        states_num = cache_state_query(a->uinode, &a->uinode->cache_state_tree, file_pos, file_pos + a->prefetch_limit, state_bitmaps);
		
		// printf("query cache state done, ino: %ld, status_num: %d\n", a->uinode->ino, states_num);

		if (states_num <= 0) {
            // printf("no cache state found\n");
            goto exit_prefetcher_th;
        }

        for (i = 0; i < states_num; i++) {

            if (!state_bitmaps[i]->fully_prefetched) {
                cache_state = state_bitmaps[i];
                break;
            }
        }

        if (cache_state == NULL || cache_state->page_cache_state == NULL || real_prefetch_size <=0)
            goto exit_prefetcher_th;

        ra.data = temp_cache_state->array;

        // printf("readahead, ino: %d, start: %ld, size: %ld\n", a->uinode->ino, cache_state->it.start, real_prefetch_size);

        err = readahead_info_wrap(a->fd, file_pos, real_prefetch_size, &ra, a->uinode);
        // err = readahead_info_wrap(a->fd, cache_state->it.start, real_prefetch_size, &ra, a->uinode);

        // printf("readahead, ino: %d, start: %ld, end: %ld done, numbits: %ld \n", a->uinode->ino, cache_state->it.start, cache_state->it.last, cache_state->page_cache_state->numBits);

        for (int j = i, k=0; j < states_num;j++,k++) {

            cache_state = state_bitmaps[j];
            len = BITS_TO_CHARS(cache_state->page_cache_state->numBits)*sizeof(unsigned long);

            memcpy(cache_state->page_cache_state->array, temp_cache_state->array + (k*len), len);
            cache_state->fully_prefetched = 1;
        }

        file_pos += a->prefetch_size;
    }

    // BitArrayClearAll(temp_cache_state);
    // BitArraySetAll(cache_state->page_cache_state);

exit_prefetcher_th:
    release_bitmap(temp_cache_state);

#ifndef CONCURRENT_PREDICTOR
    free(arg);
#endif

#ifdef ENABLE_LIB_STATS
    update_ra_stats_if_enabled(nr_ra_done, nr_bytes_ra_done);
#endif
    // printf("Exiting %s\n", __func__);
    return;
}


/*
 * function run by the prefetcher thread
 */
#ifdef CONCURRENT_PREFETCH
void *prefetcher_th(void *arg) {
#else //THPOOL needs void 
void prefetcher_th(void *arg) {
#endif

	long tid = gettid();
	struct thread_args *a = (struct thread_args*)arg;
#ifdef ENABLE_LIB_STATS
	/*
	 * per_thread counter for nr of readaheads done
	 * and nr of bytes requested for readahead
	 */
	long nr_ra_done = 0;
	long nr_bytes_ra_done = 0;
#endif
	off_t file_pos; //actual file position where readahead will be done
	size_t readnow;
	struct read_ra_req ra;
	off_t start_pg; //start from here in page_cache_state
	off_t zero_pg; //end of bitmap search
	off_t check_pg; //checking the bitmap a bit further
	off_t pg_diff;
	long err;

	bit_array_t *page_cache_state = NULL;
        off_t tot_prefetch = 0; 

	/*update the prefetch limit */
	tot_prefetch = update_prefetch_limit(a);
#if 0
#ifdef _PERF_OPT
        if(a->prefetch_limit < a->file_size) {
                tot_prefetch = a->prefetch_limit;
        } else {
                tot_prefetch = a->file_size;
        }
        a->prefetch_limit = tot_prefetch;
#else
        tot_prefetch = a->file_size;
#endif
#endif

	/*
	 * If the file is completely prefetched, dont prefetch
	 */
	if(a->uinode && a->uinode->fully_prefetched.load()){
		//printf("Aborting prefetch fd:%d since fully prefetched\n", a->fd);
		goto exit_prefetcher_th;
	}

	/*
	 * Allocate page cache bitmap if you want to use it without predictor
	 */
	page_cache_state = allocate_bitmap(a);
	check_pc_bitmap(arg);
	file_pos = a->offset;

	/*
	 * If the file prefetch offset is almost towards the end of file
	 * dont prefetch
	 */
	if(((a->file_size >> PAGE_SHIFT) - (file_pos >> PAGE_SHIFT)) < 1){
		goto exit_prefetcher_th;
	}

	//debug_print_thread_args(a, tid);

#ifdef _PERF_OPT
	while (file_pos < tot_prefetch){
#else
	while (file_pos < a->file_size){
#endif

		if(shoud_stop_prefetch(a, file_pos))
			goto exit_prefetcher_th;
#ifdef MODIFIED_RA
		if(page_cache_state) {
			ra.data = page_cache_state->array;
		}else{
			ra.data = NULL;
		}

		if(!ra.data){
			printf("%s: no ra.data\n", __func__);
			goto exit_prefetcher_th;
		}

#ifndef _PERF_OPT_EXTREME
		uinode_bitmap_lock(a->uinode);
#endif

		err = readahead_info_wrap(a->fd, file_pos, a->prefetch_size, &ra, a->uinode);
		if(err < 0){
#ifndef _PERF_OPT_EXTREME
			uinode_bitmap_unlock(a->uinode);
#endif
			//printf("readahead_info: failed fd:%d TID:%ld err:%ld\n", a->fd, tid, err);
			goto exit_prefetcher_th;
		}
#ifdef ENABLE_LIB_STATS
		else{
			nr_ra_done += 1;
			nr_bytes_ra_done += a->prefetch_size;
			debug_printf("File Size %zu, Bytes prefetched %zu Inode %d\n",
				a->file_size, nr_bytes_ra_done, a->uinode->ino);
		}
#endif

#ifdef _PERF_OPT_EXTREME
		uinode_bitmap_unlock(a->uinode);
#endif

//#ifdef ENABLE_EVICTION
//		update_lru(a->uinode);
		//update_nr_free_pg(ra.nr_free);
//#endif

#ifdef READAHEAD_INFO_PC_STATE
		pg_diff = update_offset_pc_state(a->uinode, page_cache_state, file_pos, a->prefetch_size);
		debug_printf("%s: offset=%ld, pg_diff=%ld, fd=%d, ptr=%p, "
				"tot_bits=%ld, start_pg=%ld pages in cache %ld\n", __func__,
				file_pos, pg_diff, a->fd, ra.data,
				page_cache_state->numBits, start_pg, zero_pg);
		if(pg_diff == 0){
			//printf("ERR:%s, pg_diff==0 file_pos %zu\n", __func__, file_pos);
			//goto exit_prefetcher_th;
		}
		file_pos += pg_diff << PAGE_SHIFT;

#else //READAHEAD_INFO_PC_STATE
		file_pos += a->prefetch_size;
#endif //READAHEAD_INFO_PC_STATE


#ifdef ENABLE_EVICTION_DISABLE
		/*
		 * if the memory is less NR_REMAINING
		 * the prefetcher stops
		 */
		if(check_mem_and_stop(&ra, a))
			goto exit_prefetcher_th;
#endif


#else //MODIFIED_RA
		if(real_readahead(a->fd, file_pos, a->prefetch_size) < 0) {
			//printf("error while readahead: TID:%ld \n", tid);
			goto exit_prefetcher_th;
		}

#ifdef ENABLE_LIB_STATS
		else{
			nr_ra_done += 1;
			nr_bytes_ra_done += a->prefetch_size;
		}
#endif
		file_pos += a->prefetch_size;
#endif //MODIFIED_RA
	}

exit_prefetcher_th:
	release_bitmap(page_cache_state);

#ifndef CONCURRENT_PREDICTOR
	free(arg);
#endif

#ifdef ENABLE_LIB_STATS
	update_ra_stats_if_enabled(nr_ra_done, nr_bytes_ra_done);
#endif
	debug_printf("Exiting %s\n", __func__);
	return;
}


/*
 * Spawns or enqueues a request for file prefetching
 */
void inline prefetch_file_predictor(void *args){

    struct thread_args *a = (struct thread_args*)args;
    int fd = a->fd;
    file_predictor *fp = a->fp;

    struct thread_args *arg = NULL;
    off_t filesize;
    off_t stride;
    struct u_inode *uinode;

    filesize = fp->filesize;
    stride = fp->is_strided() * fp->portion_sz;
    stride = 0; //FIXME: BUGGY
    uinode = fp->uinode;
	threadpool_t *th_pool= NULL;

 #ifdef MAINTAIN_UINODE
    if(!uinode)
    	uinode = get_uinode(i_map, fd);
#endif

    debug_printf("%s: fd=%d, filesize = %ld, stride= %ld\n", __func__, fd, filesize, stride);

    if(filesize > MIN_FILE_SZ){
#ifdef CONCURRENT_PREDICTOR
	arg = (struct thread_args*)args;
#else
	arg = (struct thread_args *)malloc(sizeof(struct thread_args));
#endif
	if(!arg) {
		goto prefetch_file_exit;
	}
	arg->fd = fd;
	arg->file_size = filesize;
	arg->stride = stride;
#ifdef ENABLE_EVICTION_DISABLE
	set_thread_args_evict(arg);
#else
	arg->current_fd = 0;
	arg->last_fd = 0;
#endif

	arg->prefetch_size = get_prefetch_pages();
	arg->prefetch_limit = fp->prefetch_limit;
	arg->offset = fp->last_read_offset;
	fp->last_ra_offset = arg->offset + arg->prefetch_limit;

#if defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE) && defined(PREDICTOR) && !defined(PER_INODE_BITMAP)
	arg->page_cache_state = fp->page_cache_state;
#elif defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE) && defined(MAINTAIN_UINODE) && defined(PER_INODE_BITMAP)
	if(uinode){
		arg->page_cache_state = uinode->page_cache_state;
		if(arg->page_cache_state == NULL)
			printf("%s: pagecache NULL\n", __func__);
			arg->uinode = uinode;
	}else{
		printf("%s: No Uinode!! fd:%d \n", __func__, fd);
		arg->page_cache_state = NULL;
		arg->uinode = NULL;
	}
#else
	arg->page_cache_state = NULL;
#endif
  }
  else{
	debug_printf("%s: fd=%d is smaller than %d bytes\n", __func__, fd, MIN_FILE_SZ);
	goto prefetch_file_exit;
  }

#ifdef CONCURRENT_PREDICTOR
    prefetcher_th((void*)arg);
#elif defined(THPOOL_PREFETCH)

#ifdef INTERVAL_BITMAP
    th_pool = pool[g_next_queue % QUEUES];
    if (th_pool!= NULL && th_pool->count != th_pool->queue_size)
        threadpool_add(th_pool, prefetcher_interval_th, (void*)arg, 0);
#else
    threadpool_add(pool[g_next_queue % QUEUES], prefetcher_th, (void*)arg, 0);
#endif
    g_next_queue++;
#else
    prefetcher_th((void*)arg);
#endif

prefetch_file_exit:
		debug_printf("Exiting %s\n", __func__);
return;
}


	/*
	 * Spawns or enqueues a request for file prefetching
	 */
#ifndef PREDICTOR
void inline prefetch_file(int fd){
#else
//void inline prefetch_file(int fd, file_predictor *fp){
void inline prefetch_file(void *args){

	struct thread_args *a = (struct thread_args*)args;
	int fd = a->fd;
	file_predictor *fp = a->fp;
#endif

	struct thread_args *arg = NULL;
	off_t filesize;
	off_t stride;
	struct u_inode *uinode;

	/*
	 * When PREDICTOR is enabled, file sanity checks are not required
	 * This is because the file has already been screened for
	 * 1. Filesize
	 * 2. Type (regular file etc.)
	 * 3. Sequentiality
	 * This was done at record_open
	 */
#ifdef PREDICTOR
	filesize = fp->filesize;
	stride = fp->is_strided() * fp->portion_sz;
	stride = 0; //XXX: TEMP fix Need to change stride detection based on all access patterns
	if(stride < 0){
		printf("ERROR: %s: stride is %ld, should be > 0\n", __func__, stride);
		stride = 0;
	}
	uinode = fp->uinode;
#else
	filesize = reg_fd(fd);
	stride = 0;
#endif
	debug_printf("%s: fd=%d, filesize = %ld, stride= %ld\n", __func__, fd, filesize, stride);

#ifdef MAINTAIN_UINODE
	if(!uinode)
		uinode = get_uinode(i_map, fd);
#else
	uinode = NULL;
#endif

	if(filesize > MIN_FILE_SZ){
#ifdef CONCURRENT_PREDICTOR
		arg = (struct thread_args*)args;
#else
		arg = (struct thread_args *)malloc(sizeof(struct thread_args));
#endif
		if(!arg) {
			goto prefetch_file_exit;
		}
		arg->fd = fd;
		arg->file_size = filesize;
		arg->stride = stride;

#ifdef ENABLE_EVICTION_DISABLE
		set_thread_args_evict(arg);
#else
		arg->current_fd = 0;
		arg->last_fd = 0;
#endif

#ifdef FULL_PREFETCH
		//Allows the whole file to be prefetched at once
		arg->prefetch_size = filesize;
		debug_printf("%s: Doing a full prefetch %zu bytes\n", __func__, filesize);

#elif PREDICTOR
		arg->prefetch_size = NR_RA_PAGES * PAGESIZE;
		arg->prefetch_limit = fp->prefetch_limit;
		arg->offset = fp->last_read_offset;

		/*
		 * Update the last ra_offset
		 */
		fp->last_ra_offset = arg->offset + arg->prefetch_limit;
		//printf("%s: last_ra_offset=%ld\n", __func__, fp->last_ra_offset);
#else
		/*
		 * This is !PREDICTOR and !FULL_PREFETCH
		 * which means prefetch blindly NR_RA_PAGES at a time
		 */
		arg->offset = 0;
		arg->prefetch_size = filesize; //NR_RA_PAGES * PAGESIZE;
		arg->prefetch_limit = filesize;
#endif

#if defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE) && defined(PREDICTOR) && !defined(PER_INODE_BITMAP)
		arg->page_cache_state = fp->page_cache_state;
#elif defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE) && defined(MAINTAIN_UINODE) && defined(PER_INODE_BITMAP)
		if(uinode){

			arg->page_cache_state = uinode->page_cache_state;

			if(arg->page_cache_state == NULL)
				printf("%s: pagecache NULL\n", __func__);
			arg->uinode = uinode;
		}else{
			printf("%s: No Uinode!! fd:%d \n", __func__, fd);
			arg->page_cache_state = NULL;
			arg->uinode = NULL;
		}
#else
		arg->page_cache_state = NULL;
#endif
	}
	else{
		debug_printf("%s: fd=%d is smaller than %d bytes\n", __func__, fd, MIN_FILE_SZ);
		goto prefetch_file_exit;
	}

#ifdef CONCURRENT_PREDICTOR
	prefetcher_th((void*)arg);
#elif defined(CONCURRENT_PREFETCH)
	pthread_t thread;
	pthread_create(&thread, NULL, prefetcher_th, (void*)arg);
#elif defined(THPOOL_PREFETCH)
	threadpool_add(pool[g_next_queue % QUEUES], prefetcher_th, (void*)arg, 0);
	g_next_queue++;
#else
	prefetcher_th((void*)arg);
#endif

prefetch_file_exit:
	debug_printf("Exiting %s\n", __func__);
	return;
}


/*
 * Initialize a file_predictor object if
 * the file is > Min_FILE_SZ
 *
 * and init the bitmap inside the kernel
 */
void inline record_open(struct file_desc desc){

	int fd = desc.fd;
	off_t filesize = reg_fd(fd);
	struct timespec start, end;


	if(!filesize) {
		//printf("%s: Trying to predict fd:%d filesize=%ld\n", __func__, fd, filesize);
		return;
	}
	/*
	 * TODO BUG: This would only work for workloads that already have their
	 * files setup.
	 *
	 * In pure write workloads, the file could be very small initially
	 */
	if(filesize > MIN_FILE_SZ){

#ifdef PREDICTOR
		file_predictor *fp = new file_predictor(fd, filesize, desc.filename);
		if(!fp){
			printf("%s ERR: Could not allocate new file_predictor\n", __func__);
			goto exit;
		}

		fp->uinode = desc.uinode;
		debug_printf("%s: fd=%d, filesize=%ld, nr_portions=%ld, portion_sz=%ld\n",
				__func__, fp->fd, fp->filesize, fp->nr_portions, fp->portion_sz);

#ifndef _PERF_OPT_EXTREME
		std::lock_guard<std::mutex> guard(fp_mutex);
#endif
		fd_to_file_pred.insert({fd, fp});
		 /*
		 * When a file is opened.
		 * We give it a signin bonus. Prefetch a small portion of the start
		 * of the file
		 */
		if(fp->should_prefetch_now()){
			struct thread_args arg;
			arg.fd = fd;
			arg.fp = fp;
			//printf("%s: Doing a Bonus Prefetch\n", __func__);
			 prefetch_file_predictor(&arg);
		}
#endif

		/*
		 * This allocates the file's bitmap inside the kernel
		 * So no file cache data is lost from bitmap
		 * This is very important todo before any app reads happen
		 *
		 * If OS stats are enabled, the first RA has already happened
		 */
#if defined(MODIFIED_RA) && defined(READAHEAD_INFO_PC_STATE) && !defined(ENABLE_OS_STATS)
		debug_printf("%s: first READAHEAD: %ld\n", __func__, ptd.mytid);
		//clock_gettime(CLOCK_REALTIME, &start);

#if defined(PREFETCH_BOOST)
		struct read_ra_req ra;
		ra.data = NULL;
		readahead_info(fd, 0, 0, &ra);
		debug_printf("%s: DONE first READAHEAD: %ld in %lf microsec new\n", __func__, ptd.mytid, get_micro_sec(&start, &end));
#endif

#endif //defined(MODIFIED_RA) &&  defined(READAHEAD_INFO_PC_STATE)
	}
	else{
		debug_printf("%s: fd=%d filesize=%ld is smaller than %d bytes\n", __func__, fd, filesize, MIN_FILE_SZ);
	}

exit:
	debug_printf("Exiting %s\n", __func__);
	return;
}


/*
 * Does all the extra computing at open
 * for all the open functions
 */
void handle_open(struct file_desc desc){

#ifdef PREDICTOR
	g_min_fd = MIN_FD;
#endif

    // printf("%s: fd:%d, TID:%ld MIN FD %d\n", __func__, desc.fd,
			// gettid(), g_min_fd);


#ifndef MMAP_PREDICT
	if(desc.fd <= g_min_fd) {
		return;
	}
#endif

	// printf("%s: fd:%d, TID:%ld MIN FD %d\n", __func__, desc.fd,
			// gettid(), g_min_fd);

	desc.uinode = NULL;

#ifdef ENABLE_OS_STATS
	ptd.touchme = true; //enable per-thread filestats
	/*
	 * Allocates the bitmaps for this file
	 */
	struct read_ra_req ra;
	ra.data = NULL;
	readahead_info(desc.fd, 0, 0, &ra);
#endif


#ifdef ONLY_INTERCEPT
	return;
#endif

#ifdef MAINTAIN_UINODE
	if(add_fd_to_inode(i_map, desc.fd) < 0){
		printf("ERR:%s unable to add to uinode\n", __func__);
	}
	desc.uinode = get_uinode(i_map, desc.fd);
#endif

#if defined(PREDICTOR) || defined(READAHEAD_INFO_PC_STATE)
	record_open(desc);
#endif

	/*
	 * DONT compile library with both PREDICTOR and BLIND_PREFETCH
	 */
#ifdef BLIND_PREFETCH
	// Prefetch without predicting
	prefetch_file(desc.fd);
#endif
	debug_printf("Exiting %s\n", __func__);
}


#ifdef PREDICTOR
void update_file_predictor_and_prefetch(void *arg){

	struct thread_args *a = (struct thread_args*)arg;
	file_predictor *fp = NULL;

	if (a->fd < 1)
		return;

	try{
#ifndef _PERF_OPT_EXTREME
		/* We don't need a guard here. Do we? */
		std::lock_guard<std::mutex> guard(fp_mutex);
#endif
		fp = fd_to_file_pred.at(a->fd);
	}
	catch(const std::out_of_range &orr){
		debug_printf("ERR:%s fp Out of Range, fd:%d, tid:%ld\n", __func__, a->fd, gettid());
		return;
	}

#if 0 //def ENABLE_EVICTION
		if(fp->uinode != NULL) {
			set_uinode_access_time(fp->uinode);
		}
#endif
	if(fp){
		/* printf("%s: updating predictor fd:%d, offset:%ld\n", __func__, a->fd, a->offset);*/
		fp->predictor_update(a->offset, a->data_size);
		fp->nr_reads_done += 1L;

		if((fp->nr_reads_done % NR_PREDICT_SAMPLE_FREQ > 0))
			return;
#if 0
		/*update lru if file is fully prefetched*/
		if(fp->uinode->fully_prefetched.load()){
				update_lru(fp->uinode);
		}
#endif
		if(fp->should_prefetch_now()){
			a->fp = fp;
			prefetch_file_predictor((void*)arg);
		}
	}
}
#endif //PREDICTOR



void read_predictor(FILE *stream, size_t data_size, int file_fd, off_t file_offset) {

	size_t amount_read = 0;
	int fd = -1;
	off_t offset;

#ifdef ENABLE_EVICTION
	if(is_memory_low() ) {
		//printf("%s:%d mem dangerously low\n", __func__, __LINE__);
		return;
	}
#endif

	if(file_fd >= 3){
		fd = file_fd;
		offset = file_offset;
	}else if(stream){
		fd = fileno(stream);
		offset = ftell(stream);
	}

	if(fd < 3) {
		goto skip_read_predictor;
	}	
#ifdef ONLY_INTERCEPT
	goto skip_read_predictor;
#endif

#ifdef ENABLE_EVICTION_DISABLE
	set_curr_last_fd(fd);
#endif

#ifdef PREDICTOR
#ifdef CONCURRENT_PREDICTOR
	struct thread_args *arg;
	arg = (struct thread_args *)malloc(sizeof(struct thread_args));

	arg->fd = fd;
	arg->offset = offset;
	arg->data_size = data_size;
	update_file_predictor_and_prefetch(arg);
	free(arg);
#else
	struct thread_args arg;
	arg.fd = fd;
	arg.offset = offset;
	arg.data_size = data_size;
	update_file_predictor_and_prefetch(&arg);
#endif //CONCURRENT_PREDICTOR
#endif //PREDICTOR

skip_read_predictor:
	return;
}


void handle_file_close(int fd){

	if(fd <= g_min_fd) {
        	return;
        }

#ifdef MAINTAIN_UINODE
	int i_fd_cnt = handle_close(i_map, fd);
#ifdef ENABLE_EVICTION
	if(!i_fd_cnt){
		evict_advise(fd);
	}
#endif
#endif


#ifdef PREDICTOR
	//init_global_ds();
	file_predictor *fp;
	try{
		debug_printf("%s: found fd %d in fd_to_file_pred\n", __func__, fd);
#ifndef _PERF_OPT_EXTREME
		std::lock_guard<std::mutex> guard(fp_mutex);
#endif
		//fp = fd_to_file_pred.at(fd);
		//fd_to_file_pred.erase(fd);
	}
	catch(const std::out_of_range){
		debug_printf("%s: unable to find fd %d in fd_to_file_pred\n", __func__, fd);
		goto exit_handle_file_close;
	}

	if(fp){
		delete(fp);
	}
#endif

exit_handle_file_close:
	debug_printf("Exiting %s\n", __func__);
	return;
}


	//////////////////////////////////////////////////////////
	//Intercepted Functions
	//////////////////////////////////////////////////////////

#ifdef ENABLE_MPI
int MPI_File_read_at(MPI_File fh, MPI_Offset offset, void *buf,
		int count, MPI_Datatype datatype, MPI_Status * status) {

	printf("%s:%d \n", __func__, __LINE__);
	return 0;
}

int MPI_File_read_at_all_end(MPI_File fh, void *buf, MPI_Status *status)
{
	printf("%s:%d \n", __func__, __LINE__);
	return real_MPI_File_read_at_all_end(fh, buf, status);
}

int MPI_File_read_at_all_begin(MPI_File fh, void *buf, MPI_Status *status)
{
	printf("%s:%d \n", __func__, __LINE__);
	return real_MPI_File_read_at_all_begin(fh, buf, status);
}

int MPI_File_open(MPI_Comm comm, const char *filename, int amode, MPI_Info info, MPI_File *fh) {

	int ret = 0;
	int fd = real_open(filename, amode, 0);
	ret = real_MPI_File_open(comm, filename, amode, info, fh);
	printf("%s:%d, FD %d\n", __func__, __LINE__, fd);
	mpi_hadle_fd[fh] = fd;

	struct file_desc desc;
	desc.fd = fd;
	handle_open(desc);

	return ret;
}
#endif

//OPEN SYSCALLS
int openat(int dirfd, const char *pathname, int flags, ...){

	int fd;
	struct file_desc desc;
	debug_printf("Entering %s\n", pathname);

	if(flags & O_CREAT){
		va_list valist;
		va_start(valist, flags);
		mode_t mode = va_arg(valist, mode_t);
		va_end(valist);
		fd = real_openat(dirfd, pathname, flags, mode);
	}
	else{
		fd = real_openat(dirfd, pathname, flags, 0);
	}

	if(fd < 0)
		goto exit;

	desc.fd = fd;
	desc.filename = pathname;

	debug_printf("%s: file %s fd:%d\n", __func__,  pathname, fd);

	handle_open(desc);

exit:
	debug_printf("Exiting %s\n", __func__);
	return fd;
}


int open64(const char *pathname, int flags, ...){

	int fd;
	struct file_desc desc;


	debug_printf("%s: file %s: fd=%d\n", __func__, pathname, fd);

	if(flags & O_CREAT){
		va_list valist;
		va_start(valist, flags);
		mode_t mode = va_arg(valist, mode_t);
		va_end(valist);
		fd = real_open(pathname, flags, mode);
	}
	else{
		fd = real_open(pathname, flags, 0);
	}

	desc.fd = fd;
	desc.filename = pathname;

	debug_printf("%s: file %s fd:%d\n", __func__,  pathname, fd);

	handle_open(desc);

exit:
	debug_printf("Exiting %s\n", __func__);
	return fd;
}


int open(const char *pathname, int flags, ...){

	int fd;
	struct file_desc desc;

	// printf("%s: file %s\n", __func__,  pathname);

	if(flags & O_CREAT){
		va_list valist;
		va_start(valist, flags);
		mode_t mode = va_arg(valist, mode_t);
		va_end(valist);
		fd = real_open(pathname, flags, mode);
	}
	else{
		fd = real_open(pathname, flags, 0);
	}

	if(fd < 0)
		goto exit;

	desc.fd = fd;
	desc.filename = pathname;
	// printf("%s: file %s fd:%d\n", __func__,  pathname, fd);

	handle_open(desc);

exit:
	debug_printf("Exiting %s\n", __func__);
	return fd;
}

#ifdef MMAP_PREDICT
void mmap_prefetcher_th(void *arg) {
    long tid = gettid();
    struct thread_args *a = (struct thread_args*)arg;

    off_t file_pos = 0;
    bit_array_t *page_cache_state = NULL;
    bit_array_t *predictor_state = NULL;
    struct read_ra_req ra;
    off_t pg_diff;
    off_t start_pg;
    off_t zero_pg;
    long err;
    int sequential = 0;

    file_pos = a->offset;
    page_cache_state = BitArrayCreate(NR_BITS_PREALLOC_PC_STATE);
    BitArrayClearAll(page_cache_state);
    a->page_cache_state = page_cache_state;
    check_pc_bitmap(arg);

    a->prefetch_size = NR_RA_PAGES * PAGESIZE;

    while (file_pos < a->prefetch_limit){

        if(page_cache_state) {
            ra.data = page_cache_state->array;
        }else{
            ra.data = NULL;
        }

        // ra.get_full_bitmap = true;

        if(!ra.data){
            printf("%s: no ra.data\n", __func__);
            goto exit_prefetcher_th;
        }


        //struct timeval start, end;
        //gettimeofday(&start, NULL);
        // uinode_bitmap_lock(a->uinode);

        // printf("readahead, filepos: %ld, size: %ld\n", file_pos, a->prefetch_size);
        err = readahead_info(a->fd, file_pos, a->prefetch_size, &ra);
        // err = readahead(a->fd, file_pos, a->prefetch_size);
        // printf("readahead11111\n");

#if 0
		if(err < -10){
            uinode_bitmap_unlock(a->uinode);
            goto exit_prefetcher_th;
        }
        else if(err < 0){
            uinode_bitmap_unlock(a->uinode);
            printf("readahead_info: failed fd:%d TID:%ld err:%ld\n", a->fd, tid, err);
            goto exit_prefetcher_th;
        }
        uinode_bitmap_unlock(a->uinode);
#endif


#if 0
        file_pos += a->prefetch_size;
        
        sequential +=1;
        sequential = (std::max<int>)(DEFNSEQ, sequential);
        a->prefetch_size = (10 * sequential) * NR_RA_PAGES * PAGESIZE;


        printf("get offset\n");
#endif
        pg_diff = update_offset_pc_state(a->uinode, page_cache_state, file_pos, a->prefetch_size);
        // printf("%s: offset=%ld, pg_diff=%ld, fd=%d, ptr=%p, "
                // "tot_bits=%ld, start_pg=%ld pages in cache %ld\n", __func__,
                // file_pos, pg_diff, a->fd, ra.data,
                // page_cache_state->numBits, start_pg, zero_pg);

        if(pg_diff == 0){
            printf("ERR:%s, pg_diff==0 file_pos %zu\n", __func__, file_pos);
            goto exit_prefetcher_th;
        }

        file_pos += pg_diff << PAGE_SHIFT;

        off_t start_pg = file_pos >> PAGE_SHIFT;
        // off_t start_pg = 0;
        off_t curr_pg = start_pg;
        off_t next_pg = curr_pg + 1;
        off_t prefetch_limit_pg = (a->file_size/16) >> PAGE_SHIFT;
        // off_t prefetch_limit_pg = 512 >> PAGE_SHIFT;
        sequential = DEFSEQ;

        if(prefetch_limit_pg == 0)
            prefetch_limit_pg = 1;

#if 1
        //uinode_bitmap_lock(a->uinode);
        while(next_pg < (start_pg + prefetch_limit_pg)){

            if(BitArrayTestBit(page_cache_state, curr_pg)){
                sequential -= 1;
            }

            curr_pg += 1;
            next_pg += 1;
        }
#endif
        sequential = (std::max<int>)(DEFNSEQ, sequential);
        // printf("sequential: %d\n", sequential);
        if (sequential > 0) {
            a->prefetch_size = (10 * sequential) * NR_RA_PAGES * PAGESIZE;
        } else {
            a->prefetch_size = NR_RA_PAGES * PAGESIZE;
		}
		// usleep(100);
	}
exit_prefetcher_th:
	release_bitmap(page_cache_state);
	return;
}


void mmap_predictor_prefetch(int file_fd, off_t file_offset, size_t length) {

    struct thread_args *arg = NULL;
    file_predictor *fp = NULL;

    arg = (struct thread_args *)malloc(sizeof(struct thread_args));
    arg->fd = file_fd;
    arg->offset = file_offset;
    arg->prefetch_limit= file_offset + length;


#ifdef PREDICTOR
    try{
        /* We don't need a guard here. Do we? */
        std::lock_guard<std::mutex> guard(fp_mutex);
        fp = fd_to_file_pred.at(arg->fd);
    }
    catch(const std::out_of_range &orr){
        debug_printf("ERR:%s fp Out of Range, fd:%d, tid:%ld\n", __func__, a->fd, gettid());
        return;
    }
#endif

    if(fp){
        arg->fp = fp;
    }
    arg->file_size = fp->filesize;
    arg->uinode = fp->uinode;
    if(!arg->uinode)
        arg->uinode = get_uinode(i_map, file_fd);

    threadpool_add(pool[g_next_queue % QUEUES], mmap_prefetcher_th, (void*)arg, 0);
    g_next_queue++;

}

void *mmap(void *addr, size_t length, int prot, int flags,
        int fd, off_t offset) {
    void* ret_ptr = NULL;
    ret_ptr = real_mmap(addr, length, prot, flags, fd, offset);

    mmap_predictor_prefetch(fd, offset, length);

    return ret_ptr;
}
#endif

FILE *fopen(const char *filename, const char *mode){

	int fd;
	FILE *ret;
	struct file_desc desc;

	debug_printf("%s: file %s\n", __func__,  filename);
	ret = real_fopen(filename, mode);
	if(!ret)
		return ret;

	fd = fileno(ret);
	desc.fd = fd;
	desc.filename = filename;

	debug_printf("%s: file %s fd:%d\n", __func__,  filename, fd);

	handle_open(desc);

exit:
	debug_printf("Exiting %s\n", __func__);
	return ret;
}


//READ SYSCALLS
ssize_t pread64(int fd, void *data, size_t size, off_t offset){
	return pread(fd, data, size, offset);
}


ssize_t pread(int fd, void *data, size_t size, off_t offset){

	ssize_t amount_read;

	debug_printf("%s: fd=%d, offset=%ld, size=%ld\n", __func__, fd, offset, size);

	read_predictor(NULL, size, fd, offset);

skip_predictor:
	amount_read = real_pread(fd, data, size, offset);

exit_pread:
	return amount_read;
}


/*Several applications use fgets*/

char *fgets( char *str, int num, FILE *stream ) {

	debug_printf( "Start %s\n", __func__);

	read_predictor(stream, num, 0, 0);

	return real_fgets(str, num, stream);
}


size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream){


	size_t amount_read = 0;

	debug_printf("%s: TID:%ld\n", __func__, gettid());

	read_predictor(stream, size*nmemb, 0, 0);

skip_predictor:
	amount_read = real_fread(ptr, size, nmemb, stream);

	exit_fread:
	debug_printf( "Exiting %s\n", __func__);
	return amount_read;
}


//CLOSE SYSCALLS

int fclose(FILE *stream){

	int fd = fileno(stream);

	debug_printf( "Entering %s\n", __func__);

#ifdef ONLY_INTERCEPT
	goto exit_fclose;
#endif

	handle_file_close(fd);

exit_fclose:
	debug_printf( "Exiting %s\n", __func__);
	return real_fclose(stream);
}


int close(int fd){

	debug_printf("Entering %s\n", __func__);

#ifdef ONLY_INTERCEPT
	goto exit_close;
#endif

	handle_file_close(fd);
exit_close:
	debug_printf( "Exiting %s\n", __func__);
	return real_close(fd);
}


ssize_t readahead(int fd, off_t offset, size_t count){

	ssize_t ret = 0;

	debug_printf("Entering %s\n", __func__);
#ifdef DISABLE_APP_READAHEADS
	goto exit_readahead;
#endif

#ifdef ENABLE_LIB_STATS
	total_nr_ra += 1;
	total_bytes_ra += count;
#endif

	ret = real_readahead(fd, offset, count);

	exit_readahead:
	debug_printf( "Exiting %s\n", __func__);
	return ret;
}


int posix_fadvise64(int fd, off_t offset, off_t len, int advice){

	int ret = -1;
	debug_printf("%s: called for %d, ADV=%d\n", __func__, fd, advice);
	ret = posix_fadvise(fd, offset, len, advice);
	debug_printf( "Exiting %s\n", __func__);
	return ret;
}


int posix_fadvise(int fd, off_t offset, off_t len, int advice){

	int ret = 0;
	debug_printf("%s: called for %d, ADV=%d\n", __func__, fd, advice);

	//goto listen_to_app;

#ifdef ENABLE_EVICTION
	if(is_memory_danger_low() ) {
		//printf("%s:%d mem dangerously low\n", __func__, __LINE__);
		goto listen_to_app;
	}
#endif

#ifdef DISABLE_FADV_RANDOM
	if(advice == POSIX_FADV_RANDOM)
		goto exit_fadvise;
#endif

#ifdef DISABLE_FADV_DONTNEED
	if(advice == POSIX_FADV_DONTNEED)
		goto exit_fadvise;
#endif

listen_to_app:
	ret = real_posix_fadvise(fd, offset, len, advice);

exit_fadvise:
	debug_printf( "Exiting %s\n", __func__);
	return ret;
}

#if 0
int madvise(void *addr, size_t length, int advice){
	int ret = 0;

	debug_printf("%s: called ADV=%d\n", __func__, advice);

#ifdef DISABLE_MADV_DONTNEED
	if(advice == MADV_DONTNEED)
		goto exit;
#endif

	ret = real_madvise(addr, length, advice);
exit:
	debug_printf( "Exiting %s\n", __func__);
	return ret;
}
#endif



#ifdef ENABLE_EVICTION_OLD
int set_thread_args_evict(struct thread_args *arg) {
	arg->current_fd = ptd.current_fd;
	arg->last_fd = ptd.last_fd;
	return 0;
}

int set_curr_last_fd(int fd){
	/*
	 * The first time ptd is accessed by a thread(clone)
	 * it calls its constructor.
	 */
	if(ptd.last_fd == 0){
		ptd.last_fd = fd;
		ptd.current_fd = fd;
	}
	else{
		/*
		 * Update the current and last fd
		 * for this thread each time it reads
		 *
		 * Heuristic: If the thread moves on to
		 * another fd, it is likely done with last_fd
		 * ie. in an event of memory pressure, cleanup that
		 * file from memory
		 */
		ptd.last_fd = ptd.current_fd;
		ptd.current_fd = fd;
	}
	return 0;
}

int perform_eviction(struct thread_args *arg){
	/*
	 * when crunched with memory, remove cache pages for
	 * last fd. Since the thread has moved on from it.
	 */
	if(arg->current_fd != arg->last_fd){
		debug_printf("%s: Evicting fd:%d\n", __func__, arg->last_fd);
		evict_advise(arg->last_fd);
	}

	return 0;
}
#endif
