func undefined[A, B](x : A) -> B {
  undefined(())
}

func id[A](x : A) -> A {
  x
}

func const[A, B](x : A) -> (B) -> A {
  fn(y) { x }
}

func compose[A, B, C](f : (B) -> C, g : (A) -> B) -> (A) -> C {
  fn(x) { f(g(x)) }
}

func println[T : Show](x : T) {
  "\(x)\n".print()
}

struct Cont[R, A] {
  runCont : ((A) -> R) -> R
}

func cont[R, A](f : ((A) -> R) -> R) -> Cont[R, A] {
  { runCont: f }
}

func fmap[R, A, B](f : (A) -> B, self : Cont[R, A]) -> Cont[R, B] {
  cont(fn(k) { self.runCont(compose(k, f)) })
}

func return_[R, A](x : A) -> Cont[R, A] {
  cont(fn(k) { k(x) })
}

func bind[R, A, B](self : Cont[R, A], f : (A) -> Cont[R, B]) -> Cont[R, B] {
  cont(fn(k) { self.runCont(fn(x) { f(x).runCont(k) }) })
}

func withCont[R, A, B](self : Cont[R, B], f : ((A) -> R) -> (B) -> R) ->
     Cont[R, A] {
  cont(fn(y) { self.runCont(f(y)) })
}

func mapCont[R, A, B](self : Cont[R, A], f : (R) -> R) -> Cont[R, A] {
  cont(fn(k) { f(self.runCont(k)) })
}

func callCC[R, A, B](f : ((A) -> Cont[R, B]) -> Cont[R, A]) -> Cont[R, A] {
  cont(fn(k) { f(fn(x) { cont(fn(y) { k(x) }) }).runCont(k) })
}

func lift[R, A, B](self : Cont[R, A]) -> Cont[Cont[R, B], A] {
  cont(fn(k) { self.bind(k) })
}

func reset[R, R0](x : Cont[R, R]) -> Cont[R0, R] {
  return_(x.runCont(id))
}

func shift[R, S, A](f : ((A) -> Cont[S, R]) -> Cont[R, R]) -> Cont[R, A] {
  cont(fn(k) { f(compose(return_, k)).runCont(id) })
}

// usage 1: early exit

// Define a function that calculates the factorial of a number using callCC
func earlyExit1(n : Int) -> Cont[Int, Int] {
  callCC(
    fn(exit) {
      return_(n).bind(
        fn(acc) {
          (if acc < 10 {
            exit(-1)
          } else {
            return_(0)
          }).bind(fn(y) { return_(acc) })
        },
      )
    },
  )
}

func init {
  let r = earlyExit1(5).runCont(id)
  println(r) // -> -1
  let r = earlyExit1(10).runCont(id)
  println(r) // -> 10
}

// usage 2: exception handling

enum Either[A, B] {
  Left(A)
  Right(B)
}

func bind[A, B, C](self : Either[A, B], f : (B) -> Either[A, C]) -> Either[A, C] {
  match self {
    Left(x) => Left(x)
    Right(x) => f(x)
  }
}

func to_string[A : Show, B : Show](self : Either[A, B]) -> String {
  match self {
    Left(x) => "Left(\(x))"
    Right(x) => "Right(\(x))"
  }
}

func divideCont[A](n : Int) -> Cont[A, Int] {
  cont(fn(k) { k(100 / n) })
}

func safeDivide[A](n : Int) -> Cont[A, Either[String, Int]] {
  if n == 0 {
    cont(fn(k) { k(Either::Left("divide by zero")) })
  } else {
    divideCont(n).bind(fn(x) { return_(Either::Right(x)) })
  }
}

func incr[A](n : Int) -> Cont[A, Int] {
  cont(fn(k) { k(n + 1) })
}

func init {
  fn catch(x : Either[String, Int]) {
    match x {
      Left(y) => "Exception: \(y)\n".print()
      Right(y) => "Result: \(y)\n".print()
    }
  }

  let r = safeDivide(0).bind(
    fn(x) {
      match x {
        Right(y) => fmap(fn(x) { Either::Right(x) }, incr(y))
        _ => return_(x)
      }
    },
  ).runCont(catch) // -> Left("divide by zero")
  let r = safeDivide(10).bind(
    fn(x) {
      match x {
        Right(y) => fmap(fn(x) { Either::Right(x) }, incr(y))
        _ => return_(x)
      }
    },
  ).runCont(catch) // -> Right(11)
  ()
}

// usage 3: delimited continuation

func init {
  fn r(n) {
    reset(
      return_(1).bind(
        fn(k) {
          if k < 10 {
            shift(fn(k0) { return_(k0(-1)) })
          } else {
            return_(k + 1)
          }
        },
      ).bind(fn(x) { return_(x + 1) }),
    ).bind(fn(x) { return_(x * 3) }).runCont(id)
  }

  println(r(1)) // -> -3
  println(r(10)) // -> 33
}

