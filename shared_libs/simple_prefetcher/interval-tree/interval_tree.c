#include <stdlib.h>
#include <stddef.h>

#include "interval_tree.h"
#include "interval_tree_generic.h"

#define START(node) ((node)->start)
#define LAST(node)  ((node)->last)

#ifdef __cplusplus
extern "C" {
#endif


INTERVAL_TREE_DEFINE(struct interval_tree_node, rb,
		     unsigned long, __subtree_last,
		     START, LAST,, interval_tree)

#ifdef __cplusplus
}
#endif


