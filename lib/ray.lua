local ffi = require('ffi')
ffi.cdef[[
typedef enum {
  RAY_UNKNOWN = -1,
  RAY_CUSTOM,
  RAY_ERROR,
  RAY_READ,
  RAY_WRITE,
  RAY_CLOSE,
  RAY_CONNECTION,
  RAY_TIMER,
  RAY_IDLE,
  RAY_CONNECT,
  RAY_SHUTDOWN,
  RAY_WORK,
  RAY_FS_CUSTOM,
  RAY_FS_ERROR,
  RAY_FS_OPEN,
  RAY_FS_CLOSE,
  RAY_FS_READ,
  RAY_FS_WRITE,
  RAY_FS_SENDFILE,
  RAY_FS_STAT,
  RAY_FS_LSTAT,
  RAY_FS_FSTAT,
  RAY_FS_FTRUNCATE,
  RAY_FS_UTIME,
  RAY_FS_FUTIME,
  RAY_FS_CHMOD,
  RAY_FS_FCHMOD,
  RAY_FS_FSYNC,
  RAY_FS_FDATASYNC,
  RAY_FS_UNLINK,
  RAY_FS_RMDIR,
  RAY_FS_MKDIR,
  RAY_FS_RENAME,
  RAY_FS_READDIR,
  RAY_FS_LINK,
  RAY_FS_SYMLINK,
  RAY_FS_READLINK,
  RAY_FS_CHOWN,
  RAY_FS_FCHOWN
} ray_type_t;

typedef enum ray_err_e {
  RAY_OK = 0,
  RAY_EOF = 1,
  RAY_EADDRINFO = 2,
  RAY_EACCES = 3,
  RAY_EAGAIN = 4,
  RAY_EADDRINUSE = 5,
  RAY_EADDRNOTAVAIL = 6,
  RAY_EAFNOSUPPORT = 7,
  RAY_EALREADY = 8,
  RAY_EBADF = 9,
  RAY_EBUSY = 10,
  RAY_ECONNABORTED = 11,
  RAY_ECONNREFUSED = 12,
  RAY_ECONNRESET = 13,
  RAY_EDESTADDRREQ = 14,
  RAY_EFAULT = 15,
  RAY_EHOSTUNREACH = 16,
  RAY_EINTR = 17,
  RAY_EINVAL = 18,
  RAY_EISCONN = 19,
  RAY_EMFILE = 20,
  RAY_EMSGSIZE = 21,
  RAY_ENETDOWN = 22,
  RAY_ENETUNREACH = 23,
  RAY_ENFILE = 24,
  RAY_ENOBUFS = 25,
  RAY_ENOMEM = 26,
  RAY_ENOTDIR = 27,
  RAY_EISDIR = 28,
  RAY_ENONET = 29,
  RAY_ENOTCONN = 31,
  RAY_ENOTSOCK = 32,
  RAY_ENOTSUP = 33,
  RAY_ENOENT = 34,
  RAY_ENOSYS = 35,
  RAY_EPIPE = 36,
  RAY_EPROTO = 37,
  RAY_EPROTONOSUPPORT = 38,
  RAY_EPROTOTYPE = 39,
  RAY_ETIMEDOUT = 40,
  RAY_ECHARSET = 41,
  RAY_EAIFAMNOSUPPORT = 42,
  RAY_EAISERVICE = 44,
  RAY_EAISOCKTYPE = 45,
  RAY_ESHUTDOWN = 46,
  RAY_EEXIST = 47,
  RAY_ESRCH = 48,
  RAY_ENAMETOOLONG = 49,
  RAY_EPERM = 50,
  RAY_ELOOP = 51,
  RAY_EXDEV = 52,
  RAY_ENOTEMPTY = 53,
  RAY_ENOSPC = 54,
  RAY_EIO = 55,
  RAY_EROFS = 56,
  RAY_ENODEV = 57,
  RAY_ESPIPE = 58,
  RAY_ECANCELED = 59,
} ray_err_t;

typedef int ray_file_t;

typedef struct ray_buf_s    ray_buf_t;
typedef struct ray_evt_s    ray_evt_t;
typedef struct ray_queue_s  ray_queue_t;
typedef struct ray_handle_s ray_handle_t;

typedef struct ray_dir_s    ray_dir_t;
typedef struct ray_stat_s   ray_stat_t;

struct ray_buf_s {
  size_t   size;
  uint8_t* head;
  uint8_t* base;
};

struct ray_evt_s {
  ray_type_t    type;
  ray_handle_t* self;
  int           info;
  void*         data;
};

struct ray_dir_s {
  char*   name;
  size_t  nlen;
};

typedef struct ray_timespec_s {
  long tv_sec;
  long tv_nsec;
} ray_timespec_t;

struct ray_stat_s {
  uint32_t mode;
  uint32_t uid;
  uint32_t gid;
  uint64_t size;
  uint64_t dev;
  uint64_t rdev;
  uint64_t ino;
  uint64_t nlink;
  ray_timespec_t atim;
  ray_timespec_t mtim;
  ray_timespec_t ctim;
};

ray_buf_t* ray_buf_new(size_t size);
void ray_buf_init(ray_buf_t* buf);
void ray_buf_need(ray_buf_t* buf, size_t len);
void ray_buf_write(ray_buf_t* buf, const char* str, size_t len);
void ray_buf_clear(ray_buf_t* buf);
const char* ray_buf_read(ray_buf_t* buf, size_t len);
void ray_buf_free(ray_buf_t* buf);

ray_queue_t* ray_queue_new(size_t size);
int ray_queue_init(ray_queue_t* self, size_t size);
void ray_queue_free(ray_queue_t* self);

int ray_evt_count(ray_queue_t* self);
ray_evt_t ray_evt_init(ray_handle_t* o, ray_type_t t, int i, void* d);

ray_handle_t* ray_handle_new(ray_queue_t* queue);
void ray_handle_free(ray_handle_t* self);

void ray_queue_post(ray_queue_t* self, ray_evt_t* evt);
ray_evt_t* ray_queue_take(ray_queue_t* self);
ray_evt_t* ray_queue_peek(ray_queue_t* self);
ray_evt_t* ray_queue_next(ray_queue_t* self);

int ray_last_error(ray_queue_t* self);
const char* ray_strerror(int code);
const char* ray_err_name(int code);

int ray_queue_interrupt(ray_queue_t* queue);

ray_handle_t* ray_tcp_new(ray_queue_t* queue);
int ray_tcp_init(ray_handle_t* self);
int ray_tcp_bind(ray_handle_t* self, const char* host, int port);

int ray_read_start(ray_handle_t* self, size_t len);
int ray_read_stop(ray_handle_t* self);

int ray_write(ray_handle_t* self, const char* str, size_t len);

int ray_listen(ray_handle_t* self, int backlog);
int ray_accept(ray_handle_t* server, ray_handle_t* client);

void ray_close(ray_handle_t* self);

ray_handle_t* ray_timer_new(ray_queue_t* queue);
int ray_timer_start(ray_handle_t* self, int64_t timeo, int64_t repeat);
int ray_timer_stop(ray_handle_t* self);

ray_handle_t* ray_idle_new(ray_queue_t* queue);
int ray_idle_start(ray_handle_t* self);
int ray_idle_stop(ray_handle_t* self);

ray_evt_t* ray_queue_next(ray_queue_t* self);
void ray_evt_done(ray_evt_t* evt);

int  ray_handle_get_id(ray_handle_t* self);
void ray_handle_set_id(ray_handle_t* self, int id);

]]

return ffi.load('./lib/libray.so')

