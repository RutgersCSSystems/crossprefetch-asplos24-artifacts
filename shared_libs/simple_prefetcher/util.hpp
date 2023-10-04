#ifndef _UTIL_HPP
#define _UTIL_HPP

#define PAGESIZE 4096L //Page size
#define PAGE_SHIFT 12

#define KB 1024L
#define MB 1024L * KB
#define GB 1024L * MB

#define likely(x)      __builtin_expect(!!(x), 1)
#define unlikely(x)    __builtin_expect(!!(x), 0)


/*
 * Setting 0 -> vanilla limits on reads and readaheads
 * Setting 1 -> no limits on reads and readaheads
 * Note: linux 5.14 doesnt prefetch more than 256 pg in vanilla
 */
#define UNBOUNDED_PROCFS_FILE "/proc/unbounded_read"
#define RA_2MB_LIMIT_PROCFS_FILE "/proc/disable_2mb_limit"
#define CROSS_BITMAP_SHIFT_FILE "/proc/cross_bitmap_shift"

#ifdef DEBUG
#define debug_printf(...) printf(__VA_ARGS__ )
//#define debug_print(...) fprintf( stderr, __VA_ARGS__ )
#else
#define debug_printf(...) do{ }while(0)
#endif

#define gettid() syscall(SYS_gettid)

//NR of pages to prefetch in each cycle
#ifndef NR_RA_PAGES
//#warning NR_RA_PAGES not defined. Assuming 40 pages
#define NR_RA_PAGES 40
#endif


/*
 * Used by predictor to prefetch if
 * the read is almost getting to last RA position
 */
#ifndef NR_EARLY_FETCH_PAGES
#define NR_EARLY_FETCH_PAGES NR_RA_PAGES*2
#endif

/* 
 * Nr of pages to read while
 * doing readahead using pread_ra
 */
#ifndef NR_PREADRA_READ
#define NR_PREADRA_READ 1
#endif


//Nr of worker threads
#ifndef NR_WORKERS
//#warning NR_WORKERS not defined. Assuming 2 workers
#define NR_WORKERS 2
#endif

#ifndef NR_NQUEUES
//#warning NR_NQUEUES not defined. Assuming 32 workers
#define NR_NQUEUES 32
#endif

#ifndef NR_QSIZE
//#warning NR_QSIZE not defined. Assuming 2000 workers
#define NR_QSIZE 2000
#endif


//NR of eviction workers
#ifndef NR_EVICT_WORKERS
//#warning NR_EVICT_WORKERS not defined. Assuming 1 workers
#define NR_EVICT_WORKERS 1
#endif


// Files smaller than this should
// not be considered for prefetching
#ifndef MIN_FILE_SZ
#define MIN_FILE_SZ 1 * MB
#endif


// Number of pages which constitute
// a portion of file to consider while prefetching
// Will be used to define the bitvector
#ifndef PORTION_PAGES
#define PORTION_PAGES 32
#endif


/*
 * Number of adjacent bits in the bitarray
 * to check to determine sequentiality
 * Note: Adjacent check will test bits at both ends
 * of the request
 * Note: Each bit in the bitarray represents PORTION_PAGES pages
 */
#ifndef NR_ADJACENT_CHECK
#define NR_ADJACENT_CHECK 1
#endif


/*
 * When prefetching, check the number of pages left
 * in the node. If it is less than NR_REMAINING
 * stop prefetching for this file
 */
#ifndef NR_REMAINING
#define NR_REMAINING ((700 * MB)/PAGESIZE)
#endif


/*
 * Minimum available memory after which we should
 * start doing eviction
 */
#ifndef MEM_LOW_WATERMARK
//#define MEM_LOW_WATERMARK (240L * GB)
#define MEM_LOW_WATERMARK (10L * GB)
#endif

/*
 * Minimum available memory after which we should
 * start doing eviction
 */
#ifndef MEM_DANGER_WATERMARK
#define MEM_DANGER_WATERMARK (4L * GB)
#endif


/*
 * Minimum available memory after which we should
 * stop doing eviction
 */
#ifndef MEM_HIGH_WATERMARK
#define MEM_HIGH_WATERMARK (10L * GB)
#endif



/*
 * Minimum available memory after which we should
 * start doing eviction
 */
#ifndef MEM_OTHER_NUMA_NODE
#define MEM_OTHER_NUMA_NODE (129L * GB)
#endif


/*
 * bitshift for kernel bitmaps
 */
#ifndef CROSS_BITMAP_SHIFT
//#warning CROSS_BITMAP_SHIFT not defined. Assuming 24
#ifdef MMAP_PREDICT
#define CROSS_BITMAP_SHIFT 39
#else
#define CROSS_BITMAP_SHIFT 33
#endif
#endif

/*
 * Inside the kernel, the Page cache bitmap 
 * is preallocated to this size. So we have 
 * todo the same.
 */
#ifndef NR_BITS_PREALLOC_PC_STATE
#define NR_BITS_PREALLOC_PC_STATE  (1UL << (CROSS_BITMAP_SHIFT - PAGE_SHIFT))
#endif


/*
 * This parameter specifes the number of bits will be checked in
 * the bitmap before saying that no more pages were fetched.
 */
#ifndef NR_BITS_BEFORE_GIVEUP
#define NR_BITS_BEFORE_GIVEUP std::min(NR_RA_PAGES, 64)
#endif


/*
 * This is the number of reads we should let happen
 * before checking if the fd is being read in changing patterns
 */
#ifndef NR_READS_BEFORE_STATS
#define NR_READS_BEFORE_STATS 10
#endif


/*
 * Maximum number of fds a file
 * can possibly open for uinode bookeeping
 * uinode fdlist
 */
#ifndef MAX_FD_PER_INODE
#define MAX_FD_PER_INODE 64
#endif


/*
 * Number of files to handle in i_map
 * for uinodes
 */
#ifndef MAXFILES
#define MAXFILES 500000
#endif


/*
 * Time eviction thread will sleep
 * for in seconds
 */
#ifndef SLEEP_TIME
#define SLEEP_TIME 1
#endif

#define FILE_EVICTED 100

/*
 * Predictor frequency. Note, this should not be 0
  */
#ifndef NR_PREDICT_SAMPLE_FREQ
#define NR_PREDICT_SAMPLE_FREQ 1
#endif

/*
 * pread_ra read_ra_req struct
 * this struct is used to send and receive info from kernel about
 * the current readahead with the typical read
 */
struct read_ra_req{

	/*These are to be filled while sending the pread_ra req
	 * position for readahead and nr_bytes for readahead
	 */
	loff_t ra_pos;
	size_t ra_count; //in bytes

	/* these are values returned by the OS
	 * for the above given readahead request 
	 * 1. how many pages were already present
	 * 2. For how many pages, bio was submitted
	 */
	unsigned long nr_present;
	unsigned long bio_req_nr;

	/* this is used to return the number of cache usage in bytes
	 * used by this application.
	 * enable CONFIG_CACHE_LIMITING(linux) and ENABLE_CACHE_LIMITING(library)
	 * to get a non-zero value
	 */
	long total_cache_usage; //total cache usage in bytes (OS return)
	bool full_file_ra; //populated by app true if pread_ra is being done to get full file
	long cache_limit; //populated by the app, desired cache_limit

	unsigned long nr_free; //nr pages that are free in mem

    // bool get_full_bitmap;

	/*
	 * The following are populated by the kernel
	 * and returned to user space
	 */
	unsigned long *data;  //page bitmap for readahead file
	unsigned long nr_relevant_ulongs; //number of bits relevant for the file


};

#if 0
//Time in microseconds
double get_micro_sec(struct timespec *start, struct timespec *end)
{
    return ((end->tv_sec - start->tv_sec)*1000000000 + \
                end->tv_nsec - start->tv_nsec)/1000; //Time in microseconds
}
#endif

#endif
