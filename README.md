### Vape

toy scripting language implemented in Elixir/Erlang for MUD scripting..

```
module Bar {
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
