#define _GNU_SOURCE         /* See feature_test_macros(7) */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <sys/resource.h>

#define __NR_start_crosslayer 448

#define ENABLE_FILE_STATS 1
#define DISABLE_FILE_STATS 2
#define CLEAR_GLOBAL_STATS 3
#define PRINT_GLOBAL_STATS 4

long start_cross_trace(int flag, int val)
{
        return syscall(__NR_start_crosslayer, flag, val);
}


int main(){

	printf("CLEAR_GLOBAL_STATS in %s\n", __func__);
        start_cross_trace(CLEAR_GLOBAL_STATS, 0);

        return 0;
}
