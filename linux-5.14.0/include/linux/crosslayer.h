#ifndef _LINUX_CROSSLAYER_H
#define _LINUX_CROSSLAYER_H

//#include <linux/fs.h>

struct file_pfetch_state;
struct readahead_control;
struct inode;
struct read_ra_req;

/**
 * struct file_pfetch_state - track a file's prefetch stats.
 *
 */
struct file_pfetch_state {
    spinlock_t spinlock;
    /*vars updated only on force_page_cache_ra*/
    bool enable_f_stats;

    /*Global Read Cache-hits stats*/
    unsigned long nr_pages_read; //total bytes read in task's lifetime
    unsigned long nr_pages_hit; // total bytes already in PG_cache
    unsigned long nr_pages_miss; //total pages not in PG_cache
};


/*
 * User request for readaheads with read
 * see pread_ra SYSCALL in fs/read_write.c
 */
struct read_ra_req {
    loff_t ra_pos;
    size_t ra_count;
    
    /*The following are return values from the OS
     * Reset at recieving them
     */
    unsigned long nr_present; //nr pages present in cache
    unsigned long bio_req_nr;//nr pages requested bio for

//#ifdef CONFIG_CACHE_LIMITING
    long total_cache_usage; //total cache usage in bytes (OS return)
    bool full_file_ra; //populated by app true if pread_ra is being done to get full file
    long cache_limit; //populated by the app, desired cache_limit
//#endif
//
    unsigned long nr_free; //nr pages that are free in memory
    
//#ifdef CONFIG_CROSS_FILE_BITMAP
    /*
     * The following are populated by the kernel
     * and returned to user space
     */
    unsigned long *data;  //page bitmap for readahead file
    unsigned long nr_relevant_ulongs; //number of longs in bitmap relevant for the file
//#endif
};


void init_global_pfetch_state(void);

void init_file_pfetch_state(struct file_pfetch_state *pfetch_state);

//void update_read_cache_stats(struct inode *inode, unsigned long index, 
void update_read_cache_stats(struct inode *inode, struct file *filp, unsigned long index, 
                unsigned long nr_pages);

void print_task_stats(struct task_struct *task);
void print_inode_stats(struct inode *inode);
void print_global_stats(void);

#ifdef CONFIG_CACHE_LIMITING
void cache_limit_cons(void);
void cache_limit_dest(void);
void cache_limit_reset(void);
long cache_usage_ret(void);
void cache_usage_increase(int nr_pages);
void cache_usage_reduce(int nr_pages);
#endif

void setup_cross_interface(void);

#endif
