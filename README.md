### Lpex

lpc-inspired toy scripting language implemented on Elixir/Erlang.

```
module Bar {
}

module Foo inherits Bar {
  numberOfWidgets = 0;

  function setWidgets(count) {
    numberOfWidgets = count;
  }
}
```

- modules are 'classes'.
- no nested modules.
- dynamic typing
- 1st-class functions
- no static methods, you must instantiate an instance of an object class.
- interop w/ elixir
