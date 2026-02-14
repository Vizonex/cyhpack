#ifndef __HELPERS_H__
#define __HELPERS_H__

#ifdef __cplusplus
extern "C" {
#endif

#include "Python.h"

// Cython can really suck at doing this optimally 
// so let me lend it a hand.
#define TuplePack_Pair(a, b) \
    PyTuple_Pack(2, a, b)



#ifdef __cplusplus
}
#endif

#endif // __HELPERS_H__