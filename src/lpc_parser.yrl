Nonterminals
program block
statement statements
explist exp
semi
declaration declaratorlist
functiondef functionbody parameterlist
.

Terminals
identifier integer
'for' 'until' 'while' 'end'
'function'
'void' 'int' 'float' 'string' 'mixed'
'nil' 'false' 'true'
'='
',' '(' ')' ';'.

Rootsymbol program.

program -> block : '$1'.
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
declaration -> function identifier functionbody : { functiondef, line('$1'), '$2', '$3' }.

%% Expression List
explist -> exp : ['$1'].

exp -> 'nil' : '$1'.
exp -> 'false' : '$1'.
exp -> 'true' : '$1'.
exp -> integer : '$1'.
exp -> float : '$1'.
exp -> functiondef : '$1'.

declaratorlist -> identifier : ['$1'].
declaratorlist -> declaratorlist ',' identifier : '$1' ++ ['$3'].

%% Functions
functiondef -> function functionbody : { functiondef, line('$1'), '$2' }.
functionbody -> '(' ')' block 'end' : {[], '$3'}.
functionbody -> '(' declaratorlist ')' block 'end' : {'$2', '$4'}.

Erlang code.

line(T) -> element(2, T).
