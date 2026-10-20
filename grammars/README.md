# grammars/

The PostScript grammar is maintained in
[claricle/postscript-parg](https://github.com/claricle/postscript-parg)
(claricle/postscript#4). This directory holds copies of its files:

- `postscript.parg`: the PARG source, with embedded tests.
- `postscript.json`: the artifact compiled from it.
- `upstream.yml`: the upstream commit the copies come from.

Do not edit the copies here. Change the grammar upstream, then:

1. Copy `postscript.parg` and `postscript.json` from the merged
   upstream commit into this directory.
2. Set `commit` in `upstream.yml` to that commit.
3. Run `ruby script/check_grammar.rb` (needs `gem install parsanol`,
   Ruby 3.2 or newer).

The `grammar` workflow runs the same check. It fails if a copy differs
from upstream, the embedded tests fail, `postscript.json` is not what
the released parsanol compiles from `postscript.parg`, its checksum is
wrong, or the gem would not package both files.
