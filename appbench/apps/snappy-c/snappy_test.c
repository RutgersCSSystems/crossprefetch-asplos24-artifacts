#include <assert.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/time.h>
#include <pthread.h> 
#include "thpool.h"

#include "snappy.h"

#ifdef _POSIX
#define OUTPUT_DIR "output_dir/"
#else
#define OUTPUT_DIR "output_dir/"
#endif
#define FILEPERM 0666

static int use_mmap;
static int use_nvmalloc;

char g_buf[4096];

size_t g_tot_input_bytes = 0;
size_t g_tot_output_bytes = 0;
static int g_snappy_init = 0;
struct snappy_env g_snappy_env;
double compress_time=0;
int g_completed=0;

threadpool workerpool = NULL;

struct thrd_cntxt {
    int id;
	struct snappy_env env;	
	char *in_path;
	char *out_path;
	size_t tot_input_bytes;
	size_t tot_output_bytes;
};
struct thrd_cntxt *cntxt = NULL;



double simulation_time(struct timeval start, struct timeval end) {
        double current_time;
        current_time = ((end.tv_sec + end.tv_usec * 1.0 / 1000000) -
                        (start.tv_sec + start.tv_usec * 1.0 / 1000000));
        return current_time;
}

FILE *cls_file;
static char *ReadFromFile(int cntr, size_t *size, char *filename,
                          char *read_dir) {
        char *input = NULL;
        size_t bytes = 0;
        FILE *fp = NULL;
        char filearr[512];
        char *nvptr = NULL;
        size_t fsize = 0;

        cls_file = NULL;
        if (strlen(filename) < 4) return NULL;
        bzero(filearr, 512);
        strcpy(filearr, read_dir);
        strcat(filearr, "/");
        strcat(filearr, filename);

        fp = fopen(filearr, "r");
        if (fp == NULL) {
                fprintf(stdout, "open failed for %s \n", filearr);
                return NULL;
        }

	int fd=fileno(fp);
	posix_fadvise(fd, 0, 0, POSIX_FADV_SEQUENTIAL);  // Or use another advice option


        cls_file = fp;
        fseek(fp, 0L, SEEK_END);
        fsize = ftell(fp);
        fseek(fp, 0, SEEK_SET);
        if (fsize < 1) {
                *size = 0;
                return NULL;
        }

        input = (char *)malloc(fsize);
        bytes = 0;
        while(bytes < fsize){
        	bytes += fread(input+bytes, 1, fsize, fp);
	}
        if(!bytes) {
        	fprintf(stdout, "invalid input data %s", filearr);
            *size = 0;
            free(input);
            input = NULL;
            return NULL;
        }
        *size = bytes;

	posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);

        fclose(fp);
        return input;
}


unsigned long tot_time = 0;
struct timeval start_io, end_io;

void WritetoFile(char *str, char *filename, size_t len) {
        FILE *fp = fopen(filename, "wb");
        if (fp == NULL) {
                perror(filename);
                exit(1);
        }
        int ret = fwrite(str, len, 1, fp);
        if (ret != 1) {
                perror("fwrite");
                exit(1);
        }
        fclose(fp);
}


#ifndef _USE_THREADING
static void CompressData(char *read_dir) {
#else
static void CompressData(void *cntxt) {
#endif

    int cntr = 0;
    FILE *fp;
    char buffer[1024];
    char output_dir[1024];
    size_t outsz = 0;
    FILE *outfp = NULL;
    size_t datasize;
    struct timeval t0,t1;
    long diff;
    struct snappy_env local_env = g_snappy_env;


#ifdef _USE_THREADING
	struct thrd_cntxt *thrdcntxt = (struct thrd_cntxt *)cntxt;
	char *read_dir = thrdcntxt->in_path;

	local_env = thrdcntxt->env;
	strcpy(output_dir, thrdcntxt->out_path);
#else
        /* Create output dir for compressed files */
        mkdir(OUTPUT_DIR, 0755);
        strcpy(output_dir, OUTPUT_DIR);
#endif
        DIR *mydir = opendir(read_dir);
        struct dirent *entry = NULL;

        assert(mydir);
        entry = readdir(mydir);
        assert(entry);

        /*
         * if snappy compression environment variable is not set,
         * then initialize it.
         */
        while ((entry = readdir(mydir)) != NULL) {
                char *output = NULL;
                char *input = NULL;
                char fname[1024];

                cls_file = NULL;
                if (entry->d_type == DT_DIR) 
                	//goto next;
                	continue;

                if (strlen(entry->d_name) < 4) 
                	//goto next;
                	continue;

#ifdef _ENABLE_TIMER
                gettimeofday(&start_t, NULL);
#endif
                input = NULL;
#ifdef _POSIX
                input = ReadFromFile(cntr, &datasize, entry->d_name, read_dir);
#else
                input = ReadFromFile_Devfs(cntr, &datasize, entry->d_name, read_dir);
#endif
                if (!input) {
                        fprintf(stdout,"failed %s \n",entry->d_name);
                        continue;
                }

                if (!datasize) 
			continue;

                bzero(fname, 1024);
                strcpy(fname, (char *)output_dir);
                strcat(fname, entry->d_name);
                strcat(fname, ".comp");
                output = (char *)malloc(datasize * 2);
                assert(output);

                g_tot_input_bytes += datasize;
#ifdef _USE_THREADING
                thrdcntxt->tot_input_bytes += datasize;
#endif
                if (snappy_compress(&local_env, (const char *)input, datasize, output, &outsz) != 0) {
                        printf("compress failed\n");
                }
                if (!use_mmap && !use_nvmalloc) {
                    if (input) {
                    	free(input);
                        input = NULL;
                    }
                }
                g_tot_output_bytes += outsz;

#ifdef _USE_THREADING
                thrdcntxt->tot_output_bytes += outsz;
#endif
		/*Writes to output file and compresses data*/
                if (output && outsz && entry) {
                        WritetoFile(output, fname, outsz);
                }

                if (output) {
                       free(output);
                       output = NULL;
                }

                if (input) {
                       free(input);
                       input = NULL;
                }
#ifdef _ENABLE_TIMER
                gettimeofday(&end_t, NULL);
                compress_time += simulation_time(start_t, end_t);
#endif
        }
	g_completed++;
}



void generate_path(struct thrd_cntxt *cntxt, char *str, int tdx) 
{
	int pathlen = 0;

	cntxt->in_path = (char *)malloc(1024);
	cntxt->out_path = (char *)malloc(1024);
	//memset(cntxt->in_path, '0', 1024);
	//memset(cntxt->out_path, '0', 1024);
	strcpy(cntxt->in_path, (char*)str);
	strcat(cntxt->in_path,"/");

	strcpy(cntxt->out_path, (char*)str);
	mkdir(cntxt->out_path, 0755);

	strcat(cntxt->out_path,"/OUT");

	pathlen = strlen(cntxt->in_path);
	sprintf(cntxt->in_path+pathlen,"%d",tdx);

	pathlen = strlen(cntxt->out_path);
	sprintf(cntxt->out_path+pathlen,"%d",tdx);

	mkdir(cntxt->out_path, 0755);
	strcat(cntxt->out_path,"/");
	//fprintf(stderr, "OUTPUT %s \n", cntxt->out_path);
}


void thread_perform_compress(char *str, int numthreads) {

    struct timeval start, end;
    double sec = 0;

#ifdef _USE_THREADING

	int tdx = 0;
    workerpool = thpool_init(numthreads);
    if(!workerpool){
        printf("%s:FAILED creating thpool with %d threads\n", __func__, numthreads);
		exit(0);
    }
    else{
        fprintf(stderr, "Created %d bg_threads\n", numthreads);
    }

	cntxt = (struct thrd_cntxt *)malloc(sizeof(struct thrd_cntxt) * numthreads);
	if(!cntxt) {
		fprintf(stderr, "Thread allocation failed \n");
		return;
	}
#endif

	for (tdx=0; tdx < numthreads; tdx++) {

		int pathlen=0;
		generate_path(&cntxt[tdx], str, tdx+1);
        cntxt[tdx].id = tdx;

	    if (snappy_init_env(&cntxt[tdx].env)) {
	    	printf("failed to init snappy environment\n");
            return;
        }
	}

    gettimeofday(&start, NULL);


	for (tdx=0; tdx < numthreads; tdx++) {
		thpool_add_work(workerpool, CompressData, (void*)&cntxt[tdx]);
	}
	thpool_wait(workerpool);

	g_tot_input_bytes = 0;
	g_tot_output_bytes = 0; 

	for (tdx=0; tdx < numthreads; tdx++) {
		g_tot_input_bytes += cntxt[tdx].tot_input_bytes;
		g_tot_output_bytes += cntxt[tdx].tot_output_bytes;
	}

    gettimeofday(&end, NULL);
    sec = simulation_time(start, end);
    printf("Total time: %.2lf s\n", sec);
    printf("Average throughput: %.2lf MB/s\n",
           g_tot_input_bytes/ sec / 1024 / 1024);

    fprintf(stdout, "tot input sz %zu outsz %zu\n", g_tot_input_bytes, g_tot_output_bytes);
	thpool_destroy(workerpool);
}


int main(int argc, char **argv) {
        if (argc < 3) {
                fprintf(stdout, "enter directory and thread count to compress \n");
                return 0;
        }

        if (argc > 3) {
                return 0;
        }
        thread_perform_compress(argv[1], atoi(argv[2]));

        return 0;
}
