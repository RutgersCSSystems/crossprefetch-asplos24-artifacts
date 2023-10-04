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
#include <mutex>

#include <sys/sysinfo.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <sys/resource.h>

#ifdef PREDICTOR
#include "predictor.hpp"

long seq_stats[17];
std::mutex stats;
void init_seq_stats(int seq);
void update_seq_stats(int old_seq, int new_seq);


file_predictor::file_predictor(int this_fd, size_t size, const char *filename){

        fd = this_fd;
        filesize = size;

        nr_reads_done = 0;


        portion_sz = PAGESIZE * PORTION_PAGES;
        nr_portions = size/portion_sz;

        //Imperfect division of filesize with portion_sz
        //add one bit to accomodate for the last portion in file
        if(size % portion_sz){
                nr_portions += 1;
        }

        access_history = BitArrayCreate(nr_portions);
        BitArrayClearAll(access_history);

#if defined(READAHEAD_INFO_PC_STATE) && !defined(PER_INODE_BITMAP)
        page_cache_state = BitArrayCreate(NR_BITS_PREALLOC_PC_STATE);
        BitArrayClearAll(page_cache_state);
#else
        page_cache_state = NULL;
#endif

        //Assume any opened file is mostly sequential
        sequentiality = DEFSEQ;
#ifdef ENABLE_PRED_STATS
        //init_seq_stats(sequentiality);
#endif
        stride = 0;
        read_size = 0;

        last_ra_offset = 0;
        last_read_offset = 0;

        uinode = NULL;
}


/*
 * file_predictor's destructor
 */
file_predictor::~file_predictor(){
        BitArrayDestroy(access_history);

#ifdef READAHEAD_INFO_PC_STATE
        BitArrayDestroy(page_cache_state);
#endif
}



int short_access_diff(off_t offset, off_t last_offset) {

	long curroff = (long)offset;
	long prevoff = (long)last_offset;

	if (abs(curroff - prevoff) > (NR_RA_PAGES * PAGESIZE)) {
		return 0;
	}
	return 1;
}

/*
 * If offset being accessed is from an Unset file portion, set it,
 * 1. Set that file portion in access_history
 * 2. reduce the sequentiality
 *
 * else increase the sequentiality
 *
 */
void file_predictor::predictor_update(off_t offset, size_t size){

        last_read_offset = offset + size;

        //size_t portion_num = (offset+size)/portion_sz; //which portion
        size_t portion_num = offset/portion_sz; //which portion
        size_t num_portions = size/portion_sz; //how many portions in this req
        size_t pn = 0; //used for adjacency check
        int old_seq, new_seq;

        if(portion_num > nr_portions){
                //printf("%s: ERR : portion_num > nr_portions, has the filesize changed ?\n", __func__);
                //goto exit_fail;
		portion_num = nr_portions;
        }

        /*
         * Go through the bit array, setting ones portions associated
         * with this read request
         */
        for(long i=0; i<=num_portions; i++)
                BitArraySetBit(access_history, portion_num+i);

        /*
         * Determine if this sequential or strided
         * TODO: Convert this to a bit operation, this is heavy
         * Develop a bit mask and test the corresponding bits
         */
        for(long i = 1; i <= NR_ADJACENT_CHECK; i++){

                pn = portion_num - i;

                /*bounds check*/
                if((long)pn < 0){
                        goto exit_fail;
                }

                if(BitArrayTestBit(access_history, pn)){
                        stride = portion_num - pn - 1;
                        if(stride > 0)
                                read_size = size;
                        //debug_printf("%s: stride=%ld\n", __func__, stride);
                        goto is_seq;
                }

        }

is_not_seq:
        old_seq = sequentiality;
        sequentiality = (std::max<int>)(DEFNSEQ, sequentiality-1); //keeps from underflowing

        goto exit_success;

is_seq:
	/* If the access difference between current and previous
	* access is still too wide,
	* may be not change the current state?
	*/
    	if(!short_access_diff(offset, last_read_offset)) {
    	    //fprintf(stderr, "short_access_diff too far \n");
	    goto exit_success;
	}
	
        old_seq = sequentiality;
        sequentiality = (std::min<int>)(DEFSEQ, sequentiality+1); //keeps from overflowing

exit_success:

#ifdef ENABLE_PRED_STATS
        new_seq = sequentiality;

        struct stat file_stat;
        fstat (fd, &file_stat);

        if(nr_reads_done > NR_READS_BEFORE_STATS && old_seq != new_seq) {
		debug_printf("%s: fd=%d, offset=%ld, size=%ld, inode_nr=%ld "
				"old_seq=%d, new_seq=%d\n", __func__, fd,
				offset, size, file_stat.st_ino, old_seq,
				new_seq);
        }
        //update_seq_stats(old_seq, new_seq);
#endif

exit_fail:
        return;
}


//Returns the current Sequentiality value
long file_predictor::is_sequential(){
        return sequentiality;
}


//returns the approximate stride in pages
//0 if not strided. doesnt mean its not sequential
long file_predictor::is_strided(){
        return stride*PORTION_PAGES;
}



bool file_predictor::should_prefetch_now(){

        off_t early_fetch = NR_EARLY_FETCH_PAGES * PAGESIZE;

        prefetch_limit = std::max(0L, early_fetch * sequentiality);

        debug_printf("%s: fd=%d last_read_offset=%ld, last_ra_offset=%ld, diff=%ld, prefetch_limit=%ld\n",
                        __func__, fd, last_read_offset, last_ra_offset, (last_ra_offset-last_read_offset), prefetch_limit);

//#ifdef ENABLE_EVICTION
//	if(is_memory_low() == true) {
		//fprintf(stderr, "preventing prefetch \n");
//		return false;
//	}
//#endif

	if(prefetch_limit > 0 && this->uinode && (this->uinode->ino > 0) &&
			!this->uinode->fully_prefetched.load()) {
                return true;
        }
        return false;
}


//PREDICTOR STATS FUNCTIONS

/*
void init_seq_stats(int seq){
        stats.lock();
        seq_stats[seq+8] += 1;
        stats.unlock();
}

void update_seq_stats(int old_seq, int new_seq){

        stats.lock();

        seq_stats[new_seq+8] += 1;
        
        seq_stats[old_seq+8] -= 1;

        stats.unlock();
}

void print_seq_stats(){
        printf("PREDICTOR STATS\n");
        stats.lock();

        for(int i=-8; i<=8; i++){
                if(seq_stats[i+8] !=0)
                        printf("SEQ[%d]=%ld ", i, seq_stats[i+8]);
        }
        printf("\n");
        stats.unlock();
}

*/

#endif //PREDICTOR
