Factory Counter {
  count = 0

  function increment() {
    count = count + 1
  }

  function decrement() {
    count = count - 1
  }

  function getCount() {
    return count
  }
}

export Counter
