#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt

#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/backing-dev.h>
#include <linux/mm.h>
#include <linux/mm_inline.h>
#include <linux/mmzone.h>
#include <linux/vmacache.h>
#include <linux/shm.h>
#include <linux/mman.h>
#include <linux/pagemap.h>
#include <linux/swap.h>
#include <linux/syscalls.h>
#include <linux/capability.h>
#include <linux/init.h>
#include <linux/file.h>
#include <linux/personality.h>
#include <linux/security.h>
#include <linux/hugetlb.h>
#include <linux/shmem_fs.h>
#include <linux/profile.h>
#include <linux/export.h>
#include <linux/mount.h>
#include <linux/mempolicy.h>
#include <linux/rmap.h>
#include <linux/mmu_notifier.h>
#include <linux/mmdebug.h>
#include <linux/perf_event.h>
#include <linux/audit.h>
#include <linux/khugepaged.h>
#include <linux/uprobes.h>
#include <linux/rbtree_augmented.h>
#include <linux/notifier.h>
#include <linux/memory.h>
#include <linux/printk.h>
#include <linux/userfaultfd_k.h>
#include <linux/moduleparam.h>
#include <linux/pkeys.h>
#include <linux/oom.h>
#include <linux/jiffies.h>
#include <linux/proc_fs.h>
#include <linux/sched.h>
#include <asm/uaccess.h>

#include <linux/btree.h>
#include <linux/radix-tree.h>
#include <linux/bitmap.h>

#include <linux/buffer_head.h>
#include <linux/jbd2.h>

#include <linux/uaccess.h>
#include <asm/cacheflush.h>
#include <asm/tlb.h>
#include <asm/atomic.h>
#include <asm/mmu_context.h>
//#include <linux/pfn_trace.h>
#include <net/sock.h>
#include <linux/migrate.h>
//#include <sys/time.h>
#include <linux/time64.h>
#include <linux/fs.h>

#include <linux/cross_bitmap.h>


#include "internal.h"

#define ENABLE_FILE_STATS 1
#define DISABLE_FILE_STATS 2
#define RESET_GLOBAL_STATS 3
#define PRINT_GLOBAL_STATS 4
#define CACHE_USAGE_CONS 5
#define CACHE_USAGE_DEST 6
#define CACHE_USAGE_RET 7
#define CACHE_USAGE_RESET 8
#define WALK_PAGECACHE 9

#define CROSS_PRINT_JIFFY 2000

struct file_pfetch_state global_counts; //global counters

atomic_t setup_cross_procfs = ATOMIC_INIT(-1);
#define BUFSIZE 100
/*
 * This variable changes behaviour of reads and readaheads
 * if 1 -> no read and readahead limits apply
 * if 0 -> vanilla read and readahead limits apply
 */
int enable_unbounded = 0;

/*
 * This variable changes behaviour of readaheads (force_page_cache_ra)
 * if 1 -> the whole readahead request is sent at once
 * if 0 -> the readahead request is sent in 2MB chunks
 */
int disable_2mb_limit = 0; 

/*
 * This variable changes the size of bitmaps being allocated.
 * value == 0 means it has not been set.
 * value == x means bitmap size will support 2^x filesize
 */
int cross_bitmap_shift = 0;

#ifdef CONFIG_CACHE_LIMITING
/*
 * This config counts nr of cache pages
 * for a given subset of task_structs
 */
atomic_long_t cache_usage; //nr_pages
atomic_long_t nr_procs; //nr_procs limiting cache usage
/*
 * to be called in the constructor of the 
 * application of interest
 */
void cache_limit_cons(void){
        if(!current->mm)
                return;

        if(!current->do_cache_acct){
                current->do_cache_acct = true;
                atomic_long_add(1UL, &nr_procs);
        }
        return;
}
EXPORT_SYMBOL(cache_limit_cons);


/*
 * To be called at destructor
 */
void cache_limit_dest(void){
        if(!current->mm)
                return;

        long nr = -1;

        if(current->do_cache_acct){
                current->do_cache_acct = false;
                nr = atomic_long_sub_return(1UL, &nr_procs);

                if(!nr){
                        /*if no process left, reset cache usage*/
                        printk("%s: total cache usage at the end = %ld\n", 
                                        __func__, cache_usage_ret());
                        cache_limit_reset();
                }
        }

        return;
}
EXPORT_SYMBOL(cache_limit_dest);

/*To be called at system boot*/
void cache_limit_reset(void){
        atomic_long_set(&cache_usage, 0UL);
        atomic_long_set(&nr_procs, 0UL);
}
EXPORT_SYMBOL(cache_limit_reset);

/*reduces cache usage by nr_pages*/
void cache_usage_reduce(int nr_pages){
        if(!current->mm)
                return;

        if(current->do_cache_acct){
                atomic_long_sub(nr_pages, &cache_usage);
        }
        return;
}
EXPORT_SYMBOL(cache_usage_reduce);

/*increases cache usage by nr_pages*/
void cache_usage_increase(int nr_pages){
        if(!current->mm)
                return;

        if(current->do_cache_acct){
                atomic_long_add(nr_pages, &cache_usage);
        }
        return;
}
EXPORT_SYMBOL(cache_usage_increase);

/*returns the current cache usage*/
long cache_usage_ret(void){
        return atomic_long_read(&cache_usage);
}
EXPORT_SYMBOL(cache_usage_ret);
#endif



void init_file_pfetch_state(struct file_pfetch_state *pfetch_state){

        spin_lock_init(&pfetch_state->spinlock);

        spin_lock(&pfetch_state->spinlock);

        pfetch_state->enable_f_stats = 0;
        pfetch_state->nr_pages_read = 0;
        pfetch_state->nr_pages_hit = 0;
        pfetch_state->nr_pages_miss = 0;

        spin_unlock(&pfetch_state->spinlock);

}
EXPORT_SYMBOL(init_file_pfetch_state);

/*
 * update_read_cache_stats uses the per inode bitmap
 *
 */
void update_read_cache_stats(struct inode *inode, struct file *filp, unsigned long index, 
                unsigned long nr_pages)
{

        if(!current->mm || !inode)
                goto err;

        if(!inode->bitmap)
                goto err;

        unsigned long nr_misses;
        unsigned long i;

        nr_misses = 0;

        for(i=0; i<nr_pages; i++){
                if(!is_set_cross_bitmap(inode, index+i))
                        nr_misses += 1;
        }


        /*
        printk("%s: %s:%s:%ld index=%ld, nr_reads=%ld, nr_misses=%ld\n", 
                        __func__, current->comm, filp->f_path.dentry->d_iname,
                        inode->i_ino, index, nr_pages, nr_misses);
        */

        /*
         * Update global counters
         */
        spin_lock(&global_counts.spinlock);

        global_counts.nr_pages_read += nr_pages;
        global_counts.nr_pages_hit += nr_pages - nr_misses;
        global_counts.nr_pages_miss += nr_misses;

        spin_unlock(&global_counts.spinlock);

        /*
         * Update per-proc counters
         */

        if(!current->cross_stats_enabled)
                goto err;

        spin_lock(&current->pfetch_state.spinlock);

        current->pfetch_state.nr_pages_read += nr_pages;
        current->pfetch_state.nr_pages_hit += nr_pages - nr_misses;
        current->pfetch_state.nr_pages_miss += nr_misses;

        spin_unlock(&current->pfetch_state.spinlock);

        /*
         * Update per-inode data structures
         */
        spin_lock(&inode->pfetch_state.spinlock);
        inode->pfetch_state.enable_f_stats = true;
        inode->pfetch_state.nr_pages_read += nr_pages;
        inode->pfetch_state.nr_pages_hit += nr_pages - nr_misses;
        inode->pfetch_state.nr_pages_miss += nr_misses;
        spin_unlock(&inode->pfetch_state.spinlock);

err:
        return;
}
EXPORT_SYMBOL(update_read_cache_stats);


/*TODO*/
void print_inode_stats(struct inode *inode){

        return;

        if(!inode)
                goto err;

        struct file_pfetch_state *pfstate = &inode->pfetch_state;

        if(!pfstate || !pfstate->enable_f_stats)
                goto err;

        if(!current->mm || !current->cross_stats_enabled)
                goto err;


        char *f_name = kmalloc(NAME_MAX+1, GFP_KERNEL);
        char *name = dentry_path_raw(inode->i_sb->s_root, f_name, NAME_MAX);

        printk("FinalFileReport: %s - nr_pages_read:%lu, nr_pages_hit:%lu \
                        nr_pages_miss:%lu\n",
                        name, pfstate->nr_pages_read,
                        pfstate->nr_pages_hit, pfstate->nr_pages_miss);

        kfree(f_name);
err:
        return;
}
EXPORT_SYMBOL(print_inode_stats);


/*TODO*/
void print_task_stats(struct task_struct *task){

        if(!task || !task->mm || !task->cross_stats_enabled)
                goto err;


        struct file_pfetch_state *pfstate = &task->pfetch_state; 

        printk("FinalTaskReport:%s:%d nr_pages_read:%lu, nr_pages_hit:%lu, nr_pages_miss:%lu\n",
                        task->comm, task->pid, pfstate->nr_pages_read,
                        pfstate->nr_pages_hit, pfstate->nr_pages_miss);

err:
        return;
}
EXPORT_SYMBOL(print_task_stats);


/*
 * Prints the final total global stats; at the end of the app run
 */
void print_final_global_stats(void){
        printk("Final GlobalReport: nr_pages_read:%lu, nr_pages_hit:%lu, nr_pages_miss:%lu\n", 
                        global_counts.nr_pages_read, global_counts.nr_pages_hit, 
                        global_counts.nr_pages_miss);

        return;
}
EXPORT_SYMBOL(print_final_global_stats);


void init_global_pfetch_state(void){
        init_file_pfetch_state(&global_counts);
}


/*
 * write procfs file for updating values in kernel
 */
static ssize_t write_proc_unbounded(struct file *filp, const char __user *buffer,
                size_t len, loff_t * offset)
{
        int length = 0;
        char buf[BUFSIZE];

        if(*offset > 0 || len > BUFSIZE){
                return -EFAULT;
        }

        if(copy_from_user(buf, buffer, len)){
                return -EFAULT;
        }


        sscanf(buf, "%d", &enable_unbounded);
        printk("%s: Value of write = %d\n", __func__, enable_unbounded);

        return len;
}


/*
 * read procfs file for showing to userspace
 */
static ssize_t read_proc_unbounded(struct file *filp, char __user *buffer,
                size_t len, loff_t * offset)
{
        printk(KERN_INFO "%s: proc file read\n", __func__);

        int length = 0;
        char buf[BUFSIZE];
        if(*offset > 0 || len < BUFSIZE){
                return 0;
        }

        length += sprintf(buf, "%d\n", enable_unbounded);

        if(copy_to_user(buffer, buf, length)){
                return -EFAULT;
        }
        *offset = len;
        return len;
}

/*
 * write procfs file for updating values in kernel
 */
static ssize_t write_proc_2mb_limit(struct file *filp, const char __user *buffer,
                size_t len, loff_t * offset)
{
        int length = 0;
        char buf[BUFSIZE];

        if(*offset > 0 || len > BUFSIZE){
                return -EFAULT;
        }

        if(copy_from_user(buf, buffer, len)){
                return -EFAULT;
        }


        sscanf(buf, "%d", &disable_2mb_limit);
        printk("%s: Value of write = %d\n", __func__, disable_2mb_limit);

        return len;
}


/*
 * read procfs file for showing to userspace
 */
static ssize_t read_proc_2mb_limit(struct file *filp, char __user *buffer,
                size_t len, loff_t * offset)
{
        printk(KERN_INFO "%s: proc file read \n", __func__);

        int length = 0;
        char buf[BUFSIZE];
        if(*offset > 0 || len < BUFSIZE){
                return 0;
        }

        length += sprintf(buf, "%d\n", disable_2mb_limit);

        if(copy_to_user(buffer, buf, length)){
                return -EFAULT;
        }
        *offset = len;
        return len;
}


/*
 * write procfs file for updating value of bitmap_shift in kernel
 * Max value of cross_bitmap_shift can be set to 128 since chars are being used
 */
static ssize_t write_proc_bitmap_shift(struct file *filp, const char __user *buffer,
                size_t len, loff_t * offset)
{
        int length = 0;
        char buf[BUFSIZE];

        if(*offset > 0 || len > BUFSIZE){
                return -EFAULT;
        }

        if(copy_from_user(buf, buffer, len)){
                return -EFAULT;
        }


	/*
	 * ignore this warning of type mismatch.
	 */
        sscanf(buf, "%c", &cross_bitmap_shift);

	if(cross_bitmap_shift < 0)
		cross_bitmap_shift = 0;

        printk("%s: Value of write = %d\n", __func__, cross_bitmap_shift);

        return len;
}


/*
 * read procfs file for showing to userspace
 */
static ssize_t read_proc_bitmap_shift(struct file *filp, char __user *buffer,
                size_t len, loff_t * offset)
{
        printk(KERN_INFO "%s: proc file read \n", __func__);

	/*
	 * Set default if cross_bitmap_shift is not set by userspace
	 */
	if(cross_bitmap_shift <= 0){
		cross_bitmap_shift = CONFIG_CROSS_PREALLOC_SHIFT;
                printk("%s: cross_bitmap_shift = %d\n", __func__, cross_bitmap_shift);
	}

        int length = 0;
        char buf[BUFSIZE];
        if(*offset > 0 || len < BUFSIZE){
                return 0;
        }

        length += sprintf(buf, "%d\n", cross_bitmap_shift);

        if(copy_to_user(buffer, buf, length)){
                return -EFAULT;
        }
        *offset = len;
        return len;
}

/*
 * This procfs interface controls the limits inside the kernel
 * right now it only enables and disables unbounded read/readaheads
 * check /proc/unbounded_read
 */
void setup_cross_interface(void){

        if(atomic_inc_and_test(&setup_cross_procfs)){
                printk("%s : inside setup procfs\n", __func__);
                static struct proc_ops proc_fops_unbounded = {
                        .proc_read = read_proc_unbounded,
                        .proc_write = write_proc_unbounded,
                };
                proc_create("unbounded_read", 0666, NULL, &proc_fops_unbounded);

                static struct proc_ops proc_fops_2mb_limit= {
                        .proc_read = read_proc_2mb_limit,
                        .proc_write = write_proc_2mb_limit,
                };
                proc_create("disable_2mb_limit", 0666, NULL, &proc_fops_2mb_limit);

                static struct proc_ops proc_fops_bitmap_shift= {
                        .proc_read = read_proc_bitmap_shift,
                        .proc_write = write_proc_bitmap_shift,
                };
                proc_create("cross_bitmap_shift", 0666, NULL, &proc_fops_bitmap_shift);
        }
        return;
}
EXPORT_SYMBOL(setup_cross_interface);


//Syscall Nr: 448
SYSCALL_DEFINE2(start_cross_trace, int, flag, int, val){

#ifdef CONFIG_ENABLE_CROSS_STATS
        switch(flag){
                case ENABLE_FILE_STATS:
                        /* Enable per-process cross-layer flag */
                        current->cross_stats_enabled = true;
                        printk("Enabled file stats for %s:%d\n", current->comm, current->pid);
                        break;
                case DISABLE_FILE_STATS:
                        current->cross_stats_enabled = false;
                        printk("Disabled file stats for %s:%d\n", current->comm, current->pid);
                        break;
                case RESET_GLOBAL_STATS:
                        init_global_pfetch_state();
                        printk("%s: RESET_GLOBAL_STATS \n", __func__);
                        break;
                case PRINT_GLOBAL_STATS:
                        printk("%s: PRINT_GLOBAL_STATS \n", __func__);
                        print_final_global_stats();
                        break; 
#ifdef CONFIG_CACHE_LIMITING
                case CACHE_USAGE_CONS:
                        cache_limit_cons();
                        printk("%s:Enabled cache limiting for %s:%d\n", __func__, current->comm, current->pid);
                        break;
                case CACHE_USAGE_DEST:
                        cache_limit_dest();
                        printk("%s: Disabled cache limiting for %s:%d\n", __func__, current->comm, current->pid);
                        break;
                case CACHE_USAGE_RET:
                        return cache_usage_ret();
                        break;
                case CACHE_USAGE_RESET:
                        cache_limit_reset();
                        printk("%s: Resetting the values\n", __func__);
                        break;
                case WALK_PAGECACHE:
                        //This will walk the page cache for a given fd and return the
                        //number of populated pages in the page cache
                        printk("%s: NR of pages in PC for FD=%d = %ld \n", __func__, val, 
                                        filemap_walk_pagecache(val));
                        break;
#endif
                default:
                        /* Enable per-process cross-layer flag */
                        current->cross_stats_enabled = true;
                        printk("Flag value undefined %d\n", flag);
                        /* 
                         * BUG FIX: We cannot return and break!!!
                         */
                        return -1;
        }
#endif
        return 0;
}
