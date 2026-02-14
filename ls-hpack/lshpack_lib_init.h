#ifndef __LSHPACK_LIB_INIT_H__
#define __LSHPACK_LIB_INIT_H__

// This was added for Python/Cython support for memory allocations
// by the author Vizonex. It's implementation is inspired by C-ARES.

#ifdef __cplusplus
extern "C" {
#endif 

/* needed so that cython knows how to read these off */
typedef void *(*lshpack_malloc_fn)(size_t size);
typedef void *(*lshpack_realloc_fn)(void* p, size_t size);
typedef void (*lshpack_free_fn)(void* p);

int lshpack_lib_init_mem(
    lshpack_malloc_fn malloc_fn,
    lshpack_realloc_fn realloc_rn,
    lshpack_free_fn free_fn
);

int lshpack_lib_cleanup();
int lshpack_lib_init();

int lshpack_lib_check_init();

void* lshpack_malloc(size_t size);
void* lshpack_realloc(void* p, size_t size);
void lshpack_free(void* p);


#ifdef __cplusplus
}
#endif 

#endif // __LSHPACK_LIB_INIT_H__