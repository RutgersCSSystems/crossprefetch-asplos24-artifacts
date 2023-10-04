#ifndef _LINUX_CROSS_BITMAP_H
#define _LINUX_CROSS_BITMAP_H

//void *cross_test(void);

void alloc_cross_bitmap(struct inode *inode, unsigned long nr_pages);

void free_cross_bitmap(struct inode *inode);

void remove_pg_cross_bitmap(struct inode *inode, pgoff_t index);

void add_pg_cross_bitmap(struct inode *inode, pgoff_t start_index, unsigned long nr_pages);

bool is_set_cross_bitmap(struct inode *inode, pgoff_t index);

void init_inode_cross(struct inode *inode);
#endif
