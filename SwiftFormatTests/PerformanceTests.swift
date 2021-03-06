//
//  PerformanceTests.swift
//  SwiftFormat
//
//  Created by Nick Lockwood on 30/10/2016.
//  Copyright © 2016 Nick Lockwood. All rights reserved.
//

import XCTest
import SwiftFormat

class PerformanceTests: XCTestCase {

    static let files: [String] = {
        var files = [String]()
        let inputURL = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        enumerateSwiftFiles(withInputURL: inputURL) { url, _ in
            if let source = try? String(contentsOf: url) {
                files.append(source)
            }
        }
        return files
    }()

    func testTokenizing() {
        let files = PerformanceTests.files
        var tokens = [[Token]]()
        measure {
            tokens = files.map { tokenize($0) }
        }
        for tokens in tokens {
            if let token = tokens.last, case .error(let msg) = token {
                XCTFail("error: \(msg)")
            }
        }
    }

    func testFormatting() {
        let files = PerformanceTests.files
        let tokens = files.map { tokenize($0) }
        measure {
            _ = tokens.flatMap { try? format($0) }
        }
    }

    func testIndent() {
        let files = PerformanceTests.files
        let tokens = files.map { tokenize($0) }
        measure {
            _ = tokens.flatMap { try? format($0, rules: [indent]) }
        }
    }
}
