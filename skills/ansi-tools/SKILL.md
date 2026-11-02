---
name: ansi-tools
description: Use when text that contains ANSI color sequences or East Asian (Japanese, Chinese, Korean) characters has to be aligned into columns, wrapped or reflowed to a width, or printed with a fixed field width - a table that comes out ragged, a paragraph to fold for the terminal or a commit message, colored status lines of a script - where column, fold, fmt and printf miscount the width. ansicolumn, ansifold, ansiprintf and ansiecho measure the visible width (ANSI sequences count 0, wide characters 2) and break Japanese text by its rules; cat-v shows the invisible characters.
---

# ansi-tools — column, fold and printf that see the screen width

## When to use

`column -t`, `fold`, `fmt` and `printf '%-20s'` count bytes or
characters.  As soon as the text has ANSI escape sequences (colored
output of a command) or East Asian characters (two columns wide each),
columns drift, lines are cut at the wrong place and padding is off.
These tools count what the terminal shows:

- **ansicolumn** aligns table columns and lays text out in columns
  and pages (`column` replacement)
- **ansifold** folds lines to a width at word boundaries, with
  Japanese line-breaking rules, and can join a paragraph first
  (`fold`/`fmt` replacement)
- **ansiprintf** is `printf` with field widths measured on the screen;
  **ansiecho** prints colored strings with a short color notation
- **cat-v** makes tabs, trailing spaces and control characters visible

For plain ASCII without color the standard commands do; reach for
these when the input has color or wide characters, or when you need
Japanese line breaking.

## Prerequisites

- Check with `ansicolumn --version`, `ansifold --version`.  Install
  with `brew install tecolicom/tap/app-ansi-tools` (ansicolumn,
  ansifold, ansiecho, ansiprintf) or
  `cpanm -n App::ansicolumn App::ansifold App::ansiecho Text::ANSI::Printf App::cat::v`
- Without installing, the default image of dozo (the dozo skill) has
  ansicolumn and ansifold: `dozo -B -q -D env HOME=/tmp ansicolumn -t FILE`
  (only the git top directory is mounted; see the dozo skill)
- The tools read `~/.ansicolumnrc` and `~/.ansifoldrc` when they
  exist; a recipe that must behave the same everywhere sets the
  options it relies on explicitly

## Recipes (all verified)

### Align a table (`ansicolumn -t`)

```sh
ansicolumn -t -s$'\t' FILE.tsv                        # tab-separated input
ansicolumn -t -s'|' -o' | ' --table-right=2 FILE      # '|' input, right-align column 2
ansicolumn -t -s'|' -o' | ' -w 50 FILE                # fit into 50 columns, wrapping wide cells
ansicolumn -t -l 4 -o ' ' FILE                        # at most 4 fields: the rest stays one field
```

- `-s` input separator, `-o` output separator (default two spaces),
  `--table-right=N[,N]` and `--table-center=N` align columns, `-w N`
  fits the table into N columns by wrapping the cells of the columns
  that do not fit (`--cell` sets widths per column)
- `-l N` splits each line into at most N fields, so a trailing free
  text (a comment, a description with spaces) stays together
- Colored cells and Japanese text line up; `column -t` on the same
  input misplaces every column after a colored or wide cell

To align a few lines inside a file and leave the rest as it is, see
"Apply them to part of a file" below.

For two texts side by side (`-V`), pages and panes (`-C`, `-D`), see
the side-by-side skill.

### Fold or reflow text (`ansifold`)

```sh
ansifold -w 72 -s FILE                 # fold at 72, word boundary, Japanese line breaking
ansifold -r -w 72 -s FILE              # join each paragraph first, then fold (reflow)
ansifold -r -w 72 -s --autoindent '^[-*] ' FILE    # list items: continuation lines indented
```

- `-s` (`--smart`) is `--boundary=word --linebreak=all`: no break
  inside a word, and a closing punctuation such as `。` or `」` is
  not left at the start of a line (run-in, up to `--runin` columns,
  default 4).  Without it ansifold breaks at any character
- `-r` (`--refill`) joins the lines of each paragraph (blank line
  separated) before folding: with a space between words, with nothing
  between two wide characters or after a fullwidth punctuation mark.
  `fmt` joins with a space everywhere and cannot break Japanese text
  at all
- `--autoindent=REGEX` makes the lines after a match start under the
  text (the matched prefix becomes spaces); `--keepindent` repeats it
  instead
- `--crmode` treats CR as the line separator for the join, for use
  under `greple -Mtee ... --crmode` (multi-line regions in one run)
- `-x` expands tabs; `--padding` pads every line to the width

ansifold is also `ansicut` and `ansicolrm`: `cut -c` and `colrm` by
screen columns.

### Apply them to part of a file (`greple -Mtee`, `teip`)

The tools read whole files, but the lines to align or fold are often a
few among others.  Two wrappers send only those to the command and
leave the rest of the file as it is:

```sh
# the key => value, # comment lines of one declaration, chosen by
# region (greple); the region stops at the #, so the comment stays put
GREPLE_NORC=1 greple -Mtee ansicolumn -tl4 -o ' ' -- \
    --block '^my \$config = (?s:.*?)^\);' \
    -E '(?<=^    )\S+\h+=>\h+\S+\h+#' --cm=N FILE.pm

# the same shape on every line of the file (teip has no region, so
# lines of that shape elsewhere are aligned together with these)
teip -og '\S+\s+=>\s+\S+\s+#' -- ansicolumn -t -o ' ' < FILE.pm

# fold the list items only, each on its own (teip -s)
teip -s -g '^- ' -- ansifold -w 72 -s --autoindent '^- ' < FILE.md
```

- [teip](https://github.com/greymd/teip) (`brew install teip`) works
  line by line: `-g` chooses the lines, `-o` passes only the matched
  part, so an indent before the match stays in place.  It has no notion
  of a region, so the pattern alone decides which lines change, and
  without `-s` the command must give back one line per line (extra
  lines are dropped without a word): use `-s` for ansifold
- greple's `-Mtee` was modeled on teip and adds what greple has: a
  region (`--inside`, `--block`), a match across lines, lookbehind in
  the pattern, and `--crmode` to fold multi-line items in one run.
  The greple skill has the details ("Pipe only the matched regions
  through a command")

### Print with widths and colors (`ansiprintf`, `ansiecho`)

```sh
ansiprintf '%-10s|%5s|\n' "$colored" "$wide"    # pads by visible width
ansiecho -c R 'error:' -c '<RoyalBlue>' "$msg"   # colored words, one space between
ansiecho -n -c GI "$text"                        # -n: no newline
COLORS=($(ansiecho -cR Red -cGI Green -cBIU Blue)); ansiprintf '| %-8s | %-8s |\n' "${COLORS[@]}"
```

- ansiprintf takes the printf format and arguments; `%-10s` pads a
  colored `林檎` to 10 screen columns, where printf pads to 10 bytes
- The color spec is Term::ANSIColor::Concise: `R G B C M Y K W` and
  lowercase for the dark variants, `D` bold, `I` italic, `U`
  underline, `S` standout, `<Name>` an X11 color name, `#rrggbb`,
  `L00`–`L25` gray levels, `FG/BG` for a background (`W/R`), `;E`
  erase to end of line.  The same notation is used by greple `--cm`,
  mdee themes and sdif
- `-c SPEC ARG` colors the next argument, `-C SPEC` the following
  ones until `-E`; `-f FORMAT ARGS` formats like ansiprintf

### See the invisible characters (`cat-v`)

```sh
cat-v FILE            # tabs as ╺───, spaces as ·, newline as ⏎, controls as ␁ ␛ ...
```

Spaces at the end of a line, tabs mixed with spaces, and control
characters become visible.  For the name and code point of a strange
character use `greple -Mcc` (the greple skill).

### From Perl

```perl
use Text::ANSI::Fold::Util qw(ansi_width ansi_fold);
ansi_width("\e[31m林檎\e[m ab");    # 7: sequences count 0, wide characters 2
```

L<Text::ANSI::Fold> is the engine behind ansifold and the cell
wrapping of ansicolumn; `Text::ANSI::Printf` behind ansiprintf.

## Notes

- `--ambiguous=wide` (ansicolumn, ansifold) treats East Asian
  ambiguous-width characters (`①`, `※`, some symbols) as wide, for
  terminals that show them so
- ansicolumn and ansifold are also callable as functions from greple's
  tee module (`-Mtee '&ansicolumn' ...`, `-Mtee '&ansifold' ...`)
  without a fork per call
