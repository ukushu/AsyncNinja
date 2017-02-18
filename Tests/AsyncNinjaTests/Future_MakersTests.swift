//
//  Copyright (c) 2016-2017 Anton Mironov
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

import XCTest
import Dispatch
@testable import AsyncNinja
#if os(Linux)
  import Glibc
#endif

class Future_MakersTests: XCTestCase {

  static let allTests = [
    ("testMakeFutureOfBlock_Success", testMakeFutureOfBlock_Success),
    ("testMakeFutureOfBlock_Failure", testMakeFutureOfBlock_Failure),
    ("testMakeFutureOfDelayedFallibleBlock_Success", testMakeFutureOfDelayedFallibleBlock_Success),
    ("testMakeFutureOfDelayedFallibleBlock_Failure", testMakeFutureOfDelayedFallibleBlock_Failure),
    ("testMakeFutureOfContextualFallibleBlock_Success_ContextAlive", testMakeFutureOfContextualFallibleBlock_Success_ContextAlive),
    ("testMakeFutureOfContextualFallibleBlock_Success_ContextDead", testMakeFutureOfContextualFallibleBlock_Success_ContextDead),
    ("testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive", testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive),
    ("testMakeFutureOfContextualFallibleBlock_Failure_ContextDead", testMakeFutureOfContextualFallibleBlock_Failure_ContextDead),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive", testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive", testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead),
    ]

  func testMakeFutureOfBlock_Success() {
    let qos = pickQoS()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(executor: .queue(qos)) { () -> Int in
      assert(qos: qos)
      expectation.fulfill()
      return try square_success(value)
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfBlock_Failure() {
    let qos = pickQoS()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(executor: .queue(qos)) { () -> Int in
      assert(qos: qos)
      expectation.fulfill()
      return try square_failure(value)
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }

  func testMakeFutureOfDelayedFallibleBlock_Success() {
    let qos = pickQoS()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")
    let startTime = DispatchTime.now()

    let futureValue = future(executor: .queue(qos), after: 0.2) { () -> Int in
      assert(qos: qos)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.2 < finishTime)
      XCTAssert(startTime + 0.4 > finishTime)
      expectation.fulfill()
      return try square_success(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 0.5)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfDelayedFallibleBlock_Failure() {
    let qos = pickQoS()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")
    let startTime = DispatchTime.now()

    let futureValue = future(executor: .queue(qos), after: 0.2) { () -> Int in
      assert(qos: qos)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.2 < finishTime)
      XCTAssert(startTime + 0.4 > finishTime)
      expectation.fulfill()
      return try square_failure(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 0.5)
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }

  func testMakeFutureOfContextualFallibleBlock_Success_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(context: actor) { (actor) -> Int in
      assert(actor: actor)
      expectation.fulfill()
      return try square_success(value)
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfContextualFallibleBlock_Success_ContextDead() {
    let value = pickInt()

    var futureValue: Future<Int>? = nil
    DispatchQueue.global().async {
      let actor = TestActor()
      actor.internalQueue.async {
        sleep(1)
      }
      futureValue = future(context: actor) { (actor) -> Int in
        XCTFail()
        assert(actor: actor)
        return try square_success(value)
      }
    }

    usleep(100_000)
    XCTAssertEqual(futureValue?.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(context: actor) { (actor) -> Int in
      assert(actor: actor)
      expectation.fulfill()
      return try square_failure(value)
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }

  func testMakeFutureOfContextualFallibleBlock_Failure_ContextDead() {
    let value = pickInt()

    var futureValue: Future<Int>? = nil

    DispatchQueue.global().async {
      let actor = TestActor()
      actor.internalQueue.async {
        sleep(1)
      }
      futureValue = future(context: actor) { (actor) -> Int in
        XCTFail()
        assert(actor: actor)
        return try square_failure(value)
      }
    }

    usleep(100_000)
    XCTAssertEqual(futureValue?.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(context: actor, after: 1.0) { (actor) -> Int in
      assert(actor: actor)
      expectation.fulfill()
      return try square_success(value)
    }

    usleep(500_000)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 2.0)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.2) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)
    actor = nil

    usleep(250_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.2) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    actor = nil
    usleep(100_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(context: actor, after: 0.2) { (actor) -> Int in
      assert(actor: actor)
      expectation.fulfill()
      return try square_failure(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 0.3)
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.2) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)
    actor = nil

    usleep(250_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.2) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    actor = nil
    usleep(100_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }
}