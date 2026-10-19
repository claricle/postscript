# Issue 4: PARG grammar and native parser

Issue: [Extract the PostScript grammar as PARG and port the parser to the parsanol native engine](https://github.com/claricle/postscript/issues/4)

## Outcome and scope

Move the source syntax contract from the hand-written lexer into a guide-derived PARG grammar, ship its compiled artifact with this gem, and use a native tokenization path when its supported engine is available. `Postscript::Source.parse(source)` must continue returning the same typed `Postscript::Model::Program`; the existing Ruby lexer remains the fallback. The native lexer may replace that fallback only after token-stream parity is established.

The grammar describes syntax, not runtime semantics. It accepts operator names as names. PostScript Language Level support belongs to operator vocabulary metadata and post-parse validation, not duplicate level-specific grammars. Existing Ruby `AstBuilder` behavior, including operator construction through `Model::Operator.from_operands`, remains the AST construction boundary. A guide syntax form omitted from the historical skeleton (such as immediately evaluated `//` names) is an inventory/spec gap to resolve explicitly, not silent scope expansion.

This plan covers the grammar and artifact, their packaging and CI checks, native/fallback dispatch, compatibility evidence, Language Guide vocabulary coverage, minimal post-parse level validation, and before/after parse benchmarks. It does not authorize implementation. It does not include interpreter semantics, a broad conformance framework, rendering changes, or replacing the Ruby AST builder.

## Requirement reconciliation

| Status | Requirement and evidence |
|---|---|
| Confirmed | Preserve the `Postscript::Source.parse` signature and typed `Model::Program`, keep the Ruby fallback, compare the full current suite (the issue cites 149 examples), and record corpus benchmarks. [Issue body](https://github.com/claricle/postscript/issues/4) |
| Confirmed correction | Use the PostScript Language Guide as the normative syntax and vocabulary contract. Derive rules from its syntax pages and check all command categories and level references. [Issue comment](https://github.com/claricle/postscript/issues/4#issuecomment-6247408519) |
| Confirmed correction | The canonical grammar and compiled JSON originate in `claricle/postscript-parg`; vendor both into this repository. The PARG framework, embedded tests, and compiled-artifact parity CI are reported as merged upstream. [Issue comment](https://github.com/claricle/postscript/issues/4#issuecomment-6256686705) |
| Confirmed decision | Keep one level-agnostic grammar/artifact. Represent levels as operator-registry metadata and apply level checks after parsing, preserving tolerant parsing. [Issue comment](https://github.com/claricle/postscript/issues/4#issuecomment-6247605502) |
| Unresolved integration constraint | The original issue says to ride the parsanol Rust/Ruby pair and that this gem needs no FFI layer. A later comment reports a `claricle/postscript-rs` tokenizer/parser and FFI scaffold, but does not explicitly rescind that constraint. Keep the no-new-FFI constraint unless the issue owner clarifies it; determine whether the parsanol route can meet the token contract. |
| Verified upstream state | The canonical [`postscript-parg` snapshot b2cbfe2](https://github.com/claricle/postscript-parg/commit/b2cbfe2) contains `postscript.parg` and JSON; its PARG entry has no captures. Its current CI uses the released parsanol CLI for smoke tests and fresh-compile payload equality (ignoring checksum/compiler-version envelope fields). The separate [`postscript-rs` snapshot c3e2361](https://github.com/claricle/postscript-rs/commit/c3e2361) is a scaffold: `tokenize(_source)` returns an empty vector; its token enum has no Ruby-compatible positions, DSC/header support, or integer fidelity, and its FFI has only a version function. These main-branch observations are not evidence that a published release provides the needed integration. |
| Verified candidate API | The [`parsanol-ruby` v1.3.94 source at 8d4f86c](https://github.com/parsanol/parsanol-ruby/commit/8d4f86c) exposes `Parsanol::PARG::Artifact.load(path)` and `parse(entry, input, mode: :native)`; the v1.3.94 code is confirmed identical to [v1.3.95](https://github.com/parsanol/parsanol-ruby/tree/v1.3.95) for this API. The latter calls `Native.parse` only when `Native.available?`; otherwise it executes the Ruby atom runtime. Thus `mode: :native` alone does not prove native execution. Verify exact released dependency and native extension/platform behavior used by implementation. |
| Unresolved design | Choose between the released parsanol artifact route and a future-capable `postscript-rs` route. The capture-free grammar and current Rust token type cannot yet supply the flat `Model::Token` stream with positions, DSC data, and integer fidelity. Prove artifact-to-token adaptation, byte/offset/line-column parity, error mapping, and genuinely native execution before dispatch is selected. Otherwise keep Ruby dispatch and identify the upstream prerequisite. |
| Unresolved compatibility edge | Build a drift matrix against the current lexer: top-level-only `dsc_comment`, composite rules consuming comments, nonempty literal names, Ruby backslash names, immediately evaluated `//` names omitted by the skeleton, EOF/tolerance behavior, and malformed or unbalanced input. Preserve current public parse/error behavior where required; document intentional guide corrections explicitly. |

## Current implementation

`Postscript::Source.parse` in `lib/postscript/source.rb` composes `Lexer.tokenize` and `AstBuilder.build`. `lib/postscript/source/lexer.rb` emits frozen `Model::Token` values with type, value, line, column, and literal-name flag; it handles comments/DSC comments, nested escaped strings, hex strings, names, numeric words, and composite delimiters. `lib/postscript/source/ast_builder.rb` constructs literals, nested composites, DSC header values, registered operator instances, unknown operators, and procedure invocations. `Model::Operator.from_operands` consumes the builder's `OperandStack` and remains Ruby-side. Lexing errors use `Postscript::LexError` with `source_position`; structure errors use `Postscript::SyntaxError`.

`grammars/README.md` says the grammar lives upstream and the local grammar skeleton is historical; there is no current local PARG artifact. `README.adoc` presents `Source.parse` as the public source-to-program API. Relevant existing specs are `spec/postscript/source/lexer_spec.rb`, `spec/postscript/source/ast_builder_spec.rb`, `spec/postscript/round_trip_spec.rb`, and the fixture corpus under `spec/fixtures/`.

## Ordered work items

### Upstream ownership and prerequisites

| Owner | Repository/evidence | Required contribution or constraint |
|---|---|---|
| This repository | `claricle/postscript` | Vendor canonical PARG and JSON, package/CI checks, Ruby-side adapter and metadata/validation only after capability proof. |
| PARG upstream | [`claricle/postscript-parg` b2cbfe2](https://github.com/claricle/postscript-parg/commit/b2cbfe2) | Grammar and artifact source; current entry has no captures, so token extraction needs a proven route. |
| Engine upstream | [`claricle/postscript-rs` c3e2361](https://github.com/claricle/postscript-rs/commit/c3e2361) or [`parsanol-ruby` v1.3.94](https://github.com/parsanol/parsanol-ruby/commit/8d4f86c) / [v1.3.95](https://github.com/parsanol/parsanol-ruby/tree/v1.3.95) | Must provide truly native parsing plus a path to the Ruby token contract; current Rust tokenizer is stubbed. Any tokenizer/ABI work here is outside the estimate until scoped. |

Effort is active engineer time in person-hours, including focused investigation and validation; elapsed time waiting on upstream releases or CI is excluded. Conditional Ruby-repository work items sum to 13–23 hours, assuming the selected upstream engine can provide the required capabilities. A 20% contingency is 2.6–4.6 hours, for an exact conditional total of **15.6–27.6 hours**. Any upstream tokenizer/ABI implementation needed to reach that capability is a separate, currently unestimated prerequisite and is not included.

### 1. Resolve native integration boundary — 2–4 h

Inspect the released `parsanol` Ruby package and the current `claricle/postscript-rs` workspace/API. The v1.3.94 artifact API (confirmed identical at tag v1.3.95) has `Parsanol::PARG::Artifact.load(path)` and `parse(entry, input, mode: :native)`, but `:native` runs the Ruby atom runtime whenever `Native.available?` is false; the observed Rust `tokenize` is a stub and its token enum lacks required fields. Compare artifact loading, explicit native-availability detection, grammar capture/CST extraction, token fields and byte positions, DSC/header representation, integer fidelity, error translation, supported Ruby/platform matrix, and release/dependency status. Choose the integration route only when a minimal sample proves artifact-to-token adaptation and genuinely native execution. Record the supported API and exact released dependency version in the implementation PR. If neither route supports this contract, document the missing upstream capability and keep implementation on the Ruby fallback.

**Files/symbols:** inspect `Gemfile`, `postscript.gemspec`, `lib/postscript/source.rb`, `lib/postscript/source/lexer.rb`, `Model::Token`, and upstream `Artifact.load`, `parse`, `Native.available?`, Rust `tokenize`, and FFI APIs. Runtime integration files are conditional on this spike; name them only after the target API is verified.

**Depends on:** none. This decision gates work item 3.

### 2. Vendor and continuously validate the canonical grammar — 2–4 h

Copy the canonical upstream grammar and compiled artifact into `grammars/postscript.parg` and `grammars/postscript.json` (using the verified upstream filenames `postscript.parg` and its compiled JSON artifact). Keep the upstream grammar as the source of truth and document the update procedure in `grammars/README.md`. Preserve its embedded smoke tests and compile-versus-checked-in-artifact payload parity check in this repository's CI, using `bundle exec parsanol parg test` and `bundle exec parsanol parg compile` (verify flags/options against pinned release docs). Add a small repository task/script to compare compiled payloads after ignoring envelope checksum/compiler-version metadata. Separately load the committed artifact through `Parsanol::PARG::Artifact.load` to validate its checksum; payload equality does not replace envelope validation. Verify the vendored files match the pinned upstream source and artifact. Ensure the packaged gem includes both files by checking `Gem::Specification#files` or the built gem contents.

Review grammar rules against the guide pages listed in the issue correction: `docs/syntax/tokens.adoc`, `objects.adoc`, `data-types.adoc`, `strings.adoc`, `arrays.adoc`, `dictionaries.adoc`, `procedures.adoc`, and `operators.adoc`. Treat `docs/commands/**` as vocabulary coverage and `docs/levels/*` as level metadata coverage. The grammar accepts names independently of the target language level.

**Files:** existing `grammars/README.md`; proposed `grammars/postscript.parg`, `grammars/postscript.json`; proposed `.github/workflows/grammar.yml` (the existing `rake.yml` is autogenerated); proposed `script/check_parg_artifact.rb` for payload parity; gemspec packaging check.

**Depends on:** work item 1 for compiler and artifact-loading version details; can proceed alongside the Ruby metadata inventory in work item 4 once exact guide paths are checked out or otherwise available.

### 3. Add native tokenization with an unchanged public parse boundary — 3–6 h

Integrate the selected engine behind `Postscript::Source.parse` in `lib/postscript/source.rb`. The native path must supply the same token contract consumed by `AstBuilder.build`: `Model::Token` type/value/line/column/literal readers (where `literal` marks a leading-slash name), and DSC/comment behavior required by the builder. Keep `AstBuilder` and `Model::Operator.from_operands` Ruby-side. Select native tokenization when supported; otherwise call `Lexer.tokenize` exactly as today. Map native syntax failures to the existing `Postscript::LexError`/`Postscript::SyntaxError` contract and `source_position` array `[line, column]` where available. Do not broadly catch parser failures and retry Ruby, which could hide native-path defects or change error behavior. Do not expose engine-specific tokens as a new public API.

**Files/symbols:** `lib/postscript/source.rb`, `Postscript::Source.parse`, `Postscript::Source::Lexer`, `Postscript::Source::AstBuilder`, `Postscript::Model::Token`, `lib/postscript/errors.rb`; add a narrowly scoped adapter only at the verified path selected by work item 1.

**Depends on:** work items 1 and 2.

### 4. Reconcile operator vocabulary and language-level metadata — 3–5 h

Compare every operator in the Guide's command categories with the gem's registry after `Model::Operators.load_all!`. Extend `Model::Operator.register_as` and the registry's registered-entry data only as needed to retain Level 1/2/3 availability. Add a Guide-derived inventory that lists every command category/operator as supported by a concrete class or intentionally represented by `Model::UnknownOperator`; do not silently omit categories or expand the implementation to add every missing operator. Add minimal post-parse validation against a requested level, preserving tolerant parse results and existing `Source.parse(source)` behavior. Define the smallest result/call shape in implementation after checking public API conventions; level violations must be observable. No level conditional may be added to the PARG grammar.

**Files/symbols:** `lib/postscript/model/operator.rb` (`register_as`), `lib/postscript/model/operators.rb` (`register`, `keywords`, `load_all!`), operator category files under `lib/postscript/model/operators/`, and proposed `lib/postscript/source/level_validator.rb`; proposed `spec/postscript/model/operator_guide_coverage_spec.rb`, proposed `spec/postscript/source/level_validator_spec.rb`, and proposed `data/postscript_operators.json` with category, operator name, language-level availability, registry mapping, and pinned Guide source provenance. Use the [Guide snapshot c45f337](https://github.com/claricle/postscript-guide/commit/c45f337f0112acc6a771cdc101a663858d23ee12) for command pages and `docs/levels/*` as explicit inventory sources. The checked-out Guide tree has 181 `docs/commands/**/*.adoc` pages across 17 subdirectories, while the issue cites 18 categories and 300+ operators; inventory work must reconcile pages, category indexes, and operator names rather than treating each page as one operator. Unknown operators remain explicit inventory rows.

**Depends on:** work item 2 for the Guide vocabulary source. This can be implemented independently of native dispatch after the grammar scope is confirmed.

### 5. Prove token and model parity, fallback behavior, and performance — 3–4 h

Use the existing lexer as the parity oracle. Compare token streams over focused syntax cases and all relevant repository fixtures, including exact positions and literal-name flags. Compare native and fallback `Model::Program` results over the current suite and source corpus, plus error class and `source_position` `[line, column]` for malformed strings, hex strings, and unbalanced composites. Verify native-unavailable dispatch reaches the pure-Ruby fallback. Use proposed `benchmark/corpus.json` to pin local fixtures and the external [`postsvg` fixture corpus at b699673](https://github.com/claricle/postsvg/commit/b699673d1a98235e38ad81f828ea2906ef3ada1c), including `spec/fixtures/ps2svg/new_tests/01_paths.ps` through `12_full_feature_test.ps` and `spec/fixtures/eps2svg/img.eps`; record expected parse failures separately and do not assume every rendering fixture parses as a complete document. Record a repeatable before/after benchmark on the same valid postscript/postsvg inputs and environment, with corpus manifest, successful/failed counts, and command in the PR; do not claim a speedup without measured results.

The inspected `postsvg` converter currently calls `Postsvg::Parser.parse`, backed by its Parslet parser. Establish the actual consumer integration entry point before claiming a downstream smoke test; parsing its fixture corpus through `Postscript::Source.parse` alone does not demonstrate converter integration. Consumer changes and rendering verification require separately scoped work.

**Files:** add focused differential coverage in proposed `spec/postscript/source/native_parity_spec.rb` and preserve `spec/postscript/source/lexer_spec.rb`, `spec/postscript/source/ast_builder_spec.rb`, `spec/postscript/round_trip_spec.rb`, `spec/fixtures/`; proposed `benchmark/parse.rb` with `bundle exec ruby benchmark/parse.rb --engine ruby` and `--engine native` against the same manifest-selected valid corpus.

**Depends on:** work item 3; work item 4 for any level metadata coverage assertion.

## Acceptance and planned verification

The commands below are **planned**, not run as part of this plan. Confirm exact CLI spelling against the selected parsanol release during implementation.

| Issue criterion / settled addition | Work | Observable check and expected result |
|---|---:|---|
| Grammar and compiled artifact are local, guide-derived, tested, and packaged | 2 | Run the upstream-supported PARG embedded-test command against `grammars/postscript.parg`; all embedded tests pass. Compile to a temporary artifact and compare payload with `grammars/postscript.json` after excluding envelope metadata; payloads match. Build the gem and inspect its file list; both artifacts are present. |
| Full Guide vocabulary is accepted and level coverage is complete | 2, 4 | CI compares Guide command names/categories to grammar name acceptance and the loaded Ruby registry; no Guide category/operator is silently omitted. A Level 3-only operator remains syntactically accepted in the same grammar and is marked as unavailable by Level 1/2 metadata validation. |
| Native and Ruby token streams agree before dispatch switches | 3, 5 | Differential checks assert token type, value, line, column, and `literal` for the same inputs. Include comments/DSC, delimiter boundaries, radix and decimal forms, escaped/nested strings, hex strings, arrays, procedures, dictionaries, and names. All assertions match. |
| `Model::Program` parity across existing suite/fixtures | 3, 5 | Run `bundle exec rspec` (the issue cites 149 examples); compare native and forced-fallback results on the suite and corpus. AST node classes/fields, headers, operator construction, unknown operators, and user procedure invocation match. |
| Pure-Ruby fallback remains intact | 3, 5 | Run focused source specs with native support unavailable/disabled; `Postscript::Source.parse` returns the same program and errors as the baseline Ruby path. |
| Error behavior and token positions remain compatible | 3, 5 | Focused malformed-input cases assert `LexError`/`SyntaxError` class and `source_position`; token locations preserve the current one-based line/column contract. |
| Benchmarks are recorded | 5 | Run the same benchmark command and corpus against baseline Ruby and native paths; include manifest/SHA, expected failures, environment, corpus identity/size, warm-up/repetition method, and measured results in the implementation PR. |
| Project checks pass | 2–5 | Run `bundle exec rake` (RSpec and RuboCop via `Rakefile`) and the grammar compile/test checks. Record exact commands and outcomes; these remain planned until run. |

Proposed implementation commands (the comparison script, focused specs, and benchmark are created by the work items above):

```sh
bundle exec parsanol parg test grammars/postscript.parg
bundle exec parsanol parg compile grammars/postscript.parg -o /tmp/postscript-fresh.json
bundle exec ruby script/check_parg_artifact.rb grammars/postscript.json /tmp/postscript-fresh.json
bundle exec ruby -rparsanol/parg/artifact -e 'Parsanol::PARG::Artifact.load("grammars/postscript.json")'
bundle exec rspec spec/postscript/source/native_parity_spec.rb spec/postscript/source/level_validator_spec.rb spec/postscript/model/operator_guide_coverage_spec.rb
bundle exec rake
gem build postscript.gemspec
bundle exec ruby benchmark/parse.rb --engine ruby
bundle exec ruby benchmark/parse.rb --engine native
```

Confirm the selected release's artifact require path in work item 1. Inspect the built gem's file list for both grammar files. The benchmark must report which engine actually ran and fail a requested native run if native execution is unavailable.

Baseline: `bundle exec rake` is the repository's default RSpec + RuboCop task. The issue reports 149 examples; establish the current count during implementation and run the full current suite. No runtime test or CI result is claimed by this plan.

## Sequencing and integration

Work item 1 is the first executable action and gates native adapter/dependency choices. Work items 2 and 4 can overlap after the source/metadata inputs are available; both converge before final CI acceptance. Work item 3 follows the integration decision and vendored artifact format. Work item 5 is the final integration gate. Keep native dispatch behind a small boundary so the baseline fallback remains selectable in tests and diagnostics.

If upstream integration prerequisites are not released or cannot produce the required token contract, complete grammar/artifact and vocabulary work independently, leave the native adapter conditional, and report the parity/performance criteria as blocked rather than representing scaffold existence as engine readiness.

## Effort and uncertainty

| Work item | Estimate |
|---|---:|
| 1. Native integration boundary | 2–4 h |
| 2. Vendor grammar/artifact and CI | 2–4 h |
| 3. Native tokenization boundary | 3–6 h |
| 4. Operator vocabulary/levels | 3–5 h |
| 5. Parity, fallback, benchmarks | 3–4 h |
| **Subtotal** | **13–23 h** |
| Contingency (20%) | 2.6–4.6 h |
| **Conditional total** | **15.6–27.6 h** |

The largest uncertainty is whether the released parsanol route can turn the capture-free artifact into Ruby-compatible positioned tokens while proving native execution. Work item 1 is bounded to that proof; the current Rust tokenizer is a stub and parsanol `:native` can use its Ruby interpreter when the native extension is unavailable. The 15.6–27.6-hour estimate is conditional on usable upstream capability. Any upstream tokenizer/ABI work is a blocked prerequisite with effort not estimated here. Estimates assume upstream grammar/artifact checks are reusable and the Guide is accessible at its cited paths.

## Progress and handoff

Status is **Not started** for every work item; this document records a plan, not implementation progress.

| Work item | Status | Evidence / remaining gap |
|---|---|---|
| 1. Native integration boundary | Not started | Establish current published package and scaffold contracts; select route or document missing prerequisite. |
| 2. Vendor grammar/artifact and CI | Not started | Confirm canonical filenames/tool version; vendor and verify package/CI parity. |
| 3. Native tokenization boundary | Not started | Wait for work item 1 decision; implement only against proven token contract. |
| 4. Operator vocabulary/levels | Not started | Map all Guide operators to current registry and Level 1/2/3 metadata. |
| 5. Parity, fallback, benchmarks | Not started | Run differential and existing checks, then capture same-corpus benchmark. |

**Next executable action:** perform work item 1's bounded integration spike. The Ruby-repository implementation can proceed once that spike records a viable released integration route; if new tokenizer/ABI work is required, that upstream-owned prerequisite must be estimated and scheduled separately. No implementation has been authorized by this planning artifact.
