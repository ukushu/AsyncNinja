//
//  Copyright (c) 2016 Anton Mironov
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom
//  the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

public extension Future {
  
  final func map<U: ExecutionContext, V>(context: U?, _ transform: @escaping (Value, U) throws -> V) -> FallibleFuture<V> {
    let promise = Promise<Fallible<V>>()
    weak var weakContext = context
    let handler = FutureHandler<Value>(executor: .immediate) { value in
      if let context = weakContext {
        context.executor.execute {
          promise.complete(with: fallible { try transform(value, context) })
        }
      } else {
        promise.complete(with: Fallible(failure: ConcurrencyError.ownedDeallocated))
      }
    }
    self.add(handler: handler)
    promise.releasePool.insert(handler)
    return promise
  }

  final func onValue<U: ExecutionContext>(context: U?, block: @escaping (Value, U) -> Void) {
    weak var weakContext = context
    let handler = FutureHandler<Value>(executor: Executor.immediate) { value in
      if let context = weakContext {
        context.executor.execute { block(value, context) }
      }
    }
    self.add(handler: handler)
    context?.releasePool.insert(handler)
  }
}

public extension Future where T : _Fallible {

  final public func liftSuccess<T, U: ExecutionContext>(context: U?, transform: @escaping (Success, U) throws -> T) -> FallibleFuture<T> {
    return self.map(context: context) { (value, context) in
      if let failureValue = value.failureValue { throw failureValue }
      if let successValue = value.successValue { return try transform(successValue, context) }
      fatalError()
    }
  }

  final public func onSuccess<U: ExecutionContext>(context: U?, block: @escaping (Success, U) -> Void) {
    self.onValue(context: context) { (value, context) in
      guard let successValue = value.successValue else { return }
      block(successValue, context)
    }
  }

  final public func liftFailure<U: ExecutionContext>(context: U?, transform: @escaping (Error, U) throws -> Success) -> FallibleFuture<Success> {
    return self.map(context: context) { (value, context) in
      if let failureValue = value.failureValue { return try transform(failureValue, context) }
      if let successValue = value.successValue { return successValue }
      fatalError()
    }
  }

  final public func onFailure<U: ExecutionContext>(context: U?, block: @escaping (Error, U) -> Void) {
    self.onValue(context: context) { (value, context) in
      guard let failureValue = value.failureValue else { return }
      block(failureValue, context)
    }
  }
}

public func future<T>(context: ExecutionContext, block: @escaping () -> T) -> Future<T> {
    let promise = Promise<T>()
    context.executor.execute { promise.complete(with: block()) }
    return promise
}

public func future<T>(context: ExecutionContext, block: @escaping () throws -> T) -> FallibleFuture<T> {
    let promise = FalliblePromise<T>()
    context.executor.execute { promise.complete(with: fallible(block: block)) }
    return promise
}