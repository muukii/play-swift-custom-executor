import Dispatch
import Foundation

final class ImmediateMainQueueExecutor: SerialExecutor {

  func enqueue(_ job: UnownedJob) {
    let e = self.asUnownedSerialExecutor()
    if Thread.isMainThread {
      job.runSynchronously(on: e)
    } else {
      DispatchQueue.main.async {
        job.runSynchronously(on: e)
      }
    }
  }

  func asUnownedSerialExecutor() -> UnownedSerialExecutor {
    .init(ordinary: self)
  }
}

@globalActor
actor ImmediateMainActor {

  static var shared: ImmediateMainActor = .init()

  typealias ActorType = ImmediateMainActor

  init() {

  }

  func foo() {
    print(Thread.isMainThread)
  }

  private let executor = ImmediateMainQueueExecutor()

  nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

  func perform(_ body: @Sendable (isolated ImmediateMainActor) -> Void) {
    body(self)
  }

  static let executor = ImmediateMainQueueExecutor()
  static var sharedUnownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

  @ImmediateMainActor
  public static func run<T>(resultType: T.Type = T.self, body: @ImmediateMainActor @Sendable () throws -> T) async rethrows -> T where T : Sendable {

    print("[MyActor] run")

    return try body()
  }
}
