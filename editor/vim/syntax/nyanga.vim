" Vim syntax file
" Language:     Nyanga
" Maintainer:   Richard Hundt <richardhundt@gmail.com>
" Credits:      Thanks to the falcon.vim authors (and transitive credits)
" -------------------------------------------------------------------------------

" When wanted, highlight the trailing whitespace.
if exists("c_space_errors")
    if !exists("c_no_trail_space_error")
        syn match nyangaSpaceError "\s\+$"
    endif

    if !exists("c_no_tab_space_error")
        syn match nyangaSpaceError " \+\t"me=e-1
    endif
endif

" Symbols
syn match nyangaSymbol "\(;\|,\|\.\)"
syn match nyangaSymbolOther "\(#\|@\)" display

" Operators
syn match nyangaOperator "\(+\|-\|\*\|/\|=\|<\|>\|\*\*\|!=\|\~=\)"
syn match nyangaOperator "\(<=\|>=\|=>\|\.\.\|<<\|>>\|\"\)"

" Keywords
syn keyword nyangaKeyword as catch const
syn keyword nyangaKeyword continue do export from extends module import
syn keyword nyangaKeyword in is
syn keyword nyangaKeyword load raise return self static meta
syn keyword nyangaKeyword try local super finally throw

syn keyword nyangaDefine class function

" Error Type Keywords
syn keyword nyangaKeyword CloneError CodeError Error InterruprtedError IoError MathError
syn keyword nyangaKeyword ParamError RangeError SyntaxError TraceStep TypeError

" Todo
syn keyword nyangaTodo DEBUG FIXME NOTE TODO XXX

" Conditionals
syn keyword nyangaConditional and case default else end if then
syn keyword nyangaConditional elseif or not switch select yield
syn match   nyangaConditional "end\s\if"

" Loops
syn keyword nyangaRepeat break for loop forfirst forlast formiddle while

" Booleans
syn keyword nyangaBool true false

" Comments

syn region nyangaComment matchgroup=nyangaComment start="--" end="$" keepend contains=nyangaTodo
syn region nyangaComment matchgroup=nyangaComment start="--\[\z(=*\)\[" end="\]\z1\]" contains=nyangaTodo,@Spell
syn match nyangaSharpBang "\%^#!.*" display

" Numbers
syn match nyangaNumbers transparent "\<[+-]\=\d\|[+-]\=\.\d" contains=nyangaIntLiteral,nyangaFloatLiteral,nyangaHexadecimal,nyangaOctal
syn match nyangaNumbersCom contained transparent "\<[+-]\=\d\|[+-]\=\.\d" contains=nyangaIntLiteral,nyangaFloatLiteral,nyangaHexadecimal,nyangaOctal
syn match nyangaHexadecimal contained "\<0x\x\+\>"
syn match nyangaOctal contained "\<0\o\+\>"
syn match nyangaIntLiteral contained "[+-]\<d\+\(\d\+\)\?\>"
syn match nyangaFloatLiteral contained "[+-]\=\d\+\.\d*"
syn match nyangaFloatLiteral contained "[+-]\=\d*\.\d*"

" Expression Substitution and Backslash Notation
syn match nyangaStringEscape "\\\\\|\\[abefnrstv]\|\\\o\{1,3}\|\\x\x\{1,2}" contained display
syn match nyangaStringEscape "\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)" contained display

" Normal String and Shell Command Output
syn region nyangaString matchgroup=nyangaStringDelimiter start="\"" end="\"" skip="\\\\\|\\\"" contains=nyangaStringEscape fold
syn region nyangaString matchgroup=nyangaStringDelimiter start="'" end="'" skip="\\\\\|\\'" fold
syn region nyangaString matchgroup=nyangaStringDelimiter start="`" end="`" skip="\\\\\|\\`" contains=nyangaStringEscape fold

" Regex
syn region nyangaRegex start=/\%(\%()\|\i\@<!\d\)\s*\|\i\)\@<!\/=\@!\s\@!/
\                      skip=/\[[^\]]\{-}\/[^\]]\{-}\]/
\                      end=/\/[gimy]\{,4}\d\@!/
\                      oneline contains=@nyangaString
hi def link nyangaRegex String


" Syntax Synchronizing
syn sync minlines=10 maxlines=100

" Define the default highlighting
if !exists("did_nyanga_syn_inits")
    command -nargs=+ HiLink hi def link <args>

    HiLink nyangaDefine           Keyword
    HiLink nyangaKeyword          Keyword
    HiLink nyangaTodo             Todo
    HiLink nyangaConditional      Keyword
    HiLink nyangaRepeat           Repeat
    HiLink nyangaComment          Comment
    HiLink nyangaConst            Constant
    HiLink nyangaConstants        Constant
    HiLink nyangaOperator         Operator
    HiLink nyangaSymbol           Normal
    HiLink nyangaSpaceError       Error
    HiLink nyangaHexadecimal      Number
    HiLink nyangaOctal            Number
    HiLink nyangaIntLiteral       Number
    HiLink nyangaFloatLiteral     Float
    HiLink nyangaStringEscape     Special
    HiLink nyangaSpecial          Special
    HiLink nyangaStringDelimiter  Delimiter
    HiLink nyangaString           String
    HiLink nyangaBool             Constant
    HiLink nyangaSharpBang        PreProc
    HiLink nyangaSymbol           Constant
    HiLink nyangaSymbolOther      Delimiter
    delcommand HiLink
endif

let b:current_syntax = "nyanga"

" vim: set sw=4 sts=4 et tw=80 :

