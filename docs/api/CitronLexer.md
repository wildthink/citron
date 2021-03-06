---
title: "CitronLexer"
permalink: /parsing-interface/api/CitronLexer/
layout: default

---

[Citron] > [Parsing interface] > [`CitronLexer`]

[Citron]: /citron/
[Parsing interface]: /citron/parsing-interface/
[`CitronLexer`]: .

# CitronLexer

_Generic Class_

A simple rule-based lexer. The type of the token data to be returned is
used as the generic parameter.

  - [Types](#types)
     - [`TokenData`](#tokendata)
     - [`LexingRule`](#lexingrule)
     - [`CitronLexerPosition`](#citronlexerposition)
  - [Initializing](#initializing)
     - [`init(rules: LexingRule)`](#initrules-lexingrule)
  - [Tokenizing](#tokenizing)
     - [`tokenize(_ string: String, onFound: Action)`](#tokenize_-string-string-onfound-action)
     - [`tokenize(_ string: String, onFound: Action, onError: ErrorAction?)`](#tokenize_-string-string-onfound-action-onerror-erroraction)
  - [Position](#position)
     - [`currentPosition: CitronLexerPosition`](#currentposition-citronlexerposition)
  - [Errors](#errors)
     - [`noMatchingRuleAt(errorPosition: CitronLexerPosition)`](#nomatchingruleaterrorposition-citronlexerposition)
  - [Usage with `CitronParser`](#usage-with-citronparser)

## Types

### `TokenData`

> The generic parameter for the `CitronLexer`. This is the type of the
> token data to be obtained as a result of tokenization.

### `LexingRule`

> A lexing rule can be either:
>   - string-based, like `.string("func", funcTokenData)`, or
>   - NSRegularExpression-based, like `.regexPattern("[0-9]+", { str in integerTokenData(str) }`
>
> It is defined as:
>
> ~~~ Swift
>     enum LexingRule {
>         case string(String, TokenData?)
>         case regex(NSRegularExpression, (String) -> TokenData?)
>         case regexPattern(String, (String) -> TokenData?)
>     }
> ~~~

### `CitronLexerPosition`

> Specifies a position in the input string that marks a token or an error.
>
> This is a tuple containing three fields:
>
>   - `tokenPosition: String.Index`
>
>     The start of a token or error in the input string.
>
>   - `linePosition: String.Index`
>
>     The start of the line containing the `tokenPosition`.
>
>   - `lineNumber: Int`
>
>     The line number of the line containing the `tokenPosition`.
>
> This type is defined outside the scope of CitronLexer.

## Initializing

### `init(rules: `[`LexingRule`]`)`

> Initialize the lexer with lexing rules.
>
> **Parameters:**
>
>   - `rules`
>
>     The lexing rules to use for tokenizing.

## Tokenizing

### `tokenize(_ string: String, onFound: Action)`

> Tokenize `string`. When a token is found, the `onFound` block is called.
>
> In case there's no lexing rule applicable at some position in the `string`,
> an error is thrown and tokenization is aborted.
>
> **Parameters:**
>
>   - string:
>
>     The input string to tokenize
>
>   - onFound:
>
>     This is an action block of type `(`[`TokenData`]`) throws -> Void`.
>
>     When a match is found as per the lexing rules, the [`TokenData`]
>     obtained from the matching rule is passed on to this action block.
>
> **Return value:**
>
>   - None
>
> **Throws:**
>
>   - If there is no matching rule at a particular position in the input,
>     a [`.noMatchingRuleAt(errorPosition:)`] error is thrown.
>
>   - Any errors thrown in the `onFound` action block
>     will be prapagated up to the caller of this method.

### `tokenize(_ string: String, onFound: Action, onError: ErrorAction?)`

> Tokenize `string`. When a token is found, the `onFound` block is called.
>
> In case there's no rule applicable at some position in the `string`,
> the `onError` block is called and tokenization continues.
>
> **Parameters:**
>
>   - string:
>
>     The input string to tokenize
>
>   - onFound:
>
>     This is an action block of type `(`[`TokenData`]`) throws -> Void`.
>
>     When a match is found as per the lexing rules, the [`TokenData`]
>     obtained from the matching rule is passed on to this action block.
>
>   - onError:
>
>     This is an action block of type `(`[`CitronLexerError`]`) throws -> Void`.
>
>     If there is no matching rule at a particular position in the input,
>     a [`.noMatchingRuleAt(errorPosition:)`][`CitronLexerError`] error is
>     passed to this action block. The lexer then moves ahead to the next
>     position in the input at which a rule can be applied and
>     tokenization continues from there.
>
> **Return value:**
>
>   - None
>
> **Throws:**
>
>   - Any errors thrown in the `onFound` and `onError` action blocks
>     will be prapagated up to the caller of this method.

## Position

### `currentPosition: `[`CitronLexerPosition`]

The current position of the lexer.

## Errors

### `.noMatchingRuleAt(errorPosition: `[`CitronLexerPosition`]`)`

> Signifies that at position [`CitronLexerPosition`] of the input, none of the
> specified rules could be applied.

## Usage with [`CitronParser`]

A `CitronLexer` can be used with a [`CitronParser`] by using a
[`TokenData`] that contains:
  - a [`CitronToken`], and
  - a [`CitronTokenCode`]

The tokens generated by the lexer can then be passed on to the
Citron-generated parser by calling its [`consume(token:, code:)`]
method.

[`consume(token:, code:)`]: ../CitronParser/#consumetoken-citrontoken-tokencode-citrontokencode

Assuming that the Citron-generated parser is called `Parser`, we can
write:

~~~ Swift
let parser = Parser()

typealias TokenData = (token: Parser.CitronToken, code: Parser.CitronTokenCode)
// Parser.CitronToken = Int (%token_type)
// Parser.CitronTokenCode is an enum with .Plus, .Minus and .Integer as values
// (where Plus, Minus and Integer are terminals used in the grammar)

let lexer = CitronLexer<TokenData>(rules: [
        .string("+", (token: 0, code: .Plus)),
        .string("-", (token: 0, code: .Minus)),
        .regexPattern("[0-9]+", { s in (token: Int(s)!, .Integer) }
        ])

try lexer.tokenize("40+2") { tokenData in
    try parser.consume(token: tokenData.token, code: tokenData.code)
}
let result = try parser.endParsing()
~~~

---

[`LexingRule`]: #lexingrule
[`TokenData`]: #tokendata
[`CitronLexerError`]: #nomatchingruleaterrorposition-citronlexerposition
[`.noMatchingRuleAt(errorPosition:)`]: #nomatchingruleaterrorposition-citronlexerposition
[`CitronLexerPosition`]: #citronlexerposition
[`CitronParser`]: ../CitronParser/#citronparser
[`CitronToken`]: ../CitronParser/#citrontoken
[`CitronTokenCode`]: ../CitronParser/#citrontokencode

