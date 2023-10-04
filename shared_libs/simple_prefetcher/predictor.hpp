#ifndef _PREDICTOR_HPP
#define _PREDICTOR_HPP

#include "util.hpp"
#include "utils/thpool.h"
#include "utils/bitarray.h"
#include "uinode.hpp"

#if 0
#define DEFNSEQ (0) //Not seq or strided(since off_t is ulong)
#define LIKELYNSEQ (1) /*possibly not seq */
#define POSSNSEQ 2 /*possibly not seq */
#define MAYBESEQ 4 /*maybe seq */
#define POSSSEQ 32 /* possibly seq? */
#define LIKELYSEQ 64 /* likely seq? */
#define DEFSEQ 128 /* definitely seq */
#endif

#if 0
#define DEFNSEQ (-8) //Not seq or strided(since off_t is ulong)
#define LIKELYNSEQ (-4) /*possibly not seq */
#define POSSNSEQ 0 /*possibly not seq */
#define MAYBESEQ 1 /*maybe seq */
#define POSSSEQ 2 /* possibly seq? */
#define LIKELYSEQ 4 /* likely seq? */
#define DEFSEQ 8 /* definitely seq */
#endif

#define DEFNSEQ 0 //Not seq or strided(since off_t is ulong)
#define LIKELYNSEQ 1 /*possibly not seq */
#define POSSNSEQ 2 /*possibly not seq */
#define MAYBESEQ 4 /*maybe seq */
#define POSSSEQ 8 /* possibly seq? */
#define LIKELYSEQ 16 /* likely seq? */
#define DEFSEQ 32 /* definitely seq */


void print_seq_stats();

///////////////////////////////////////////////////////////////
//This portion is used to keep track of per file prefetching
///////////////////////////////////////////////////////////////

class file_predictor{
	public:
		int fd;
		size_t filesize;

        long nr_reads_done;

		/*
		 * The file is divided into FILESIZE/(PORTION_SIZE*PAGESIZE) portions
		 * Each such portions is represented with a bit in access_history
		 * Accesses to an area represented by a set bit increases sequentiality
		 * else increases Non sequentiality
		 */
		bit_array_t *access_history;
		size_t nr_portions;
		size_t portion_sz;

		/*
		 * This is the difference between the last access
		 * and this access.
		 * XXX: ASSUMPTION for now: Stride doesnt change for a file
		 * the read_size doesnt change either
		 */
		size_t stride; //in nr_portions
		size_t read_size; //in bytes

		/*
		 * For each file doing readahead_info, the syscall
		 * returns the page cache state in its return struct
		 * We will be using this to update the access_history
		 * based on the PORTION_PAGES.
                 * TODO: Remove it since this is done for per-uinode stuff
		 */
		bit_array_t *page_cache_state;

        /*
        * Records the last read done on this fd
        * Also records the last RA done using this fd
        * Since the file can be large and be opened with multiple
        * fds; there can be multiple RAs on the same file (multiple fds)
        */
        size_t last_ra_offset;
        size_t last_read_offset;

        /*
        * It is the limit of bytes to prefetch in a file
        * from last_ra_offset before exiting prefetcher_th
        */
        size_t prefetch_limit;

		/*
		 * This variable summarizes if the file is reasonably
		 * sequential/strided for prefetching to happen.
		 */
		int sequentiality;


		/*
		 * Connect with the corresponding UINODE if available
		 */
		struct u_inode *uinode;


		file_predictor(int this_fd, size_t size, const char *filename);

		/*Destructor*/
		~file_predictor();

		void predictor_update(off_t offset, size_t size);

		//Returns the current Sequentiality value
		long is_sequential();

		//returns the approximate stride in pages
		//0 if not strided. doesnt mean its not sequential
		long is_strided();

        /*
        * Returns true if it is time to prefetch for
        * the given access pattern etc on this fd
        */
        bool should_prefetch_now();
};

#endif //_PREDICTOR_HPP
