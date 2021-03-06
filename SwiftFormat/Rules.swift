//
//  Rules.swift
//  SwiftFormat
//
//  Version 0.17.1
//
//  Created by Nick Lockwood on 12/08/2016.
//  Copyright 2016 Nick Lockwood
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/SwiftFormat
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

public typealias FormatRule = (Formatter) -> Void

/// Implement the following rules with respect to the spacing around parens:
/// * There is no space between an opening paren and the preceding identifier,
///   unless the identifier is one of the specified keywords
/// * There is no space between an opening paren and the preceding closing brace
/// * There is no space between an opening paren and the preceding closing square bracket
/// * There is space between a closing paren and following identifier
/// * There is space between a closing paren and following opening brace
/// * There is no space between a closing paren and following opening square bracket
public func spaceAroundParens(_ formatter: Formatter) {

    func spaceAfter(_ keyword: String, index: Int) -> Bool {
        switch keyword {
        case "@autoclosure":
            if let nextIndex = formatter.indexOfNextToken(fromIndex: index, matching: { !$0.isWhitespaceOrLinebreak }),
                formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: nextIndex) == .identifier("escaping") {
                assert(formatter.tokens[nextIndex] == .startOfScope("("))
                return false
            }
            return true
        case "@escaping", "@noescape":
            return true
        case "private", "fileprivate", "internal",
             "init", "subscript":
            return false
        default:
            if let first = keyword.characters.first {
                return !"@#".characters.contains(first)
            }
            return true
        }
    }

    func isCaptureList(atIndex i: Int) -> Bool {
        assert(formatter.tokens[i] == .endOfScope("]"))
        guard formatter.previousToken(fromIndex: i + 1, matching: {
            !$0.isWhitespaceOrCommentOrLinebreak && $0 != .endOfScope("]") }) == .startOfScope("{")
        else { return false }
        guard formatter.nextToken(fromIndex: i, matching: {
            !$0.isWhitespaceOrCommentOrLinebreak && $0 != .startOfScope("(") }) == .keyword("in")
        else { return false }
        return true
    }

    func isAttribute(atIndex i: Int) -> Bool {
        assert(formatter.tokens[i] == .endOfScope(")"))
        guard let openParenIndex = formatter.indexOfPreviousToken(
            fromIndex: i, matching: { $0 == .startOfScope("(") }) else { return false }
        guard let prevToken = formatter.previousToken(fromIndex: openParenIndex, matching: {
            !$0.isWhitespaceOrCommentOrLinebreak }), case .keyword(let string) = prevToken,
            string.hasPrefix("@") else { return false }
        return true
    }

    formatter.forEachToken(.startOfScope("(")) { i, token in
        guard let previousToken = formatter.tokenAtIndex(i - 1) else {
            return
        }
        switch previousToken {
        case .keyword(let string) where spaceAfter(string, index: i - 1):
            fallthrough
        case .endOfScope("]") where isCaptureList(atIndex: i - 1),
             .endOfScope(")") where isAttribute(atIndex: i - 1):
            formatter.insertToken(.whitespace(" "), atIndex: i)
        case .whitespace:
            if let token = formatter.tokenAtIndex(i - 2) {
                switch token {
                case .keyword(let string) where !spaceAfter(string, index: i - 2):
                    fallthrough
                case .identifier:
                    fallthrough
                case .endOfScope("}"), .endOfScope(">"),
                     .endOfScope("]") where !isCaptureList(atIndex: i - 2),
                     .endOfScope(")") where !isAttribute(atIndex: i - 2):
                    formatter.removeTokenAtIndex(i - 1)
                default:
                    break
                }
            }
        default:
            break
        }
    }
    formatter.forEachToken(.endOfScope(")")) { i, token in
        guard let nextToken = formatter.tokenAtIndex(i + 1) else {
            return
        }
        switch nextToken {
        case .identifier, .keyword, .startOfScope("{"):
            formatter.insertToken(.whitespace(" "), atIndex: i + 1)
        case .whitespace where formatter.tokenAtIndex(i + 2) == .startOfScope("["):
            formatter.removeTokenAtIndex(i + 1)
        default:
            break
        }
    }
}

/// Remove whitespace immediately inside parens
public func spaceInsideParens(_ formatter: Formatter) {
    formatter.forEachToken(.startOfScope("(")) { i, token in
        if formatter.tokenAtIndex(i + 1)?.isWhitespace == true {
            formatter.removeTokenAtIndex(i + 1)
        }
    }
    formatter.forEachToken(.endOfScope(")")) { i, token in
        if formatter.tokenAtIndex(i - 1)?.isWhitespace == true &&
            formatter.tokenAtIndex(i - 2)?.isLinebreak == false {
            formatter.removeTokenAtIndex(i - 1)
        }
    }
}

/// Implement the following rules with respect to the spacing around square brackets:
/// * There is no space between an opening bracket and the preceding identifier,
///   unless the identifier is one of the specified keywords
/// * There is no space between an opening bracket and the preceding closing brace
/// * There is no space between an opening bracket and the preceding closing square bracket
/// * There is space between a closing bracket and following identifier
/// * There is space between a closing bracket and following opening brace
public func spaceAroundBrackets(_ formatter: Formatter) {

    func spaceAfter(_ token: Token, index: Int) -> Bool {
        switch token {
        case .keyword:
            return true
        default:
            return false
        }
    }

    formatter.forEachToken(.startOfScope("[")) { i, token in
        guard let previousToken = formatter.tokenAtIndex(i - 1) else {
            return
        }
        if spaceAfter(previousToken, index: i - 1) {
            formatter.insertToken(.whitespace(" "), atIndex: i)
        } else if previousToken.isWhitespace {
            if let token = formatter.tokenAtIndex(i - 2) {
                switch token {
                case .identifier, .keyword:
                    if !spaceAfter(token, index: i - 2) {
                        fallthrough
                    }
                case .endOfScope("]"), .endOfScope("}"), .endOfScope(")"):
                    formatter.removeTokenAtIndex(i - 1)
                default:
                    break
                }
            }
        }
    }
    formatter.forEachToken(.endOfScope("]")) { i, token in
        guard let nextToken = formatter.tokenAtIndex(i + 1) else {
            return
        }
        switch nextToken {
        case .identifier, .keyword, .startOfScope("{"):
            formatter.insertToken(.whitespace(" "), atIndex: i + 1)
        case .whitespace where formatter.tokenAtIndex(i + 2) == .startOfScope("["):
            formatter.removeTokenAtIndex(i + 1)
        default:
            break
        }
    }
}

/// Remove whitespace immediately inside square brackets
public func spaceInsideBrackets(_ formatter: Formatter) {
    formatter.forEachToken(.startOfScope("[")) { i, token in
        if formatter.tokenAtIndex(i + 1)?.isWhitespace == true {
            formatter.removeTokenAtIndex(i + 1)
        }
    }
    formatter.forEachToken(.endOfScope("]")) { i, token in
        if formatter.tokenAtIndex(i - 1)?.isWhitespace == true &&
            formatter.tokenAtIndex(i - 2)?.isLinebreak == false {
            formatter.removeTokenAtIndex(i - 1)
        }
    }
}

/// Ensure that there is space between an opening brace and the preceding
/// identifier, and between a closing brace and the following identifier.
public func spaceAroundBraces(_ formatter: Formatter) {
    formatter.forEachToken(.startOfScope("{")) { i, token in
        if let previousToken = formatter.tokenAtIndex(i - 1) {
            switch previousToken {
            case .whitespace, .linebreak:
                break
            case .startOfScope(let string) where string != "\"":
                break
            default:
                formatter.insertToken(.whitespace(" "), atIndex: i)
            }
        }
    }
    formatter.forEachToken(.endOfScope("}")) { i, token in
        if let nextToken = formatter.tokenAtIndex(i + 1) {
            switch nextToken {
            case .identifier, .keyword:
                formatter.insertToken(.whitespace(" "), atIndex: i + 1)
            default:
                break
            }
        }
    }
}

/// Ensure that there is space immediately inside braces
public func spaceInsideBraces(_ formatter: Formatter) {
    formatter.forEachToken(.startOfScope("{")) { i, token in
        if let nextToken = formatter.tokenAtIndex(i + 1) {
            if nextToken.isWhitespace {
                if formatter.tokenAtIndex(i + 2) == .endOfScope("}") {
                    formatter.removeTokenAtIndex(i + 1)
                }
            } else if !nextToken.isLinebreak && nextToken != .endOfScope("}") {
                formatter.insertToken(.whitespace(" "), atIndex: i + 1)
            }
        }
    }
    formatter.forEachToken(.endOfScope("}")) { i, token in
        if let previousToken = formatter.tokenAtIndex(i - 1),
            !previousToken.isWhitespaceOrLinebreak && previousToken != .startOfScope("{") {
            formatter.insertToken(.whitespace(" "), atIndex: i)
        }
    }
}

/// Ensure there is no space between an opening chevron and the preceding identifier
public func spaceAroundGenerics(_ formatter: Formatter) {
    formatter.forEachToken(.startOfScope("<")) { i, token in
        if formatter.tokenAtIndex(i - 1)?.isWhitespace == true &&
            formatter.tokenAtIndex(i - 2)?.isIdentifierOrKeyword == true {
            formatter.removeTokenAtIndex(i - 1)
        }
    }
}

/// Remove whitespace immediately inside chevrons
public func spaceInsideGenerics(_ formatter: Formatter) {
    formatter.forEachToken(.startOfScope("<")) { i, token in
        if formatter.tokenAtIndex(i + 1)?.isWhitespace == true {
            formatter.removeTokenAtIndex(i + 1)
        }
    }
    formatter.forEachToken(.endOfScope(">")) { i, token in
        if formatter.tokenAtIndex(i - 1)?.isWhitespace == true &&
            formatter.tokenAtIndex(i - 2)?.isLinebreak == false {
            formatter.removeTokenAtIndex(i - 1)
        }
    }
}

/// Implement the following rules with respect to the spacing around operators:
/// * Infix operators are separated from their operands by a space on either
///   side. Does not affect prefix/postfix operators, as required by syntax.
/// * Punctuation such as commas and colons is consistently followed by a
///   single space, unless it appears at the end of a line, and is not
///   preceded by a space, unless it appears at the beginning of a line.
public func spaceAroundOperators(_ formatter: Formatter) {

    func isLvalue(_ token: Token) -> Bool {
        switch token {
        case .identifier, .number, .endOfScope, .symbol("?"), .symbol("!"):
            return true
        default:
            return false
        }
    }

    func isRvalue(_ token: Token) -> Bool {
        switch token {
        case .identifier, .number, .startOfScope:
            return true
        default:
            return false
        }
    }

    func isUnwrapOperatorSequence(_ token: Token) -> Bool {
        if case .symbol(let string) = token {
            for c in string.characters {
                if c != "?" && c != "!" {
                    return false
                }
            }
        }
        return true
    }

    func spaceAfter(_ token: Token, index: Int) -> Bool {
        switch token {
        case .keyword, .endOfScope("case"):
            return true
        default:
            return false
        }
    }

    var scopeStack: [Token] = []
    formatter.forEachToken { i, token in
        switch token {
        case .symbol(":"):
            if let nextToken = formatter.tokenAtIndex(i + 1) {
                switch nextToken {
                case .whitespace, .linebreak, .endOfScope:
                    break
                case .identifier where formatter.tokenAtIndex(i + 2) == .symbol(":"):
                    // It's a selector
                    break
                default:
                    // Ensure there is a space after the token
                    formatter.insertToken(.whitespace(" "), atIndex: i + 1)
                }
            }
            if scopeStack.last == .symbol("?") {
                // Treat the next : after a ? as closing the ternary scope
                scopeStack.removeLast()
                // Ensure there is a space before the :
                if let previousToken = formatter.tokenAtIndex(i - 1) {
                    if !previousToken.isWhitespaceOrLinebreak {
                        formatter.insertToken(.whitespace(" "), atIndex: i)
                    }
                }
            } else if formatter.tokenAtIndex(i - 1)?.isWhitespace == true &&
                formatter.tokenAtIndex(i - 2)?.isLinebreak == false {
                // Remove space before the token
                formatter.removeTokenAtIndex(i - 1)
            }
        case .symbol(","), .symbol(";"):
            if let nextToken = formatter.tokenAtIndex(i + 1) {
                switch nextToken {
                case .whitespace, .linebreak, .endOfScope:
                    break
                default:
                    // Ensure there is a space after the token
                    formatter.insertToken(.whitespace(" "), atIndex: i + 1)
                }
            }
            if formatter.tokenAtIndex(i - 1)?.isWhitespace == true &&
                formatter.tokenAtIndex(i - 2)?.isLinebreak == false {
                // Remove space before the token
                formatter.removeTokenAtIndex(i - 1)
            }
        case .symbol("?"):
            if let previousToken = formatter.tokenAtIndex(i - 1), let nextToken = formatter.tokenAtIndex(i + 1) {
                if nextToken.isWhitespaceOrLinebreak {
                    if previousToken.isWhitespaceOrLinebreak {
                        // ? is a ternary operator, treat it as the start of a scope
                        scopeStack.append(token)
                    }
                } else if [.keyword("as"), .keyword("try")].contains(previousToken) {
                    formatter.insertToken(.whitespace(" "), atIndex: i + 1)
                }
            }
        case .symbol("!"):
            if let previousToken = formatter.tokenAtIndex(i - 1), let nextToken = formatter.tokenAtIndex(i + 1) {
                if !nextToken.isWhitespaceOrLinebreak &&
                    [.keyword("as"), .keyword("try")].contains(previousToken) {
                    formatter.insertToken(.whitespace(" "), atIndex: i + 1)
                }
            }
        case .symbol("."):
            if formatter.tokenAtIndex(i + 1)?.isWhitespace == true {
                formatter.removeTokenAtIndex(i + 1)
            }
            if let previousToken = formatter.tokenAtIndex(i - 1) {
                let previousNonWhitespaceTokenIndex = i - (previousToken.isWhitespace ? 2 : 1)
                if let previousNonWhitespaceToken = formatter.tokenAtIndex(previousNonWhitespaceTokenIndex) {
                    let previousNonWhitespaceTokenIsSymbol: Bool = {
                        if case .symbol = previousNonWhitespaceToken {
                            return true
                        }
                        return false
                    }()
                    if !previousNonWhitespaceToken.isLinebreak && previousNonWhitespaceToken != .startOfScope("{") &&
                        (!previousNonWhitespaceTokenIsSymbol ||
                            (previousNonWhitespaceToken == .symbol("?") && scopeStack.last != .symbol("?")) ||
                            (previousNonWhitespaceToken != .symbol("?") &&
                                formatter.tokenAtIndex(previousNonWhitespaceTokenIndex - 1)?.isWhitespace == false &&
                                isUnwrapOperatorSequence(previousNonWhitespaceToken))) &&
                        !spaceAfter(previousNonWhitespaceToken, index: previousNonWhitespaceTokenIndex) {
                        if previousToken.isWhitespace {
                            formatter.removeTokenAtIndex(i - 1)
                        }
                    } else if !previousToken.isWhitespace {
                        formatter.insertToken(.whitespace(" "), atIndex: i)
                    }
                }
            }
        case .symbol("->"):
            if let nextToken = formatter.tokenAtIndex(i + 1) {
                if !nextToken.isWhitespaceOrLinebreak {
                    formatter.insertToken(.whitespace(" "), atIndex: i + 1)
                }
            }
            if let previousToken = formatter.tokenAtIndex(i - 1) {
                if !previousToken.isWhitespaceOrLinebreak {
                    formatter.insertToken(.whitespace(" "), atIndex: i)
                }
            }
        case .symbol("..."), .symbol("..<"):
            break
        case .symbol:
            if let previousToken = formatter.tokenAtIndex(i - 1), isLvalue(previousToken) {
                if let nextToken = formatter.tokenAtIndex(i + 1), isRvalue(nextToken) {
                    // Insert space before and after the infix token
                    formatter.insertToken(.whitespace(" "), atIndex: i + 1)
                    formatter.insertToken(.whitespace(" "), atIndex: i)
                }
            }
        case .startOfScope:
            scopeStack.append(token)
        case .endOfScope:
            scopeStack.removeLast()
        default: break
        }
    }
}

/// Add space around comments, except at the start or end of a line
public func spaceAroundComments(_ formatter: Formatter) {
    formatter.forEachToken { i, token in
        if token == .startOfScope("/*") || token == .startOfScope("//"), let prevToken = formatter.tokenAtIndex(i - 1),
            !prevToken.isWhitespaceOrLinebreak {
            formatter.insertToken(.whitespace(" "), atIndex: i)
        } else if token == .endOfScope("*/"), let nextToken = formatter.tokenAtIndex(i + 1),
            !nextToken.isWhitespaceOrLinebreak {
            formatter.insertToken(.whitespace(" "), atIndex: i + 1)
        }
    }
}

/// Add space inside comments, taking care not to mangle headerdoc or
/// carefully preformatted comments, such as star boxes, etc.
public func spaceInsideComments(_ formatter: Formatter) {
    guard formatter.options.indentComments else { return }
    formatter.forEachToken(.startOfScope("/*")) { i, token in
        guard let nextToken = formatter.tokenAtIndex(i + 1), case .commentBody(let string) = nextToken else { return }
        if case let characters = string.characters, let first = characters.first, "*!:".characters.contains(first) {
            if characters.count > 1, case let next = characters[characters.index(after: characters.startIndex)],
                !" /t".characters.contains(next), !string.hasPrefix("**"), !string.hasPrefix("*/") {
                let string = String(string.characters.first!) + " " +
                    string.substring(from: string.characters.index(string.startIndex, offsetBy: 1))
                formatter.replaceTokenAtIndex(i + 1, with: .commentBody(string))
            }
        } else {
            formatter.insertToken(.whitespace(" "), atIndex: i + 1)
        }
    }
    formatter.forEachToken(.startOfScope("//")) { i, token in
        guard let nextToken = formatter.tokenAtIndex(i + 1), case .commentBody(let string) = nextToken else { return }
        if case let characters = string.characters, let first = characters.first, "/!:".characters.contains(first) {
            if characters.count > 1, case let next = characters[characters.index(after: characters.startIndex)],
                !" /t".characters.contains(next) {
                let string = String(string.characters.first!) + " " +
                    string.substring(from: string.characters.index(string.startIndex, offsetBy: 1))
                formatter.replaceTokenAtIndex(i + 1, with: .commentBody(string))
            }
        } else if !string.hasPrefix("===") { // Special-case check for swift stdlib codebase
            formatter.insertToken(.whitespace(" "), atIndex: i + 1)
        }
    }
    formatter.forEachToken(.endOfScope("*/")) { i, token in
        guard let previousToken = formatter.tokenAtIndex(i - 1) else { return }
        if !previousToken.isWhitespaceOrLinebreak && !previousToken.string.hasSuffix("*") {
            formatter.insertToken(.whitespace(" "), atIndex: i)
        }
    }
}

/// Adds or removes the space around range operators
public func ranges(_ formatter: Formatter) {
    formatter.forEachToken { i, token in
        if token == .symbol("...") || token == .symbol("..<") {
            if !formatter.options.spaceAroundRangeOperators {
                if formatter.tokenAtIndex(i + 1)?.isWhitespace == true {
                    formatter.removeTokenAtIndex(i + 1)
                }
                if formatter.tokenAtIndex(i - 1)?.isWhitespace == true {
                    formatter.removeTokenAtIndex(i - 1)
                }
            } else if let nextToken = formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i) {
                if nextToken != .endOfScope(")") && nextToken != .symbol(",") {
                    if formatter.tokenAtIndex(i + 1)?.isWhitespaceOrLinebreak == false {
                        formatter.insertToken(.whitespace(" "), atIndex: i + 1)
                    }
                    if formatter.tokenAtIndex(i - 1)?.isWhitespaceOrLinebreak == false {
                        formatter.insertToken(.whitespace(" "), atIndex: i)
                    }
                }
            }
        }
    }
}

/// Collapse all consecutive whitespace characters to a single space, except at
/// the start of a line or inside a comment or string, as these have no semantic
/// meaning and lead to noise in commits.
public func consecutiveSpaces(_ formatter: Formatter) {
    formatter.forEachToken({ $0.isWhitespace }) { i, token in
        if let previousToken = formatter.tokenAtIndex(i - 1), !previousToken.isLinebreak {
            switch token {
            case .whitespace(""):
                formatter.removeTokenAtIndex(i)
            case .whitespace(" "):
                break
            case .whitespace:
                let scope = formatter.scopeAtIndex(i)
                if scope != .startOfScope("/*") && scope != .startOfScope("//") {
                    formatter.replaceTokenAtIndex(i, with: .whitespace(" "))
                }
            default:
                break
            }
        }
    }
}

/// Remove trailing whitespace from the end of lines, as it has no semantic
/// meaning and leads to noise in commits.
public func trailingWhitespace(_ formatter: Formatter) {
    formatter.forEachToken({ $0.isLinebreak }) { i, token in
        if formatter.tokenAtIndex(i - 1)?.isWhitespace == true {
            formatter.removeTokenAtIndex(i - 1)
        }
    }
    if formatter.tokens.last?.isWhitespace == true {
        formatter.removeLastToken()
    }
}

/// Collapse all consecutive blank lines into a single blank line
public func consecutiveBlankLines(_ formatter: Formatter) {
    var linebreakCount = 0
    var lastToken = Token.whitespace("")
    formatter.forEachToken { i, token in
        if token.isLinebreak {
            linebreakCount += 1
            if linebreakCount > 2 {
                formatter.removeTokenAtIndex(i)
                if lastToken.isWhitespace {
                    formatter.removeTokenAtIndex(i - 1)
                }
                linebreakCount -= 1
            }
        } else if !token.isWhitespace {
            linebreakCount = 0
        }
        lastToken = token
    }
    if linebreakCount > 1 && !formatter.options.fragment {
        if lastToken.isWhitespace {
            formatter.removeLastToken()
        }
        formatter.removeLastToken()
    }
}

/// Remove blank lines immediately before a closing brace, bracket, paren or chevron,
/// unless it's followed by more code on the same line (e.g. } else { )
public func blankLinesAtEndOfScope(_ formatter: Formatter) {
    guard formatter.options.removeBlankLines else { return }
    formatter.forEachToken { i, token in
        guard [.endOfScope("}"), .endOfScope(")"), .endOfScope("]"), .endOfScope(">")].contains(token)
        else { return }
        if let nextToken = formatter.nextNonWhitespaceOrCommentToken(fromIndex: i) {
            // If there is extra code after the closing scope on the same line, ignore it
            guard nextToken.isLinebreak else { return }
        }
        // Find previous non-whitespace token
        var index = i - 1
        var indexOfFirstLineBreak: Int?
        var indexOfLastLineBreak: Int?
        loop: while let token = formatter.tokenAtIndex(index) {
            switch token {
            case .linebreak:
                indexOfFirstLineBreak = index
                if indexOfLastLineBreak == nil {
                    indexOfLastLineBreak = index
                }
            case .whitespace:
                break
            default:
                break loop
            }
            index -= 1
        }
        if let indexOfFirstLineBreak = indexOfFirstLineBreak, let indexOfLastLineBreak = indexOfLastLineBreak {
            formatter.removeTokensInRange(indexOfFirstLineBreak ..< indexOfLastLineBreak)
            return
        }
    }
}

/// Adds a blank line immediately after a closing brace, unless followed by another closing brace
public func blankLinesBetweenScopes(_ formatter: Formatter) {
    guard formatter.options.insertBlankLines else { return }
    var spaceableScopeStack = [true]
    var isSpaceableScopeType = false
    formatter.forEachToken { i, token in
        switch token {
        case .keyword("class"),
             .keyword("struct"),
             .keyword("extension"),
             .keyword("enum"):
            isSpaceableScopeType = true
        case .keyword("func"), .keyword("var"):
            isSpaceableScopeType = false
        case .startOfScope("{"):
            spaceableScopeStack.append(isSpaceableScopeType)
            isSpaceableScopeType = false
        case .endOfScope("}"):
            if spaceableScopeStack.count > 1 && spaceableScopeStack[spaceableScopeStack.count - 2] {
                guard let openingBraceIndex = formatter.indexOfPreviousToken(fromIndex: i, matching: { $0 == .startOfScope("{") }),
                    let previousLinebreakIndex = formatter.indexOfPreviousToken(fromIndex: i, matching: { $0.isLinebreak }),
                    previousLinebreakIndex > openingBraceIndex else {
                    // Inline braces
                    break
                }
                var i = i
                if let nextTokenIndex = formatter.indexOfNextToken(fromIndex: i, matching: { !$0.isWhitespace }),
                    formatter.tokenAtIndex(nextTokenIndex) == .startOfScope("("),
                    let closingParenIndex = formatter.indexOfNextToken(fromIndex: nextTokenIndex, matching: {
                        $0 == .endOfScope(")") }) {
                    i = closingParenIndex
                }
                if let nextTokenIndex = formatter.indexOfNextToken(fromIndex: i, matching: {
                    !$0.isWhitespaceOrLinebreak }), let nextToken = formatter.tokenAtIndex(nextTokenIndex) {
                    switch nextToken {
                    case .error, .endOfScope,
                         .symbol("."), .symbol(","), .symbol(":"),
                         .keyword("else"), .keyword("catch"):
                        break
                    case .keyword("while"):
                        if let previousBraceIndex = formatter.indexOfPreviousToken(fromIndex: i, matching: {
                            $0 == .startOfScope("{") }),
                            formatter.previousNonWhitespaceOrCommentOrLinebreakToken(fromIndex: previousBraceIndex)
                            != .keyword("repeat") {
                            fallthrough
                        }
                        break
                    default:
                        if let firstLinebreakIndex = formatter.indexOfNextToken(fromIndex: i, matching: { $0.isLinebreak }),
                            firstLinebreakIndex < nextTokenIndex {
                            if let secondLinebreakIndex = formatter.indexOfNextToken(
                                fromIndex: firstLinebreakIndex, matching: { $0.isLinebreak }),
                                secondLinebreakIndex < nextTokenIndex {
                                // Already has a blank line after
                            } else {
                                // Insert linebreak
                                formatter.insertToken(.linebreak(formatter.options.linebreak), atIndex: firstLinebreakIndex)
                            }
                        }
                    }
                }
            }
            spaceableScopeStack.removeLast()
        default:
            break
        }
    }
}

/// Always end file with a linebreak, to avoid incompatibility with certain unix tools:
/// http://stackoverflow.com/questions/2287967/why-is-it-recommended-to-have-empty-line-in-the-end-of-file
public func linebreakAtEndOfFile(_ formatter: Formatter) {
    guard !formatter.options.fragment else { return }
    if let lastToken = formatter.previousToken(fromIndex: formatter.tokens.count, matching: {
        !$0.isWhitespace && !$0.isError }), !lastToken.isLinebreak {
        formatter.insertToken(.linebreak(formatter.options.linebreak), atIndex: formatter.tokens.count)
    }
}

/// Indent code according to standard scope indenting rules.
/// The type (tab or space) and level (2 spaces, 4 spaces, etc.) of the
/// indenting can be configured with the `options` parameter of the formatter.
public func indent(_ formatter: Formatter) {
    var scopeIndexStack: [Int] = []
    var scopeStartLineIndexes: [Int] = []
    var lastNonWhitespaceOrLinebreakIndex = -1
    var lastNonWhitespaceIndex = -1
    var indentStack = [""]
    var indentCounts = [1]
    var linewrapStack = [false]
    var lineIndex = 0

    @discardableResult func insertWhitespace(_ whitespace: String, atIndex index: Int) -> Int {
        if formatter.tokenAtIndex(index)?.isWhitespace == true {
            formatter.replaceTokenAtIndex(index, with: .whitespace(whitespace))
            return 0 // Inserted 0 tokens
        }
        formatter.insertToken(.whitespace(whitespace), atIndex: index)
        return 1 // Inserted 1 token
    }

    func currentScope() -> Token? {
        if let scopeIndex = scopeIndexStack.last {
            return formatter.tokens[scopeIndex]
        }
        return nil
    }

    func tokenIsEndOfStatement(_ i: Int) -> Bool {
        if let token = formatter.tokenAtIndex(i) {
            switch token {
            case .endOfScope("case"),
                 .endOfScope("default"):
                return false
            case .keyword(let string):
                // TODO: handle in
                // TODO: handle context-specific keywords
                // associativity, convenience, dynamic, didSet, final, get, infix, indirect,
                // lazy, left, mutating, none, nonmutating, open, optional, override, postfix,
                // precedence, prefix, Protocol, required, right, set, Type, unowned, weak, willSet
                switch string {
                case "let", "func", "var", "if", "as", "import", "try", "guard", "case",
                     "for", "init", "switch", "throw", "where", "subscript", "is",
                     "while", "associatedtype", "inout":
                    return false
                case "return":
                    guard let nextToken =
                        formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i)
                    else { return true }
                    switch nextToken {
                    case .keyword, .endOfScope("case"), .endOfScope("default"):
                        return true
                    default:
                        return false
                    }
                default:
                    return true
                }
            case .symbol("."), .symbol(":"):
                return false
            case .symbol(","):
                // For arrays or argument lists, we already indent
                return ["<", "[", "(", "case"].contains(currentScope()?.string ?? "")
            case .symbol:
                if formatter.previousToken(fromIndex: i, matching: { $0 == .keyword("operator") }) != nil {
                    return true
                }
                if let previousToken = formatter.tokenAtIndex(i - 1) {
                    switch previousToken {
                    case .keyword("as"), .keyword("try"):
                        return false
                    default:
                        if previousToken.isWhitespaceOrCommentOrLinebreak {
                            return formatter.previousNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i) == .symbol("=")
                        }
                    }
                }
            default:
                return true
            }
        }
        return true
    }

    func tokenIsStartOfStatement(_ i: Int) -> Bool {
        if let token = formatter.tokenAtIndex(i) {
            switch token {
            case .keyword(let string) where [ // TODO: handle "in"
                "as", "is", "where", "dynamicType", "rethrows", "throws"].contains(string):
                return false
            case .symbol("."):
                // Is this an enum value?
                if let previousToken = formatter.previousNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i) {
                    if let scope = currentScope()?.string, ["<", "(", "[", "case"].contains(scope),
                        [scope, ",", ":"].contains(previousToken.string) {
                        return true
                    }
                    return false
                }
                return true
            case .symbol(","):
                if let scope = currentScope()?.string, ["<", "[", "(", "case"].contains(scope) {
                    // For arrays, dictionaries, cases, or argument lists, we already indent
                    return true
                }
                return false
            case .symbol where formatter.tokenAtIndex(i + 1)?.isWhitespaceOrCommentOrLinebreak == true:
                // Is an infix operator
                return false
            default:
                return true
            }
        }
        return true
    }

    func tokenIsStartOfClosure(_ i: Int) -> Bool {
        var i = i - 1
        while let token = formatter.tokenAtIndex(i) {
            switch token {
            case .keyword(let string):
                switch string {
                case "class", "struct", "enum", "protocol", "extension",
                     "let", "var", "func", "init", "subscript",
                     "if", "switch", "guard", "else",
                     "for", "while", "repeat",
                     "do", "catch":
                    return false
                default:
                    break
                }
            case .startOfScope:
                return true
            default:
                break
            }
            i = formatter.indexOfPreviousToken(fromIndex: i) {
                return !$0.isWhitespaceOrCommentOrLinebreak && (!$0.isEndOfScope || $0 == .endOfScope("}"))
            } ?? -1
        }
        return true
    }

    if formatter.options.fragment,
        let firstIndex = formatter.indexOfNextToken(fromIndex: -1, matching: { !$0.isWhitespaceOrLinebreak }),
        let indentToken = formatter.tokenAtIndex(firstIndex - 1), case .whitespace(let string) = indentToken {
        indentStack[0] = string
    } else {
        insertWhitespace("", atIndex: 0)
    }
    formatter.forEachToken { i, token in
        var i = i
        switch token {
        case .startOfScope(let string):
            switch string {
            case ":":
                if currentScope() == .endOfScope("case") {
                    if linewrapStack.last == true {
                        indentStack.removeLast()
                    }
                    indentStack.removeLast()
                    indentCounts.removeLast()
                    linewrapStack.removeLast()
                    scopeStartLineIndexes.removeLast()
                    scopeIndexStack.removeLast()
                }
            case "{":
                if !tokenIsStartOfClosure(i) {
                    if linewrapStack.last == true {
                        indentStack.removeLast()
                        linewrapStack[linewrapStack.count - 1] = false
                    }
                }
            default:
                break
            }
            // Handle start of scope
            scopeIndexStack.append(i)
            let indentCount: Int
            if lineIndex > scopeStartLineIndexes.last ?? -1 {
                indentCount = 1
            } else {
                indentCount = indentCounts.last! + 1
            }
            indentCounts.append(indentCount)
            var indent = indentStack[indentStack.count - indentCount]
            switch string {
            case "/*":
                // Comments only indent one space
                indent += " "
            case "[", "(":
                if formatter.nextNonWhitespaceOrCommentToken(fromIndex: i)?.isLinebreak == false {
                    let nextIndex: Int! = formatter.indexOfNextToken(fromIndex: i) { !$0.isWhitespace }
                    let start = formatter.startOfLine(atIndex: i)
                    // align indent with previous value
                    indent = ""
                    for token in formatter.tokens[start ..< nextIndex] {
                        if case .whitespace(let string) = token {
                            indent += string
                        } else {
                            indent += String(repeating: " ", count: token.string.characters.count)
                        }
                    }
                    break
                }
                fallthrough
            default:
                indent += formatter.options.indent
            }
            indentStack.append(indent)
            scopeStartLineIndexes.append(lineIndex)
            linewrapStack.append(false)
        case .whitespace:
            break
        default:
            if let scope = currentScope() {
                // Handle end of scope
                if token.closesScopeForToken(scope) {
                    if linewrapStack.last == true {
                        indentStack.removeLast()
                    }
                    linewrapStack.removeLast()
                    scopeStartLineIndexes.removeLast()
                    scopeIndexStack.removeLast()
                    indentStack.removeLast()
                    let indentCount = indentCounts.last! - 1
                    indentCounts.removeLast()
                    if lineIndex > scopeStartLineIndexes.last ?? -1 {
                        // If indentCount > 0, drop back to previous indent level
                        if indentCount > 0 {
                            indentStack.removeLast()
                            indentStack.append(indentStack.last ?? "")
                        }
                        // Check if line on which scope ends should be unindented
                        let start = formatter.startOfLine(atIndex: i)
                        if let nextToken = formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: start - 1),
                            nextToken.isEndOfScope && nextToken != .endOfScope("*/") {
                            // Only reduce indent if line begins with a closing scope token
                            let indent = indentStack.last ?? ""
                            i += insertWhitespace(indent, atIndex: start)
                        }
                    }
                    if token == .endOfScope("case") {
                        scopeIndexStack.append(i)
                        var indent = (indentStack.last ?? "")
                        if formatter.nextNonWhitespaceOrCommentToken(fromIndex: i)?.isLinebreak == true {
                            indent += formatter.options.indent
                        } else {
                            // align indent with previous case value
                            indent += "     "
                        }
                        indentStack.append(indent)
                        indentCounts.append(1)
                        scopeStartLineIndexes.append(lineIndex)
                        linewrapStack.append(false)
                    }
                } else if token == .keyword("#else") || token == .keyword("#elseif") {
                    let indent = indentStack[indentStack.count - 2]
                    i += insertWhitespace(indent, atIndex: formatter.startOfLine(atIndex: i))
                }
            } else if [.error("}"), .error("]"), .error(")"), .error(">")].contains(token) {
                // Handled over-terminated fragment
                if let prevToken = formatter.tokenAtIndex(i - 1) {
                    if case .whitespace(let string) = prevToken {
                        let prevButOneToken = formatter.tokenAtIndex(i - 2)
                        if prevButOneToken == nil || prevButOneToken!.isLinebreak {
                            indentStack[0] = string
                        }
                    } else if prevToken.isLinebreak {
                        indentStack[0] = ""
                    }
                }
                return
            }
            // Indent each new line
            if token.isLinebreak {
                // Detect linewrap
                let nextTokenIndex = formatter.indexOfNextToken(fromIndex: i) { !$0.isWhitespaceOrCommentOrLinebreak }
                let linewrapped = !tokenIsEndOfStatement(lastNonWhitespaceOrLinebreakIndex) ||
                    !(nextTokenIndex == nil || tokenIsStartOfStatement(nextTokenIndex!))
                // Determine current indent
                var indent = indentStack.last ?? ""
                if linewrapped && lineIndex == scopeStartLineIndexes.last {
                    indent = indentStack.count > 1 ? indentStack[indentStack.count - 2] : ""
                }
                lineIndex += 1
                // Begin wrap scope
                if linewrapStack.last == true {
                    if !linewrapped {
                        indentStack.removeLast()
                        linewrapStack[linewrapStack.count - 1] = false
                        indent = indentStack.last!
                    }
                } else if linewrapped {
                    linewrapStack[linewrapStack.count - 1] = true
                    // Don't indent line starting with dot if previous line was just a closing scope
                    let lastToken = formatter.tokenAtIndex(lastNonWhitespaceOrLinebreakIndex)
                    if formatter.tokenAtIndex(nextTokenIndex ?? -1) != .symbol(".") ||
                        !(lastToken?.isEndOfScope == true && lastToken != .endOfScope("case") &&
                            formatter.previousNonWhitespaceToken(fromIndex:
                                lastNonWhitespaceOrLinebreakIndex)?.isLinebreak == true) {
                        indent += formatter.options.indent
                    }
                    indentStack.append(indent)
                }
                // Apply indent
                if formatter.tokenAtIndex(i + 1)?.isWhitespace == false {
                    insertWhitespace("", atIndex: i + 1)
                }
                if let nextToken = formatter.tokenAtIndex(i + 2) {
                    switch nextToken {
                    case .linebreak:
                        insertWhitespace(formatter.options.truncateBlankLines ? "" : indent, atIndex: i + 1)
                    case .commentBody:
                        if formatter.options.indentComments {
                            insertWhitespace(indent, atIndex: i + 1)
                        }
                    case .startOfScope(let string):
                        if formatter.options.indentComments || string != "/*" {
                            insertWhitespace(indent, atIndex: i + 1)
                        }
                    case .endOfScope(let string):
                        if formatter.options.indentComments || string != "*/" {
                            insertWhitespace(indent, atIndex: i + 1)
                        }
                    case .error:
                        break
                    default:
                        insertWhitespace(indent, atIndex: i + 1)
                    }
                }
            }
        }
        // Track token for line wraps
        if !token.isWhitespaceOrComment {
            lastNonWhitespaceIndex = i
            if !token.isLinebreak {
                lastNonWhitespaceOrLinebreakIndex = i
            }
        }
    }

    // Remove zero-width spaces
    formatter.forEachToken(.whitespace("")) { i, token in
        formatter.removeTokenAtIndex(i)
    }
}

// Implement brace-wrapping rules
public func braces(_ formatter: Formatter) {
    formatter.forEachToken(.startOfScope("{")) { i, token in
        // Check this isn't an inline block
        guard let nextLinebreakIndex = formatter.indexOfNextToken(fromIndex: i, matching: { $0.isLinebreak }),
            let closingBraceIndex = formatter.indexOfNextToken(fromIndex: i, matching: { $0 == .endOfScope("}") }),
            nextLinebreakIndex < closingBraceIndex else { return }
        if formatter.options.allmanBraces {
            // Implement Allman-style braces, where opening brace appears on the next line
            if let previousTokenIndex = formatter.indexOfPreviousToken(fromIndex: i, matching: { !$0.isWhitespace }),
                let previousToken = formatter.tokenAtIndex(previousTokenIndex) {
                switch previousToken {
                case .identifier, .keyword, .endOfScope:
                    formatter.insertToken(.linebreak(formatter.options.linebreak), atIndex: i)
                    if let indentToken = formatter.indentTokenForLineAtIndex(i) {
                        formatter.insertToken(indentToken, atIndex: i + 1)
                    }
                    if formatter.tokens[i - 1].isWhitespace {
                        formatter.removeTokenAtIndex(i - 1)
                    }
                default:
                    break
                }
            }
        } else {
            // Implement K&R-style braces, where opening brace appears on the same line
            var index = i - 1
            var linebreakIndex: Int?
            while let token = formatter.tokenAtIndex(index) {
                switch token {
                case .linebreak:
                    linebreakIndex = index
                case .whitespace, .commentBody,
                     .startOfScope("/*"), .startOfScope("//"),
                     .endOfScope("*/"):
                    break
                default:
                    if let linebreakIndex = linebreakIndex {
                        formatter.removeTokensInRange(Range(linebreakIndex ... i))
                        if formatter.tokenAtIndex(linebreakIndex - 1)?.isWhitespace == true {
                            formatter.removeTokenAtIndex(linebreakIndex - 1)
                        }
                        formatter.insertToken(.whitespace(" "), atIndex: index + 1)
                        formatter.insertToken(.startOfScope("{"), atIndex: index + 2)
                    }
                    return
                }
                index -= 1
            }
        }
    }
}

/// Ensure that an `else` statement following `if { ... }` appears on the same line
/// as the closing brace. This has no effect on the `else` part of a `guard` statement.
/// Also applies to `catch` after `try` and `while` after `repeat`.
public func elseOnSameLine(_ formatter: Formatter) {
    var closingBraceIndex: Int?
    formatter.forEachToken { i, token in
        switch token {
        case .endOfScope("}"):
            closingBraceIndex = i
        case .keyword("while"):
            if let closingBraceIndex = closingBraceIndex,
                let previousBraceIndex = formatter.indexOfPreviousToken(fromIndex: closingBraceIndex, matching: {
                    $0 == .startOfScope("{") }), formatter.previousNonWhitespaceOrCommentOrLinebreakToken(
                    fromIndex: previousBraceIndex) == .keyword("repeat") {
                fallthrough
            }
            break
        case .keyword("else"), .keyword("catch"):
            if let closingBraceIndex = closingBraceIndex {
                // Only applies to dangling braces
                if formatter.previousNonWhitespaceToken(fromIndex: closingBraceIndex)?.isLinebreak == true {
                    if let prevLinebreakIndex = formatter.indexOfPreviousToken(fromIndex: i, matching: {
                        $0.isLinebreak }), closingBraceIndex < prevLinebreakIndex {
                        if !formatter.options.allmanBraces {
                            formatter.replaceTokensInRange(closingBraceIndex + 1 ..< i, with: [.whitespace(" ")])
                        }
                    } else if formatter.options.allmanBraces {
                        formatter.replaceTokensInRange(closingBraceIndex + 1 ..< i, with:
                            [.linebreak(formatter.options.linebreak)])
                        if let indentToken = formatter.indentTokenForLineAtIndex(i) {
                            formatter.insertToken(indentToken, atIndex: closingBraceIndex + 2)
                        }
                    }
                }
            }
        default:
            if !token.isWhitespaceOrCommentOrLinebreak {
                closingBraceIndex = nil
            }
            break
        }
    }
}

/// Ensure that the last item in a multi-line array literal is followed by a comma.
/// This is useful for preventing noise in commits when items are added to end of array.
public func trailingCommas(_ formatter: Formatter) {
    // TODO: we don't currently check if [] is a subscript rather than a literal.
    // This should't matter in practice, as nobody splits subscripts onto multiple
    // lines, but ideally we'd check for this just in case
    formatter.forEachToken(.endOfScope("]")) { i, token in
        if let linebreakIndex = formatter.indexOfPreviousToken(fromIndex: i, matching: {
            return !$0.isWhitespaceOrComment }), formatter.tokens[linebreakIndex].isLinebreak {
            if let previousTokenIndex = formatter.indexOfPreviousToken(fromIndex: linebreakIndex + 1, matching: {
                return !$0.isWhitespaceOrCommentOrLinebreak
            }), let token = formatter.tokenAtIndex(previousTokenIndex) {
                switch token {
                case .startOfScope("["), .symbol(":"):
                    break // do nothing
                case .symbol(","):
                    if !formatter.options.trailingCommas {
                        formatter.removeTokenAtIndex(previousTokenIndex)
                    }
                default:
                    if formatter.options.trailingCommas {
                        formatter.insertToken(.symbol(","), atIndex: previousTokenIndex + 1)
                    }
                }
            }
        }
    }
}

/// Ensure that TODO, MARK and FIXME comments are followed by a : as required
public func todos(_ formatter: Formatter) {
    formatter.forEachToken { i, token in
        if case .commentBody(let string) = token {
            for tag in ["TODO", "MARK", "FIXME"] {
                if string.hasPrefix(tag) {
                    var suffix = string.substring(from: tag.endIndex)
                    if let first = suffix.characters.first {
                        // If not followed by a space or :, don't mess with it as it may be a custom format
                        if " :".characters.contains(first) {
                            while let first = suffix.characters.first, " :".characters.contains(first) {
                                suffix = suffix.substring(from: suffix.index(after: suffix.startIndex))
                            }
                            formatter.replaceTokenAtIndex(i, with: .commentBody(tag + ": " + suffix))
                        }
                    } else {
                        formatter.replaceTokenAtIndex(i, with: .commentBody(tag + ":"))
                    }
                    break
                }
            }
        }
    }
}

/// Remove semicolons, except where doing so would change the meaning of the code
public func semicolons(_ formatter: Formatter) {
    formatter.forEachToken(.symbol(";")) { i, token in
        if let nextToken = formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i) {
            let lastToken = formatter.previousNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i)
            if lastToken == nil || nextToken == .endOfScope("}") {
                // Safe to remove
                formatter.removeTokenAtIndex(i)
            } else if lastToken == .keyword("return") || formatter.scopeAtIndex(i) == .startOfScope("(") {
                // Not safe to remove or replace
            } else if formatter.nextNonWhitespaceOrCommentToken(fromIndex: i)?.isLinebreak == true {
                // Safe to remove
                formatter.removeTokenAtIndex(i)
            } else if !formatter.options.allowInlineSemicolons {
                // Replace with a linebreak
                if formatter.tokenAtIndex(i + 1)?.isWhitespace == true {
                    formatter.removeTokenAtIndex(i + 1)
                }
                if let indentToken = formatter.indentTokenForLineAtIndex(i) {
                    formatter.insertToken(indentToken, atIndex: i + 1)
                }
                formatter.replaceTokenAtIndex(i, with: .linebreak(formatter.options.linebreak))
            }
        } else {
            // Safe to remove
            formatter.removeTokenAtIndex(i)
        }
    }
}

/// Standardise linebreak characters as whatever is specified in the options (\n by default)
public func linebreaks(_ formatter: Formatter) {
    formatter.forEachToken({ $0.isLinebreak }) { i, token in
        formatter.replaceTokenAtIndex(i, with: .linebreak(formatter.options.linebreak))
    }
}

/// Standardise the order of property specifiers
public func specifiers(_ formatter: Formatter) {
    let order = [
        "private(set)", "fileprivate(set)", "internal(set)", "public(set)",
        "private", "fileprivate", "internal", "public", "open",
        "final", "dynamic", // Can't be both
        "optional", "required",
        "convenience",
        "override",
        "lazy",
        "weak", "unowned",
        "static", "class",
        "mutating", "nonmutating",
        "prefix", "postfix",
    ]
    let validSpecifiers = Set(order)
    formatter.forEachToken { i, token in
        guard case .keyword(let string) = token else {
            return
        }
        switch string {
        case "let", "func", "var", "class", "extension", "init", "enum",
             "struct", "typealias", "subscript", "associatedtype", "protocol":
            break
        default:
            return
        }
        var specifiers = [String: [Token]]()
        var index = i - 1
        var specifierIndex = i
        loop: while let token = formatter.tokenAtIndex(index) {
            switch token {
            case .keyword(let string), .identifier(let string):
                if !validSpecifiers.contains(string) {
                    break loop
                }
                specifiers[string] = [Token](formatter.tokens[index ..< specifierIndex])
                specifierIndex = index
            case .endOfScope(")"):
                if formatter.previousNonWhitespaceOrCommentOrLinebreakToken(fromIndex: index) == .identifier("set") {
                    // Skip tokens for entire private(set) expression
                    while let token = formatter.tokenAtIndex(index) {
                        if case .keyword(let string) = token,
                            ["private", "fileprivate", "public", "internal"].contains(string) {
                            specifiers[string + "(set)"] = [Token](formatter.tokens[index ..< specifierIndex])
                            specifierIndex = index
                            break
                        }
                        index -= 1
                    }
                }
            case .linebreak,
                 .whitespace,
                 .commentBody,
                 .startOfScope("//"),
                 .startOfScope("/*"),
                 .endOfScope("*/"):
                break
            default:
                // Not a specifier
                break loop
            }
            index -= 1
        }
        guard specifiers.count > 0 else { return }
        var sortedSpecifiers = [Token]()
        for specifier in order {
            if let tokens = specifiers[specifier] {
                sortedSpecifiers += tokens
            }
        }
        formatter.replaceTokensInRange(specifierIndex ..< i, with: sortedSpecifiers)
    }
}

/// Remove redundant parens around the arguments for loops, if statements, etc
public func redundantParens(_ formatter: Formatter) {
    formatter.forEachToken(.startOfScope("(")) { i, token in
        if let prevToken = formatter.previousNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i) {
            switch prevToken {
            case .keyword("if"), .keyword("while"), .keyword("switch"):
                if let closingIndex = formatter.indexOfNextToken(fromIndex: i, matching: { $0 == .endOfScope(")") }),
                    formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: closingIndex) == .startOfScope("{") {
                    if prevToken == .keyword("switch"),
                        let commaIndex = formatter.indexOfNextToken(fromIndex: i, matching: { $0 == .symbol(",") }),
                        commaIndex < closingIndex {
                        // Might be a tuple, so we won't remove the parens
                        // TODO: improve the logic here so we don't misidentify function calls as tuples
                        break
                    }
                    formatter.removeTokenAtIndex(closingIndex)
                    formatter.removeTokenAtIndex(i)
                }
            default:
                break
            }
        }
    }
}

/// Normalize the use of void in closure arguments and return values
public func void(_ formatter: Formatter) {
    formatter.forEachToken(.identifier("Void")) { i, token in
        if let prevIndex = formatter.indexOfPreviousToken(fromIndex: i, matching: { !$0.isWhitespaceOrLinebreak }),
            formatter.tokenAtIndex(prevIndex) == .startOfScope("("),
            let nextIndex = formatter.indexOfNextToken(fromIndex: i, matching: { !$0.isWhitespaceOrLinebreak }),
            formatter.tokenAtIndex(nextIndex) == .endOfScope(")") {
            if let nextToken = formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: nextIndex),
                [.symbol("->"), .keyword("throws"), .keyword("rethrows")].contains(nextToken) {
                // Remove Void
                formatter.removeTokensInRange(prevIndex + 1 ..< nextIndex)
            } else if formatter.options.useVoid {
                // Strip parens
                formatter.removeTokensInRange(i + 1 ..< nextIndex + 1)
                formatter.removeTokensInRange(prevIndex ..< i)
            } else {
                // Remove Void
                formatter.removeTokensInRange(prevIndex + 1 ..< nextIndex)
            }
        } else if !formatter.options.useVoid ||
            formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i) == .symbol("->") {
            if let prevToken = formatter.previousNonWhitespaceOrCommentOrLinebreakToken(fromIndex: i),
                prevToken == .symbol(".") || prevToken == .keyword("typealias") {
                return
            }
            // Convert to parens
            formatter.replaceTokenAtIndex(i, with: .endOfScope(")"))
            formatter.insertToken(.startOfScope("("), atIndex: i)
        }
    }
    if formatter.options.useVoid {
        formatter.forEachToken(.startOfScope("(")) { i, token in
            if let prevIndex = formatter.indexOfPreviousToken(fromIndex: i, matching: { !$0.isWhitespaceOrCommentOrLinebreak }),
                let prevToken = formatter.tokenAtIndex(prevIndex), prevToken == .symbol("->"),
                let nextIndex = formatter.indexOfNextToken(fromIndex: i, matching: { !$0.isWhitespaceOrLinebreak }),
                let nextToken = formatter.tokenAtIndex(nextIndex), nextToken == .endOfScope(")"),
                formatter.nextNonWhitespaceOrCommentOrLinebreakToken(fromIndex: nextIndex) != .symbol("->") {
                // Replace with Void
                formatter.replaceTokensInRange(i ..< nextIndex + 1, with: [.identifier("Void")])
            }
        }
    }
}

/// Strip header comments from the file
public func stripHeader(_ formatter: Formatter) {
    guard formatter.options.stripHeader && !formatter.options.fragment else { return }
    if let startIndex = formatter.indexOfNextToken(fromIndex: -1, matching: { !$0.isWhitespaceOrLinebreak }) {
        switch formatter.tokens[startIndex] {
        case .startOfScope("//"):
            var lastIndex = startIndex
            while let index = formatter.indexOfNextToken(fromIndex: lastIndex, matching: { $0.isLinebreak }) {
                if let nextToken = formatter.tokenAtIndex(index + 1), nextToken != .startOfScope("//") {
                    switch nextToken {
                    case .linebreak:
                        formatter.removeTokensInRange(0 ..< index + 2)
                    case .whitespace where formatter.tokenAtIndex(index + 2)?.isLinebreak == true:
                        formatter.removeTokensInRange(0 ..< index + 3)
                    default:
                        break
                    }
                    return
                }
                lastIndex = index
            }
        case .startOfScope("/*"):
            // TODO: handle multiline comment headers
            break
        default:
            return
        }
    }
}

public let defaultRules: [FormatRule] = [
    linebreaks,
    semicolons,
    specifiers,
    redundantParens,
    void,
    braces,
    ranges,
    trailingCommas,
    elseOnSameLine,
    spaceAroundParens,
    spaceInsideParens,
    spaceAroundBrackets,
    spaceInsideBrackets,
    spaceAroundBraces,
    spaceInsideBraces,
    spaceAroundGenerics,
    spaceInsideGenerics,
    spaceAroundOperators,
    spaceAroundComments,
    spaceInsideComments,
    consecutiveSpaces,
    todos,
    indent,
    blankLinesAtEndOfScope,
    blankLinesBetweenScopes,
    consecutiveBlankLines,
    trailingWhitespace,
    linebreakAtEndOfFile,
    stripHeader,
]
