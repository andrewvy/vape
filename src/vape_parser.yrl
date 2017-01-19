Nonterminals
program block
statement statements
dottedname
explist exp
declaration declaratorlist
functiondef functionbody functioncall
.

Terminals
identifier
'object'
'function'
integer float string
new 'nil' 'false' 'true'
'=' '.'
',' '(' ')' '{' '}'.

Rootsymbol program.

program -> block : '$1'.

block -> block object identifier '{' block '}' : '$1' ++ [{object, line('$3'), '$3', '$5'}].
block -> statements : '$1'.

%% Statements
statements -> '$empty' : [].
statements -> statements statement : '$1' ++ ['$2'].

%% Statement
statement -> declaration : '$1'.

%% Declaration
declaration -> declaratorlist : { declaration, line(hd('$1')), '$1', [] }.
declaration -> declaratorlist '=' explist : { assign, line('$2'), '$1', '$3' }.

%% Expression List
explist -> exp : ['$1'].

exp -> 'nil' : '$1'.
exp -> 'false' : '$1'.
exp -> 'true' : '$1'.
exp -> integer : '$1'.
exp -> float : '$1'.
exp -> functiondef : '$1'.
exp -> string : '$1'.
exp -> function identifier functionbody : { functiondef, line('$1'), '$2', '$3' }.
exp -> new functioncall : {'$1', '$2'}.
exp -> functioncall : '$1'.

functioncall -> dottedname '(' ')' : { functioncall, line('$3'), '$1', [] }.
functioncall -> dottedname '(' declaratorlist ')' : { functioncall, line('$4'), '$1', '$3' }.

dottedname -> identifier : ['$1'].
dottedname -> dottedname '.' identifier : '$1' ++ ['$3'].

declaratorlist -> identifier : ['$1'].
declaratorlist -> exp : ['$1'].
declaratorlist -> declaratorlist ',' identifier : '$1' ++ ['$3'].

%% Functions
functiondef -> function functionbody : { functiondef, line('$1'), '$2' }.
functionbody -> '(' ')' '{' block '}' : {[], '$4'}.
functionbody -> '(' declaratorlist ')' '{' block '}' : {'$2', '$5'}.


Erlang code.

line(T) -> element(2, T).
