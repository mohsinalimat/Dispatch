import Foundation

public typealias DispatchIdentifier = String

public final class Dispatcher {

  public enum Mode {
    case mainThread
    case sync
    case serial
    case async
  }

  public static let `default` = Dispatcher()

  /** All the registered stores. */
  private var stores: [AnyStore] = []

  // The main queue used for the .async mode.
  private let queue = OperationQueue()

  // The serial queue used for the .serial mode.
  private let serialQueue = OperationQueue()

  private var middleware: [Middleware] = []

  /** Returns the store with the given identifier. */
  public func store(with identifier: String) -> AnyStore? {
    return self.stores.filter { $0.identifier == identifier }.first
  }

  public func register(store: AnyStore) {
    precondition(Thread.isMainThread)
    self.stores.append(store)
  }

  public func unregister(identifier: String) {
    precondition(Thread.isMainThread)
    self.stores = self.stores.filter { $0.identifier == identifier }
  }

  public func register(middleware: Middleware) {
    precondition(Thread.isMainThread)
    self.middleware.append(middleware)
  }

  /** Dispatch an action and redirects it to the correct store. */
  public func dispatch(storeIdentifier: String? = nil,
                       action: ActionType,
                       mode: Dispatcher.Mode = .serial,
                       then: ((Void) -> (Void))? = nil) {
    var stores = self.stores
    if let storeIdentifier = storeIdentifier {
      stores = self.stores.filter { $0.identifier == storeIdentifier }
    }
    for store in stores where store.responds(to: action) {
      self.run(action: action, mode: mode, store: store, then: then)
    }
  }

  private func run(action: ActionType,
                   mode: Dispatcher.Mode = .serial,
                   store: AnyStore,
                   then: ((Void) -> (Void))? = nil) {

    // Create a transaction id for this action dispatch.
    // This is useful for the middleware to track down which action got completed.
    let transactionId = NSUUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")

    // Get the operation.
    let operation = store.dispatchOperation(action: action) {
      self.middleware.didDispatch(transaction: transactionId, action: action, in: store)

      // Dispatch chaining.
      if let then = then {
        DispatchQueue.main.async(execute: then)
      }
    }

    // If the store return a 'nil' operation
    guard let op = operation else {
      return
    }

    self.middleware.willDispatch(transaction: transactionId, action: action, in: store)

    // Dispatch the operation on the queue.
    switch mode {
    case .async:
      self.queue.addOperation(op)
    case .serial:
      self.serialQueue.addOperation(op)
    case .sync:
      op.start()
      op.waitUntilFinished()
    case .mainThread:
      DispatchQueue.main.async {
        op.start()
        op.waitUntilFinished()
      }
    }
  }
}


