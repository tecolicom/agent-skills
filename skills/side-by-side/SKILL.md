---
name: side-by-side
description: Use when two texts should be read next to each other in the terminal - an original and its translation (English/Japanese issue drafts, release notes, documentation), two versions of a document, or any pair of Markdown or plain-text files - and when such a pair should appear side by side inside a Claude Code reply. Offers seven verified methods (ansicolumn -V, mdee -V, sdif -V with conflict markers, cdif --lxl for line pairs, plain text pasted into a code block for any agent, a Markdown table for short pairs, a Claude Code MessageDisplay hook for color) and says which to pick. Handles CJK text correctly; column/fold -s/paste do not.
---

# side-by-side — two texts next to each other

Showing an original and its translation, or two versions of a text, in
two columns is a layout job that generic tools do badly: `column`,
`paste` and `fold -s` break only at spaces, so Japanese (or any text
without spaces) comes out as unbroken runs or is cut inside a word, and
none of them pads by display width.  `diff -y` (`sdiff`) cuts every line
at the column width and drops the rest.  The tools below fold by display
width with East Asian line-breaking rules (kinsoku), so both columns
stay aligned whatever the script.

## Choosing a method

| You want | Use | Alignment |
|---|---|---|
| Two files next to each other, plain text, nothing else | `ansicolumn -V` | each file fills its own pane |
| The same, with Markdown rendered (headings, tables, code, colors) | `mdee -V` | each file fills its own pane |
| Corresponding paragraphs on the same line (original beside its translation) | `sdif -V` on conflict-marker text | block by block |
| Text whose lines alternate original/translation (or two line-aligned files) | `cdif --lxl --style=diff \| sdif` | line pair by line pair |
| Two versions of the same text, a corrected draft, with what changed marked | `sdif old new` (the sdif skill) | diff: common lines beside each other, changed words marked |
| The pair shown inside the agent's reply, with any agent | plain text in a code block (below) | as the tool used |
| A few short pairs (terms, one sentence each) in the reply, no tool at all | a Markdown table (below) | row by row |
| The same with colors, in Claude Code | the MessageDisplay hook (below) | each text fills its own pane |

Pane-filling layouts (the first two) read best when each side is to be
read on its own; the user who asked for this said that for texts of a
few screens they are enough.  Block alignment matters when the reader
jumps between the languages sentence by sentence.

## Prerequisites

Each method needs its own tool; install only what you use.

| Method | Tool | CPAN | Homebrew |
|---|---|---|---|
| `ansicolumn -V` | ansicolumn | `cpanm -n App::ansicolumn` | `brew install tecolicom/tap/app-ansi-tools` |
| `mdee -V` | mdee 1.10+ (pulls in nup, ansicolumn, ansifold, greple) | `cpanm -n App::mdee` | `brew install tecolicom/tap/app-mdee` |
| `sdif -V`, `cdif --lxl` | sdif, cdif (one distribution) | `cpanm -n App::sdif` | `brew install tecolicom/tap/app-sdif` |
| Claude Code hook | mdee 1.11+ (`--no-filename`), `jq`; nup and sdif for those layouts | as above | as above, plus `brew install jq` |

Check with `ansicolumn --version`, `mdee --version`, `sdif --version`.

## Width

All the commands take the total output width; give them the terminal
width (`tput cols`), or less if the output goes somewhere narrower.
Inside a Claude Code reply, at most `columns - 5` fits (the reply is
indented and the code fence has margins); see the hook section.

## Recipes (all verified)

### Plain text: `ansicolumn -V`

```sh
ansicolumn -V -w "$(tput cols)" left.md right.md        # one pane per file, boxed
ansicolumn -V -H -w "$(tput cols)" left.md right.md     # with file name headers
```

Lines are folded to the pane width with kinsoku; the panes are drawn
with box characters.  Nothing is interpreted: Markdown comes out as
Markdown.

### Markdown: `mdee -V`

```sh
mdee -V -w "$(tput cols)" left.md right.md               # pager (less)
mdee -V -w "$(tput cols)" --no-pager left.md right.md    # to stdout
mdee -V -w 180 -m dark --no-pager --no-page-number left.md right.md
```

Headings, emphasis, code blocks and tables are colored and formatted
(tables are fitted to the pane width), then the two files are laid out
one per pane.  `-m dark|light` picks the theme when the terminal
background cannot be detected (no tty, e.g. in a hook).  `-P N` sets
the page height; the default is the terminal height.

### Block-aligned: conflict markers + `sdif -V`

`sdif -V` ("parallel") reads git conflict-marker text and shows the two
sides of every conflict next to each other, with the lines in between
as common text.  Put each corresponding pair of blocks in one conflict
and the paragraphs line up:

```
<<<<<<< EN
First paragraph in English.
=======
日本語の最初の段落。
>>>>>>> JA

<<<<<<< EN
Second paragraph.
=======
二番目の段落。
>>>>>>> JA
```

A few lines of Perl build this from two files, pairing the n-th
blank-line separated block of one with the n-th of the other (the same
function is inside the hook script below as `cm_join`):

```sh
cm_join() {
    perl -e '
        sub blocks { local (@ARGV, $/) = (shift); grep { /\S/ } split /\n{2,}/, <> }
        my @l = blocks(shift); my @r = blocks(shift);
        my $n = @l > @r ? @l : @r;
        for my $i (0 .. $n - 1) {
            print "\n" if $i;
            print "<<<<<<< LEFT\n", $l[$i] // "", "\n=======\n", $r[$i] // "", "\n>>>>>>> RIGHT\n";
        }' "$1" "$2"
}
cm_join en.md ja.md | sdif -V --no-filename --no-tc --no-cdif --mark=no -W "$(tput cols)"
```

- `--no-cdif`, `--no-tc`: no word-level diff marking and no text
  coloring; the two sides are different languages, so a diff between
  them means nothing.  Drop `--no-tc` to keep sdif's side coloring
- `--mark=no`: no `-+`/`..` change-mark columns
- `-W`: total width (both columns plus the gutter)
- Blocks must correspond one to one; `cm_join` emits an unpaired block
  on its own if the counts differ

The same format comes out of `greple -Mxlate` (its default output is
conflict markers, translation under original), of `diff3 -m`, and of a
git merge, so `sdif -V` also serves those.  `sdif -V3` handles three
sides.

### Line pairs: `cdif --lxl` + `sdif`

When the input already alternates, line by line, between the two texts
(an interleaved translation, `OLD:`/`NEW:` lines, the output of a
line-oriented translator), `cdif --lxl` takes every two lines as a pair
and `--style=diff` turns the pairs into diff output that sdif lays out:

```sh
cdif --lxl --style=diff --limit length=1 pairs.txt |
  sdif --no-cdif --no-tc --no-filename --no-command --mark=no -W "$(tput cols)"
```

- `--limit length=1` makes cdif skip the word-by-word comparison (it
  would mark differences between two languages); the two sides still
  get their own colors.  Add `--no-tc` to cdif for no color at all
- `--no-command` hides the `1c1` hunk headers that every pair produces
- Two files whose lines correspond one to one (paragraph per line, say)
  are interleaved with `paste -d '\n' left.md right.md` first.  Blank
  line pairs come out as blank lines, so paragraph breaks survive

This is finer than the block alignment above: every line pair starts on
the same row, whatever the folded heights of the previous pair.

### Two versions: see the sdif skill

An old and a new version of the same text (a corrected draft, a
revised document) are compared rather than laid out: plain `sdif old
new` shows them side by side with the changed words marked, and
`--unit=mecab` compares Japanese by word.  The sdif skill covers it.

### Inside a reply, with any agent: plain text in a code block

Any of the layouts above can be put straight into a reply: run the
command without color and paste the output into a fenced code block.
Nothing else is needed, so this works with every agent whose UI draws
code blocks in a monospace font; only the colors are lost, and for
everything but mdee's Markdown highlighting they carry little.

```sh
NO_COLOR=1 ansicolumn -V -w 160 left.md right.md               # boxed panes
NO_COLOR=1 nup -V --pane=2 --no-pager --no-page-number left.md right.md -w 160 --no-filename
cm_join left.md right.md | sdif -V --no-filename --no-cdif --mark=no --no-color -W 160
```

- `NO_COLOR=1` turns the colors off in ansicolumn and nup; sdif and
  cdif take `--no-color`.  If a tool leaves escape sequences anyway,
  `perl -pe 's/\e\[[\d;]*[mK]//g'` removes them
- Fence the output with `~~~text` rather than backticks: the text may
  itself contain ``` lines (code blocks in the source), and a tilde
  fence is not closed by them
- The width must fit the UI's code block; in Claude Code that is the
  terminal width minus 5.  Wider lines are wrapped by the UI and the
  layout falls apart
- In parallel mode (`-V`) ansicolumn and nup size the page to the
  longer file, so no page height is needed

### Inside a reply, no tool at all: a Markdown table

The agent's own Markdown table is the cheapest layout, and for a few
short pairs (a glossary, UI strings, one sentence per row) it is enough:
one row per pair, the original in one column and the translation in the
other.  Claude Code and other agent UIs draw such a table with aligned
columns and do the width calculation themselves.

```markdown
| English | 日本語 |
|---|---|
| Release notes | リリースノート |
| The option is ignored for a single file. | ファイルが一つのときは無視されます。 |
```

Its limits decide when to stop using it:

- Cells are folded only at spaces.  Japanese text with an English word
  or code in it is broken next to that word, leaving a short line and
  a long one; a Japanese sentence without spaces is kept on one line
  and makes its column as wide as itself
- When the columns cannot get that wide, words and code may be cut in
  the middle, without kinsoku
- A table whose cells grow too tall or too wide is not drawn as a table
  at all but as `Header: value` lines, where long Japanese lines are
  left to the terminal to wrap
- `<br>` is shown literally, so a cell cannot hold more than one
  paragraph, and lists, code blocks and headings cannot go in a cell

In practice: keep every cell to one line, the Japanese ones shorter
than about half the terminal width, and one pair per row.

For anything longer than a few lines per side, use one of the tool
layouts above in a code block, or the hook below.

### Inside a Claude Code reply, in color: the MessageDisplay hook

`scripts/mdee-sxs.sh` is a Claude Code `MessageDisplay` hook.  A reply
whose first line is a marker is split at the marker lines (left text,
marker, right text, and optionally marker and a postscript) and shown
side by side; every other reply is shown as usual.  The first line
picks the layout:

| First line | Layout |
|---|---|
| `<!-- sxs -->` | `mdee -V`: Markdown rendered, one boxed pane per text |
| `<!-- sxs nup -->` | `nup -V`: plain text in the same boxed panes |
| `<!-- sxs sdif -->` | conflict markers + `sdif -V`: no boxes, paragraphs aligned, left and right in two text colors |

The user this was built for preferred the boxed panes for texts of a
few screens ("the frames make the two texts easier to tell apart") and
found sdif's default colors with backgrounds hard to read; the hook
therefore runs sdif with foreground colors only, a cool tone on the
left (#9CC4E4) and a warm one on the right (#E0B48C).  With the two
sides in different colors the areas stay distinct without any rules,
which the user found easier to read than the boxed layouts for a
parallel text.

Setup:

1. Copy `scripts/mdee-sxs.sh` to `~/.claude/hooks/`, executable.
2. Add the hook to a settings file Claude Code reads — the project's
   `.claude/settings.local.json` or `~/.claude/settings.json`
   (`~/.claude/settings.local.json` is **not** read).  An agent is
   normally not allowed to edit hook settings itself; give the user this
   JSON:

```json
{
  "hooks": {
    "MessageDisplay": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "SXS_PANE_WIDTH=91 $HOME/.claude/hooks/mdee-sxs.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

3. Set `SXS_PANE_WIDTH` to `(terminal columns - 5) / 2` (91 for a
   187-column terminal).  The hook runs without a terminal, so it can
   measure nothing; `SXS_MODE=light` for light terminals, `SXS_MDEE`
   to point at another mdee, `SXS_LEFT_COLOR`/`SXS_RIGHT_COLOR` for the
   sdif text colors.

Then write the reply as (the second and third markers are always the
plain `<!-- sxs -->`):

```
<!-- sxs -->            or <!-- sxs nup --> / <!-- sxs sdif -->
English text in Markdown ...
<!-- sxs -->
日本語のテキスト ...
<!-- sxs -->
Optional note shown below the panes.
```

What the script does, and why (each point cost an experiment):

- Claude Code calls the hook once per batch of completed lines, and the
  hooks for the batches of one reply **run concurrently**, so each batch
  is saved under its index and the final batch waits for the others.
  Intermediate batches are replaced by `""` (hidden); the final batch
  returns the whole page.
- `displayContent` **is interpreted as Markdown**.  The panes are
  wrapped in a code fence so widths survive, and mdee is told to draw
  no ``` marks (`--cm 'code_mark=sub{""}'`), because a fence inside a
  pane swallows the layout up to the next one.
- Text containing **`ESC[K` (Erase Line) is not displayed at all.**
  mdee runs with `ANSICOLOR_NO_RESET_EL=1`, and the remaining ones
  (explicit `E` in heading colors) are stripped.
- The page height `-P` is grown until both sides fit on one page
  (mdee and nup).
- The file name label is hidden with `--no-filename` (mdee 1.11) and
  nup's with `--no-filename` after the file names; sdif runs with
  `--no-cdif --mark=no` and `--cm OTEXT=...,NTEXT=...` (no backgrounds).
- If mdee fails, the plain Markdown is shown instead; a reply cancelled
  before its final batch shows nothing (its parts are swept after ten
  minutes).


## Verify

```sh
ansicolumn -V -w 160 a.md b.md | head -3            # two boxes, 160 columns
mdee -V -w 160 --no-pager a.md b.md | head -3
cm_join a.md b.md | sdif -V --no-filename --no-tc --no-cdif --mark=no -W 160 | head -3   # cm_join from above
paste -d '\n' a.md b.md | cdif --lxl --style=diff --limit length=1 | sdif --no-cdif --no-tc --no-filename --no-command --mark=no -W 160 | head -3
```

For the hook, feed it one final batch and check the width and that no
`ESC[K` is left:

```sh
printf '<!-- sxs -->\n# A\n\ntext\n<!-- sxs -->\n# B\n\n本文\n' |
  jq -Rs '{message_id:"t",index:0,final:true,delta:.}' |
  SXS_PANE_WIDTH=80 ~/.claude/hooks/mdee-sxs.sh |
  jq -r .hookSpecificOutput.displayContent | grep -c $'\e\\[K'      # 0
cat "${TMPDIR:-/tmp}/mdee-sxs/log"                                   # ... pages=1
```
