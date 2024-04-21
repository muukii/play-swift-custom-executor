import XCTest

@testable import custom_executor

final class custom_executorTests: XCTestCase {

  private var subscription: RunLoopActivityObserver.Subscription?
  private var count: Int = 0

  override func setUp() {
    super.setUp()

    subscription = RunLoopActivityObserver.reduce(acitivity: .allActivities, in: .main, initial: 0) {

      $0 += 1

      print("🔄 [RunLoop] cycle \($0)")

      self.count = $0
    }

  }

  override func tearDown() {
    super.tearDown()

    RunLoopActivityObserver.remove(subscription!)
  }

  @MainActor
  func testAsyncInMyActor() async {

    print("=> Enter")
    await ImmediateMainActor.run {
      print("👨🏻 result: 1")
    }
    print("<= Leave")

  }

  @MainActor
  func testAsyncInMyActor2() async {

    print("=> Enter")
    await Task { @ImmediateMainActor in
      print("👨🏻 result: 1")
    }
    .value
    print("<= Leave")

  }

  @MainActor
  func testAsyncInMainActor() async {

    print("=> Enter")
    await MainActor.run {
      print("👨🏻 result: 1")
    }
    print("<= Leave")

  }

  @MainActor
  func testAsyncInMainActorImmediately() async {

    print("=> Enter")
    await MainActor.immediateRun {
      print("👨🏻 result: 1")
    }
    print("<= Leave")

  }

  @MainActor
  func testAsyncInMainActorUsingTask() async {

    print("=> Enter")
    await Task { @MainActor in
      print("👨🏻 result: 1")
    }
    .value
    print("<= Leave")

  }


}

extension MainActor {

  @MainActor
  public static func immediateRun<T>(resultType: T.Type = T.self, body: @MainActor @Sendable () throws -> T) async rethrows -> T where T : Sendable {
    return try body()
  }
}

private enum RunLoopActivityObserver {

  struct Subscription {
    let mode: CFRunLoopMode
    let observer: CFRunLoopObserver?
    weak var targetRunLoop: RunLoop?
  }

  static func addObserver(
    acitivity: CFRunLoopActivity,
    in runLoop: RunLoop,
    callback: @escaping () -> Void
  ) -> Subscription {

    let o = CFRunLoopObserverCreateWithHandler(
      kCFAllocatorDefault,
      acitivity.rawValue,
      true,
      Int.max,
      { observer, activity in
        callback()
      }
    )

    assert(o != nil)

    let mode = CFRunLoopMode.commonModes!
    let cfRunLoop = runLoop.getCFRunLoop()

    CFRunLoopAddObserver(cfRunLoop, o, mode)

    return .init(mode: mode, observer: o, targetRunLoop: runLoop)
  }

  static func reduce<Accumulation>(
    acitivity: CFRunLoopActivity,
    in runLoop: RunLoop,
    initial: Accumulation,
    reduce: @escaping (inout Accumulation) -> Void
  ) -> Subscription {
    var current = initial
    return addObserver(acitivity: acitivity, in: runLoop) {
      reduce(&current)
    }
  }

  static func remove(_ subscription: Subscription) {

    guard let observer = subscription.observer, let targetRunLoop = subscription.targetRunLoop
    else {
      return
    }

    CFRunLoopRemoveObserver(targetRunLoop.getCFRunLoop(), observer, subscription.mode)
  }

}
