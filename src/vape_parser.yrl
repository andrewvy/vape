Nonterminals
program block
statement statements
dottedname
explist exp binop
declaration declaratorlist
functiondef functionbody functioncall
.

Terminals
import
identifier
'object'
'function'
integer float string and or
new 'nil' 'false' 'true'
'+' '-' '*' '/' '%' '^' '==' '<=' '>=' '<' '>' '='
'.' ',' '(' ')' '{' '}' '[' ']'.

Rootsymbol program.

%% Operator Precedence

Left 100 'or'.
Left 200 'and'.
Left 300 '<' '>' '<=' '>=' '=='.
Left 500 '+' '-'.
Left 600 '*' '/' '%'.

program -> block : '$1'.

block -> block object identifier '{' block '}' : '$1' ++ [{object, line('$3'), '$3', '$5'}].
block -> statements : '$1'.

%% Statements
statements -> '$empty' : [].
statements -> statements statement : '$1' ++ ['$2'].

%% Statement
statement -> declaration : '$1'.

%% Declaration
declaration -> import dottedname : { import, line('$1'), '$2' }.
declaration -> declaratorlist : { declaration, line(hd('$1')), '$1' }.
declaration -> identifier '=' exp : { assign, line('$2'), '$1', '$3' }.

%% Expression List
explist -> exp : ['$1'].
explist -> explist ',' exp : '$1' ++ ['$3'].

exp -> '[' ']' : [].
exp -> '[' explist ']' : '$2'.
exp -> '(' exp ')' : '$2'.
exp -> dottedname : '$1'.
exp -> 'nil' : '$1'.
exp -> 'false' : '$1'.
exp -> 'true' : '$1'.
exp -> integer : '$1'.
exp -> float : '$1'.
exp -> functiondef : '$1'.
exp -> string : '$1'.
exp -> function identifier functionbody : { functiondef, line('$1'), '$2', '$3' }.
exp -> new functioncall : {new, '$2'}.
exp -> functioncall : '$1'.
exp -> binop : '$1'.

binop -> exp '+' exp   : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '-' exp   : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '*' exp   : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '/' exp   : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '%' exp   : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '^' exp   : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '==' exp  : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '<=' exp  : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '>=' exp  : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '<' exp   : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp '>' exp   : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp 'and' exp : {op, line('$2'),cat('$2'),'$1','$3'}.
binop -> exp 'or' exp  : {op, line('$2'),cat('$2'),'$1','$3'}.

functioncall -> dottedname '(' ')' : { functioncall, line('$3'), '$1', [] }.
functioncall -> dottedname '(' declaratorlist ')' : { functioncall, line('$4'), '$1', '$3' }.

dottedname -> identifier : { identifier, line('$1'), ['$1'] }.
dottedname -> dottedname '.' identifier : { identifier, line('$2'), element(3, '$1') ++ ['$3'] }.

declaratorlist -> exp : ['$1'].
declaratorlist -> declaratorlist ',' exp : '$1' ++ ['$3'].

%% Functions
functiondef -> function functionbody : { functiondef, line('$1'), '$2' }.
functionbody -> '(' ')' '{' statements '}' : {[], '$4'}.
functionbody -> '(' declaratorlist ')' '{' statements '}' : {'$2', '$5'}.


Erlang code.

cat(T) -> element(1, T).
line(T) -> element(2, T).
