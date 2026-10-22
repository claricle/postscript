# Issue 4: PARG grammar and native parser

Issue: [Extract the PostScript grammar as PARG and port the parser to the parsanol native engine](https://github.com/claricle/postscript/issues/4)

## Outcome and scope

Move the source syntax contract from the hand-written lexer into a guide-derived PARG grammar, ship its compiled artifact with this gem, and add an opt-in native tokenization path on the parsanol engine. `Postscript::Source.parse(source)` must continue returning the same typed `Postscript::Model::Program`; the existing Ruby lexer remains the default. The native lexer may become the default only after token-stream parity is established and it is measured faster than the Ruby lexer.

The grammar describes syntax, not runtime semantics. It accepts operator names as names. PostScript Language Level support belongs to operator vocabulary metadata and post-parse validation, not duplicate level-specific grammars. Existing Ruby `AstBuilder` behavior, including operator construction through `Model::Operator.from_operands`, remains the AST construction boundary. A guide syntax form omitted from the historical skeleton (such as immediately evaluated `//` names) is an inventory/spec gap to resolve explicitly, not silent scope expansion.

This plan covers the grammar and artifact, their packaging and CI checks, opt-in native engine selection, compatibility evidence, Language Guide vocabulary coverage, minimal post-parse level validation, and before/after parse benchmarks. It does not authorize implementation. It does not include interpreter semantics, a broad conformance framework, rendering changes, or replacing the Ruby AST builder.

## Requirement reconciliation

| Status | Requirement and evidence |
|---|---|
| Confirmed | Preserve the `Postscript::Source.parse` signature and typed `Model::Program`, keep the Ruby fallback, compare the full current suite (the issue cites 149 examples), and record corpus benchmarks. [Issue body](https://github.com/claricle/postscript/issues/4) |
| Confirmed correction | Use the PostScript Language Guide as the normative syntax and vocabulary contract. Derive rules from its syntax pages and check all command categories and level references. [Issue comment](https://github.com/claricle/postscript/issues/4#issuecomment-6247408519) |
| Confirmed correction | The canonical grammar and compiled JSON originate in `claricle/postscript-parg`; vendor both into this repository. The PARG framework, embedded tests, and compiled-artifact parity CI are reported as merged upstream. [Issue comment](https://github.com/claricle/postscript/issues/4#issuecomment-6256686705) |
| Confirmed decision | Keep one level-agnostic grammar/artifact. Represent levels as operator-registry metadata and apply level checks after parsing, preserving tolerant parsing. [Issue comment](https://github.com/claricle/postscript/issues/4#issuecomment-6247605502) |
| Decided | Native parsing rides the parsanol Rust/Ruby pair, as the original issue says; this gem adds no FFI layer. `claricle/postscript-rs` is out of scope for this issue. |
| Verified upstream state | The canonical [`postscript-parg` snapshot b2cbfe2](https://github.com/claricle/postscript-parg/commit/b2cbfe2) has no captures, so it returns the whole input as one slice. [postscript-parg#3](https://github.com/claricle/postscript-parg/pull/3) captures every token under its rule name (integer, real, radix, name, string, hex_string, literal_name, array, procedure, dictionary, and top-level DSC comments as dsc), with choice order unchanged. Its CI runs the released parsanol CLI for embedded tests and fresh-compile payload equality. |
| Verified upstream defect | parsanol-ruby ≤ 1.3.95 (crate ≤ 0.18.8) returns wrong, *successful* parses for inputs of 8 KB or more: the bytecode VM, used from that size, decoded PARG's escaped classes (`[\x61-\x7a]`) wrongly and the bridge accepted a short parse. Fixed in [parsanol-rs#251](https://github.com/parsanol/parsanol-rs/pull/251) (crate 0.18.9) and [parsanol-ruby#242](https://github.com/parsanol/parsanol-ruby/pull/242) (gem 1.3.96, also versions the compiled-program cache). The native path requires `parsanol >= 1.3.96`. `Artifact#parse(entry, input, mode: :native)` falls back to the Ruby atom runtime when `Native.available?` is false, so the adapter must check that itself. parsanol requires Ruby ≥ 3.2; this gem supports ≥ 3.0. |
| Decided | parsanol is an optional dependency, not in the gemspec. Native tokenization is opt-in through `Source.parse(source, engine: :native)`; that call raises a clear error when parsanol ≥ 1.3.96 or its native extension is unavailable, and never silently runs the Ruby atom runtime. The default stays the Ruby lexer: measured with the fixed engine, native parse plus token conversion is 10–24× slower than `Lexer.tokenize` (5 KB: 86 ms vs 6 ms; 943 KB: 30 s vs 1.2 s). |
| Decided | Where the grammar and the current lexer disagree, the lexer wins for now: the parity spec requires identical tokens and the grammar is adjusted upstream to match. Each guide difference found (candidates: top-level-only `dsc_comment`, composite rules consuming comments, nonempty literal names, Ruby backslash names, immediately evaluated `//` names, EOF/tolerance behavior, malformed or unbalanced input) is recorded as a follow-up issue, not changed silently. |

## Current implementation

`Postscript::Source.parse` in `lib/postscript/source.rb` composes `Lexer.tokenize` and `AstBuilder.build`. `lib/postscript/source/lexer.rb` emits frozen `Model::Token` values with type, value, line, column, and literal-name flag; it handles comments/DSC comments, nested escaped strings, hex strings, names, numeric words, and composite delimiters. `lib/postscript/source/ast_builder.rb` constructs literals, nested composites, DSC header values, registered operator instances, unknown operators, and procedure invocations. `Model::Operator.from_operands` consumes the builder's `OperandStack` and remains Ruby-side. Lexing errors use `Postscript::LexError` with `source_position`; structure errors use `Postscript::SyntaxError`.

`grammars/README.md` says the grammar lives upstream and the local grammar skeleton is historical; there is no current local PARG artifact. `README.adoc` presents `Source.parse` as the public source-to-program API. Relevant existing specs are `spec/postscript/source/lexer_spec.rb`, `spec/postscript/source/ast_builder_spec.rb`, `spec/postscript/round_trip_spec.rb`, and the fixture corpus under `spec/fixtures/`.

## Ordered work items

### Upstream ownership and prerequisites

| Owner | Repository/evidence | Required contribution or constraint |
|---|---|---|
| This repository | `claricle/postscript` | Vendor canonical PARG and JSON, package/CI checks, the opt-in Ruby-side adapter, metadata and validation. |
| PARG upstream | [`claricle/postscript-parg#3`](https://github.com/claricle/postscript-parg/pull/3) | Token captures. Must be merged before the grammar is vendored. |
| Engine upstream | [`parsanol-rs#251`](https://github.com/parsanol/parsanol-rs/pull/251) → crate 0.18.9; [`parsanol-ruby#242`](https://github.com/parsanol/parsanol-ruby/pull/242) → gem 1.3.96 | VM correctness for PARG grammars and a versioned program cache. Must be released before the native adapter merges. |

Effort is active engineer time in person-hours, including focused investigation and validation; elapsed time waiting on upstream releases or CI is excluded. Work items sum to 12–20 hours; a 20% contingency is 2.4–4.0 hours, for a total of **14.4–24 hours**.

### 1. Confirm the released engine — 1 h

The route is decided (parsanol, opt-in). Once parsanol 1.3.96 is released, confirm on it that the captured artifact parses natively (`Native.available?` true) on the CI platforms, that the 8 KB-or-more fixtures parse identically in `mode: :native` and `mode: :ruby`, and record the exact version in the implementation PR.

**Depends on:** parsanol 1.3.96 released.

### 2. Vendor and continuously validate the canonical grammar — 2–4 h

Copy the canonical upstream grammar and compiled artifact into `grammars/postscript.parg` and `grammars/postscript.json` (using the verified upstream filenames `postscript.parg` and its compiled JSON artifact). Keep the upstream grammar as the source of truth and document the update procedure in `grammars/README.md`. Preserve its embedded smoke tests and compile-versus-checked-in-artifact payload parity check in this repository's CI (in a job on Ruby ≥ 3.2 that installs parsanol as a development dependency only), using `bundle exec parsanol parg test` and `bundle exec parsanol parg compile` (verify flags/options against pinned release docs). Add a small repository task/script to compare compiled payloads after ignoring envelope checksum/compiler-version metadata. Separately load the committed artifact through `Parsanol::PARG::Artifact.load` to validate its checksum; payload equality does not replace envelope validation. Verify the vendored files match the pinned upstream source and artifact. Ensure the packaged gem includes both files by checking `Gem::Specification#files` or the built gem contents.

Review grammar rules against the guide pages listed in the issue correction: `docs/syntax/tokens.adoc`, `objects.adoc`, `data-types.adoc`, `strings.adoc`, `arrays.adoc`, `dictionaries.adoc`, `procedures.adoc`, and `operators.adoc`. Treat `docs/commands/**` as vocabulary coverage and `docs/levels/*` as level metadata coverage. The grammar accepts names independently of the target language level.

**Files:** existing `grammars/README.md`; proposed `grammars/postscript.parg`, `grammars/postscript.json`; proposed `.github/workflows/grammar.yml` (the existing `rake.yml` is autogenerated); proposed `script/check_parg_artifact.rb` for payload parity; gemspec packaging check.

**Depends on:** postscript-parg#3 merged; can proceed alongside the Ruby metadata inventory in work item 4 once exact guide paths are checked out or otherwise available.

### 3. Add opt-in native tokenization with an unchanged public parse boundary — 3–6 h

Add `Source.parse(source, engine: :ruby)`; `engine: :native` tokenizes with the vendored artifact through parsanol and `engine: :ruby` (the default) calls `Lexer.tokenize` exactly as today. The native adapter loads parsanol lazily, requires `>= 1.3.96` and `Native.available?`, and raises a clear error otherwise; it never runs the Ruby atom runtime in place of the native engine. It converts captures to the same token contract consumed by `AstBuilder.build`: `Model::Token` type/value/line/column/literal readers, with line/column computed from capture byte offsets, and DSC/comment behavior required by the builder. Keep `AstBuilder` and `Model::Operator.from_operands` Ruby-side.

Errors: when the native parse fails, run `Lexer.tokenize` on the same source to raise the error. Failures then carry exactly the current `Postscript::LexError`/`Postscript::SyntaxError` class, message and `source_position`. This is limited to failed parses; successful native parses are never retried, so parity defects stay visible to the parity spec. Do not expose engine-specific tokens as a new public API. Do not add parsanol to the gemspec.

**Files/symbols:** `lib/postscript/source.rb`, `Postscript::Source.parse`, `Postscript::Source::Lexer`, proposed `lib/postscript/source/native_lexer.rb`, `Postscript::Model::Token`, `lib/postscript/errors.rb`.

**Depends on:** work items 1 and 2.

### 4. Reconcile operator vocabulary and language-level metadata — 3–5 h

Compare every operator in the Guide's command categories with the gem's registry after `Model::Operators.load_all!`. Extend `Model::Operator.register_as` and the registry's registered-entry data only as needed to retain Level 1/2/3 availability. Add a Guide-derived inventory that lists every command category/operator as supported by a concrete class or intentionally represented by `Model::UnknownOperator`; do not silently omit categories or expand the implementation to add every missing operator. Add minimal post-parse validation against a requested level, preserving tolerant parse results and existing `Source.parse(source)` behavior. Define the smallest result/call shape in implementation after checking public API conventions; level violations must be observable. No level conditional may be added to the PARG grammar.

**Files/symbols:** `lib/postscript/model/operator.rb` (`register_as`), `lib/postscript/model/operators.rb` (`register`, `keywords`, `load_all!`), operator category files under `lib/postscript/model/operators/`, and proposed `lib/postscript/source/level_validator.rb`; proposed `spec/postscript/model/operator_guide_coverage_spec.rb`, proposed `spec/postscript/source/level_validator_spec.rb`, and proposed `data/postscript_operators.json` with category, operator name, language-level availability, registry mapping, and pinned Guide source provenance. Use the [Guide snapshot c45f337](https://github.com/claricle/postscript-guide/commit/c45f337f0112acc6a771cdc101a663858d23ee12) for command pages and `docs/levels/*` as explicit inventory sources. The checked-out Guide tree has 181 `docs/commands/**/*.adoc` pages across 17 subdirectories, while the issue cites 18 categories and 300+ operators; inventory work must reconcile pages, category indexes, and operator names rather than treating each page as one operator. Unknown operators remain explicit inventory rows.

**Depends on:** work item 2 for the Guide vocabulary source. This can be implemented independently of native dispatch after the grammar scope is confirmed.

### 5. Prove token and model parity, error behavior, and performance — 3–4 h

Use the existing lexer as the parity oracle. Compare token streams over focused syntax cases and all relevant repository fixtures, including exact positions and literal-name flags. Compare native and Ruby-lexer `Model::Program` results over the current suite and source corpus, plus error class and `source_position` `[line, column]` for malformed strings, hex strings, and unbalanced composites. Verify that without parsanol the default path is unchanged and `engine: :native` raises a clear error. Use proposed `benchmark/corpus.json` to pin local fixtures and the external [`postsvg` fixture corpus at b699673](https://github.com/claricle/postsvg/commit/b699673d1a98235e38ad81f828ea2906ef3ada1c), including `spec/fixtures/ps2svg/new_tests/01_paths.ps` through `12_full_feature_test.ps` and `spec/fixtures/eps2svg/img.eps`; record expected parse failures separately and do not assume every rendering fixture parses as a complete document. Record a repeatable before/after benchmark on the same valid postscript/postsvg inputs and environment, with corpus manifest, successful/failed counts, and command in the PR; do not claim a speedup without measured results. The benchmark decides whether native may later become the default; current measurements say it may not.

The inspected `postsvg` converter currently calls `Postsvg::Parser.parse`, backed by its Parslet parser. Establish the actual consumer integration entry point before claiming a downstream smoke test; parsing its fixture corpus through `Postscript::Source.parse` alone does not demonstrate converter integration. Consumer changes and rendering verification require separately scoped work.

**Files:** add focused differential coverage in proposed `spec/postscript/source/native_parity_spec.rb` and preserve `spec/postscript/source/lexer_spec.rb`, `spec/postscript/source/ast_builder_spec.rb`, `spec/postscript/round_trip_spec.rb`, `spec/fixtures/`; proposed `benchmark/parse.rb` with `bundle exec ruby benchmark/parse.rb --engine ruby` and `--engine native` against the same manifest-selected valid corpus.

**Depends on:** work item 3; work item 4 for any level metadata coverage assertion.

## Acceptance and planned verification

The commands below are **planned**, not run as part of this plan. Confirm exact CLI spelling against the selected parsanol release during implementation.

| Issue criterion / settled addition | Work | Observable check and expected result |
|---|---:|---|
| Grammar and compiled artifact are local, guide-derived, tested, and packaged | 2 | Run the upstream-supported PARG embedded-test command against `grammars/postscript.parg`; all embedded tests pass. Compile to a temporary artifact and compare payload with `grammars/postscript.json` after excluding envelope metadata; payloads match. Build the gem and inspect its file list; both artifacts are present. |
| Full Guide vocabulary is accepted and level coverage is complete | 2, 4 | CI compares Guide command names/categories to grammar name acceptance and the loaded Ruby registry; no Guide category/operator is silently omitted. A Level 3-only operator remains syntactically accepted in the same grammar and is marked as unavailable by Level 1/2 metadata validation. |
| Native and Ruby token streams agree | 3, 5 | Differential checks assert token type, value, line, column, and `literal` for the same inputs. Include comments/DSC, delimiter boundaries, radix and decimal forms, escaped/nested strings, hex strings, arrays, procedures, dictionaries, and names. All assertions match. |
| `Model::Program` parity across existing suite/fixtures | 3, 5 | Run `bundle exec rspec` (the issue cites 149 examples); compare `engine: :native` and `engine: :ruby` results on the suite and corpus. AST node classes/fields, headers, operator construction, unknown operators, and user procedure invocation match. |
| Ruby lexer remains the default | 3, 5 | Without parsanol installed, `Postscript::Source.parse(source)` returns the same program and errors as before; `engine: :native` raises a clear error. |
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

Delivered as separate PRs:

1. postscript-parg#3: token captures (upstream).
2. Vendor the grammar and artifact with CI checks (work item 2), after postscript-parg#3 merges.
3. Opt-in native lexer, parity spec, error mapping and benchmark (work items 1, 3, 5). It can be developed against a local parsanol build and merges after parsanol 1.3.96 is released.
4. Operator vocabulary and language-level metadata (work item 4), independent of parsanol.

## Effort and uncertainty

| Work item | Estimate |
|---|---:|
| 1. Confirm the released engine | 1 h |
| 2. Vendor grammar/artifact and CI | 2–4 h |
| 3. Opt-in native tokenization | 3–6 h |
| 4. Operator vocabulary/levels | 3–5 h |
| 5. Parity, errors, benchmarks | 3–4 h |
| **Subtotal** | **12–20 h** |
| Contingency (20%) | 2.4–4.0 h |
| **Total** | **14.4–24 h** |

The largest remaining uncertainty is how many grammar/lexer differences the parity spec finds; each one is either a grammar change upstream or a follow-up issue. Native speed is a known limitation, not a blocker, because native is opt-in. Estimates assume the Guide is accessible at its cited paths.

## Progress and handoff

Status on 2026-10-22: **every work item is done**, and [#4](https://github.com/claricle/postscript/issues/4) is closed. The plan itself landed in [#7](https://github.com/claricle/postscript/pull/7). Upstream prerequisites are met: [postscript-parg#3](https://github.com/claricle/postscript-parg/pull/3) merged on 2026-10-20, and the engine fixes ([parsanol-rs#251](https://github.com/parsanol/parsanol-rs/pull/251), [parsanol-ruby#242](https://github.com/parsanol/parsanol-ruby/pull/242)) are released in parsanol 1.3.96 and later.

| Work item | Status | PRs | Evidence |
|---|---|---|---|
| 1. Confirm the released engine | Done | [#11](https://github.com/claricle/postscript/pull/11) | The native path requires parsanol 1.3.96 or newer with its native extension; CI runs the native specs on Ruby 3.3, 3.4 and 4.0. |
| 2. Vendor grammar/artifact and CI | Done | [#5](https://github.com/claricle/postscript/pull/5), [#6](https://github.com/claricle/postscript/pull/6), [#8](https://github.com/claricle/postscript/pull/8) | `grammars/postscript.parg` and `grammars/postscript.json` are pinned to an upstream commit in `grammars/upstream.yml`; the `grammar` workflow runs `script/check_grammar.rb`. |
| 3. Opt-in native tokenization | Done | [#10](https://github.com/claricle/postscript/pull/10), [#11](https://github.com/claricle/postscript/pull/11) | `Postscript::Source.parse(source, engine: :native)`; the Ruby lexer stays the default, and `NativeEngineUnavailable` is raised when parsanol is missing. |
| 4. Operator vocabulary/levels | Done | [#13](https://github.com/claricle/postscript/pull/13) (I4-A1), [#16](https://github.com/claricle/postscript/pull/16) (A2), [#19](https://github.com/claricle/postscript/pull/19) (A3), [#14](https://github.com/claricle/postscript/pull/14) (A4), [#18](https://github.com/claricle/postscript/pull/18) (B1), [#17](https://github.com/claricle/postscript/pull/17) (B3), [#20](https://github.com/claricle/postscript/pull/20) (B4), [#22](https://github.com/claricle/postscript/pull/22) (B5), [#21](https://github.com/claricle/postscript/pull/21) (C1), [#23](https://github.com/claricle/postscript/pull/23) (C2), [#25](https://github.com/claricle/postscript/pull/25) (C3), [#24](https://github.com/claricle/postscript/pull/24) (C4) | Guide operators extracted to `data/guide_operators.yml` and checked in CI, gaps filled in `data/operator_overrides.yml`, `Model::Vocabulary`, `Operator.language_level`, level violations through `Postscript.level_violations`, and the generated inventory in `docs/operators.adoc`. |
| 5. Parity, errors, benchmarks | Done | [#11](https://github.com/claricle/postscript/pull/11), [#15](https://github.com/claricle/postscript/pull/15) | `spec/postscript/source/native_lexer_spec.rb` checks token and `Model::Program` parity and errors against the Ruby lexer on every fixture; `benchmark/parse.rb` and the postsvg corpus benchmark record the measurements, and native stays opt-in. |

**Follow-ups, tracked separately:**

- [#26](https://github.com/claricle/postscript/issues/26): decide on the 6 places where the lexer differs from the Guide.
- [#27](https://github.com/claricle/postscript/issues/27): the AST builder drops dictionaries and non-literal array elements.
- Guide gaps behind the operator overrides, each linked from its `reason` in `data/operator_overrides.yml`: [postscript-guide#8](https://github.com/claricle/postscript-guide/issues/8) (pages without a level), [#9](https://github.com/claricle/postscript-guide/issues/9) (operators without a page), [#10](https://github.com/claricle/postscript-guide/issues/10) (Level 2 operators listed as new in Level 3), [#11](https://github.com/claricle/postscript-guide/issues/11) (operators named only on the level pages).
