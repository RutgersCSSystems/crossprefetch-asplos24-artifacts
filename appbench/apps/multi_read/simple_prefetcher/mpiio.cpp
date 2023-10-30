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
#include <sys/types.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <sys/resource.h>

#ifdef ENABLE_MPI
#include <mpi.h>
#endif


//#include "util.hpp"
//#include "shim.hpp"
//#include "frontend.hpp"
//#include "utils/robin_hood.h"


#if 0 //Uncompleted port functions
MPI_Abort
U MPI_Alloc_mem
U MPI_Allreduce
U MPI_Barrier
U MPI_Bcast
U MPI_Cancel
U MPI_Cart_create
U MPI_Cart_get
U MPI_Comm_free
U MPI_Comm_rank
U MPI_Comm_size
U MPI_Comm_split
U MPI_File_close
U MPI_File_get_size
U MPI_File_open
U MPI_File_read_at
U MPI_File_read_at_all_begin
U MPI_File_read_at_all_end
U MPI_File_set_atomicity
U MPI_File_set_errhandler
U MPI_File_set_size
U MPI_File_set_view
U MPI_File_sync
U MPI_File_write_at
U MPI_Finalize
U MPI_Free_mem
U MPI_Get_address
U MPI_Get_count
U MPI_Get_processor_name
U MPI_Ibarrier
U MPI_Init
U MPI_Isend
U MPI_Recv_init
U MPI_Send
U MPI_Start
U MPI_Test
U MPI_Testany
U MPI_Type_commit
U MPI_Type_create_hindexed
U MPI_Type_free
U MPI_Wait
U MPI_Waitall
#endif //Uncompleted port functions
