#include "cache_state_tree.hpp"

// #include <interval_tree.h>


unsigned long get_prefetch_offset(struct cache_state_node** cache_states, int n, off_t start_pos, off_t end_pos) {

	off_t start_pg = start_pos >> PAGE_SHIFT;
	off_t curr_pg = start_pg;
	off_t prefetch_limit_pg = (NODE_SIZE_LIMIT) >> PAGE_SHIFT;
    bit_array_t *page_cache_state = NULL;

    for (int i = 0; i < n; i++) {
        page_cache_state = cache_states[i]->page_cache_state;
        if (page_cache_state == NULL) break;
        pthread_mutex_lock(&cache_states[i]->lock);
        while(curr_pg < (start_pg + prefetch_limit_pg)){

            if(BitArrayTestBit(page_cache_state, curr_pg)){
                curr_pg += 1;
            } else{
                break;
            }
        }
        pthread_mutex_unlock(&cache_states[i]->lock);
    }

	return curr_pg << PAGE_SHIFT;
}

struct cache_state_node* cache_state_insert_new_node(struct u_inode* inode, struct rb_root* root,
        unsigned long start_pos, unsigned long end_pos, bit_array_t *state_bitmap) {
    struct cache_state_node* node = NULL;
    node = (struct cache_state_node*) malloc(sizeof(struct cache_state_node));

    node->page_cache_state = state_bitmap;

    node->it.start = start_pos;
    node->it.last = end_pos;

    pthread_mutex_init(&node->lock, NULL);

    interval_tree_insert(&node->it, root);
    return node;
}

int cache_state_query(struct u_inode* inode, struct rb_root* root, 
        unsigned long start_pos, unsigned long end_pos, struct cache_state_node** cache_states) { 

    struct interval_tree_node *it = NULL;
    struct cache_state_node* tree_node = NULL;
    int retval = 0;

    unsigned long start = start_pos;
    unsigned long end = end_pos;

    unsigned long start_idx = 0;
    unsigned long end_idx = 0;

    unsigned long new_node_start = 0;
    unsigned long new_node_end = 0;

    bit_array_t *state_bitmap = NULL;

    int idx = 0;


    if (root == NULL || cache_states == NULL) {
        printf("err, tree is emply\n");
        return -1;
    }


    // pthread_mutex_lock(&inode->tree_lock);

    // pthread_rwlock_rdlock(&inode->rwlock);
    // printf("cache_state_query, ino: %d, start: %ld, end: %ld\n", inode->ino, start_pos, end_pos);

    it = interval_tree_iter_first(root, start, end);

    // printf("cache_state_query done, ino:%d, start: %ld, end: %ld\n", inode->ino, start_pos, end_pos);

    while (it) {
        tree_node = container_of(it, struct cache_state_node, it);
        if (!tree_node) {
            printf("Get NULL object!\n");
            retval = -1;
            goto exit_iterate_tree;
        }

        if (start >= it->start && it->last >= end) {

            cache_states[idx++] = tree_node;
            start = end = 0;
            break;
        } else if (start >= it->start && end > it->last)   {

            cache_states[idx++] = tree_node;
            start = it->last + 1;
        } else if (it->start > start && end <= it->last) {

            cache_states[idx++] = tree_node;
            end = it->start - 1;
        }

        if ((start == 0 & end == 0) || start > end) {
            break;
        }
find_next:
        it = interval_tree_iter_next(it, start, end);
    }


    if (start < end) {

        start_idx = start / NODE_SIZE_LIMIT;
        end_idx = end / NODE_SIZE_LIMIT;

        for (int i = start_idx; i <= end_idx; i++) {
            new_node_start = i * NODE_SIZE_LIMIT;
            new_node_end = new_node_start + NODE_SIZE_LIMIT - 1;

            state_bitmap = BitArrayCreate(NODE_SIZE_LIMIT/PAGESIZE);
            BitArrayClearAll(state_bitmap);

            // printf("insert new cache_state, ino:%d, start: %ld, end: %ld, size: %ld, idx: %d\n", inode->ino, new_node_start, new_node_end, NODE_SIZE_LIMIT/PAGESIZE, idx);
            tree_node = cache_state_insert_new_node(inode, root, new_node_start, new_node_end, state_bitmap);

            cache_states[idx++] = tree_node;
        }
    }


    // printf("cache_state_query, ino:%d, start: %ld, end: %ld done\n",inode->ino,  start_pos, end_pos);
exit_iterate_tree:
    // pthread_mutex_unlock(&inode->tree_lock);
    return idx;
}
