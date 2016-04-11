# Yield

Lots of languages allow uses to `yield` in functions to easily create generators and coroutines. Yield brings this functionality to Swift using threads. Essentially, Yield spawns a new thread for each coroutine and pauses it when waiting for the next call to `next`.

```swift
let fibbGenerator = Coroutine<Int> { yield in
    var (a, b) = (1, 1)
    while b < 100 {
        (a, b) = (b, a + b)
        yield(a)
   }
}
```

The above coroutine will, on first call to `next`, begin execution. Once it reaches the first `yield` call, it will stop, and wait until the next call to `next`. This will continue until the coroutine finishes execution and returns. At this point, `next` will return `nil`.

Note that a `Coroutine` is a `GeneratorType`, so we can wrap it in an `AnySequence` and use it multiple times.
```swift
let fibb = AnySequence { fibbGenerator }

for x in fibb {
    print(x) // -> 1, 2, 3, 5, 8, 13, 21, 55, 89
}
```

If you want to use `Coroutine` in a iOS or OS X, it's super easy---just use it! If you want to use it in a Playground or a command line application, however, its a bit tricker (but not hard!). Since these don't have main run loop (and thus will never check the coroutine thread to see if its ready), our coroutines won't work. There's an easy fix though. Write all your code in `func main() { ... }`, and then put the following after your function declaration:
```swift
dispatch_async(dispatch_get_main_queue(), main)
dispatch_async(dispatch_get_main_queue(), { exit(0) })
dispatch_main()
```
This will make sure your main function runs and that the program exits once it returns. Additionally, this will start the programs run loop so that our coroutine thread will run.
