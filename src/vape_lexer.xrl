Definitions.

IDENTIFIER   = [a-zA-Z_][a-zA-Z_0-9]*
INTEGER      = [0-9]+
FLOAT        = (\+|-)?[0-9]+\.[0-9]+((E|e)(\+|-)?[0-9]+)?
WHITESPACE   = [\s\t\n\r]

Rules.

{IDENTIFIER}           : identifier_token(TokenChars, TokenLine).
{INTEGER}              : {token, {'integer', TokenLine, list_to_integer(TokenChars)}}.
{FLOAT}                : {token, {'float', TokenLine, list_to_float(TokenChars)}}.
\=                     : {token, {'=', TokenLine}}.
\#                     : {token, {'#', TokenLine}}.
\.                     : {token, {'.', TokenLine}}.
\<                     : {token, {'<', tokenline}}.
\>                     : {token, {'>', tokenline}}.
\(                     : {token, {'(', TokenLine}}.
\)                     : {token, {')', TokenLine}}.
\{                     : {token, {'{', TokenLine}}.
\}                     : {token, {'}', TokenLine}}.
\[                     : {token, {'[', TokenLine}}.
\]                     : {token, {']', TokenLine}}.
\,                     : {token, {',', TokenLine}}.
\+                     : {token, {'+', TokenLine}}.
\-                     : {token, {'-', TokenLine}}.
\*                     : {token, {'*', TokenLine}}.
\/                     : {token, {'/', TokenLine}}.
\%                     : {token, {'%', TokenLine}}.
\^                     : {token, {'^', TokenLine}}.
>=                     : {token, {'>=', TokenLine}}.
<=                     : {token, {'<=', TokenLine}}.
==                     : {token, {'==', TokenLine}}.
\"(\\.|\\\n|[^"\\])*\" : string_token(TokenChars, TokenLen, TokenLine).
#.*\n?                 : skip_token.
{WHITESPACE}+          : skip_token.

Erlang code.

-export([is_keyword/1]).

identifier_token(Cs, L) ->
  case catch {ok, list_to_atom(Cs)} of
    {ok, Identifier} ->
      case is_keyword(Identifier) of
        true -> {token, {Identifier, L}};
        false -> {token, {'identifier', L, Cs}}
      end;
    _ -> {error,"illegal identifier"}
  end.

string_token(Cs0, Len, L) ->
  Cs = string:substr(Cs0, 2, Len - 2),  %Strip quotes
  case catch {ok,chars(Cs)} of
    {ok,S} ->
      {token, {'string', L, list_to_binary(S)}};
    error -> {error,"illegal string"}
  end.

chars([$\\,C1|Cs0]) when C1 >= $0, C1 =< $9 ->  %1-3 decimal digits
    I1 = C1 - $0,
    case Cs0 of
  [C2|Cs1] when C2 >= $0, C2 =< $9 ->
      I2 = C2 - $0,
      case Cs1 of
    [C3|Cs2] when C3 >= $0, C3 =< $9 ->
        [100*I1 + 10*I2 + (C3-$0)|chars(Cs2)];
    _ -> [10*I1 + I2|chars(Cs1)]
      end;
  _ -> [I1|chars(Cs0)]
    end;
chars([$\\,$x,C1,C2|Cs]) ->     %2 hex digits
    case hex_char(C1) and hex_char(C2) of
  true -> [hex_val(C1)*16+hex_val(C2)|chars(Cs)];
  false -> throw(error)
    end;
chars([$\\,$z|Cs]) -> chars(skip_space(Cs));  %Skip blanks
chars([$\\,C|Cs]) -> [escape_char(C)|chars(Cs)];
chars([$\n|_]) -> throw(error);
chars([C|Cs]) -> [C|chars(Cs)];
chars([]) -> [].
skip_space([C|Cs]) when C >= 0, C =< $\s -> skip_space(Cs);
skip_space(Cs) -> Cs.
hex_char(C) when C >= $0, C =< $9 -> true;
hex_char(C) when C >= $a, C =< $f -> true;
hex_char(C) when C >= $A, C =< $F -> true;
hex_char(_) -> false.
hex_val(C) when C >= $0, C =< $9 -> C - $0;
hex_val(C) when C >= $a, C =< $f -> C - $a + 10;
hex_val(C) when C >= $A, C =< $F -> C - $A + 10.

escape_char($n) -> $\n;       %\n = LF
escape_char($r) -> $\r;       %\r = CR
escape_char($t) -> $\t;       %\t = TAB
escape_char($v) -> $\v;       %\v = VT
escape_char($b) -> $\b;       %\b = BS
escape_char($f) -> $\f;       %\f = FF
escape_char($e) -> $\e;       %\e = ESC
escape_char($s) -> $\s;       %\s = SPC
escape_char($d) -> $\d;       %\d = DEL
escape_char(C) -> C.

is_keyword('import') -> true;
is_keyword('object') -> true;
is_keyword('else') -> true;
is_keyword('false') -> true;
is_keyword('for') -> true;
is_keyword('function') -> true;
is_keyword('if') -> true;
is_keyword('null') -> true;
is_keyword('return') -> true;
is_keyword('true') -> true;
is_keyword('while') -> true;
is_keyword('new') -> true;
is_keyword('and') -> true;
is_keyword('or') -> true;
is_keyword(_) -> false.
