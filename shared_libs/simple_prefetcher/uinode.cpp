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
#include <sys/sysinfo.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <sys/resource.h>

//#include "util.hpp"
//#include "frontend.hpp"


#define __FADVISE 221


#include "utils/hashtable.h"
#include "utils/lrucache.hpp"

#ifdef MAINTAIN_UINODE
#include "uinode.hpp"


int fadvise(int fd, off_t offset, off_t len, int advice){
        return syscall(__FADVISE, fd, offset, len, advice);
}


//std::unordered_map<int, void *> inode_map;
//robin_hood::unordered_map<int, void *> inode_map;
std::atomic_flag inode_map_init;
std::mutex m;
std::mutex evict_lock;

bool g_lowmem_thresh=false;
bool g_dangermem_thresh=false;
long g_tot_bytes_fetch = 0;
/*****************************************************************************/
struct key
{
    uint32_t inode;
};

struct value
{
    void *value;
};

DEFINE_HASHTABLE_INSERT(insert_some, struct key, struct value);
DEFINE_HASHTABLE_SEARCH(search_some, struct key, struct value);
DEFINE_HASHTABLE_REMOVE(remove_some, struct key, struct value);



static unsigned int
hashfromkey(void *ky)
{
    struct key *k = (struct key *)ky;
    return (((k->inode << 17) | (k->inode >> 15)));
}

static int
equalkeys(void *k1, void *k2)
{
    return (0 == memcmp(k1,k2,sizeof(struct key)));
}

#ifdef ENABLE_FNAME
char* get_filename(int fd) {

	std::string str = fd_to_file_name.at(fd);
	return (char *)str.c_str();
}
#endif


int hash_insert(struct hashtable *i_hash, int inode, void *value) {

	struct key *k = (struct key *)malloc(sizeof(struct key));
    if (NULL == k) {
        printf("ran out of memory allocating a key\n");
        return 1;
    }
    k->inode = inode;

    struct value *v = (struct value *)malloc(sizeof(struct value));
    v->value = value;

    if (!insert_some(i_hash,k,v))
    	return -1;

    return 0;
}

struct value *hash_get(struct hashtable *i_hash, int inode) {

	struct value *found = NULL;
	struct key *k = (struct key *)malloc(sizeof(struct key));
    if (NULL == k) {
        printf("ran out of memory allocating a key\n");
        return NULL;
    }
    k->inode = inode;

	if (NULL == (found = search_some(i_hash, k))) {
		//printf("BUG: key not found\n");
		return NULL;
	}
	/* We don't the structure anymore */
	free(k);
	return found;
}

int hash_remove(struct hashtable *i_hash, int inode) {

	struct value *found = NULL;

	if(!i_hash)
		return -1;

	struct key *k = (struct key *)malloc(sizeof(struct key));
    if (NULL == k) {
        printf("ran out of memory allocating a key\n");
        return -1;
    }
    k->inode = inode;

	if (NULL == (found = remove_some(i_hash,k))) {
		//printf("BUG: key not found\n");
		return -1;
	}
	/* We don't the structure anymore */
	free(k);
	return 0;
}


void uinode_bitmap_lock(struct u_inode *uinode) {

	if(uinode != NULL)
		uinode->bitmap_lock.lock();
}


void uinode_bitmap_unlock(struct u_inode *uinode) {

	if(uinode != NULL)
		uinode->bitmap_lock.unlock();
}


struct u_inode *get_uinode(struct hashtable *i_hash, int fd){

	struct stat file_stat;
	int inode, ret;
	struct u_inode *uinode = NULL;
	struct value *found = NULL;

	if(!i_hash)
		return NULL;

	ret = fstat (fd, &file_stat);
	inode = file_stat.st_ino;  // inode now contains inode number of the file with descriptor fd

    //m.lock();
	//uinode = (struct u_inode *)inode_map[inode];
    found = hash_get(i_hash, inode);
    if(!found) {
    	return NULL;
    }
    uinode = (struct u_inode *)found->value;
	//m.unlock();
	return uinode;
}


#ifdef ENABLE_FNAME
int add_fd_to_inode(struct hashtable *i_map, int fd, char *fname){
#else
int add_fd_to_inode(struct hashtable *i_map, int fd){
#endif

	struct stat file_stat;
   	int inode, ret;
   	struct u_inode *uinode = NULL;
   	struct value *found = NULL;

   	bool new_uinode = false;

   	if(!i_map)
		return -1;

    	ret = fstat (fd, &file_stat);
    	inode = file_stat.st_ino;  // inode now contains inode number of the file with descriptor fd

    	m.lock();

    	found = hash_get(i_map, inode);
    	
	if(found) {
    		uinode = (struct u_inode *)found->value;
    	}

	if(uinode == NULL){
        	uinode = new struct u_inode;
		if(!uinode){
			m.unlock();
			return -1;
		}

        	new_uinode = true;
		uinode->ino = inode;
		uinode->fdcount = 0;
		uinode->full_prefetched = 0;
        	uinode->file_size = file_stat.st_size;

#if defined(READAHEAD_INFO_PC_STATE) && defined(PER_INODE_BITMAP)
       		/*
       		* Allocate per inode bitmaps if adding new inode
       		*/
		uinode->page_cache_state = BitArrayCreate(NR_BITS_PREALLOC_PC_STATE);
        	//BitArrayClearAll(uinode->page_cache_state);
        	debug_printf("%s: adding page cache to uinode %d with %lu bits\n",
        		__func__, inode, NR_BITS_PREALLOC_PC_STATE);

#else
        	uinode->page_cache_state = NULL;
#endif

#ifdef ENABLE_FNAME
		strcpy(uinode->filename, fname);
#endif
		hash_insert(i_map, inode, (void *)uinode);
	}
	m.unlock();
	uinode->fdlist[uinode->fdcount] = fd;
	uinode->fdcount++;
	debug_printf("ADDING INODE %d, FDCOUNT %d, uinode=%p \n", inode, uinode->fdcount, uinode);

#ifdef ENABLE_EVICTION
        //Adds the uinode to the LRU
        if(new_uinode && uinode && uinode->file_size > MIN_FILE_SZ){
                update_lru(uinode);
        }
#endif
	return 0;
}


bool is_file_closed(struct u_inode *uinode, int fd){

#ifdef _PERF_OPT
	if(!uinode)
		return false;

	for(int i=0; i < uinode->fdcount; i++){
		if(uinode->fdlist[i] == fd){
			return false;
		}
	}
	return true;
#endif
	return false;
}

#ifdef _PERF_OPT
void remove_fd_from_uinode(struct u_inode *uinode, int fd) {
  if (!uinode || uinode->fdcount == 0) {
    return;
  }

  // Find the fd in the fdlist.
  int i = 0;
  while (i < uinode->fdcount && uinode->fdlist[i] != fd) {
    i++;
  }

  // If the fd is not found, return.
  if (i == uinode->fdcount) {
    return;
  }

  // Set the fd to 0 in the fdlist.
  uinode->fdlist[i] = 0;

  // Copy the new file descriptors back to the uinode's fdlist.
  int j = 0;
  for (i = 0; i < uinode->fdcount; i++) {
    if (uinode->fdlist[i] != 0) {
      uinode->fdlist[j] = uinode->fdlist[i];
      j++;
    }
  }

  // Decrement the uinode's fdcount.
  uinode->fdcount--;
}

#else
void remove_fd_from_uinode(struct u_inode *uinode, int fd){

	int newfdlist[MAX_FD_PER_INODE];
	int new_i = 0;

        if(!uinode)
                return;

	for(int i=0; i <  uinode->fdcount; i++){
		if(uinode->fdlist[i] == fd){
			uinode->fdlist[i] = 0;
		}

		if(uinode->fdlist[i] >= 3){
			newfdlist[new_i] = uinode->fdlist[i];
			new_i += 1;
		}
	}

	for(int i=0; i<  uinode->fdcount; i++){
		uinode->fdlist[i] = newfdlist[i];
	}
	if(uinode->fdcount)
		uinode->fdcount--;
}
#endif



/*
 * Reduce and remove inode refcount because a file descriptor
 * might have been close.
 */
int inode_reduce_ref(struct hashtable *i_map, int fd) {

	struct u_inode *uinode = NULL;

	if(!i_map)
		return -1;

	uinode = get_uinode(i_map, fd);
	if(uinode && uinode->fdcount > 0) {
		remove_fd_from_uinode(uinode, fd);

		uinode->fdcount--;
		return uinode->fdcount;
	}
	return -1;
}

struct hashtable *init_inode_fd_map(void) {

	 return create_hashtable(MAXFILES, hashfromkey, equalkeys);
}


int handle_close(struct hashtable *i_map, int fd){

	int inode_fd_count = -1;

	if(!i_map)
		return -1;
	/*
	 * if the reference count is 0,
	 * FIXME: also remove the software uinode? But that would
	 * require protection
	 */
	inode_fd_count = inode_reduce_ref(i_map, fd);
	//printf("%s:%d Reducing current FDCOUNT %d\n",
		//	__func__, __LINE__, inode_fd_count);
	return inode_fd_count;
}



#ifdef ENABLE_EVICTION
/*Number of pages free inside the OS*/
/*GLOBAL FILE LEVEL LRU*/
cache::lru_cache<int, struct u_inode*> lrucache(MAXFILES);
std::mutex lru_guard;
long lru_inodes=0;

void update_lru(struct u_inode *uinode){
        if(uinode){
            //std::lock_guard<std::mutex> guard(lru_guard);
        	evict_lock.lock();
            	lrucache.put(uinode->ino, uinode);
		evict_lock.unlock();
		lru_inodes++;
        }
}

struct u_inode *get_lru_victim(){

	struct u_inode *uinode = NULL;
	if(lru_inodes > 0)
		lru_inodes--;

	evict_lock.lock();
	uinode = (struct u_inode *)lrucache.pop_last()->second;
	evict_lock.unlock();
    //std::lock_guard<std::mutex> guard(lru_guard);
    return uinode;
}

long update_prefetch_bytes(size_t bytes, int add) {

	if(add) { 
		g_tot_bytes_fetch += bytes;
	}else if(g_tot_bytes_fetch > 0){
		g_tot_bytes_fetch -= bytes;
	}
	return g_tot_bytes_fetch;
}

long get_prefetch_bytes(void) {

	if(g_tot_bytes_fetch < 0)
		return 0;
	else
		return g_tot_bytes_fetch;
}



ssize_t read_mem_info(void)
{
    char * line = NULL;
    size_t len = 0;
    ssize_t read;
    FILE *meminfo_fp = NULL;

    if(!meminfo_fp)
    meminfo_fp = fopen("memcap.out", "r");
    if (meminfo_fp == NULL)
        return -1;

    getline(&line, &len, meminfo_fp);
    read = (size_t)atoi(line);
    printf("%s memcap %zu \n", line, read);
    fclose(meminfo_fp);
    return read;	
 }


/*
 * Returns True if available memory is lower than
 * LOW WATERMARK
 */
unsigned long mem_low_watermark(){
        
	struct sysinfo si;
        sysinfo (&si);

       //return (si.freeram - MEM_OTHER_NUMA_NODE <= MEM_LOW_WATERMARK);
        return (si.freeram <= MEM_LOW_WATERMARK);

}

unsigned long mem_danger_watermark(){

        struct sysinfo si;
        sysinfo (&si);

	debug_printf("si.freeram %ld MEM_OTHER_NUMA_NODE %ld diff %ld MEM_DANGER_WATERMARK %ld \n", 
			si.freeram, MEM_OTHER_NUMA_NODE, si.freeram - MEM_OTHER_NUMA_NODE,  MEM_DANGER_WATERMARK);
        return (si.freeram <= MEM_DANGER_WATERMARK);
	//return (si.freeram - MEM_OTHER_NUMA_NODE <= MEM_DANGER_WATERMARK);
}


/*
 * Returns True if available memory is higher than
 * HIGH WATERMARK
 */
unsigned long mem_high_watermark(){
        struct sysinfo si;
        sysinfo (&si);

        return (si.freeram - MEM_OTHER_NUMA_NODE > MEM_HIGH_WATERMARK);
}


int have_we_evicted_enough() {
	struct sysinfo si;
	sysinfo (&si);

	/*We get the single numa available memory*/
	unsigned long avblmem = si.freeram - MEM_OTHER_NUMA_NODE;
	unsigned long singlenuma = si.totalram/2;
	singlenuma = singlenuma/2;
	/*We check if prefetching is using more than half of singlenuma 
	 * If yes, we will return false, else, the memory usage is not likely 
	 * from our prefetching and we cannot do much
	 */
	if(singlenuma > get_prefetch_bytes()) {
		//fprintf(stderr, "Half of memroy socket %lu, " 
		//	"current prefetched %lu available mem %lu \n", 
		//		singlenuma, get_prefetch_bytes(), avblmem);
		return 1;
	}
		return 0;
}


bool is_memory_low(void) {
	return g_lowmem_thresh;
}

bool is_memory_danger_low(void) {
	return g_dangermem_thresh;
}


int set_memory_low(bool islowmem) {
	g_lowmem_thresh = islowmem;
	return 0;
}

int set_memory_danger_low(bool islowmem) {
        g_dangermem_thresh = islowmem;
	return 0;
}



void set_uinode_access_time(struct u_inode *uinode) {
	uinode->update_time = std::time(nullptr);
	//std::cout << uinode->update_time << " seconds since the Epoch\n";
}






#ifdef _PERF_OPT
int evict_inode_from_mem(void) {

    int batch_size = 10;
    struct u_inode *uinode = NULL;

    for (int i = 0; i < batch_size; i++) {
        if (!mem_danger_watermark()) {
            set_memory_danger_low(false);
        } else {
            set_memory_danger_low(true);
        }

        if (!mem_low_watermark()) {
            set_memory_low(false);
            return 0; // Early return when low memory is not a concern
        } else {
            set_memory_low(true);
        }

        uinode = get_lru_victim();
        if (!uinode) {
            return -1; // Early return when no victim is available
        }

        if (uinode->fdcount > 0 &&
            uinode->file_size > 0 &&
            uinode->fdlist[0] > 0 &&
            uinode->evicted != FILE_EVICTED) {

            if (fadvise(uinode->fdlist[0], 0, 0, POSIX_FADV_DONTNEED)) {
                fprintf(stderr, "%s:%d eviction failed using fadvise fd:%d SIZE:%zu\n", __func__,
                        __LINE__, uinode->fdlist[0], uinode->file_size);
                return -1;
            }

            uinode->evicted = FILE_EVICTED;
            uinode->fully_prefetched.store(false); // Reset fully prefetched for this file
            update_prefetch_bytes(uinode->file_size, 0);
        }
    }

    return 0;
}
#else
/*
 * Call this for victim uinode
 */
int evict_inode_from_mem(void){

	int batch_size = 10;
	int i = 0, lowmem=0, dangermem=0;
	struct u_inode *uinode = NULL;

	for (i=0; i < batch_size; i++) {

		if(!mem_danger_watermark()){
                        set_memory_danger_low(false);
                }else {
			dangermem=1;
			set_memory_danger_low(true);
		}

		/* We can return beyond this point*/
		if(!mem_low_watermark()){
                        set_memory_low(false);
			return 0;
                }else {
			lowmem=1;
			set_memory_low(true);
		}

		uinode = get_lru_victim();
		if(!uinode)
			return -1;

		if((uinode->fdcount > 0)
			&& (uinode->file_size > 0)
			&& (uinode->fdlist[0] > 0)
			&& (uinode->evicted != FILE_EVICTED)) {

			if(fadvise(uinode->fdlist[0], 0, 0, POSIX_FADV_DONTNEED)){
				fprintf(stderr, "%s:%d eviction failed using fadvise fd:%d SIZE:%zu\n", __func__,
						__LINE__, uinode->fdlist[0], uinode->file_size);
				return -1;
			}

		/*	printf("%s: evicting uinode:%d, fd:%d items in list %ld " 
					"TID %ld PID %ld dangermem=%d lowmem=%d\n", 
					__func__, uinode->ino, uinode->fdlist[0], lru_inodes, 
					gettid(), (long)getpid(), dangermem, lowmem);*/

			uinode->evicted = FILE_EVICTED;
			uinode->fully_prefetched.store(false); //Reset fully prefetched for this file

			update_prefetch_bytes(uinode->file_size, 0);
		}
		uinode = NULL;
	}
        return 0;
}
#endif


//EVICTION CODE
void evict_inactive_inodes(void *arg){

        struct hashtable *i_map = (struct hashtable *)arg;
        int tot_inodes;

        while(true){
retry:
                tot_inodes = hashtable_count(i_map);

                if(tot_inodes < 2 || !lrucache.size()){
			/*printf("WAITING FOR EVICTION totinodes %d " 
				"LRU size %zu TID %ld PID %d\n", 
				tot_inodes, lrucache.size(), gettid(), getpid());*/
                        goto wait_for_eviction;
                }

                if(!mem_low_watermark()){

			set_memory_low(false);
                        goto wait_for_eviction;
                }

		set_memory_low(true);

                evict_inode_from_mem();

                //Not enough eviction done
                if(!mem_low_watermark()){
                        goto retry;
                }

wait_for_eviction:
		//printf("WAITING FOR EVICTION \n");
                sleep(SLEEP_TIME);
        }
}
#endif //ENABLE_EVICTION

#endif //MAINTAIN_UINODE


#ifdef ENABLE_MPI
struct hashtable *init_mpifile_fd_map(void) {
	 return create_hashtable(MAXFILES, hashfromkey, equalkeys);
}
#endif
