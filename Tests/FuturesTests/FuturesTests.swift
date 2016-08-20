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

import XCTest
import Foundation
@testable import FunctionalConcurrency

class FuturesTests : XCTestCase {

  func testFuture() {

    let result = future(value: 1)
      .map(executor: .utility) { $0 * 3 }
      .wait()

    XCTAssertEqual(result, 3)
  }

  func testSteam() {
    let stream = MutableStream<Int>()
    stream.send([1, 2, 3, 4, 5])
    stream
      .map(executor: .utility) { $0 * 2 }
      .onValue(executor: .utility) { print("\($0)") }
  }

  func testPerformanceFuture() {
    self.measure {
      
      func makePerformer(globalQOS: DispatchQoS.QoSClass, multiplier: Int) -> (Int) -> Int {
        return {
          let queue = DispatchQueue.global(qos: globalQOS)
          if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
          }
          return $0 * multiplier
        }
      }
      
      let result1 = future(value: 1)
        .map(executor: .userInteractive, makePerformer(globalQOS: .userInteractive, multiplier: 2))
        .map(executor: .default, makePerformer(globalQOS: .default, multiplier: 3))
        .map(executor: .utility, makePerformer(globalQOS: .utility, multiplier: 4))
        .map(executor: .background, makePerformer(globalQOS: .background, multiplier: 5))

      let result2 = future(value: 2)
        .map(executor: .background, makePerformer(globalQOS: .background, multiplier: 5))
        .map(executor: .utility, makePerformer(globalQOS: .utility, multiplier: 4))
        .map(executor: .default, makePerformer(globalQOS: .default, multiplier: 3))
        .map(executor: .userInteractive, makePerformer(globalQOS: .userInteractive, multiplier: 2))
      
      let result = combine(result1, result2).map { $0 + $1 }.wait()

      XCTAssertEqual(result, 360)
    }
  }
  
}