//
//  Coroutine.swift
//  Tensor
//
//  Created by Michael Lockyer on 9/17/19.
//

import Foundation
import Dispatch


private let coroutineQueue = DispatchQueue(label: "coroutine",
										   qos: .default,
										   attributes: .concurrent,
										   autoreleaseFrequency: .inherit,
										   target: nil)

// Used to supress warnings about unsused return from
// DispatchSemaphore.wait()
@discardableResult fileprivate func semaphoreWait(semaphore: DispatchSemaphore,
												  timeout: DispatchTime)
	-> DispatchTimeoutResult {
		return semaphore.wait(timeout: timeout)
}

public class Coroutine<Element>: IteratorProtocol {
	private let callerReady = DispatchSemaphore(value: 0)
	private let coroutineReady = DispatchSemaphore(value: 0)
	private var done: Bool = false
	private var transportStorage: Element?
	
	public typealias Yield = (Element) -> ()
	public init(implementation: @escaping (Yield) -> ()) {
		coroutineQueue.async() {
			// Don't start coroutine until first call.
			semaphoreWait(semaphore: self.callerReady, timeout: .distantFuture)
			
			implementation { next in
				// Place element in transport storage, and let caller know it's ready.
				self.transportStorage = next
				self.coroutineReady.signal()
				// Don't continue coroutine until next call.
				semaphoreWait(semaphore: self.callerReady, timeout: .distantFuture)
			}
			// The coroutine is forever over, so let's let the caller know.
			self.done = true
			self.coroutineReady.signal()
		}
	}
	
	public func next() -> Element? {
		// Make sure work is happening before we wait.
		guard !done else { return nil }
		// Return to the coroutine.
		self.callerReady.signal()
		// Wait until it has finished, then return and clear the result.
		semaphoreWait(semaphore: self.coroutineReady, timeout: .distantFuture)
		defer { transportStorage = nil }
		return transportStorage
	}
}
