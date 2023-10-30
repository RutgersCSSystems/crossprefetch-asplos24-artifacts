#ifndef _FRONTEND_HPP
#define _FRONTEND_HPP

#include "shim.hpp"
#include "utils/thpool.h"
#include "utils/bitarray.h"
#include "predictor.hpp"

#define __READAHEAD_INFO 451
#define __NR_start_crosslayer 448
#define __DISABLE_RW_LOCK 452

#define ENABLE_FILE_STATS 1
#define DISABLE_FILE_STATS 2
#define CLEAR_GLOBAL_STATS 3
#define PRINT_GLOBAL_STATS 4

//Used to send data to pthread or worker thread
struct thread_args{
	int fd; //opened file fd
	long offset; //where to start
	long file_size; //total filesize
	long prefetch_size; //size of each prefetch req
    long prefetch_limit; //total prefetch todo

	//difference between the end of last access and start of this access in pages
	size_t stride;

	/*
	 * Share current and last fd with the prefetcher thread
	 */
	int current_fd;
	int last_fd; 

	/*
	 * Send a pointer to the page cache state to be updated
	 */
	bit_array_t *page_cache_state;

    struct u_inode *uinode;

    /*
    * Some offsets used exclusively by read_predictor
    */
    size_t data_size;
    file_predictor *fp;

};


off_t reg_fd(int fd){

    if(fd<=2)
        return false;

    struct stat st;

    if(fstat(fd, &st) == 0){
        switch (st.st_mode & S_IFMT) {
            case S_IFBLK:
                debug_printf("fd:%d block device\n", fd);
                break;
            case S_IFCHR:
                debug_printf("fd:%d character device\n", fd);
                break;
            case S_IFDIR:
                debug_printf("fd:%d directory\n", fd);
                break;
            case S_IFIFO:
                debug_printf("fd:%d FIFO/pipe\n", fd);
                break;
            case S_IFLNK:
                debug_printf("fd:%d symlink\n", fd);
                break;
            case S_IFREG:
                debug_printf("fd:%d regular file\n", fd); 
                return st.st_size;
                //return true;            
                break;
            case S_IFSOCK:
                debug_printf("fd:%d socket\n", fd);
                break;
            default:
                debug_printf("fd:%d unknown?\n", fd);
        }
        /*
           if(S_ISREG(st.st_mode)){
           return true;
           }
           */
    }
    //return true;
    return false;
}

//returns filesize if FILE is regular file
//else 0
off_t reg_file(FILE *stream){
    return reg_fd(fileno(stream));
}

long readahead_info(int fd, loff_t offset, size_t count, struct read_ra_req *ra_req)
{
        return syscall(__READAHEAD_INFO, fd, offset, count, ra_req);
}

long start_cross_trace(int flag, int val)
{
        return syscall(__NR_start_crosslayer, flag, val);
}


/*
 * Per-Thread constructors can be made using
 * constructors for threadlocal objects
 */
class per_thread_ds{
    public:
        //Any variables here.
        long mytid; //this threads TID

        int last_fd; //records the last fd being used to read
        int current_fd; // records the current fd being used

        unsigned long nr_readaheads; //Counts the nr of readaheads done by apps

        int touchme; //just touch this variable if you want to call the constructor

        //constructor
        per_thread_ds(){
        //mytid = gettid();

#ifdef ENABLE_OS_STATS
		fprintf(stderr, "ENABLE_FILE_STATS in %s\n", __func__);
                start_cross_trace(ENABLE_FILE_STATS, 0);
#endif

        }

        ~per_thread_ds(){}
};


/*
 * The following set of commands are to enable single call at construction
 */

/*Returns the Parent PID of this process*/
pid_t getgppid(){
	char buf[128];

	pid_t ppid = getppid();

	pid_t gppid;

	FILE *fp;

	sprintf(buf, "/proc/%d/stat", (int)ppid);

	fp = fopen(buf, "r");
	if(fp == NULL)
		return -1;

	fscanf(fp, "%*d %*s %*s %d", &gppid);
	fclose(fp);

     //printf("My gppid = %d\n", gppid);

	return gppid;
}


/*Checks if this process is the root process*/
bool is_root_process(){
	char *gppid_env = getenv("TARGET_GPPID");

	if(gppid_env == NULL){
		printf("TARGET_GPPID is not set, cannot pick individual\n");
		goto err;
	}

	if(getgppid() == atoi(gppid_env)){
		return true;
	}

err:
	return false;
}

#endif //_FRONTEND_HPP
