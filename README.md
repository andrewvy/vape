### Vape

toy scripting language implemented in Elixir/Erlang for MUD scripting..

```
Singleton Bar {
  numberOfWidgets = 0;

  function setWidgets(count) {
    numberOfWidgets = count;
  }
}
```

- `Singleton` are singletons that are spawned globally initial in the VM boot.
- `Factory` are object definitions that can create new objects.
- no nested modules.
- dynamic typing
- 1st-class functions
- no static methods, you must instantiate an instance of an object class.
- interop w/ elixir
