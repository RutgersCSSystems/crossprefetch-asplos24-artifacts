#define _GNU_SOURCE
#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

#include "latency.hpp"


static void latency_con() __attribute__((constructor));
// static void latency_dest() __attribute__((destructor));

// ssize_t pread(int fd, void *data, size_t size, off_t offset);

real_pread_t pread_ptr_latency = NULL;

void latency_con()
{
    // printf("latency constructor\n");
    //
    // init rand
    srand(time(NULL));

    pread_ptr_latency = (real_pread_t)dlsym(RTLD_NEXT, "pread");
    if (pread_ptr_latency == NULL) {
        printf("%s: hook failed\n", __func__);
    }
}

ssize_t real_pread_latency(int fd, void *data, size_t size, off_t offset){

    // debug_printf("%s %zu\n", __func__, size);
    // printf("%s %zu\n", __func__, size);

    if(!pread_ptr_latency)
        pread_ptr_latency = (real_pread_t)dlsym(RTLD_NEXT, "pread");


    return ((real_pread_t)pread_ptr_latency)(fd, data, size, offset);
}

// ssize_t pread(int fd, void *data, size_t size, off_t offset);

ssize_t pread64(int fd, void *data, size_t size, off_t offset){
	return pread(fd, data, size, offset);
}

ssize_t pread(int fd, void *data, size_t size, off_t offset){

    GET_LATENCY_START
	ssize_t amount_read;

	// debug_printf("%s: fd=%d, offset=%ld, size=%ld\n", __func__, fd, offset, size);
	// printf("%s: fd=%d, offset=%ld, size=%ld\n", __func__, fd, offset, size);

	amount_read = real_pread_latency(fd, data, size, offset);
    GET_LATENCY_END
#if defined(GET_LATENCY) && defined(LATENCY_DEBUG)
    printf("[LATENCY_DEBUG] ts0: %lld, ts1: %lld\n", ts0.tv_nsec, ts1.tv_nsec);
#endif

exit_pread:
	return amount_read;
}

