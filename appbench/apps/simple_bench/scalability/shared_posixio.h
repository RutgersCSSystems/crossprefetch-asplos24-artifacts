#ifndef DEVFS_CLIENT_H_
#define DEVFS_CLIENT_H_

#define PAGE_SIZE 4096
#define DATA_SIZE 4096
#define QSIZE 409600
#define BLOCKSIZE 512
#define TEST "/users/Jian123/ssd/ioopt/shared_libs/simple_prefetcher/benchmarks/DATA/test"
#if defined(_KERNEL_TESTING)
	#define OPSCNT 1
#else
	//#define OPSCNT 1024
	//#define OPSCNT 3145728
	#define OPSCNT 524288
	//#define OPSCNT 1048576
#endif
#define CREATDIR O_RDWR | O_CREAT //| O_TRUNC
#define READIR O_RDWR
//#define CREATDIR O_RDWR|O_CREAT|O_TRUNC //|O_DIRECT
#define MODE S_IRWXU //S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH

#define WRITER_CNT 1
#define READER_CNT 4
 
#define MAX_SLBA 16*1024*1024*1024L
#define GB 1024*1024L*1024L;

typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

enum nvme_opcode {
    nvme_cmd_flush          = 0x00,
    nvme_cmd_write          = 0x01,
    nvme_cmd_read           = 0x02,
    nvme_cmd_lseek          = 0x03, 	
    nvme_cmd_write_uncor    = 0x04,
    nvme_cmd_compare        = 0x05,
    nvme_cmd_append         = 0x07,
    nvme_cmd_write_zeroes   = 0x08,
    nvme_cmd_dsm            = 0x09,
    nvme_cmd_digest		= 0x0a,
    nvme_cmd_resv_register  = 0x0d,
    nvme_cmd_resv_report    = 0x0e,
    nvme_cmd_resv_acquire   = 0x11,
    nvme_cmd_resv_release   = 0x15,
    nvme_cmd_close		= 0x20,
};


#endif /*DEVFS_CLIENT_H_ */

