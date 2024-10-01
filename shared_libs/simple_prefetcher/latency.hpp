#ifndef LATENCY_HPP
#define LATENCY_HPP

// #define GET_LATENCY
#include <time.h>
#include <stdio.h>

#ifdef GET_LATENCY
#define GET_LATENCY_START { \
            struct timespec ts0, ts1; \
            clock_gettime(CLOCK_MONOTONIC_RAW, &ts0); \
        }

#define GET_LATENCY_END { \
            clock_gettime(CLOCK_MONOTONIC_RAW, &ts1); \
            time_t _latency = ts1.tv_nsec - ts0.tv_nsec; \
            printf("[LATENCY] %lld\n", (long long)_latency); \
        }
#else
#define GET_LATENCY_START (void)0;
#define GET_LATENCY_END (void)0;


#endif

#endif
