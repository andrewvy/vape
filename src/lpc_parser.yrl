Nonterminals
program block
statement statements
explist exp
semi
declaration declaratorlist
functiondef functionbody parameterlist
.

Terminals
IDENTIFIER
'module' 'inherits'
'function'
INTEGER FLOAT
'float' 'string' 'mixed'
'nil' 'false' 'true'
'='
',' '(' ')' '{' '}' '[' ']' ';'.

Rootsymbol program.

program -> block : '$1'.

block -> block module IDENTIFIER inherits IDENTIFIER '{' block '}' : '$1' ++ [{module_inherit, line('$3'), '$3', '$5', '$7'}].
block -> block module IDENTIFIER '{' block '}' : '$1' ++ [{module, line('$3'), '$3', '$5'}].
block -> statements : '$1'.

semi -> ';'.
semi -> '$empty'.

%% Statements
statements -> '$empty' : [].
statements -> statements statement : '$1' ++ ['$2'].

%% Statement
statement -> ';' : '$1'.
statement -> declaration : '$1'.

%% Declaration
declaration -> declaratorlist : {assign, line(hd('$1')), '$1', []}.
declaration -> declaratorlist '=' explist : {assign, line('$2'), '$1', '$3'}.
declaration -> function IDENTIFIER functionbody : { functiondef, line('$1'), '$2', '$3' }.

%% Expression List
explist -> exp : ['$1'].

exp -> 'nil' : '$1'.
exp -> 'false' : '$1'.
exp -> 'true' : '$1'.
exp -> INTEGER : '$1'.
exp -> FLOAT : '$1'.
exp -> functiondef : '$1'.

declaratorlist -> IDENTIFIER : ['$1'].
declaratorlist -> declaratorlist ',' IDENTIFIER : '$1' ++ ['$3'].

%% Functions
functiondef -> function functionbody : { functiondef, line('$1'), '$2' }.
functionbody -> '(' ')' '{' block '}' : {[], '$3'}.
functionbody -> '(' declaratorlist ')' '{' block '}' : {'$2', '$4'}.

Erlang code.

line(T) -> element(2, T).
