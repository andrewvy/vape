import Counter from "counter_factory.v"

Singleton CountToThree {
  counter = new Counter()

  function initialize() {
    counter.increment()
    counter.increment()
    counter.increment()

    count = counter.getCount()
    print(count)
  }
}

export CountToThree
