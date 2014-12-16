" Vim syntax file
" Language:     Shine
" Maintainer:   Richard Hundt <richardhundt@gmail.com>
" Credits:      Thanks to the falcon.vim authors (and transitive credits)
" -------------------------------------------------------------------------------

" When wanted, highlight the trailing whitespace.
if exists("c_space_errors")
    if !exists("c_no_trail_space_error")
        syn match shineSpaceError "\s\+$"
    endif

    if !exists("c_no_tab_space_error")
        syn match shineSpaceError " \+\t"me=e-1
    endif
endif

" Symbols
syn match shineSymbol "\(;\|,\|\.\)"
syn match shineSymbolOther "\(#\|@\)" display

" Operators
syn match shineOperator "\(+\|-\|\*\|/\|=\|<\|>\|\*\*\|!=\|\~=\)"
syn match shineOperator "\(<=\|>=\|=>\|\.\.\.\|\.\.\|::\|<<\|>>>\|>>\|\"\)"

" Keywords
syn keyword shineKeyword continue do export from extends import include
syn keyword shineKeyword in is as
syn keyword shineKeyword return self
syn keyword shineKeyword try catch finally local super throw

syn keyword shineDefine class function grammar module macro

syn keyword shineFunction assert print yield getmetatable setmetatable tonumber
syn keyword shineFunction rawget rawset rawlen newproxy type typeof tostring
syn keyword shineFunction _G __magic__ error pairs ipairs require

syn match shineFunction "[a-zA-Z_][a-zA-Z_0-9]*\((\)\@="
syn match shineFunction "[a-zA-Z_][a-zA-Z_0-9]*\s*\(<-\)\@="

" Error Type Keywords
syn keyword shineKeyword Error

" Todo
syn keyword shineTodo DEBUG FIXME NOTE TODO XXX

" Conditionals
syn keyword shineConditional and case given else end if then
syn keyword shineConditional elseif or not
syn match   shineConditional "end\s\if"

" Loops
syn keyword shineRepeat break for while repeat until

" Booleans and Constants
syn keyword shineBool true false nil null __FILE__ __LINE__

" Comments

syn region shineComment matchgroup=shineComment start="--" end="$" keepend contains=shineTodo
syn region shineComment matchgroup=shineComment start="--\[\z(.*\)\[" end="\]\z1\]" contains=shineTodo,@Spell
syn region shineComment matchgroup=shineComment start="--:\z([^(]*\)\(([^)]*)\)\?:" end=":\z1:" contains=shineTodo,@Spell
syn match shineSharpBang "\%^#!.*" display

" Numbers
syn case ignore

syn match shineDec      display "\<\d[0-9]*\(U\=L\=L\=\)\>"
syn match shineHex      display "\<0x[0-9a-f_]\+\(U\=L\=L\=\)\>"
syn match shineOctal    display "\<0o[0-7]\+\(U\=L\=L\=\)\>"
syn match shineBadOctal display "\<0o[0-7]*[89][0-9]*"
syn match shineFloat    display "\<\d[0-9]*\.[0-9]*\(e[-+]\=[0-9]\+\)\="
syn match shineHexFloat display "\<0x[0-9a-f]\+\.[0-9a-f]*\(p[-+]\=[0-9]\+\)\="

syn case match


" Expression Substitution and Backslash Notation
syn match shineStringEscape "\\\\\|\\[abefnrstv]\|\\\o\{1,3}\|\\x\x\{1,2}" contained display
syn match shineStringEscape "\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)" contained display

" Normal String and Shell Command Output
syn region shineString matchgroup=shineStringDelimiter start="\"" end="\"" skip="\\\\\|\\\"" contains=shineStringEscape fold
syn region shineString matchgroup=shineStringDelimiter start="'" end="'" skip="\\\\\|\\'" fold
syn region shineString matchgroup=shineStringDelimiter start="`" end="`" skip="\\\\\|\\`" contains=shineStringEscape fold


" Syntax Synchronizing
syn sync minlines=10 maxlines=100

" Define the default highlighting
if !exists("did_shine_syn_inits")
    command -nargs=+ HiLink hi def link <args>

    HiLink shineDefine           Keyword
    HiLink shineFunction         Function
    HiLink shineKeyword          Keyword
    HiLink shineTodo             Todo
    HiLink shineConditional      Keyword
    HiLink shineRepeat           Repeat
    HiLink shineComment          Comment
    HiLink shineConst            Constant
    HiLink shineConstants        Constant
    HiLink shineOperator         Operator
    HiLink shineSymbol           Normal
    HiLink shineSpaceError       Error
    HiLink shineDec              Number
    HiLink shineHex              Number
    HiLink shineOctal            Number
    HiLink shineBadOctal         Error
    HiLink shineFloat            Number
    HiLink shineHexFloat         Number
    HiLink shineStringEscape     Special
    HiLink shineSpecial          Special
    HiLink shineStringDelimiter  Delimiter
    HiLink shineString           String
    HiLink shineBool             Constant
    HiLink shineSharpBang        PreProc
    HiLink shineSymbol           Constant
    HiLink shineSymbolOther      Delimiter
    delcommand HiLink
endif

let b:current_syntax = "shine"

" vim: set sw=4 sts=4 et tw=80 :

