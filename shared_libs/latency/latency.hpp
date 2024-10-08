#ifndef __LATENCY_HPP__
#define __LATENCY_HPP__

#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdlib.h>
#include <time.h>

typedef ssize_t (*real_pread_t)(int, void *, size_t, off_t);

#ifndef LATENCY_SAMPLE
#define LATENCY_SAMPLE 100
#endif // LATENCY_SAMPLE

#ifdef GET_LATENCY
#define GET_LATENCY_START \
            struct timespec ts0, ts1; \
            clock_gettime(CLOCK_MONOTONIC_RAW, &ts0); \

#define GET_LATENCY_END  \
            clock_gettime(CLOCK_MONOTONIC_RAW, &ts1); \
            time_t _latency = ts1.tv_nsec - ts0.tv_nsec; \
            if (rand() % LATENCY_SAMPLE == 0) \
            printf("[LATENCY] %lld\n", (long long)_latency); \
        
#else
#define GET_LATENCY_START (void)0;
#define GET_LATENCY_END (void)0;


#endif // GET_LATENCY

#endif // __LATENCY_HPP__
