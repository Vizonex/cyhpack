/**
 * This Section is based off C-Ares and was made for providing support for different kinds of memory allocators rather than
 * purely C's, This allows for Python's performance enhancements such as mimalloc to become useful.
 * 
 * If litespeed-tech wants my addon feel free to add it. C-ARES is MIT Licensed. And it's implementation works wonders.
 */

#include <stdlib.h>
#include <string.h>
#include "lshpack_lib_init.h"
#include "lshpack.h"


/* Based off c-ares */
static int __lshpack_lib_init = 0;

static void *default_malloc(size_t size)
{
    return (size == 0) ? NULL : malloc(size);
}

static void *default_realloc(void *p, size_t size)
{
    return realloc(p, size);
}

static void default_free(void *p)
{
    free(p);
}

static void *(*__lshpack_malloc)(size_t size)             = default_malloc;
static void *(*__lshpack_realloc)(void *ptr, size_t size) = default_realloc;
static void (*__lshpack_free)(void *ptr)                  = default_free;

void* lshpack_malloc(size_t size){
    return __lshpack_malloc(size);
}

void* lshpack_realloc(void* p, size_t size){
    return __lshpack_realloc(p, size);
}

void lshpack_free(void* p){
    return __lshpack_free(p);
}

void *lshpack_malloc_zero(size_t size)
{
  void *ptr = lshpack_malloc(size);
  if (ptr != NULL) {
    memset(ptr, 0, size);
  }

  return ptr;
}

void *lshpack_realloc_zero(void *ptr, size_t orig_size, size_t new_size)
{
  void *p = lshpack_realloc(ptr, new_size);
  if (p == NULL) {
    return NULL;
  }

  if (new_size > orig_size) {
    memset((unsigned char *)p + orig_size, 0, new_size - orig_size);
  }

  return p;
}

int lshpack_lib_init_mem(
    lshpack_malloc_fn malloc_fn,
    lshpack_realloc_fn realloc_fn,
    lshpack_free_fn free_fn
){
    if (__lshpack_lib_init){
        return LSHPACK_ERR_LIB_ALREADY_INITALIZED;
    }
    __lshpack_malloc = malloc_fn;
    __lshpack_realloc = realloc_fn;
    __lshpack_free = free_fn;
    __lshpack_lib_init++;
    return LSHPACK_OK;
}


int lshpack_lib_cleanup(){
    if (!__lshpack_lib_init){
        return LSHPACK_ERR_LIB_NOT_INITALIZED;
    }
    __lshpack_malloc = lshpack_malloc;
    __lshpack_realloc = lshpack_realloc;
    __lshpack_free = lshpack_free;

    __lshpack_lib_init--;
    return LSHPACK_OK;
}

int lshpack_lib_init(){
    if (__lshpack_lib_init){
        return LSHPACK_ERR_LIB_ALREADY_INITALIZED;
    }
    __lshpack_lib_init++;
    return LSHPACK_OK;
}

int lshpack_lib_check_init(){
    return __lshpack_lib_init != 0;
}
