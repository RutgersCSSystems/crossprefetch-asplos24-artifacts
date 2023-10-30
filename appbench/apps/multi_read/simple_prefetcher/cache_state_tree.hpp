#ifndef _CACHE_STATE_TREEE_HPP
#define _CACHE_STATE_TREEE_HPP

// #define NODE_SIZE_LIMIT (2 * 1024 * 1024)
#define NODE_SIZE_LIMIT (128 * 1024 * 1024)
//#define MAX_STATES 1024 
#define MAX_STATES 512

#include <stdio.h>
#include <sys/types.h>
#include <pthread.h>
#include <stdlib.h>
#include <interval_tree.h>

#include "util.hpp"
#include "utils/bitarray.h"
#include "uinode.hpp"

#if 1
#define container_of(ptr, type, member) \
        (type *)((char *)(ptr) - (char *) &((type *)0)->member)
#endif



struct cache_state_node {
    bit_array_t *page_cache_state;
    pthread_mutex_t lock;
    int fully_prefetched;

    struct interval_tree_node it;
};


unsigned long get_prefetch_offset(struct cache_state_node** cache_states, int n, off_t start_pos, off_t end_pos);
void cache_state_insert();

int cache_state_query(struct u_inode* inode, struct rb_root* tree_root, 
        unsigned long start_pos, unsigned long end_pos, struct cache_state_node** cache_states);

#endif
