#ifndef _UTIL_HPP
#define _UTIL_HPP

#define PG_SZ 4096L
#define PAGESHIFT 12L
#define BYTESHIFT 3L

#ifdef DEBUG
#define debug_printf(...) printf(__VA_ARGS__ )
//#define debug_print(...) fprintf( stderr, __VA_ARGS__ )
#else
#define debug_printf(...) do{ }while(0)
#endif

#ifndef NR_THREADS //Nr of BG readahead threads
#define NR_THREADS 1
#endif


#ifndef MINCORE_THREADS
#define MINCORE_THREADS 4
#endif

/*
 * NR of pages to skip after each read
 */
#ifndef NR_STRIDE
#define NR_STRIDE 50
#endif

/*
 * Size of file in GB
 */
#ifdef FILESZ
#define FILESIZE (FILESZ * 1024L * 1024L * 1024L)
#else
#define FILESIZE (10L * 1024L * 1024L * 1024L)
#endif

//Number of pages to read in one pread syscall
#ifndef NR_PAGES_READ
#define NR_PAGES_READ 10
#endif

#ifndef NR_RA_PAGES
#define NR_RA_PAGES 256L
#endif

#define FILEBASE "bigfakefile"

#define gettid() syscall(SYS_gettid)

#define __READAHEAD_INFO 451
#define __NR_start_crosslayer 448

#define ENABLE_FILE_STATS 1
#define DISABLE_FILE_STATS 2
#define CLEAR_GLOBAL_STATS 3
#define PRINT_GLOBAL_STATS 4

/*
 * bitshift for kernel bitmaps
 */
#ifndef CROSS_BITMAP_SHIFT
//#warning CROSS_BITMAP_SHIFT not defined. Assuming 24
#define CROSS_BITMAP_SHIFT 37
#endif

/*
 * Setting 0 -> vanilla limits on reads and readaheads
 * Setting 1 -> no limits on reads and readaheads
 * Note: linux 5.14 doesnt prefetch more than 256 pg in vanilla
 */
#define UNBOUNDED_PROCFS_FILE "/proc/unbounded_read"
#define RA_2MB_LIMIT_PROCFS_FILE "/proc/disable_2mb_limit"
#define CROSS_BITMAP_SHIFT_FILE "/proc/cross_bitmap_shift"

#define FILENAMEMAX 1024


/*
 * Set unbounded_read to 0 or 1
 */
void set_read_limits(char a){

	int fd = open(UNBOUNDED_PROCFS_FILE, O_RDWR, 0);
	int bytes = pwrite(fd, &a, sizeof(char), 0);
	printf("%s: Setting Read Limits to %c %d\n", __func__, a, bytes);

	close(fd);
	printf("Exiting %s\n", __func__);
}

/*
 * Set disable_2mb_limits to 0 or 1
 */
void set_readahead_2mb_limit(char a){
	//printf("%s: Setting Readahead 2MB Limit to %c\n", __func__, a);
	int fd = open(RA_2MB_LIMIT_PROCFS_FILE, O_RDWR, 0);
	int bytes =  pwrite(fd, &a, sizeof(char), 0);
	printf("%s: Setting Setting Readahead 2MB Limit to %c %d\n", __func__, a, bytes);
	close(fd);
	printf("Exiting %s\n", __func__);
}

/*
 * Set cross_bitmap_shift
 */
void set_cross_bitmap_shift(char a){
	int fd = open(CROSS_BITMAP_SHIFT_FILE, O_RDWR, 0);
	int bytes = pwrite(fd, &a, sizeof(char), 0);
	printf("%s: Setting cross_bitmap_shift to %c %d\n", __func__, a, bytes);
	close(fd);
	printf("Exiting %s\n", __func__);
}


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


	/*
	 * The following are populated by the kernel
	 * and returned to user space
	 */
	unsigned long *data;  //page bitmap for readahead file
	unsigned long nr_relevant_ulongs; //number of bits relevant for the file
};


long readahead_info(int fd, loff_t offset, size_t count, struct read_ra_req *ra_req)
{
        return syscall(__READAHEAD_INFO, fd, offset, count, ra_req);
}


long start_cross_trace(int flag, int val)
{
        return syscall(__NR_start_crosslayer, flag, val);
}


void folder_name(char *buffer, int nr_files){
        char *nr_threads;
        const char* str1 = "./threads_";

        if (asprintf(&nr_threads, "%d", nr_files) == -1) {
                perror("asprintf");
        } else {
                strcat(strcpy(buffer, str1), nr_threads);
                free(nr_threads);
        }
}
/*
 * Given the mpi rank and the initial string, this
 * function returns the filename per mpi rank
 */
void file_name(int rank, char *buffer, int nr_files){
        char *num;
        char *nr_threads;

        const char* str1 = "./threads_";

        if (asprintf(&num, "%d", rank) == -1 || asprintf(&nr_threads, "%d", nr_files) == -1) {
                perror("asprintf");
        } else {
                strcat(strcpy(buffer, str1), nr_threads);
                strcat(buffer, "/");
                strcat(buffer, FILEBASE);
                strcat(buffer, num);
                strcat(buffer, ".txt");
                free(num);
                free(nr_threads);
        }
}


//returns microsecond time difference
unsigned long usec_diff(struct timeval *a, struct timeval *b)
{
    unsigned long usec;

    usec = (b->tv_sec - a->tv_sec)*1000000;
    usec += b->tv_usec - a->tv_usec;
    return usec;
}


//Returns the aggregate throughput experienced in MB/sec
double throughput(struct timeval *a, struct timeval *b, unsigned long filesize){
        
        double throughput = 0.0;
        

        //TODO Complete the algorithm

        return throughput;
}

#endif
