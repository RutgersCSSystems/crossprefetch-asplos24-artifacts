#ifndef _UINODE_HPP
#define _UINODE_HPP

#include <mutex>
#include <atomic>
#include "util.hpp"
#include "utils/hashtable.h"
#include "utils/thpool.h"
#include "utils/bitarray.h"

#include "cache_state_tree.hpp"

//user-level inodes
struct u_inode {
	int ino; //opened file fd
	long file_size; //total filesize
	int fdlist[MAX_FD_PER_INODE]; //array of file descriptors for this inode
	int fdcount; //total fd's opened for this file

	int full_prefetched; //has the file been already fully prefetched?

#ifdef ENABLE_FNAME
    	char filename[256];
#endif

	long prefetch_size; //size of each prefetch req
	//difference between the end of last access and start of this access in pages
	size_t stride;
	//helps debugging
	int last_fd;

	/*
	 * Send a pointer to the page cache state to be updated
	 */
	bit_array_t *page_cache_state;
        std::mutex bitmap_lock;

	/*
	* Returns true if file has been prefetched completely
	* for this file
	*/
	std::atomic<bool> fully_prefetched;
	size_t prefetched_bytes;


    /*
     * Used by Eviction
     */
    int evicted; //set to FILE_EVICTED if evicted
    std::time_t update_time;


    struct rb_root cache_state_tree;
    pthread_mutex_t tree_lock;

    u_inode(){
        ino = 0;
        file_size = 0;
        fdcount = 0;
        page_cache_state = NULL;

        fully_prefetched.store(false);
        prefetched_bytes = 0;

        evicted = 0;

        cache_state_tree = RB_ROOT;
        pthread_mutex_init(&tree_lock, NULL);
    }
};

struct hashtable *init_inode_fd_map(void);

#ifdef ENABLE_MPI
struct hashtable *init_mpifile_fd_map(void) ;
#endif

int handle_close(struct hashtable *, int);
struct u_inode *get_uinode(struct hashtable *, int);

#ifdef ENABLE_FNAME
int add_fd_to_inode(struct hashtable *, int, char);
#else
int add_fd_to_inode(struct hashtable *, int fd);
#endif

void uinode_bitmap_lock(struct u_inode *inode);
void uinode_bitmap_unlock(struct u_inode *inode);

bool is_file_closed(struct u_inode *uinode, int fd);


void update_nr_free_pg(unsigned long nr_free);
void increase_free_pg(unsigned long increased_pg);
//void add_to_lru(struct u_inode *uinode);
void update_lru(struct u_inode *uinode);
long curr_available_free_mem_pg();

bool is_memory_low(void);
bool is_memory_danger_low(void);

int evict_inode_from_mem(struct u_inode *uinode);
void evict_inactive_inodes(void *arg);
void set_uinode_access_time(struct u_inode *uinode);
long update_prefetch_bytes(size_t bytes, int add);
#endif
