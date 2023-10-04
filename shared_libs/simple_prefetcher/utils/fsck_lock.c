#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <linux/unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <pthread.h>
#include <sched.h>
#include "fsck_lock.h"
//#include "spinlock-xchg.h"
//#include "spinlock-ticket.h"
#include "spinlock-xchg-backoff.h"


int fsck_lock_init(fsck_lock_t* mutex, pthread_mutexattr_t *attr) {
#ifdef _ENABLE_PTHREAD_LOCK
	return pthread_mutex_init(mutex, NULL);
#else
	fprintf(stderr, "fsck_lock init spin\n");
	//return fsck_spinlock_init(mutex);
#endif
}

 int fsck_lock(fsck_lock_t* mutex) {
#ifdef _ENABLE_PTHREAD_LOCK
	return pthread_mutex_lock(mutex);
#else
	fprintf(stderr, "fsck_lock \n");
        spin_lock(mutex);
	return 0;
#endif
}

 int fsck_unlock(fsck_lock_t* mutex) {
#ifdef _ENABLE_PTHREAD_LOCK
	return pthread_mutex_unlock(mutex);
#else
        spin_unlock(mutex);
	return 0;
#endif
}

