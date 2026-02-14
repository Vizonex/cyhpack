from cpython.bytearray cimport (PyByteArray_AS_STRING,
                                PyByteArray_FromStringAndSize)
from cpython.bytes cimport PyBytes_FromStringAndSize
from cpython.exc cimport PyErr_NoMemory, PyErr_SetString
from cpython.mapping cimport (  # multidict will also work here...
    PyMapping_Check, PyMapping_Items)
from cpython.mem cimport PyMem_Free, PyMem_Malloc, PyMem_Realloc, PyMem_RawMalloc, PyMem_RawRealloc, PyMem_RawFree
from cpython.unicode cimport PyUnicode_DecodeUTF8
from libc.string cimport memcpy


from .lshpack cimport *
from .utils cimport cyhpack_get_buffer, cyhpack_release_buffer

from hpack.exceptions import HPACKDecodingError


cdef extern from "Python.h":
    object PyTuple_GET_ITEM(object tuple, Py_ssize_t pos)

cdef extern from "helpers.h":
    tuple TuplePack_Pair(object a, object b)


DEF LSHPACK_MAX_INDEX = 61

DEF LSHPACK_ERR_MORE_BUF  = -3 # type: ignore
DEF LSHPACK_ERR_TOO_LARGE = -2 # type: ignore
DEF LSHPACK_ERR_BAD_DATA  = -1 # type: ignore
DEF LSHPACK_OK = 0


cdef class LSXPackHeader:
    cdef lsxpack_header_t hdr


    cdef void set_idx(
        self, 
        int hpack_idx, 
        const char* val, 
        size_t val_len
    ) noexcept:
        lsxpack_header_set_idx(&self.hdr, hpack_idx, val, val_len)

    # python eq
    cdef int set_index(
        self,
        int hpack_idx,
        object val
    ) except -1:
        cdef Py_buffer val_buf
        if cyhpack_get_buffer(val, &val_buf) < 0:
            return -1
        self.set_idx(hpack_idx, <const char*>val_buf.buf, val_buf.len)
        cyhpack_release_buffer(&val_buf)
        return 0


    cdef void set_qpack_idx(
        self,
        int qpack_idx,
        const char *val, 
        size_t val_len
    ) noexcept:
        lsxpack_header_set_qpack_idx(&self.hdr, qpack_idx, val, val_len)
    
    # python eq
    cdef int set_qpack_index(
        self,
        int qpack_idx,
        object val
    ) except -1:
        cdef Py_buffer val_buf
        if cyhpack_get_buffer(val, &val_buf) < 0:
            return -1
        self.set_qpack_idx(qpack_idx, <const char*>val_buf.buf, val_buf.len)
        cyhpack_release_buffer(&val_buf)
        return 0


    cdef void set_offset(
        self,
        const char *buf,
        size_t name_offset, 
        size_t name_len,
        size_t val_len
    ):
        lsxpack_header_set_offset(&self.hdr, buf, name_offset, name_len, val_len)

 
    cdef void set_offset2(
        self,
        const char *buf,
        size_t name_offset, 
        size_t name_len,
        size_t val_offset, 
        size_t val_len
    ):
        lsxpack_header_set_offset2(
            &self.hdr, 
            buf, 
            name_offset, 
            name_len, 
            val_offset, 
            val_len
        )

    cdef void perpare_decode(
        self,
        char *out, 
        size_t offset, 
        size_t len
    ):
        lsxpack_header_prepare_decode(
            &self.hdr, out, offset, len
        )

  
    cdef const char* get_name(self):
        return lsxpack_header_get_name(&self.hdr)
    
    cdef const char* get_value(self):
        return lsxpack_header_get_value(&self.hdr)
    
    cdef size_t get_dec_size(self):
        return lsxpack_header_get_dec_size(&self.hdr)
    
    cdef void mark_val_changed(self):
        lsxpack_header_mark_val_changed(&self.hdr)

    cdef unsigned int get_std_tab_id(self, LSXPackHeader input):
        return lshpack_enc_get_stx_tab_id(&input.hdr)

    @staticmethod
    cdef LSXPackHeader new():
        return LSXPackHeader.__new__(LSXPackHeader)
    

    
    cdef bytearray set_ptr(
        self,
        object name,
        object val
    ): 
        cdef bytearray arr
        cdef char* buf
        cdef Py_buffer name_buf, val_buf

        if cyhpack_get_buffer(name, &name_buf) < 0:
            raise
        
        if cyhpack_get_buffer(val, &val_buf) < 0:
            cyhpack_release_buffer(&name_buf)
            raise
        try:
            arr = PyByteArray_FromStringAndSize(NULL, name_buf.len + val_buf.len)
            buf = PyByteArray_AS_STRING(arr)

            memcpy(buf, name_buf.buf, name_buf.len)
            memcpy(&buf[name_buf.len], val_buf.buf, val_buf.len)

            self.set_offset2(buf, 0, name_buf.len, name_buf.len, val_buf.len)
            return arr
        finally:
            cyhpack_release_buffer(&name_buf)
            cyhpack_release_buffer(&val_buf)
    
    cdef bytes raw_name(self):
        return PyBytes_FromStringAndSize(lsxpack_header_get_name(&self.hdr), self.hdr.name_len)

    cdef bytes raw_value(self):
        return PyBytes_FromStringAndSize(lsxpack_header_get_value(&self.hdr), self.hdr.val_len)


cdef class HeaderTuple:
    cdef:
        LSXPackHeader hdr
        bytearray buf
        tuple pair # for compatability with python-hpack

    def __init__(self, object name, object value) -> None:
        self.hdr = LSXPackHeader.new()
        self.buf = self.hdr.set_ptr(name, value)
        self.pair = (self.hdr.raw_name(), self.hdr.raw_value())

    def __getitem__(self, object index):
        return self.pair.__getitem__(index)
    
    def __contains__(self, object item):
        return self.pair.__contains__(item)

    @staticmethod
    cdef HeaderTuple from_lsxpack_header(LSXPackHeader hdr):
        cdef HeaderTuple self = HeaderTuple.__new__(HeaderTuple)
        self.hdr = hdr
        self.pair = (self.hdr.raw_name(), self.hdr.raw_value())
        # we got it from another resource so do this instead...
        self.buf = bytearray(self.hdr.raw_name() + self.hdr.raw_value())
        return self



cdef class LSHPackEnc:
    cdef lshpack_enc enc

    cdef unsigned int get_max_capacity(self):
        return self.enc.hpe_max_capacity

    cdef int init(self):
        return lshpack_enc_init(&self.enc)

    cdef void cleanup(self):
        lshpack_enc_cleanup(&self.enc)
    
    cdef void set_max_capacity(self, unsigned int max_capacity):
        lshpack_enc_set_max_capacity(&self.enc, max_capacity)
    
    cdef int use_hist(self, bint on):
        return lshpack_enc_use_hist(&self.enc, on)
    
    cdef int hist_used(self):
        return lshpack_enc_hist_used(&self.enc)

    cdef unsigned char* encode(self, 
        unsigned char* dst, 
        unsigned char* dst_end, 
        LSXPackHeader input
    ):
        return lshpack_enc_encode(&self.enc, dst, dst_end, &input.hdr)

    def __init__(self) -> None:
        if self.init() < 0:
            raise MemoryError
    
    def __dealloc__(self):
        self.cleanup()


cdef class LSHPackDec:
    cdef:
        lshpack_dec dec
   
    cdef void cleanup(self):
        lshpack_dec_cleanup(&self.dec)
    
    cdef int decode(
        self,
        const unsigned char **src, 
        const unsigned char *src_end,
        lsxpack_header_t* hdr
    ):
        return lshpack_dec_decode(&self.dec, src, src_end, hdr)


        # if last_status == LSHPACK_ERR_BAD_DATA:
        #     # Assume that we did not advance
        #     if src[0] == src_end:
        #         return None
        #     else:
        #         raise HPACKDecodingError("LSHPACK_ERR_BAD_DATA")
        
        # elif last_status == LSHPACK_ERR_MORE_BUF:
        #     raise HPACKDecodingError("Lshpack received incompleted data")
        
        # elif last_status == LSHPACK_ERR_TOO_LARGE:
        #     raise HPACKDecodingError("Data Receieve was too large")
        
        # return out





    def __dealloc__(self):
        self.cleanup()

    cdef void set_max_capacity(self, unsigned int max_capacity):
        lshpack_dec_set_max_capacity(&self.dec, max_capacity)
    
    def __init__(self) -> None:
        lshpack_dec_init(&self.dec)
       

# inspired by aiohttp
DEF BUF_SIZE = 16 * 1024  # 16KiB

cdef struct Writer:
    unsigned char* buf
    Py_ssize_t size
    Py_ssize_t pos
    bint heap

cdef inline void writer_init(Writer* writer, unsigned char* buf):
    writer.buf = buf
    writer.size = BUF_SIZE
    writer.pos = 0
    writer.heap = 0

cdef inline int writer_realloc(Writer* writer):
    cdef Py_ssize_t size
    size = writer.size + BUF_SIZE
    if not writer.heap:
        buf = <unsigned char*>PyMem_Malloc(size)
        if buf == NULL:
            PyErr_NoMemory()
            return -1
        memcpy(buf, writer.buf, writer.size)
    else:
        buf = <unsigned char*>PyMem_Realloc(writer.buf, size)
        if buf == NULL:
            PyErr_NoMemory()
            return -1
    writer.buf = buf
    writer.size = size
    writer.heap = 1 
    return 0


cdef inline int writer_encode(Writer* writer, LSHPackEnc enc, HeaderTuple ht):
    cdef unsigned char* dst = NULL

    while True:
        dst = enc.encode(writer.buf + writer.pos, writer.buf + writer.size, ht.hdr)
        
        if dst == (writer.buf + writer.pos):
            # needs more memory
            if writer_realloc(writer) < 0:
                return -1
            continue

        # calculate distance that we managed to cover
        writer.pos = <Py_ssize_t>(dst - writer.buf)
        return 0

cdef inline bytes writer_finish(Writer* writer):
    return PyBytes_FromStringAndSize(<const char*>writer.buf, writer.pos)

cdef inline void writer_release(Writer* writer):
    if writer.heap:
        PyMem_Free(writer.buf)



# Custom made for handling reading
cdef struct Reader:
    char* buf
    Py_ssize_t size
    bint heap

cdef inline void reader_init(Reader* writer, char* buf):
    writer.buf = buf
    writer.size = BUF_SIZE
    writer.heap = 0

cdef inline int reader_realloc(Reader* reader):
    cdef Py_ssize_t size
    size = reader.size + BUF_SIZE
    if not reader.heap:
        buf = <char*>PyMem_Malloc(size)
        if buf == NULL:
            PyErr_NoMemory()
            return -1
        memcpy(buf, reader.buf, reader.size)
    else:
        buf = <char*>PyMem_Realloc(reader.buf, size)
        if buf == NULL:
            PyErr_NoMemory()
            return -1
    reader.buf = buf
    reader.size = size
    reader.heap = 1 
    return 0

cdef inline void reader_prepare(Reader* reader, lsxpack_header* hdr):
    lsxpack_header_prepare_decode(hdr, reader.buf, 0, reader.size)
    

cdef inline int reader_read(
    Reader* reader, 
    LSHPackDec dec, 
    const unsigned char** src,
    const unsigned char* eof,
    lsxpack_header* hdr
):
    cdef int ret
    # ensure src doesn't move unless something other than bad data or ddos attack
    cdef const unsigned char** last_src = src
    
    while True:
        reader_prepare(reader, hdr)
        ret = dec.decode(src, eof, hdr)
        # go through each possible case will cut after 
        # LSHPACK_ERR_MORE_BUF if we recieved more data to work with...
        if ret == LSHPACK_ERR_MORE_BUF:
            if reader_realloc(reader) < 0:
                return -1

        elif ret == LSHPACK_ERR_BAD_DATA:
            PyErr_SetString(HPACKDecodingError, "Bad Data Recieved while trying to decode headers")
            return -1

        elif ret == LSHPACK_ERR_TOO_LARGE:
            # Headers are too large and could've resulted in a Denial of Service attack.
            PyErr_SetString(HPACKDecodingError, "Headers were too large")
            return -1

        elif ret == LSHPACK_OK:
            return 0

        # reset with previous src incase the pointer was moved previously...
        # Then try again. 
        src = last_src

cdef inline void reader_release(Reader* r):
    if r.heap:
        PyMem_Free(r.buf)


# same as the python version _unicode_if_needed
# but is written for private use and can decode utf-8 strings if raw is disabled.
# these 4 functions are the same as raw_name(...) and raw_value(...)
# but with the cdef extension class shortcutted as an optimization.
cdef inline bytes header_raw_name(lsxpack_header* hdr):
    return PyBytes_FromStringAndSize(lsxpack_header_get_name(hdr), hdr.name_len)
    
cdef inline bytes header_raw_value(lsxpack_header* hdr):
    return PyBytes_FromStringAndSize(lsxpack_header_get_value(hdr), hdr.val_len) 

cdef inline str header_name(lsxpack_header* hdr):
    return PyUnicode_DecodeUTF8(lsxpack_header_get_name(hdr), hdr.name_len, "surrogateescape")
 
cdef inline str header_value(lsxpack_header* hdr):
    return PyUnicode_DecodeUTF8(lsxpack_header_get_value(hdr), hdr.val_len, "surrogateescape")

# if raw this returns -> tuple[bytes, bytes] 
# if not this returns -> tuple[str, str] # surrogateescaped 
cdef tuple decode_header_if_needed(lsxpack_header* hdr, bint raw):
    cdef tuple pair
    if not raw:
        return TuplePack_Pair(header_name(hdr), header_value(hdr))
    else:
        return TuplePack_Pair(header_raw_name(hdr), header_raw_value(hdr))











cdef class Encoder:
    cdef LSHPackEnc enc

    def __init__(self) -> None:
        self.enc = LSHPackEnc()
    
    @property
    def header_table_size(self):
        return self.enc.get_max_capacity()
    
    @header_table_size.setter
    def header_table_size(self, unsigned int value):
        self.enc.set_max_capacity(value)
    
    # XXX: we do want Our library to be a drop-in replacement 
    # at h2 library's level so some research into what functions
    # are required or not might be nessesary.  
    # def add(self, tuple to_add, bint sensitive, bint huffman = False):

    cdef bytes encode_headers(self, object headers):
        cdef object h, k, v
        cdef Writer w
        cdef unsigned char buf[BUF_SIZE]
        writer_init(&w, buf)
        try:
            for h in iter(headers):
                if isinstance(h, HeaderTuple):
                    if writer_encode(&w, self.enc, (<HeaderTuple>h)) < 0:
                        raise
                else:
                    # Otherwise we need to try and transform it.
                    k, v = h
                    if writer_encode(&w, self.enc, HeaderTuple(k, v)) < 0:
                        raise

            return writer_finish(&w)
        finally:
            writer_release(&w)

    def encode(self, object headers, bint huffman = True):
        # ensure memory can be allocated if huffman is chosen
        # otherwise we could run into a memory error.
        if self.enc.use_hist(huffman) < 0:
            raise MemoryError

        # MultiDict/CIMultidict are also supported here...
        if PyMapping_Check(headers):
            return self.encode_headers(PyMapping_Items(headers))
        else:
            return self.encode_headers(headers)


DEF DEFAULT_MAX_HEADER_LIST_SIZE = 65536

cdef class Decoder:
    cdef: 
        LSHPackDec dec
        char* buf # buf per header prepared
        
        # we want to force this decoder to work alongside 
        # h2, httpx & starlette even though cyhpack was primarlly written
        # for the server-side since curl-cffi does a faster job client-side.
        public Py_ssize_t max_header_list_size
        public Py_ssize_t max_allowed_table_size

    def __init__(self, Py_ssize_t max_header_list_size = DEFAULT_MAX_HEADER_LIST_SIZE) -> None:
        self.dec = LSHPackDec()
        self.dec.set_max_capacity(max_header_list_size)
        self.max_header_list_size = max_header_list_size
        self.max_allowed_table_size = self.dec.dec.hpd_max_capacity

    @property
    def header_table_size(self) -> int:
        """
        Controls the size of the HPACK header table.
        """
        return self.dec.dec.hpd_cur_max_capacity

    @header_table_size.setter
    def header_table_size(self, unsigned int value) -> None:
        self.dec.set_max_capacity(value)
        self.max_header_list_size = value


    def decode(self, object data, bint raw = False):
        cdef list headers = []
        cdef Py_buffer buf
        cdef const unsigned char* data_buf
        cdef const unsigned char* eof
        cdef lsxpack_header_t hdr
        cdef char rbuf[BUF_SIZE]
        # We need a reader so that we can safely allocate on the heap without being super costly at it...
        cdef Reader r

        reader_init(&r, rbuf)

        if cyhpack_get_buffer(data, &buf) < 0:
            raise
        try:
            data_buf = <const unsigned char*>buf.buf
            eof = data_buf + buf.len

            while (data_buf < eof):
                if reader_read(&r, self.dec, &data_buf, eof, &hdr) < 0:
                    raise
                headers.append(decode_header_if_needed(&hdr, raw))

            return headers
            
        finally:
            reader_release(&r)
            cyhpack_release_buffer(&buf)


# inject python memory allocators if possible to do so.
if not lshpack_lib_check_init():
    lshpack_lib_init_mem(
        PyMem_RawMalloc,
        PyMem_RawRealloc,
        PyMem_RawFree
    )
