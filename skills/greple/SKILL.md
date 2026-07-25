---
name: greple
description: Use when plain grep/ripgrep falls short while searching code or text - AND search for multiple keywords co-occurring in the same line/paragraph/function, showing the whole function or section containing a match (instead of grep-then-read round-trips), restricting search to comments/POD/code regions, phrase search across line breaks (prose and Japanese text), detecting invisible Unicode characters (zero-width, combining, bidi controls) when identical-looking strings fail to match, or searching/extracting text inside Office files (docx/xlsx/pptx). greple is a block-oriented grep with region control.
---

# greple — block-oriented grep

## When to use

For single-pattern line search or scanning huge trees, ripgrep is faster —
use it when it suffices.  greple wins in these situations:

- **Co-occurrence (AND) search** — find lines, paragraphs, or functions
  that contain *all* of several keywords, in one shot
- **You want the whole logical unit containing a match** — print the
  entire function or Markdown section instead of grep-then-read round-trips
- **Region-restricted search** — only inside comments, outside comments,
  only in POD, etc.
- **Phrase search across line breaks** — prose and Japanese text.
  ripgrep works line by line and misses phrases split across lines;
  greple finds them

## Prerequisites and caveats

- Check availability with `greple --version` (fall back to plain grep if
  absent; install with `cpanm -n App::Greple` or
  `brew install tecolicom/tap/app-greple`)
- **Always prefix commands with `GREPLE_NORC=1`** to neutralize the
  user's `~/.greplerc` (which may force `--color=always` etc.) and keep
  behavior reproducible.  Without an rc file, color defaults to `auto`,
  so piped output contains no ANSI codes
  - If you cannot set an environment variable, pass `--norc` as the
    **first** argument (it is position-sensitive) plus `--color=never`
- Put `-M` module options **immediately after the command name**
  (`greple -Mdig ...`)
- `-n` adds line numbers; with multiple files each line is prefixed with
  the file name
- If output could be large, cap it with `-m N` (at most N blocks per file)
- Exit status: 0 = matched, 1 = no match.  Block output is separated by
  `--` lines

## Recipes (all verified)

### AND / NOT / OR search (co-occurrence within a block)

```sh
GREPLE_NORC=1 greple -e foo -e bar -v baz FILE   # foo AND bar on a line, no baz
GREPLE_NORC=1 greple -p -e foo -e bar FILE       # foo AND bar in one paragraph
GREPLE_NORC=1 greple -e 'foo|bar' FILE           # OR via regex alternation
```

### Show the whole function or section containing a match

```sh
# Perl: print the entire sub containing the pattern
GREPLE_NORC=1 greple -n --block '^sub\s+\w+.*\n(?:.*\n)*?^\}\n' PATTERN FILE

# Indentation-based languages (Python etc.): non-indented line starts a chunk
GREPLE_NORC=1 greple -n --block '^\S.*\n(?:[ \t].*\n|\n)*' PATTERN FILE

# Markdown: use heading-delimited sections as the unit
GREPLE_NORC=1 greple --border '^(?=#+ )' -e WORD1 -e WORD2 FILE
```

Combining `--block`/`--border` with multiple `-e` options means
"functions (sections) containing both A and B".

### Region-restricted search

```sh
GREPLE_NORC=1 greple -Mperl --pod PATTERN FILE.pm    # POD only
                                                      # also --comment --code --doc --data
GREPLE_NORC=1 greple --exclude '(?s)/\*.*?\*/' --exclude '//.*' PATTERN FILE.c
                                                      # search outside C-style comments
```

Two caveats:

- Multiple `--outside`/`--inside` options combine as **OR (union)**.
  To stack exclusions, repeat **`--exclude`, which narrows in AND
  manner**, or merge into a single `--outside` with alternation
  `(?s)/\*.*?\*/|//.*`
- By default a match that only **partially overlaps** the region also
  counts (e.g. `--inside and` matches `command`).  Add **`--strict`**
  to reject boundary-crossing matches and confine hits strictly inside
  the region

### Phrase search across line breaks (prose, Japanese)

```sh
GREPLE_NORC=1 greple -e 'position cache' doc.md   # space matches any whitespace incl. newline
GREPLE_NORC=1 greple '検索性能' doc.md             # matches even when split as 検索\n性能
```

Japanese text can be wrapped at any character, so phrases that ripgrep
cannot find are found by greple.  Prefer greple for document search.

### Recursive search

```sh
GREPLE_NORC=1 greple -Mdig PATTERN --git       # search git-managed files
GREPLE_NORC=1 greple -Mdig PATTERN --dig DIR   # find-based; skips binaries and artifacts
```

Restrict by file type with `-Mtype` (`cpanm -n App::Greple::type`;
bundled with the Homebrew app-greple formula):

```sh
GREPLE_NORC=1 greple -Mdig -Mtype --perl PATTERN --dig .      # Perl files only
GREPLE_NORC=1 greple -Mdig -Mtype --no-perl PATTERN --dig .   # everything except Perl
```

Types cover most languages (`--python`, `--go`, `--rust`, `--js`, …;
`--type-NAME` is the long form).  Unlike extension-based filters, these
also match by `#!` line, so extensionless scripts are found.

**Skip minified and generated files** with `-Mselect
--x-select-longer=N`, which excludes any file containing a line longer
than N characters:

```sh
GREPLE_NORC=1 greple -Mdig -Mselect --x-select-longer=200 PATTERN --dig .
```

This catches minified CSS/JS, bundled assets, and single-line JSON dumps
even when the file name gives no hint (`bundle.css`, not `*.min.css`).
Worth adding to any search that might touch build output — one matching
line from a minified file floods the output with thousands of useless
characters.

`-Mselect` also provides the primitives behind `-Mtype` for ad-hoc
conditions: `--suffix=pl,pm`, `--shebang=perl`, `--select-name=REGEX`,
`--select-data=REGEX`, each with an exclusive `--x-` counterpart.

### Region-restricted bulk substitution (-Msubst)

Unlike sed, substitution can be **combined with region restriction**
(e.g. unify terminology only inside comments).  Separately distributed
module (`cpanm -n App::Greple::subst`; bundled with the Homebrew
app-greple formula).

```sh
GREPLE_NORC=1 greple -Msubst --dictpair 'colou?r' color --diff FILE     # preview as diff
GREPLE_NORC=1 greple -Msubst --dictpair 'colou?r' color --replace FILE  # apply (original saved as .bak)
GREPLE_NORC=1 greple -Mperl -Msubst --comment --dictpair OLD NEW --diff FILE.pm   # comment lines only
GREPLE_NORC=1 greple -Msubst --dictdata $'foo bar\nbaz qux\n' --diff FILE         # multiple pairs at once
```

- The replacement is given directly with `--dictpair PATTERN REPLACEMENT`
- Correction semantics: matches already equal to the replacement are
  left untouched (`colou?r`→`color` does not touch `color`)
- **Always preview with `--diff` before running `--replace`**.  Avoid
  `--overwrite`, which keeps no backup

When the replacement is not a literal string (uppercasing,
backreferences, computed transforms), use `-Mupdate` instead: the
`--cm 'sub{...}'` function is called with the matched string in `$_`
and its return value becomes the replacement:

```sh
GREPLE_NORC=1 greple -Mupdate PATTERN --cm 'sub{uc}' --diff FILE                  # uppercase
GREPLE_NORC=1 greple -Mupdate 'colou?r' --cm 'sub{s/colou(r)/COLO_$1/r}' --diff FILE  # backreference
```

Preview with `--diff`, write with `--update` (`--with-backup` keeps a
.bak copy).  Composes with region restriction (`-Mperl --comment` etc.).

### Inspecting invisible and Unicode characters (-Mcharcode / -Mcc)

When identical-looking strings fail to match, or a diff looks empty yet
differs, suspect invisible characters (zero-width spaces, combining
characters, bidi controls) and visualize them with `-Mcc`.  Requires
the separately distributed module: `cpanm -n App::Greple::charcode` or
`brew install tecolicom/tap/app-greple-charcode`.

```sh
GREPLE_NORC=1 greple -Mcc -P ASCII FILE      # annotate non-ASCII chars with column and Unicode name
GREPLE_NORC=1 greple -Mcc --outstand FILE    # combining chars and other non-ASCII at once
GREPLE_NORC=1 greple -Mcc --ansicode FILE    # detect ANSI control sequences
```

Example output (reveals a ZERO WIDTH SPACE hidden at column 5):

```
     ┌─   5 \x{200b} name=\N{ZERO WIDTH SPACE}
hidden​zero width
```

`--nfd`/`--nfc` display normalization forms, useful for diagnosing
NFC/NFD mismatches.

### Output control

```sh
-l        # matching file names only
-c        # match count per file
-o        # only the matched substrings
-C N      # show N blocks of context (with -p: surrounding paragraphs)
```

### head/tail by block, not by line

`-m` selects which matched blocks to print, counting in whatever unit
the block options define.  `head`/`tail` cannot do this — they only
count lines:

```sh
GREPLE_NORC=1 greple -p -m 3 PATTERN FILE       # first 3 matching paragraphs
GREPLE_NORC=1 greple -p -m 0,-3 PATTERN FILE    # last 3 matching paragraphs
GREPLE_NORC=1 greple --block '^sub\s+\w+.*\n(?:.*\n)*?^\}\n' -m 0,-2 PATTERN FILE
                                                 # last 2 matching functions
```

Forms: `-m N` first N, `-m 0,-N` last N, `-m 0,N` drop first N,
`-m -N` drop last N.  Counts apply per file.

A real pattern is required — with `--need=0` and an empty pattern the
whole file becomes a single block and `-m` has nothing to count.

### Searching for many literal strings at once (-Mxp)

To search for a list of literal strings — code fragments, symbol names,
anything full of regex metacharacters — put them in a file, one per
line, and let `-Mxp` treat them as fixed strings.  No escaping needed
(`cpanm -n App::Greple::xp`; bundled with the Homebrew app-greple
formula):

```sh
printf '$self->{need}\n@ARGV\n' > /tmp/literals.txt
GREPLE_NORC=1 greple -Mxp --le-string /tmp/literals.txt -l FILES
```

`--le-pattern FILE` does the same but treats each line as a regex, and
`#` comments are allowed there.  Region options have file-based forms
too (`--inside-pattern`, `--exclude-string`, …).  greple's built-in
`-f FILE` also reads patterns from a file, but only as regexes.

### Machine-readable structured output (TSV / JSON Lines)

Each match can be emitted as a structured record with file name,
character offsets, and matched string — useful when post-processing
results with scripts.  `--callback` receives `__file__`/`start`/`end`/
`index`/`match` per match and its return value replaces the matched
string; combined with `-h -o`, only the return values are printed,
one per line:

```sh
# TSV: file<TAB>start<TAB>end<TAB>match
GREPLE_NORC=1 greple -h -o --callback 'sub{my %a=@_; sprintf("%s\t%d\t%d\t%s", $a{"__file__"}, $a{start}, $a{end}, $a{match})}' PATTERN FILES

# JSON Lines
GREPLE_NORC=1 greple -h -o --callback 'sub{my %a=@_; require JSON::PP; JSON::PP->new->canonical->encode({file=>$a{"__file__"}, start=>0+$a{start}, end=>0+$a{end}, match=>$a{match}})}' PATTERN FILES
```

`start`/`end` are character offsets from the beginning of the file
(not line numbers).  If line numbers suffice, plain `-n` output is
simpler.

### Transparent search in compressed and non-text files (--if)

`.gz`/`.Z` files are decompressed before search by default
(`greple needle data.txt.gz` just works).  With `--if='REGEX:command'`
an input filter is applied only to files whose name matches:

```sh
GREPLE_NORC=1 greple --if='/\.dat$/:tr A-Z a-z' needle FILES        # lowercase .dat files before search
GREPLE_NORC=1 greple --if='/\.pdf$/:pdftotext - -' PATTERN *.pdf    # e.g. search PDFs as text
```

### Searching Office documents directly (-Mmsdoc)

Text inside docx/pptx/xlsx files can be searched directly.  Separately
distributed module (`cpanm -n App::Greple::msdoc` or
`brew install tecolicom/tap/app-greple-msdoc`).

```sh
GREPLE_NORC=1 greple -Mmsdoc PATTERN file.docx   # search docx/pptx/xlsx directly
GREPLE_NORC=1 greple -Mmsdoc --dump file.docx    # extract full text (works as Office-to-text converter)
```

`--dump` matters for agents too: it reads Office file content as text
without pandoc or other converters.

For PDF, git objects, and other formats beyond Office XML, use
`optex -Mtc greple ...` instead — it applies the same conversion to any
command.  See the `textconv` skill.

## Advanced: generate a task-specific module on the fly

When the same search conditions are reused, generate a module in a
scratch directory and call it as named options.

```sh
mkdir -p $SCRATCH/lib/App/Greple
cat > $SCRATCH/lib/App/Greple/xtask.pm <<'EOF'
package App::Greple::xtask;
use v5.24;
use warnings;
1;
__DATA__
option --md-section --border '^(?=#+ )'
option --perl-sub --block '^sub\s+\w+.*\n(?:.*\n)*?^\}\n'
EOF

GREPLE_NORC=1 PERL5LIB="$SCRATCH/lib:$PERL5LIB" greple -Mxtask --md-section -e WORD1 -e WORD2 FILE
```

Notes:

- **Append** to `PERL5LIB` (overwriting it breaks greple itself under
  local::lib setups)
- Option definitions after `__DATA__` are parsed with shellwords, so
  **always single-quote patterns containing backslashes or spaces**
  (unquoted, `\s` degrades to `s`)
- Defined options compose freely with ordinary options
  (`--md-section -e A -e B -v C` etc.)
