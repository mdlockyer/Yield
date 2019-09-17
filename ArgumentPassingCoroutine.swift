import Dispatch

private let coroutineQueue = DispatchQueue(label: "coroutine",
										   qos: .default,
										   attributes: .concurrent,
										   autoreleaseFrequency: .inherit,
										   target: nil)

private enum TransportStorage<Argument, Element> {
    case Input(Argument)
    case Output(Element)
}

// Used to supress warnings about unsused return from
// DispatchSemaphore.wait()
@discardableResult fileprivate func semaphoreWait(semaphore: DispatchSemaphore,
												  timeout: DispatchTime)
	-> DispatchTimeoutResult {
		return semaphore.wait(timeout: timeout)
}

public class ArgumentPassingCoroutine<Argument, Element> {
	private let callerReady = DispatchSemaphore(value: 0)
	private let coroutineReady = DispatchSemaphore(value: 0)
    private var done: Bool = false
    private var transportStorage: TransportStorage<Argument, Element>?
    
	public typealias Yield = (Element) -> Argument
	public init(implementation: @escaping (Yield) -> ()) {
        coroutineQueue.async() {
            // Don't start coroutine until first call.
            semaphoreWait(semaphore: self.callerReady, timeout: .distantFuture)
            
            implementation { next in
                // Place element in transport storage, and let caller know it's ready.
                self.transportStorage = .Output(next)
                self.coroutineReady.signal()
                
                // Don't continue coroutine until next call.
                self.coroutineReady.signal()
                
                // Caller sent the next argument, so let's continue.
                defer { self.transportStorage = nil }
                guard case let .some(.Input(input)) = self.transportStorage else { fatalError() }
                return input
            }
            
            // The coroutine is forever over, so let's let the caller know.
            self.done = true
            self.coroutineReady.signal()
        }
    }
    
    public func next(argument: Argument) -> Element? {
        // Make sure work is happening before we wait.
        guard !done else { return nil }
        // Return to the coroutine, passing the argument.
        transportStorage = .Input(argument)
        self.callerReady.signal()
        // Return to the caller the result, then clear it.
        semaphoreWait(semaphore: self.coroutineReady, timeout: .distantFuture)
        guard case let .some(.Output(output)) = transportStorage else { return nil }
        return output
    }
}
