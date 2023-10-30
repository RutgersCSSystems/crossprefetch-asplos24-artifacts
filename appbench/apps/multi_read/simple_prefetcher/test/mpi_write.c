#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mpi.h>


#ifdef FILESZ
#define FILESIZE (FILESZ * 1024L * 1024L * 1024L)
#else
#define FILESIZE (10L * 1024L * 1024L * 1024L)
#endif

#define FILENAMEMAX 100

/*
 * Given the rank and the initial string, this
 * function returns the filename per mpi rank
 */
void file_name(const char *str1, int rank, char *buffer){
    char *num;

    if (asprintf(&num, "%d", rank) == -1) {
        perror("asprintf");
    } else {
        strcat(strcpy(buffer, str1), num);
        strcat(buffer, ".txt");
        printf("%s\n", buffer);
        free(num);
    }
}

int main() {
    // Initialize the MPI environment
    MPI_Init(NULL, NULL);

    char filename[FILENAMEMAX];
    const char* str1 = "bigfakefile";

    // Get the number of processes
    int world_size;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    // Get the rank of the process
    int world_rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    // Print off a hello world message
    printf("Hello world fromrank %d out of %d processors\n", world_rank, world_size);

    /*
     * Per MPI rank code of interest starts here
     */
    long i;
    FILE *fp;

    file_name(str1, world_rank, filename);
    fp=fopen(filename,"w");

    for(i=0; i<FILESIZE; i++) {
        fprintf(fp,"C");
    }

    fclose(fp);

    // Finalize the MPI environment.
    MPI_Finalize();
}
