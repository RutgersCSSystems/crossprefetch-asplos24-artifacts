#define _LARGEFILE64_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdbool.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/syscall.h>
#include <sys/time.h>

#define __NR_start_crosslayer 448

#define NR_PAGES_READ 10
#define NR_PAGES_RA 20
#define PG_SZ 4096

#define ENABLE_FILE_STATS 1
#define DISABLE_FILE_STATS 2
#define RESET_GLOBAL_STATS 3
#define PRINT_GLOBAL_STATS 4
#define CACHE_USAGE_CONS 5
#define CACHE_USAGE_DEST 6
#define CACHE_USAGE_RET 7
#define WALK_PAGECACHE 9

#ifdef FILESZ
#define FILESIZE (FILESZ * 1024L * 1024L * 1024L)
#else
#define FILESIZE (10L * 1024L * 1024L * 1024L)
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
	size_t ra_count;

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
	long total_cache;
};

void set_crosslayer(){
	syscall(__NR_start_crosslayer, ENABLE_FILE_STATS, 0);
}

void reset_global_stats(){
	syscall(__NR_start_crosslayer, RESET_GLOBAL_STATS, 0);
}

void print_global_stats(){
	syscall(__NR_start_crosslayer, PRINT_GLOBAL_STATS, 0);
}

/*enable cache accounting for calling threads/procs
 * implemented in linux 5.14 (CONFIG_CACHE_LIMITING)
 */
void enable_cache_limit(){
    syscall(__NR_start_crosslayer, CACHE_USAGE_CONS, 0);
}

/*disable cache accounting for calling threads/procs
 * implemented in linux 5.14 (CONFIG_CACHE_LIMITING)
 */
void disable_cache_limit(){
    syscall(__NR_start_crosslayer, CACHE_USAGE_DEST, 0);
}

/*
 * walks the page cache for this particular fd
 * and returns the number of pages allocated and
 * populated
 */
void check_page_cache(int fd){
    syscall(__NR_start_crosslayer, WALK_PAGECACHE, fd);
}

int main() {

	//set_crosslayer();
	//reset_global_stats();
	//
	enable_cache_limit();

	int fd;

	long nr_read = 0; //controls the readaheads

	long size = FILESIZE; //10GB

	long buff_sz = (PG_SZ * NR_PAGES_READ);

	char *buffer = (char*) malloc(buff_sz * sizeof(char));
	fd = open("DATA/bigfakefile.txt", O_RDWR);
	if (fd == -1){
		printf("\nFile Open Unsuccessful\n");
		exit (0);;
	}

	check_page_cache(fd);

#ifdef ONLYAPP
	//Disable OS pred
	posix_fadvise(fd, 0, 0, POSIX_FADV_RANDOM);
#endif

	off_t chunk = 0;
	lseek64(fd, 0, SEEK_SET);
	bool prefetch = false;
    struct read_ra_req ra_req;

	while ( chunk < size ){

		size_t readnow;

#ifdef ONLYOS //No PRediction from app
		if(prefetch){
			//readnow = pread(fd, ((char *)buffer), PG_SZ*NR_PAGES_READ, chunk);
			ra_req.ra_pos = 0;
			ra_req.ra_count = FILESIZE;
			readnow = syscall(449, fd, ((char *)buffer), 
					PG_SZ*NR_PAGES_READ, chunk, &ra_req);
			prefetch = false;
		}
		else
			readnow = pread(fd, ((char *)buffer), PG_SZ*NR_PAGES_READ, chunk);

		
#elif READRA //Read+Ra from App
		if(nr_read >= NR_PAGES_RA){
			ra_req.ra_pos = 0;
			ra_req.ra_count = NR_PAGES_RA*PG_SZ;
			readnow = syscall(449, fd, ((char *)buffer), 
					PG_SZ*NR_PAGES_READ, chunk, &ra_req);
			printf("total_cache = %ld\n", ra_req.total_cache);
			nr_read = 0;
		}
		else
		{
			ra_req.ra_pos = 0;
			ra_req.ra_count = 0;
			readnow = syscall(449, fd, ((char *)buffer), 
					PG_SZ*NR_PAGES_READ, chunk, &ra_req);
		}
		nr_read += NR_PAGES_READ;
//#elif APP_NATIVE_RA //Read and Readahead from App
#else
		readnow = pread(fd, ((char *)buffer), PG_SZ*NR_PAGES_READ, chunk);
#endif

		if (readnow < 0 ){
			printf("\nRead Unsuccessful\n");
			free (buffer);
			close (fd);
			return 0;
		}
		chunk += readnow; //offset
		nr_read += NR_PAGES_READ;
#ifdef APP_NATIVE_RA
		if(nr_read >= NR_PAGES_RA){
			readahead(fd, chunk, PG_SZ*NR_PAGES_RA);
		}
#endif
	}

	printf("Read done\n");

	close(fd);
	//print_global_stats();
	return 0;
}
