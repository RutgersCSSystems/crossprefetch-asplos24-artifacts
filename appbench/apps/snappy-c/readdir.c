#include <stdio.h>
#include <dirent.h>
#include <string.h>

int main()
{
    DIR *dir;
    struct dirent *dp;
    char * file_name;
    dir = opendir("/users/kannan11/ssd/sudarsun/prefetching/dataset/snappy/1");
    while ((dp=readdir(dir)) != NULL) {
        printf("debug: %s\n", dp->d_name);
        if ( !strcmp(dp->d_name, ".") || !strcmp(dp->d_name, "..") )
        {
            // do nothing (straight logic)
        } else {
            file_name = dp->d_name; // use it
            printf("file_name: \"%s\"\n",file_name);
        }
    }
    closedir(dir);
    return 0;
}
