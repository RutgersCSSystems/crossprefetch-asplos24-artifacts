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
#include "predictor.hpp"
robin_hood::unordered_map<int, file_predictor*> fd_to_file_pred;
std::atomic_flag fd_to_file_pred_init;
std::mutex fp_mutex;
#endif


#include <assert.h>
#include "utils/thpool-simple.h"
#define THREAD NR_WORKERS
#define SIZE   50000
#define QUEUES 64

threadpool_t *pool[QUEUES];
int g_next_queue=0;
pthread_mutex_t lock;

#include "frontend.hpp"


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

void con(){
	char a;
	link_shim_functions();
}


void dest(){
}


int evict_advise(int fd){
	//fprintf(stderr,"evicting inode \n");
	return real_posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);
}

ssize_t readahead(int fd, off_t offset, size_t count){

	ssize_t ret = 0;

#ifdef DISABLE_APP_READAHEADS
	goto exit_readahead;
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
