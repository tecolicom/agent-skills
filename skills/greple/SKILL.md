---
name: greple
description: Use when plain grep/ripgrep falls short while searching code or text - AND search for multiple keywords co-occurring in the same line/paragraph/function, showing the whole function or section containing a match (instead of grep-then-read round-trips), restricting search to comments/POD/code regions, phrase search across line breaks (prose and Japanese text), or detecting invisible Unicode characters (zero-width, combining, bidi controls) when identical-looking strings fail to match. greple is a block-oriented grep with region control.
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
  absent; install with `cpanm App::Greple` or
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

### Inspecting invisible and Unicode characters (-Mcharcode / -Mcc)

When identical-looking strings fail to match, or a diff looks empty yet
differs, suspect invisible characters (zero-width spaces, combining
characters, bidi controls) and visualize them with `-Mcc`.  Requires
the separately distributed module: `cpanm App::Greple::charcode` or
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
