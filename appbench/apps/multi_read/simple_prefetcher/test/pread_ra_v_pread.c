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

#define NR_PAGES_READ 0
#define NR_PAGES_RA 20
#define PG_SZ 4096

#define ENABLE_FILE_STATS 1
#define DISABLE_FILE_STATS 2
#define RESET_GLOBAL_STATS 3
#define PRINT_GLOBAL_STATS 4
#define CACHE_USAGE_CONS 5
#define CACHE_USAGE_DEST 6
#define CACHE_USAGE_RET 7

#define FILESIZE (5L * 1024L * 1024L * 1024L)

/*
 * pread_ra read_ra_req struct
 * this struct is used to send and receive info from kernel about
 * the current readahead with the typical read
 */
struct read_ra_req {
    loff_t ra_pos;
    size_t ra_count;
    
    /*The following are return values from the OS
     * Reset at recieving them
     */
    unsigned long nr_present; //nr pages present in cache
    unsigned long bio_req_nr;//nr pages requested bio for

//#ifdef CONFIG_CACHE_LIMITING
    long total_cache_usage; //total cache usage in bytes (OS return)
    bool full_file_ra; //populated by app true if pread_ra is being done to get full file
    long cache_limit; //populated by the app, desired cache_limit
//#endif
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


int main() {
	long buff_sz = (PG_SZ * NR_PAGES_READ);

	char *buffer = (char*) malloc(buff_sz * sizeof(char));

	int fd;
	fd = open("bigfakefile.txt", O_RDWR);
	if (fd == -1){
		printf("\nFile Open Unsuccessful\n");
		exit (0);;
	}

	off_t chunk = 0;
	long size = FILESIZE; //10GB
	size_t readnow;
        struct read_ra_req ra_req;

	while ( chunk < size ){

#ifdef PREAD
		readnow = pread(fd, ((char *)buffer), PG_SZ*NR_PAGES_READ, chunk);
#else
		ra_req.ra_pos = 0;
		ra_req.ra_count = PG_SZ*NR_PAGES_RA;
		readnow = syscall(449, fd, ((char *)buffer), 
				PG_SZ*NR_PAGES_READ, chunk, &ra_req);
		//printf("sycall return=%ld\n", readnow);
#endif

		if (readnow < 0 ){
			printf("\nRead Unsuccessful\n");
			free (buffer);
			close (fd);
			return 0;
		}
		chunk += PG_SZ*NR_PAGES_RA;
		//chunk += readnow; //offset
	}

	return 0;
}
