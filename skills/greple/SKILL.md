---
name: greple
description: Use when plain grep/ripgrep falls short while searching code or text - AND search for multiple keywords co-occurring in the same line/paragraph/function, showing the whole function or section containing a match (instead of grep-then-read round-trips), restricting search to comments/POD/code regions, phrase search across line breaks (prose and Japanese text), detecting invisible Unicode characters (zero-width, combining, bidi controls) when identical-looking strings fail to match, or searching/extracting text inside Office files (docx/xlsx/pptx), or piping only the matched regions of a file through an external command (-Mtee) to align or reformat them in place. greple is a block-oriented grep with region control.
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
- **Transform only the matched regions** with an external command
  (`-Mtee`): align or reformat part of a file and leave the rest as it is

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

### Without installing greple: `dozo -D`

If greple is not installed but Docker is, the default image of dozo
(the dozo skill) has greple with its common modules:

```sh
dozo -B -q -D env GREPLE_NORC=1 greple -n -e PATTERN file.md
```

- `GREPLE_NORC=1` matters even more there: the image's `~/.greplerc`
  sets `--color=always`
- Only the git top directory (or, outside git, the current directory)
  is mounted, at the same relative place; files elsewhere on the host,
  such as `/tmp`, are not visible in the container
- The tools are as new as the image (the dozo skill tells how to
  update it), and the first run downloads about 1 GB: ask the user
  before that

## Recipes (all verified)

### AND / NOT / OR search (co-occurrence within a block)

```sh
GREPLE_NORC=1 greple -e foo -e bar -v baz FILE   # foo AND bar on a line, no baz
GREPLE_NORC=1 greple -p -e foo -e bar FILE       # foo AND bar in one paragraph
GREPLE_NORC=1 greple -e 'foo|bar' FILE           # OR via regex alternation
```

**Repeating `-e` means AND, not OR.**  This is the opposite of
`grep -e`, and it fails silently: patterns that never co-occur return
nothing, which reads exactly like "the keywords are absent".  When the
alternatives need different anchoring and do not merge cleanly into one
alternation, use `-f` or `--need`:

```sh
GREPLE_NORC=1 greple -f patterns.txt FILE            # one regex per line, combined as OR
GREPLE_NORC=1 greple -e A -e B -e C --need=1 FILE    # any 1 of the 3 is enough
```

`-f` keeps the patterns in a file, so shell quoting stops mattering for
regexes full of backslashes and backticks; blank lines and `#` comments
are ignored there.  There is no inline form of `-f`, but process
substitution supplies one without writing a file:

```sh
GREPLE_NORC=1 greple -f <(printf '%s\n' '^name:' '^\s*skiprows:') FILE
```

`-t` (`--may`) is **not** an OR.  It marks a pattern as optional — to be
highlighted where present, never required — so `-e A -t B` selects on A
alone, and a command whose patterns are *all* `-t` requires nothing and
matches nothing.

### One-argument logic with -x / --le

`-x` (`--le`) expresses the whole condition inline: tokens split on
whitespace, `-` negates, `?` marks optional, and everything else is
required.

```sh
GREPLE_NORC=1 greple -x 'foo -bar ?baz' FILE          # foo, not bar, highlight baz if present
GREPLE_NORC=1 greple -x 'foo bar baz' --need=1 FILE   # any one of the three
```

Since tokens split on whitespace, a pattern containing a literal space
must spell it `\s` (`-x 'foo\sbar'`) — otherwise it silently becomes two
AND-ed patterns.  Reach for `-e` when the patterns are long or full of
spaces, and `-x` when they are short words.

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

The block pattern can describe any delimited unit, not just code — a
fenced code block of one language, a YAML document, a log entry.  But
**verify the block pattern matches before trusting a zero result**: a
`--block` that matches nothing returns zero hits for every search,
indistinguishable from "the keyword is absent".  Searching for the
block pattern itself counts the blocks:

```sh
GREPLE_NORC=1 greple -c -e "$BLOCK" FILES   # how many blocks exist per file
GREPLE_NORC=1 greple -l -e "$BLOCK" FILES   # which files contain any
```

Do this whenever a zero result is to be reported as a finding.

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

**Pick N with the prose in mind.**  CJK text is frequently written
without line wrapping, so ordinary Japanese or Chinese documents run to
thousands of characters per line and are silently dropped from the
search — the excluded files never appear, so the loss is invisible.
Raise N well above the longest legitimate paragraph, or omit the option
entirely for document trees, and reserve it for source and build output.

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

### Pipe only the matched regions through a command (-Mtee)

When the transformation is a job for an existing command (aligning
columns, reformatting, translating), `-Mtee` sends **only the matched
regions** to that command and puts its output back in their place;
the rest of the file passes through untouched.  Separately distributed
module (`cpanm -n App::Greple::tee`; bundled with the Homebrew
app-greple formula).

```sh
GREPLE_NORC=1 greple -Mtee CMD ARGS -- PATTERN --all FILE
```

- The words up to `--` are the command, so `-Mtee` comes **last** among
  the `-M` options and greple's own options follow the `--`
- `--all` prints the whole file, not just the matching lines
- By default all regions go to the command in one run and the output
  is distributed back by line count
- A region need not be a whole line or end with a newline: a word or a
  quoted string in the middle of a line is sent as a line of its own
  (tee adds the newline and removes it from the output), so
  `-E '"[^"]*"'` with `tr a-z A-Z` uppercases only the quoted
  strings.  The command must give back as many lines as it got: fewer
  is an error, more is a warning and the extra lines are dropped

The options of the module go after the `--`, with greple's own
(before it they would be arguments of the command):

- `--discrete` runs the command once per region, for a command whose
  output depends on the whole input or keeps state (`cat -n` numbers
  every region from 1 with it, continuously without it)
- `--crmode` turns the newlines inside a multi-line region into CRs on
  the way in and the CRs of the output back into newlines, so that
  multi-line regions can go through a line-oriented command in one
  run.  `ansifold --crmode` understands this and folds each region as a
  unit; this is how `mdee` folds list items:

  ```sh
  GREPLE_NORC=1 greple -Mtee ansifold -w30 --crmode -- --crmode -E '^- .*\n(?:  .*\n)*' --all FILE.md
  ```

- `--fillup` joins the lines of each region into one line first, with a
  space between words and nothing between wide characters (Japanese),
  for translation or reflow
- `--squeeze` collapses runs of blank lines
- `-S` (`--stretch`, a greple option) widens each match to the whole
  line, so that a short pattern sends the lines that contain it:
  `-S -E foo` (the module's own `--blocks` does the same and is legacy)
- `-Mtee '&ansifold'`, `'&ansicolumn'` and `'&cat-v'` call the Perl
  function instead of running the command; any `'&Full::Name::func'`
  works.  It is cheaper with `--discrete`, which otherwise forks once
  per region
- The module follows [teip](https://github.com/greymd/teip)
  (`teip -g PATTERN -- CMD`, `-o` for the matched part only), which is
  faster for line-by-line work; greple adds the region (`--inside`,
  `--block`), matches across lines and `--crmode`.  The ansi-tools
  skill shows both on the same task

Example — align the `key => value, # comment` lines of one hash with
`ansicolumn -t` and leave everything else, including the indentation,
as it is:

```sh
GREPLE_NORC=1 greple -Mtee ansicolumn -tl4 -o' ' -- \
    --inside '(?s)Config->new\(.*?^\);' \
    -E '(?<=^ {4})\w+ +=> (?!\{).*# .*\n' --all FILE.pm
```

- `--inside` limits the region to the one block, `-E` picks the lines of
  that shape; `(?!\{)` skips a value that is a hash ref `{ ... }` (a
  character class like `[^{\n]*` would also drop a value that merely
  contains a brace, such as `"\x{b4}"`, and nothing tells you)
- Check the selection before transforming: the same pattern with `-n`
  and without `-Mtee` lists the lines that will be sent, so a line that
  the pattern misses shows up before the result does
- The lookbehind `(?<=^ {4})` starts the match **after** the indent, so
  the indent is not sent to the command and stays in place.  Shape the
  region boundaries this way whenever the command should see only part
  of a line
- `ansicolumn -l4` splits each line into at most 4 fields, so the
  comment with its spaces stays one field

To write the result back, add `-Mupdate` in front and `--diff` to
preview, `--update` to replace the file:

```sh
GREPLE_NORC=1 greple -Mupdate -Mtee ansicolumn -tl4 -o' ' -- --diff   PATTERN FILE   # preview
GREPLE_NORC=1 greple -Mupdate -Mtee ansicolumn -tl4 -o' ' -- --update PATTERN FILE   # write
```

`--update` with `-Mtee` needs App::Greple::update newer than 1.04:
1.04 diverts STDOUT to an in-memory handle, the command's output is
lost, and tee dies with `Unexpected short response`.  With 1.04,
redirect the output to a new file and move it over the original
(`... --all FILE > FILE.new && mv FILE.new FILE`).  The function form
of the command (`-Mtee '&ansicolumn'`, which runs it in-process)
additionally needs Command::Run newer than 1.04.

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

`-c` reports every file it scanned, including the ones with no match, so
totalling its output requires dropping the zeros first:

```sh
GREPLE_NORC=1 greple -Mdig -c PATTERN --dig . | awk -F: '$NF > 0'
```

Reading the head of an unfiltered `-c` listing shows a run of `:0` lines
and looks like the search never ran.

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
`-f FILE` also reads patterns from a file, but only as regexes — and
combines them as OR, unlike repeated `-e`.

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
