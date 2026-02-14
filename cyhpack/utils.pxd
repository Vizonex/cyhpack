cdef extern from "Python.h":
    """
/* This comes from both cyares & msgspec */

/*
Copyright (c) 2021, Jim Crist-Harif
All rights reserved.

Redistribution and use in source and binary forcyhpack, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
  may be used to endorse or promote products derived from this software
  without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#ifdef __GNUC__
#define CYHPACK_LIKELY(pred) __builtin_expect(!!(pred), 1)
#define CYHPACK_UNLIKELY(pred) __builtin_expect(!!(pred), 0)
#else
#define CYHPACK_LIKELY(pred) (pred)
#define CYHPACK_UNLIKELY(pred) (pred)
#endif

#ifdef __GNUC__
#define CYHPACK_INLINE __attribute__((always_inline)) inline
#define CYHPACK_NOINLINE __attribute__((noinline))
#elif ((_WIN32) || (_MSVC_VER))
#define CYHPACK_INLINE __forceinline
#define CYHPACK_NOINLINE __declspec(noinline)
#else
#define CYHPACK_INLINE inline
#define CYHPACK_NOINLINE
#endif


static inline const char *
cyhpack_unicode_str_and_size_nocheck(PyObject *str, Py_ssize_t *size) {
    if (CYHPACK_LIKELY(PyUnicode_IS_COMPACT_ASCII(str))) {
        *size = ((PyASCIIObject *)str)->length;
        return (char *)(((PyASCIIObject *)str) + 1);
    }
    *size = ((PyCompactUnicodeObject *)str)->utf8_length;
    return ((PyCompactUnicodeObject *)str)->utf8;
}

/* Msgspec NOTE: XXX: Optimized `PyUnicode_AsUTF8AndSize` */
static inline const char *
cyhpack_unicode_str_and_size(PyObject *str, Py_ssize_t *size) {
    const char *out = cyhpack_unicode_str_and_size_nocheck(str, size);
    if (CYHPACK_LIKELY(out != NULL)) return out;
    return PyUnicode_AsUTF8AndSize(str, size);
}



/* Fill in view.buf & view.len from either a Unicode or buffer-compatible
 * object. */
static int
cyhpack_get_buffer(PyObject *obj, Py_buffer *view) {
    if (CYHPACK_UNLIKELY(PyUnicode_CheckExact(obj))) {
        view->buf = (void *)cyhpack_unicode_str_and_size(obj, &(view->len));
        if (view->buf == NULL) return -1;
        Py_INCREF(obj);
        view->obj = obj;
        return 0;
    }
    return PyObject_GetBuffer(obj, view, PyBUF_CONTIG_RO);
}

static void
cyhpack_release_buffer(Py_buffer *view) {
    if (CYHPACK_LIKELY(!PyUnicode_CheckExact(view->obj))) {
        PyBuffer_Release(view);
    }
    else {
        Py_CLEAR(view->obj);
    }
}
    """
    int cyhpack_get_buffer(object obj, Py_buffer* view) 
    void cyhpack_release_buffer(Py_buffer* view)
    