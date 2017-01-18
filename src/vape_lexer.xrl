Definitions.

IDENTIFIER   = [a-zA-Z_][a-zA-Z_0-9]*
INTEGER      = [0-9]+
FLOAT        = (\+|-)?[0-9]+\.[0-9]+((E|e)(\+|-)?[0-9]+)?
WHITESPACE   = [\s\t\n\r]

Rules.

{IDENTIFIER}     : identifier_token(TokenChars, TokenLine).
{INTEGER}        : {token, {'integer', TokenLine, list_to_integer(TokenChars)}}.
{FLOAT}          : {token, {'float', TokenLine, list_to_float(TokenChars)}}.
\=               : {token, {'=', TokenLine}}.
\#               : {token, {'#', TokenLine}}.
\.               : {token, {'.', TokenLine}}.
\<               : {token, {'<', tokenline}}.
\>               : {token, {'>', tokenline}}.
\(               : {token, {'(', TokenLine}}.
\)               : {token, {')', TokenLine}}.
\{               : {token, {'{', TokenLine}}.
\}               : {token, {'}', TokenLine}}.
\[               : {token, {'[', TokenLine}}.
\]               : {token, {']', TokenLine}}.
\;               : {token, {';', TokenLine}}.
\,               : {token, {',', TokenLine}}.
\+               : {token, {'+', TokenLine}}.
\-               : {token, {'-', TokenLine}}.
\*               : {token, {'*', TokenLine}}.
\/               : {token, {'/', TokenLine}}.
>=               : {token, {'>=', TokenLine}}.
<=               : {token, {'<=', TokenLine}}.
==               : {token, {'==', TokenLine}}.
'+='             : {token, {'+=', tokenline}}.
'-='             : {token, {'-=', tokenline}}.
'++'             : {token, {'++', tokenline}}.
'--'             : {token, {'--', tokenline}}.
{WHITESPACE}+    : skip_token.

Erlang code.

-export([is_keyword/1]).

identifier_token(Cs, L) ->
  case catch {ok, list_to_atom(Cs)} of
    {ok, Identifier} ->
      case is_keyword(Identifier) of
        true -> {token, {Identifier, L}};
        false -> {token, {'identifier', L, Identifier}}
      end;
    _ -> {error,"illegal identifier"}
  end.

is_keyword('module') -> true;
is_keyword('break') -> true;
is_keyword('do') -> true;
is_keyword('else') -> true;
is_keyword('false') -> true;
is_keyword('for') -> true;
is_keyword('function') -> true;
is_keyword('if') -> true;
is_keyword('in') -> true;
is_keyword('nil') -> true;
is_keyword('return') -> true;
is_keyword('true') -> true;
is_keyword('while') -> true;
is_keyword(_) -> false.
