# Changelog

All notable changes to the postscript gem will be documented in this file.

## [Unreleased]

### Added — 2026-07-28

**0.1.0 — initial release.**

The postscript gem is extracted from postsvg 0.3.0 as a standalone,
pure-Ruby PostScript (PS) / EPS parser, typed domain model, and
serializer. Independently reusable for any tool that needs to read,
write, or transform PostScript source.

* `Postscript::Source::Lexer` — comment-aware state-machine lexer
  (preserves `%` chars inside string literals, which the legacy
  postsvg Tokenizer's `gsub`-based comment stripping corrupted).
* `Postscript::Source::AstBuilder` — tokens → `Model::Program` with
  per-operator `consumes` / `produces` stack-arity tracking so
  chained operators parse cleanly.
* `Postscript::Source::OperandStack` — permissive pop (returns
  `Computed` sentinel on underflow) so procedure bodies parse
  without runtime context.
* `Postscript::Model::*` — typed PS records: `Program`,
  `Literals::*` (Number, Name, StringLiteral, HexLiteral,
  ArrayLiteral, Procedure, Dictionary), `Operators::*` (120 PS
  operators across 13 PLRM chapters).
* `Postscript::Serializer` — `Model::Program` → PS / EPS source
  text with DSC-conformant header (BoundingBox, HiResBoundingBox,
  LanguageLevel, EPSF-3.0 marker). Idempotent round-trip
  (serialize(parse(serialize(parse(x)))) == serialize(parse(x))).
* `Postscript::Matrix`, `Postscript::Color`,
  `Postscript::FormatNumber` — general-purpose value types
  (2D affine transforms, RGB/Gray/CMYK value object, PS-safe
  float formatting).
* `Postscript::Error` hierarchy — typed errors for every failure
  mode (ParseError, LexError, SyntaxError, StackUnderflowError,
  UndefinedOperatorError, RecursionLimitError, etc.) plus
  control-flow signals (ExitSignal, QuitSignal).
* Top-level convenience API: `Postscript.parse`,
  `Postscript.serialize`, `Postscript.tokenize`.
* `exe/postscript` CLI: `parse`, `serialize`, `tokenize`,
  `version` subcommands.

### Architecture

Mirrors the `emf`/`emfsvg` split: a separate gem owns format
parsing/model/serializer; the consumer gem (postsvg) depends on it
and adds the rendering/conversion layer. This unlocks:

* Independent reuse (PS validators, formatters, future PS↔PDF).
* Single-responsibility per gem.
* Clean dependency direction (postsvg depends on postscript, never
  the other way).

### Code quality

- Pure Ruby autoload (no `require_relative` in lib/).
- No `respond_to?` for type checks, no `instance_variable_set/get`.
- No `send` to private methods.
- `# frozen_string_literal: true` on every `.rb` file.
- 149 specs, 0 failures.
- Round-trip property spec covering 6 representative PS programs.

### Backwards compatibility

postsvg's BC aliases (`Postsvg::Source = Postscript::Source`,
`Postsvg::Matrix = Postscript::Matrix`, etc.) continue to expose
the PS-side constants under the `Postsvg::*` namespace for
existing user code.
