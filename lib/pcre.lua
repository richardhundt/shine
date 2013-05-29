local ffi = require('ffi')

ffi.cdef [[
enum  {
   PCRE_CASELESS           = 0x00000001,
   PCRE_MULTILINE          = 0x00000002,
   PCRE_DOTALL             = 0x00000004,
   PCRE_EXTENDED           = 0x00000008,
   PCRE_ANCHORED           = 0x00000010,
   PCRE_DOLLAR_ENDONLY     = 0x00000020,
   PCRE_EXTRA              = 0x00000040,
   PCRE_NOTBOL             = 0x00000080,
   PCRE_NOTEOL             = 0x00000100,
   PCRE_UNGREEDY           = 0x00000200,
   PCRE_NOTEMPTY           = 0x00000400,
   PCRE_UTF8               = 0x00000800,
   PCRE_UTF16              = 0x00000800,
   PCRE_UTF32              = 0x00000800,
   PCRE_NO_AUTO_CAPTURE    = 0x00001000,
   PCRE_NO_UTF8_CHECK      = 0x00002000,
   PCRE_NO_UTF16_CHECK     = 0x00002000,
   PCRE_NO_UTF32_CHECK     = 0x00002000,
   PCRE_AUTO_CALLOUT       = 0x00004000,
   PCRE_PARTIAL_SOFT       = 0x00008000,
   PCRE_PARTIAL            = 0x00008000,
   PCRE_DFA_SHORTEST       = 0x00010000,
   PCRE_DFA_RESTART        = 0x00020000,
   PCRE_FIRSTLINE          = 0x00040000,
   PCRE_DUPNAMES           = 0x00080000,
   PCRE_NEWLINE_CR         = 0x00100000,
   PCRE_NEWLINE_LF         = 0x00200000,
   PCRE_NEWLINE_CRLF       = 0x00300000,
   PCRE_NEWLINE_ANY        = 0x00400000,
   PCRE_NEWLINE_ANYCRLF    = 0x00500000,
   PCRE_BSR_ANYCRLF        = 0x00800000,
   PCRE_BSR_UNICODE        = 0x01000000,
   PCRE_JAVASCRIPT_COMPAT  = 0x02000000,
   PCRE_NO_START_OPTIMIZE  = 0x04000000,
   PCRE_NO_START_OPTIMISE  = 0x04000000,
   PCRE_PARTIAL_HARD       = 0x08000000,
   PCRE_NOTEMPTY_ATSTART   = 0x10000000,
   PCRE_UCP                = 0x20000000,

   PCRE_ERROR_NOMATCH         =  -1,
   PCRE_ERROR_NULL            =  -2,
   PCRE_ERROR_BADOPTION       =  -3,
   PCRE_ERROR_BADMAGIC        =  -4,
   PCRE_ERROR_UNKNOWN_OPCODE  =  -5,
   PCRE_ERROR_UNKNOWN_NODE    =  -5,
   PCRE_ERROR_NOMEMORY        =  -6,
   PCRE_ERROR_NOSUBSTRING     =  -7,
   PCRE_ERROR_MATCHLIMIT      =  -8,
   PCRE_ERROR_CALLOUT         =  -9,
   PCRE_ERROR_BADUTF8         = -10,
   PCRE_ERROR_BADUTF16        = -10,
   PCRE_ERROR_BADUTF32        = -10,
   PCRE_ERROR_BADUTF8_OFFSET  = -11,
   PCRE_ERROR_BADUTF16_OFFSET = -11,
   PCRE_ERROR_PARTIAL         = -12,
   PCRE_ERROR_BADPARTIAL      = -13,
   PCRE_ERROR_INTERNAL        = -14,
   PCRE_ERROR_BADCOUNT        = -15,
   PCRE_ERROR_DFA_UITEM       = -16,
   PCRE_ERROR_DFA_UCOND       = -17,
   PCRE_ERROR_DFA_UMLIMIT     = -18,
   PCRE_ERROR_DFA_WSSIZE      = -19,
   PCRE_ERROR_DFA_RECURSE     = -20,
   PCRE_ERROR_RECURSIONLIMIT  = -21,
   PCRE_ERROR_NULLWSLIMIT     = -22,
   PCRE_ERROR_BADNEWLINE      = -23,
   PCRE_ERROR_BADOFFSET       = -24,
   PCRE_ERROR_SHORTUTF8       = -25,
   PCRE_ERROR_SHORTUTF16      = -25,
   PCRE_ERROR_RECURSELOOP     = -26,
   PCRE_ERROR_JIT_STACKLIMIT  = -27,
   PCRE_ERROR_BADMODE         = -28,
   PCRE_ERROR_BADENDIANNESS   = -29,
   PCRE_ERROR_DFA_BADRESTART  = -30,
   PCRE_ERROR_JIT_BADOPTION   = -31,
   PCRE_ERROR_BADLENGTH       = -32,


   PCRE_UTF8_ERR0             =   0,
   PCRE_UTF8_ERR1             =   1,
   PCRE_UTF8_ERR2             =   2,
   PCRE_UTF8_ERR3             =   3,
   PCRE_UTF8_ERR4             =   4,
   PCRE_UTF8_ERR5             =   5,
   PCRE_UTF8_ERR6             =   6,
   PCRE_UTF8_ERR7             =   7,
   PCRE_UTF8_ERR8             =   8,
   PCRE_UTF8_ERR9             =   9,
   PCRE_UTF8_ERR10            =  10,
   PCRE_UTF8_ERR11            =  11,
   PCRE_UTF8_ERR12            =  12,
   PCRE_UTF8_ERR13            =  13,
   PCRE_UTF8_ERR14            =  14,
   PCRE_UTF8_ERR15            =  15,
   PCRE_UTF8_ERR16            =  16,
   PCRE_UTF8_ERR17            =  17,
   PCRE_UTF8_ERR18            =  18,
   PCRE_UTF8_ERR19            =  19,
   PCRE_UTF8_ERR20            =  20,
   PCRE_UTF8_ERR21            =  21,
   PCRE_UTF8_ERR22            =  22,

   /* Request types for pcre_fullinfo() */

   PCRE_INFO_OPTIONS          =   0,
   PCRE_INFO_SIZE             =   1,
   PCRE_INFO_CAPTURECOUNT     =   2,
   PCRE_INFO_BACKREFMAX       =   3,
   PCRE_INFO_FIRSTBYTE        =   4,
   PCRE_INFO_FIRSTCHAR        =   4,
   PCRE_INFO_FIRSTTABLE       =   5,
   PCRE_INFO_LASTLITERAL      =   6,
   PCRE_INFO_NAMEENTRYSIZE    =   7,
   PCRE_INFO_NAMECOUNT        =   8,
   PCRE_INFO_NAMETABLE        =   9,
   PCRE_INFO_STUDYSIZE        =  10,
   PCRE_INFO_DEFAULT_TABLES   =  11,
   PCRE_INFO_OKPARTIAL        =  12,
   PCRE_INFO_JCHANGED         =  13,
   PCRE_INFO_HASCRORLF        =  14,
   PCRE_INFO_MINLENGTH        =  15,
   PCRE_INFO_JIT              =  16,
   PCRE_INFO_JITSIZE          =  17,
   PCRE_INFO_MAXLOOKBEHIND    =  18,
   PCRE_INFO_FIRSTCHARACTER   =  19,
   PCRE_INFO_FIRSTCHARACTERFLAGS = 20,
   PCRE_INFO_REQUIREDCHAR        = 21,
   PCRE_INFO_REQUIREDCHARFLAGS   = 22,

   /* Request types for pcre_config(). */

   PCRE_CONFIG_UTF8                   = 0,
   PCRE_CONFIG_NEWLINE                = 1,
   PCRE_CONFIG_LINK_SIZE              = 2,
   PCRE_CONFIG_POSIX_MALLOC_THRESHOLD = 3,
   PCRE_CONFIG_MATCH_LIMIT            = 4,
   PCRE_CONFIG_STACKRECURSE           = 5,
   PCRE_CONFIG_UNICODE_PROPERTIES     = 6,
   PCRE_CONFIG_MATCH_LIMIT_RECURSION  = 7,
   PCRE_CONFIG_BSR                    = 8,
   PCRE_CONFIG_JIT                    = 9,
   PCRE_CONFIG_UTF16                 = 10,
   PCRE_CONFIG_JITTARGET             = 11,
   PCRE_CONFIG_UTF32                 = 12,

   /* Request types for pcre_study(). */

   PCRE_STUDY_JIT_COMPILE              = 0x0001,
   PCRE_STUDY_JIT_PARTIAL_SOFT_COMPILE = 0x0002,
   PCRE_STUDY_JIT_PARTIAL_HARD_COMPILE = 0x0004,
   PCRE_STUDY_EXTRA_NEEDED             = 0x0008,

   /* Bit flags for the pcre_extra structure. */

   PCRE_EXTRA_STUDY_DATA            = 0x0001,
   PCRE_EXTRA_MATCH_LIMIT           = 0x0002,
   PCRE_EXTRA_CALLOUT_DATA          = 0x0004,
   PCRE_EXTRA_TABLES                = 0x0008,
   PCRE_EXTRA_MATCH_LIMIT_RECURSION = 0x0010,
   PCRE_EXTRA_MARK                  = 0x0020,
   PCRE_EXTRA_EXECUTABLE_JIT        = 0x0040
} PCRE;

/* Types */

struct real_pcre;                 /* declaration; the definition is private  */
typedef struct real_pcre pcre;

struct real_pcre_jit_stack;       /* declaration; the definition is private  */
typedef struct real_pcre_jit_stack pcre_jit_stack;

/* The structure for passing additional data to pcre_exec(). This is defined in
such as way as to be extensible. Always add new fields at the end, in order to
remain compatible. */

typedef struct pcre_extra {
  unsigned long int flags;        /* Bits for which fields are set */
  void *study_data;               /* Opaque data from pcre_study() */
  unsigned long int match_limit;  /* Maximum number of calls to match() */
  void *callout_data;             /* Data passed back in callouts */
  const unsigned char *tables;    /* Pointer to character tables */
  unsigned long int match_limit_recursion; /* Max recursive calls to match() */
  unsigned char **mark;           /* For passing back a mark pointer */
  void *executable_jit;           /* Contains a pointer to a compiled jit code */
} pcre_extra;

void  free(void *);
void *malloc(size_t);

/* User defined callback which provides a stack just before the match starts. */

typedef pcre_jit_stack *(*pcre_jit_callback)(void *);

/* Exported PCRE functions */

pcre *pcre_compile(const char *, int, const char **, int *,
                  const unsigned char *);
pcre *pcre_compile2(const char *, int, int *, const char **,
                  int *, const unsigned char *);
int  pcre_config(int, void *);
int  pcre_copy_named_substring(const pcre *, const char *,
                  int *, int, const char *, char *, int);
int  pcre_copy_substring(const char *, int *, int, int,
                  char *, int);
int  pcre_dfa_exec(const pcre *, const pcre_extra *,
                  const char *, int, int, int, int *, int, int *, int);
int  pcre_exec(const pcre *, const pcre_extra *, const char *,
                   int, int, int, int *, int);
int  pcre_jit_exec(const pcre *, const pcre_extra *,
                   const char*, int, int, int, int *, int,
                   pcre_jit_stack *);
void pcre_free_substring(const char *);
void pcre_free_substring_list(const char **);
int  pcre_fullinfo(const pcre *, const pcre_extra *, int, void *);
int  pcre_get_named_substring(const pcre *, const char *,
                  int *, int, const char *, const char **);
int  pcre_get_stringnumber(const pcre *, const char *);
int  pcre_get_stringtable_entries(const pcre *, const char *,
                  char **, char **);
int  pcre_get_substring(const char *, int *, int, int,
                  const char **);
int  pcre_get_substring_list(const char *, int *, int,
                  const char ***);

const unsigned char *pcre_maketables(void);
int  pcre_refcount(pcre *, int);
pcre_extra *pcre_study(const pcre *, int, const char **);
void pcre_free_study(pcre_extra *);
const char *pcre_version(void);

/* Utility functions for byte order swaps. */
int  pcre_pattern_to_host_byte_order(pcre *, pcre_extra *, const unsigned char *);

/* JIT compiler related functions. */

pcre_jit_stack *pcre_jit_stack_alloc(int, int);
void pcre_jit_stack_free(pcre_jit_stack *);
void pcre_assign_jit_stack(pcre_extra *, pcre_jit_callback, void *);

]]

local lib = ffi.load('pcre')

local function compile(pat, opt)
   opt = opt or 0
   local err1 = ffi.new('const char *[1]')
   local errN = ffi.new('int [1]')
   local errptr = ffi.cast('const char **', err1)
   local errofs = ffi.cast('int *', errN)
   local rx = lib.pcre_compile(pat, opt, errptr, errofs, nil)
   if rx == nil then
      return nil, ffi.string(err1[0]).." at position "..tonumber(errN[0])
   end
   return ffi.gc(rx, lib.free)
end

local function execute(re, str, idx, opt)
   local ovec = ffi.new('int [30]')
   idx = idx or 0
   opt = opt or 0
   local rc = lib.pcre_exec(re, nil, str, #str, idx, opt, ovec, 30)
   if rc > 0 then
      local capt = { }
      local buf  = ffi.new('const char *[1]')
      local bufptr = ffi.cast('const char **', buf)
      capt.index = idx
      capt.input = str
      for i=0, rc - 1 do
         local len = lib.pcre_get_substring(str, ovec, rc, i, bufptr)
         capt[#capt + 1] = ffi.string(buf[0], len)
         lib.pcre_free_substring(buf[0])
      end
      return capt
   else
      return rc
   end
end

return {
   lib     = lib,
   compile = compile,
   execute = execute,
}

