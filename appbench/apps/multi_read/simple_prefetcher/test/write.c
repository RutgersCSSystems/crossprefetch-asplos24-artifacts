#include <stdio.h>
#include <stdlib.h>

#ifdef FILESZ
#define FILESIZE (FILESZ * 1024L * 1024L * 1024L)
#else
#define FILESIZE (10L * 1024L * 1024L * 1024L)
#endif

int main() {
	long i;
	FILE *fp;

	fp=fopen("DATA/bigfakefile.txt","w");

	for(i=0; i<FILESIZE; i++) {
		fprintf(fp,"C");
	}

	fclose(fp);
	return 0;
}
