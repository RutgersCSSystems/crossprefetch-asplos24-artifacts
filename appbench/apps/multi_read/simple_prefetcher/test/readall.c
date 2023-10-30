#define _GNU_SOURCE
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/time.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/stat.h>

#define __NR_start_crosslayer 448

#define NR_PAGES_READ 1
#define NR_PAGES_RA 10000
#define PG_SZ 4096

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

	int main(){

		int fd;

		fd = open("bigfakefile.txt", O_RDWR);
		if (fd == -1){
			printf("\nFile Open Unsuccessful\n");
			exit (0);;
		}

		long buff_sz = (PG_SZ * NR_PAGES_READ);
		char *buffer = (char*) malloc(buff_sz * sizeof(char));

		struct read_ra_req ra_req;
		size_t readnow;

		//posix_fadvise(fd, 0, 0, POSIX_FADV_WILLNEED);

		ra_req.ra_pos = 0;
		ra_req.ra_count = PG_SZ*NR_PAGES_RA;
		readnow = syscall(449, fd, ((char *)buffer), 
				PG_SZ*NR_PAGES_READ, chunk, &ra_req);

		//readahead(fd, 0, FILESIZE);
		close(fd);


		return 0;
	}

