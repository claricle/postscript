# grammars/

PARG grammar sources for the PostScript parser (parsanol grammar
language: https://github.com/parsanol/parsanol-rs).

- `postscript.parg` — the grammar skeleton; the authoritative source
  for the token/cst shapes `lib/postscript/source/ast_builder.rb`
  consumes once the native engine path lands (claricle/postscript#4).

Toolchain:

```sh
parsanol parg compile grammars/postscript.parg -o grammars/postscript.json
```
