#ifndef _SHIM_HPP
#define _SHIM_HPP
/*The following are the intercepted function definitions*/
typedef int (*real_open_t)(const char *, int, ...);
typedef int (*real_openat_t)(int, const char *, int, ...);
typedef int (*real_creat_t)(const char *, mode_t);
typedef FILE *(*real_fopen_t)(const char *, const char *);

typedef ssize_t (*real_read_t)(int, void *, size_t);
typedef ssize_t (*real_pread_t)(int, void *, size_t, off_t);
typedef size_t (*real_fread_t)(void *, size_t, size_t,FILE *);

typedef char *(*real_fgets_t)(char *, int, FILE *);
typedef ssize_t (*real_write_t)(int, const void *, size_t);
typedef size_t (*real_fwrite_t)(const void *, size_t, 
        size_t,FILE *);

typedef int (*real_fclose_t)(FILE *);
typedef int (*real_close_t)(int);
typedef uid_t (*real_getuid_t)(void);

typedef int (*real_posix_fadvise_t)(int, off_t, off_t, int);
typedef ssize_t (*real_readahead_t)(int, off64_t, size_t);
typedef int (*real_madvise_t)(void *, size_t, int);

typedef int (*real_clone_t)(int (void*), void *, int, void *, pid_t *, void *, pid_t *);

typedef void* (*real_mmap_t)(void *addr, size_t length, int prot, int flags,
                                  int fd, off_t offset);

real_fopen_t fopen_ptr = NULL;
real_open_t open_ptr = NULL;
real_openat_t openat_ptr = NULL;

real_pread_t pread_ptr = NULL;
real_read_t read_ptr = NULL;
real_fgets_t fgets_ptr = NULL;


real_write_t write_ptr = NULL;

real_fread_t fread_ptr = NULL;
real_fwrite_t fwrite_ptr = NULL;

real_fclose_t fclose_ptr = NULL;
real_close_t close_ptr = NULL;

real_clone_t clone_ptr = NULL;

/*Advise calls*/
real_posix_fadvise_t posix_fadvise_ptr = NULL;
real_readahead_t readahead_ptr = NULL;
real_madvise_t madvise_ptr = NULL;

real_mmap_t mmap_ptr = NULL;


/*MPI operations */
#ifdef ENABLE_MPI
#include <mpi.h>

typedef int (*real_MPI_File_open_t)(MPI_Comm, const char *, int, MPI_Info, MPI_File *);
typedef int (*real_MPI_File_read_at_all_end_t)(MPI_File, void *, MPI_Status *);
typedef int (*real_MPI_File_read_at_all_begin_t)(MPI_File, void *, MPI_Status *);
typedef int (*real_MPI_File_read_at_t)(MPI_File, MPI_Offset, void *, int, MPI_Datatype, MPI_Status *);


real_MPI_File_open_t MPI_File_open_ptr = NULL;
real_MPI_File_read_at_all_end_t MPI_File_read_at_all_end_ptr = NULL;
real_MPI_File_read_at_all_begin_t MPI_File_read_at_all_begin_ptr = NULL;
real_MPI_File_read_at_t MPI_File_read_at_ptr = NULL;
#endif



void link_shim_functions(void){

	clone_ptr = (real_clone_t)dlsym(RTLD_NEXT, "clone");
	posix_fadvise_ptr = (real_posix_fadvise_t)dlsym(RTLD_NEXT, "posix_fadvise");
	readahead_ptr = (real_readahead_t)dlsym(RTLD_NEXT, "readahead");
	madvise_ptr = (real_madvise_t)dlsym(RTLD_NEXT, "madvise");
	fopen_ptr = (real_fopen_t)dlsym(RTLD_NEXT, "fopen");
	fread_ptr = (real_fread_t)dlsym(RTLD_NEXT, "fread");
	fgets_ptr = (real_fgets_t)dlsym(RTLD_NEXT, "fgets");
	fwrite_ptr = (real_fwrite_t)dlsym(RTLD_NEXT, "fwrite");
	pread_ptr = (real_pread_t)dlsym(RTLD_NEXT, "pread");
	write_ptr = ((real_write_t)dlsym(RTLD_NEXT, "write"));
	read_ptr = (real_read_t)dlsym(RTLD_NEXT, "read");
	open_ptr = ((real_open_t)dlsym(RTLD_NEXT, "open"));
	openat_ptr = ((real_openat_t)dlsym(RTLD_NEXT, "openat"));
	fclose_ptr = ((real_fclose_t)dlsym(RTLD_NEXT, "fclose"));
	close_ptr = ((real_close_t)dlsym(RTLD_NEXT, "close"));

#ifdef ENABLE_MPI
	MPI_File_open_ptr = ((real_MPI_File_open_t)dlsym(RTLD_NEXT, "MPI_File_open"));
	MPI_File_read_at_all_end_ptr = ((real_MPI_File_read_at_all_end_t)dlsym(RTLD_NEXT, "MPI_File_read_at_all_end"));
	MPI_File_read_at_all_begin_ptr = ((real_MPI_File_read_at_all_begin_t)dlsym(RTLD_NEXT, "MPI_File_read_at_all_begin"));
	MPI_File_read_at_ptr = ((real_MPI_File_read_at_t)dlsym(RTLD_NEXT, "MPI_File_read_at"));;
#endif

	debug_printf("done with %s\n", __func__);
	return;
}

#ifdef ENABLE_MPI
int real_MPI_File_read_at_all_end(MPI_File fh, void *buf, MPI_Status *status){
    if(!MPI_File_read_at_all_end_ptr)
    	MPI_File_read_at_all_end_ptr = (real_MPI_File_read_at_all_end_t)dlsym(RTLD_NEXT, "MPI_File_read_at_all_end");

    return ((real_MPI_File_read_at_all_end_t)MPI_File_read_at_all_end_ptr)(fh, buf, status);

}

int real_MPI_File_read_at_all_begin(MPI_File fh, void *buf, MPI_Status *status){
    if(!MPI_File_read_at_all_begin_ptr)
    	MPI_File_read_at_all_begin_ptr = (real_MPI_File_read_at_all_begin_t)dlsym(RTLD_NEXT, "MPI_File_read_at_all_begin");

    return ((real_MPI_File_read_at_all_begin_t)MPI_File_read_at_all_begin_ptr)(fh, buf, status);

}


int real_MPI_File_open(MPI_Comm comm, const char *filename, int amode, MPI_Info info, MPI_File *fh) {

    if(!MPI_File_open_ptr)
    	MPI_File_open_ptr = (real_MPI_File_open_t)dlsym(RTLD_NEXT, "MPI_File_open");

    return ((real_MPI_File_open_t)MPI_File_open_ptr)(comm, filename, amode, info, fh);

}
#endif


int real_clone(int (*fn)(void *), void *child_stack, int flags, void *arg,
        pid_t *ptid, void *newtls, pid_t *ctid){
    if(!clone_ptr)
        clone_ptr = (real_clone_t)dlsym(RTLD_NEXT, "clone");

    return ((real_clone_t)clone_ptr)(fn, child_stack, flags, arg, ptid, newtls, ctid);

}

int real_posix_fadvise(int fd, off_t offset, off_t len, int advice){

	debug_printf("%s\n", __func__);

    if(!posix_fadvise_ptr)
        posix_fadvise_ptr = (real_posix_fadvise_t)dlsym(RTLD_NEXT, "posix_fadvise");

    return ((real_posix_fadvise_t)posix_fadvise_ptr)(fd, offset, len, advice);
}

ssize_t real_readahead(int fd, off_t offset, size_t count){
    if(!readahead_ptr)
        readahead_ptr = (real_readahead_t)dlsym(RTLD_NEXT, "readahead");

    return ((real_readahead_t)readahead_ptr)(fd, offset, count);
}

int real_madvise(void *addr, size_t length, int advice){
    if(!madvise_ptr)
        madvise_ptr = (real_madvise_t)dlsym(RTLD_NEXT, "madvise");

    return ((real_madvise_t)madvise_ptr)(addr, length, advice);
}


void* real_mmap(void *addr, size_t length, int prot, int flags,
        int fd, off_t offset) {

    if(!mmap_ptr)
        mmap_ptr = (real_mmap_t)dlsym(RTLD_NEXT, "mmap");

    return ((real_mmap_t)mmap_ptr)(addr, length, prot, flags, fd, offset);

}

FILE *real_fopen(const char *filename, const char *mode){

	debug_printf("%s:%d filen: %s\n", __func__, __LINE__, filename);

    if(!fopen_ptr)
        fopen_ptr = (real_fopen_t)dlsym(RTLD_NEXT, "fopen");

    return ((real_fopen_t)fopen_ptr)(filename, mode);
}

size_t real_fread(void *ptr, size_t size, size_t nmemb, FILE *stream){

    debug_printf("%s %zu\n", __func__, size);

    if(!fread_ptr)
        fread_ptr = (real_fread_t)dlsym(RTLD_NEXT, "fread");

    return ((real_fread_t)fread_ptr)(ptr, size, nmemb, stream);
}

/*Several applications use fgets*/
char *real_fgets( char *str, int num, FILE *stream ) {

	debug_printf("%s %d\n", __func__, num);

    if(!fgets_ptr)
        fgets_ptr = (real_fgets_t)dlsym(RTLD_NEXT, "fgets");

    return ((real_fgets_t)fgets_ptr)(str, num, stream);
}



size_t real_fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream){

    if(!fwrite_ptr)
        fwrite_ptr = (real_fwrite_t)dlsym(RTLD_NEXT, "fwrite");

    return ((real_fwrite_t)fwrite_ptr)(ptr, size, nmemb, stream);
}

ssize_t real_pread(int fd, void *data, size_t size, off_t offset){

    debug_printf("%s %zu\n", __func__, size);

    if(!pread_ptr)
        pread_ptr = (real_pread_t)dlsym(RTLD_NEXT, "pread");


    return ((real_pread_t)pread_ptr)(fd, data, size, offset);
}

ssize_t real_write(int fd, const void *data, size_t size) {

	debug_printf("Using real write %zu\n", size);

    if(!write_ptr)
        write_ptr = ((real_write_t)dlsym(RTLD_NEXT, "write"));


    return ((real_write_t)write_ptr)(fd, data, size);
}

ssize_t real_read(int fd, void *data, size_t size) {

	debug_printf("%s %zu\n", __func__, size);

    if(!read_ptr)
        read_ptr = (real_read_t)dlsym(RTLD_NEXT, "read");

    
    return ((real_read_t)read_ptr)(fd, data, size);
}

int real_openat(int dirfd, const char *pathname, int flags, mode_t mode){
    if(!openat_ptr)
        openat_ptr = ((real_openat_t)dlsym(RTLD_NEXT, "openat"));

    return ((real_openat_t)openat_ptr)(dirfd, pathname, flags, mode);
}

int real_open(const char *pathname, int flags, mode_t mode){

     debug_printf("%s\n", __func__);

    if(!open_ptr)
        open_ptr = ((real_open_t)dlsym(RTLD_NEXT, "open"));

    return ((real_open_t)open_ptr)(pathname, flags, mode);
}

int real_fclose(FILE *stream){
    if(!fclose_ptr)
        fclose_ptr = ((real_fclose_t)dlsym(RTLD_NEXT, "fclose"));
    return ((real_fclose_t)fclose_ptr)(stream);
}

int real_close(int fd){
    if(!close_ptr)
        close_ptr = ((real_close_t)dlsym(RTLD_NEXT, "close"));
    return ((real_close_t)close_ptr)(fd);
}

uid_t real_getuid(){
        return ((real_getuid_t)dlsym(
                    RTLD_NEXT, "getuid"))();
}


#endif
