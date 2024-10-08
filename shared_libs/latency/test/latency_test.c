#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

int main()
{
    char *filename = "./latency.test";
    int fd;
    mode_t mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
    if ((fd = open(filename, O_RDWR | O_TRUNC | O_CREAT, mode)) == -1) {
        fprintf(stderr, "line %d: Cannot open %s \n", __LINE__, filename);
        exit(1);
    }
    char buf0[20], buf1[20];
    strcpy(buf0, "TestTest");
    write(fd, buf0, strlen(buf0));
    close(fd);
    if ((fd = open(filename, O_RDWR, mode)) == -1) {
        fprintf(stderr, "line %d: Cannot open %s \n", __LINE__, filename);
        exit(1);
    }
    for (int i = 0; i < 1000; ++i)
        pread(fd, buf1, 1, 0);
    close(fd);
    return 0;
}
