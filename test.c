module Bar {
}

module Foo inherits Bar {
  number_of_widgets = 0;

  function setWidgetsToTen() {
    number_of_widgets = 10;
  }
}
