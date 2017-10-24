/*

Lemon: LALR(1) parser generator that generates a parser in C

    Author disclaimed copyright

    Public domain code.

Citron: Modifications to Lemon to generate a parser in Swift

    Copyright (C) 2017 Roopesh Chander <roop@roopc.net>

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

protocol CitronParser {

    // Symbol code: Integer code representing terminal and non-terminal
    // symbols. Actual type depends on how many symbols there are. For
    // example, if numberOfSymbolCodes < 256, the type will be UInt8.
    // If there are n terminals in the grammar, the integers 0..n are used to
    // represent terminals and integers >=n are used to represent non-terminals.
    // YYCODETYPE in lemon.
    associatedtype SymbolCode: BinaryInteger

    // Token code: An enum representing the terminals. The raw value shall
    // be equal to the symbol code representing the terminal.
    associatedtype TokenCode: RawRepresentable where TokenCode.RawValue == SymbolCode

    // Action code: Integer code representing the actions. Actual type depends on
    // how many actions there are.
    // YYACTIONTYPE in lemon.
    associatedtype ActionCode: BinaryInteger

    // Token: The type representing a terminal, defined using %token in the grammar.
    // ParseTOKENTYPE in lemon.
    associatedtype Token

    // Symbol: An enum type representing any terminal or non-terminal symbol.
    // YYMINORTYPE in lemon.
    associatedtype Symbol

    // Control constants

    var yyInvalidSymbolCode: SymbolCode { get } // YYNOCODE in lemon
    var yyHasFallback: Bool { get } // YYFALLBACK in lemon
    var yyNumberOfStates: Int { get } // YYNSTATE in lemon
    var yyNumberOfRules: Int { get } // YNRULE in lemon

    // Action tables

    var yyMaxShift: ActionCode { get } // YY_MAX_SHIFT in lemon
    var yyMinShiftReduce: ActionCode { get } // YY_MIN_SHIFTREDUCE in lemon
    var yyMaxShiftReduce: ActionCode { get } // YY_MAX_SHIFTREDUCE in lemon
    var yyMinReduce: ActionCode { get } // YY_MIN_REDUCE in lemon
    var yyMaxReduce: ActionCode { get } // YY_MIN_REDUCE in lemon
    var yyErrorAction: ActionCode { get } // YY_ERROR_ACTION in lemon
    var yyAcceptAction: ActionCode { get } // YY_ACCEPT_ACTION in lemon
    var yyNoAction: ActionCode { get } // YY_NO_ACTION in lemon
    var yyNumberOfActionCodes: ActionCode { get } // YY_ACTTAB_COUNT in lemon
    var yyAction: [ActionCode] { get } // yy_action in lemon
    var yyLookahead: [SymbolCode] { get } // yy_lookahead in lemon

    var yyShiftUseDefault: Int { get } // YY_SHIFT_USE_DFLT in lemon
    var yyShiftOffsetIndexMax: Int { get } // YY_SHIFT_COUNT in lemon
    var yyShiftOffsetMin: Int { get } // YY_SHIFT_MIN in lemon
    var yyShiftOffsetMax: Int { get } // YY_SHIFT_MAX in lemon
    var yyShiftOffset: [Int] { get } // yy_shift_ofst in lemon

    var yyReduceUseDefault: Int { get } // YY_REDUCE_USE_DFLT in lemon
    var yyReduceOffsetIndexMax: Int { get } // YY_REDUCE_COUNT in lemon
    var yyReduceOffsetMin: Int { get } // YY_REDUCE_MIN in lemon
    var yyReduceOffsetMax: Int { get } // YY_REDUCE_MAX in lemon
    var yyReduceOffset: [Int] { get } // yy_reduce_ofst in lemon

    var yyDefault: [ActionCode] { get } // yy_default in lemon

    // Fallback tables

    var yyFallback: [SymbolCode] { get } // yyFallback in lemon

    // Wildcard

    var yyWildcard: SymbolCode? { get }

    // Rules

    var yyRuleInfo: [(lhs: SymbolCode, nrhs: UInt)] { get }

    // Stack

    var yyStack: [(state: Int /*FIXME*/, symbolCode: SymbolCode, symbol: Symbol)] { get set }
    var maxStackSize: Int? { get set }
    var onStackOverflow: (() -> Void)? { get set }

    // Error handling

    var onSyntaxError: ((Token, TokenCode) -> Void)? { get set }

    // Tracing

    var isTracingEnabled: Bool { get set }
    var yyTokenName: [String] { get } // yyTokenName in lemon
    var yyRuleName: [String] { get } // yyRuleName in lemon

    // Functions that shall be defined in the autogenerated code

    func yyTokenToSymbol(_ token: Token) -> Symbol
    func yyArbitrarySymbol() -> Symbol // FIXME
}

// Parsing interface

extension CitronParser {
    mutating func consumeToken(token: Token, code tokenCode: TokenCode) {
        let symbolCode = tokenCode.rawValue
        tracePrint("Input:", safeTokenName(at: Int(symbolCode)))
        let action = yyFindShiftAction(lookAhead: symbolCode)
        if (action <= yyMaxShiftReduce) {
            yyShift(yyNewState: Int(action), symbolCode: symbolCode, token: token)
        } else if (action <= yyMaxReduce) {
            yyReduce(ruleNumber: Int(action - yyMinReduce))
        } else if (action == yyErrorAction) {
            onSyntaxError?(token, tokenCode)
        } else {
            fatalError("Unexpected action")
        }
    }

    mutating func endParsing() {
        yyPopAll()
    }
}

// Private methods

private extension CitronParser {

    mutating func yyPush(state: Int, symbolCode: SymbolCode, symbol: Symbol) {
        yyStack.append((state: state, symbolCode: symbolCode, symbol: symbol))
    }

    mutating func yyPop() {
        let last = yyStack.popLast()
        if let last = last {
            tracePrint("Popping", safeTokenName(at: Int(last.symbolCode)))
        }
    }

    mutating func yyPopAll() {
        while (!yyStack.isEmpty) {
            yyPop()
        }
    }

    mutating func yyStackOverflow() {
        tracePrint("Stack overflow")
        yyPopAll()
        onStackOverflow?()
    }

    func yyFindShiftAction(lookAhead la: SymbolCode) -> ActionCode {
        guard (!yyStack.isEmpty) else { fatalError("Unexpected empty stack") }
        let state = yyStack.last!.state
        if (state >= yyMinReduce) {
            return ActionCode(state)
        }
        assert(state >= yyShiftOffsetIndexMax)
        var i: Int = 0
        var lookAhead = Int(la)
        while (true) {
            guard let shiftOffset = yyShiftOffset[safe: state] else { fatalError("Invalid state") }
            i = shiftOffset
            assert(lookAhead != yyInvalidSymbolCode)
            i += lookAhead
            if (i < 0 || i >= yyNumberOfActionCodes || yyLookahead[i] != lookAhead) {
                // Fallback
                if let fallback = yyFallback[safe: lookAhead], fallback > 0 {
                    tracePrint("Fallback:", safeTokenName(at: lookAhead), "=>", safeTokenName(at: Int(fallback)))
                    precondition((yyFallback[safe: fallback] ?? -1) == 0, "Fallback loop detected")
                    lookAhead = Int(fallback)
                    continue
                }
                // Wildcard
                if let yyWildcard = yyWildcard {
                    let wildcard = Int(yyWildcard)
                    let j = i - lookAhead + wildcard
                    if ((yyShiftOffsetMin + wildcard >= 0 || j >= 0) &&
                        (yyShiftOffsetMax + wildcard < yyNumberOfActionCodes || j < yyNumberOfActionCodes) &&
                        (yyLookahead[j] == wildcard && lookAhead > 0)) {
                        tracePrint("Wildcard:", safeTokenName(at: lookAhead), "=>", safeTokenName(at: wildcard))
                        return yyAction[j]
                    }
                }
                // No fallback and no wildcard. Pick the default action for this state.
                return yyDefault[Int(state)]
            } else {
                // Pick action from action table
                return yyAction[i]
            }
        }
    }

    func yyFindReduceAction(state: Int, lookAhead: SymbolCode) -> ActionCode {
        assert(state <= yyReduceOffsetIndexMax)
        var i = yyReduceOffset[state]

        assert(i != yyReduceUseDefault)
        assert(lookAhead != yyInvalidSymbolCode)
        i += Int(lookAhead)

        assert(i >= 0 && i < yyNumberOfActionCodes)
        assert(yyLookahead[i] == lookAhead)

        return yyAction[i]
    }

    mutating func yyShift(yyNewState: Int, symbolCode: SymbolCode, token: Token) {
        if (maxStackSize != nil && yyStack.count >= maxStackSize!) {
            // Can't grow stack anymore
            yyStackOverflow()
            return
        }
        var newState = yyNewState
        if (newState > yyMaxShift) {
            newState += Int(yyMinReduce) - Int(yyMinShiftReduce)
        }
        yyPush(state: newState, symbolCode: symbolCode, symbol: yyTokenToSymbol(token))
        tracePrint("Shift:", safeTokenName(at: Int(symbolCode)))
        if (newState < yyNumberOfStates) {
            tracePrint("       and go to state", "\(newState)")
        }
    }

    mutating func yyReduce(ruleNumber: Int) {
        assert(ruleNumber < yyRuleInfo.count)
        guard (!yyStack.isEmpty) else { fatalError("Unexpected empty stack") }

        // TODO: Perform reduce actions defined in the grammar

        let ruleInfo = yyRuleInfo[ruleNumber]
        let lhsSymbolCode = ruleInfo.lhs
        let numberOfRhsSymbols = ruleInfo.nrhs
        assert(yyStack.count > numberOfRhsSymbols)
        let nextState = yyStack[yyStack.count - 1 - Int(numberOfRhsSymbols)].state
        let action = yyFindReduceAction(state: nextState, lookAhead: lhsSymbolCode)

        // There are no SHIFTREDUCE actions on nonterminals because the table
        // generator has simplified them to pure REDUCE actions.
        precondition(!(action >= yyMaxShift && action <= yyMaxShiftReduce),
                     "Unexpected shift-reduce action after a reduce")

        // It is not possible for a REDUCE to be followed by an error
        precondition(action != yyErrorAction,
                     "Unexpected error action after a reduce")

        for _ in (0 ..< numberOfRhsSymbols) {
            yyPop()
        }

        if (action == yyAcceptAction) {
            yyAccept()
        } else {
            precondition(isShift(actionCode: action), "Unexpected non-shift action")
            let newState = action
            yyPush(state: Int(newState), symbolCode: lhsSymbolCode,
                 symbol: /*FIXME*/ yyArbitrarySymbol())
            tracePrint("Shift:", safeTokenName(at: Int(lhsSymbolCode)))
            if (newState < yyNumberOfStates) {
                tracePrint("       and go to state", "\(newState)")
            }
        }
    }

    func yyAccept() {
        tracePrint("Parsing complete")
        // TODO: assert something about the stack size
        traceStack()
    }
}

// Private helpers

private extension CitronParser {
    func isShift(actionCode i: ActionCode) -> Bool {
        return i >= 0 && i <= yyMaxShift
    }

    func isShiftReduce(actionCode i: ActionCode) -> Bool {
        return i >= yyMinShiftReduce && i <= yyMaxShiftReduce
    }

    func isReduce(actionCode i: ActionCode) -> Bool {
        return i >= yyMinReduce && i <= yyMaxReduce
    }
}

private extension CitronParser {
    func tracePrint(_ msg: String) {
        if (isTracingEnabled) {
            debugPrint("\(msg)")
        }
    }

    func tracePrint(_ msg: String, _ closure: @autoclosure () -> CustomDebugStringConvertible) {
        if (isTracingEnabled) {
            debugPrint("\(msg) \(closure())")
        }
    }

    func tracePrint(_ msg: String, _ closure: @autoclosure () -> CustomDebugStringConvertible,
                    _ msg2: String, _ closure2: @autoclosure () -> CustomDebugStringConvertible) {
        if (isTracingEnabled) {
            debugPrint("\(msg) \(closure()) \(msg2) \(closure2())")
        }
    }

    func safeTokenName(at i: Int) -> String {
        return yyTokenName[safe: i] ?? "(Unknown token)"
    }

    func traceStack() {
        if (isTracingEnabled) {
            print("STACK contents:")
            for (i, e) in yyStack.enumerated() {
                print("    \(i): (state: \(e.state), symbolCode: \(e.symbolCode))")
            }
        }
    }
}

private extension Array {
    subscript<I: BinaryInteger>(safe i: I) -> Element? {
        get {
            let index = Int(i)
            return index < self.count ? self[index] : nil
        } set(from) {
            let index = Int(i)
            if (index < count && from != nil) {
                self[index] = from!
            }
        }
    }
}
