/*
 * This program demonstrates how to enable and print global cache stats for a given program
 */

#define _LARGEFILE64_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/syscall.h>

#define __NR_start_crosslayer 448

#define NR_PAGES_READ 10
#define NR_PAGES_RA 2
#define PG_SZ 4096

#define ENABLE_FILE_STATS 1
#define DISABLE_FILE_STATS 2
#define RESET_GLOBAL_STATS 3
#define PRINT_GLOBAL_STATS 4

void set_crosslayer(){
    syscall(__NR_start_crosslayer, ENABLE_FILE_STATS, 0);
}

void reset_global_stats(){
    syscall(__NR_start_crosslayer, RESET_GLOBAL_STATS, 0);
}

void print_global_stats(){
    syscall(__NR_start_crosslayer, PRINT_GLOBAL_STATS, 0);
}

int main() {

	reset_global_stats();

	int fd;

	long size = (1024L * 1024L * 1024L);

	char *buffer = (char*) malloc(size * sizeof(char));
	fd = open("bigfakefile.txt", O_RDWR);
	if (fd == -1){
		printf("\nFile Open Unsuccessful\n");
		exit (0);;
	}

	off_t chunk = 0;
	lseek64(fd, 0, SEEK_SET);

	while ( chunk < size ){
		//printf ("the size of chunk read is  %ld\n", chunk);
		size_t readnow;
		readnow = read(fd, ((char *)buffer)+chunk, 4096*NR_PAGES_READ);

		if (readnow < 0 ){
			printf("\nRead Unsuccessful\n");
			free (buffer);
			close (fd);
			return 0;
		}
		chunk = chunk + readnow;
	}

	printf("Read done\n");

	close(fd);
	print_global_stats();
	return 0;
}
