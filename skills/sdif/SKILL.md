---
name: sdif
description: Use when comparing two versions of a text and the changes inside lines matter - reviewing a corrected or proofread draft, a rewritten paragraph, a translation revision, git diff / git log -p / git show output, conflict markers, or the changing output of a command. cdif marks the changed words within changed lines, sdif lays the diff out side by side, watchdiff repeats a command and marks what changed. Compares Japanese by word (MeCab) instead of by line or character, and can print the word marks as [-old-]{+new+} so that an agent can read them without color.
---

# sdif — word-level and side-by-side diffs

App::sdif installs three commands:

| Command | Does |
|---|---|
| `cdif` | reads diff output and marks the changed **words** inside the changed lines (one column) |
| `sdif` | lays diff output, or two files, out side by side; runs cdif on the changed lines by default |
| `watchdiff` | runs a command repeatedly and marks what changed since the last run |

All of them read ordinary diff output (normal, `-c`, `-u`, git's
combined diff) and git conflict markers, so they work after `diff`,
`git diff`, `git log -p`, `git show` and a merge.

## When to use

- **Checking a correction**: what a proofreader, a reviewer or the
  agent itself changed in a document, word by word
- **Japanese (or other CJK) text**, where line diffs and `git diff
  --word-diff` mark whole sentences and character diffs mark nonsense
  (see below)
- **Reading `git diff` / `git log -p`** with the changed words marked,
  in one column (cdif) or two (sdif)
- **Watching** a status command, a log or a test run for changes
  (watchdiff)

For an original and its *translation*, a diff means nothing: every line
differs.  To lay such pairs out next to each other use the side-by-side
skill (`sdif -V` on conflict markers, `cdif --lxl` on line pairs).

## Prerequisites

```sh
cpanm -n App::sdif                   # CPAN
brew install tecolicom/tap/app-sdif  # Homebrew
```

Check with `sdif --version` (this skill was verified with 4.49).  For
Japanese word units also install MeCab and a dictionary
(`brew install mecab mecab-ipadic`); `mecab --version` checks it.

## Recipes (all verified)

```sh
diff -u old.md new.md | cdif                      # one column, words marked
git diff | cdif                                   # also git log -p, git show
sdif old.md new.md -W "$(tput cols)"              # two columns
git diff file.md | sdif -W "$(tput cols)"
```

- sdif folds long lines to the column width with kinsoku, Japanese
  included, and marks continuation lines `..` in the mark column
- `--no-filename` hides the `---`/`+++` lines, `--no-command` the
  `1c1` hunk headers, `--mark=no` the mark columns
- `-W` is the total width; give it the terminal width
- Both color by default, also into a pipe; `less -R` shows the colors
  (`LESSANSIENDCHARS=mK` as well, for the erase-line sequences)

## Japanese: word units and `--unit=mecab`

Line diffs, and `git diff --word-diff` (which splits words at spaces),
mark a whole Japanese sentence as changed.  Character diffs
(`--word-diff-regex=.`) match single characters across unrelated words,
so the marks fall inside words.  The same edit, three ways:

```
git diff --word-diff-regex=.
  [-ファイルの-]{+まず+}内容を確[-認して-]か[-ら-]{+め+}、[-必-]要[-に応じて-]{+るなら+}設定{+ファイル+}を[-修正-]{+直+}してください。

cdif (default --unit=word)
  < [-ファイルの-]内容を確[-認してから-]、[-必-]要[-に応じて-]設定を[-修正-]してください。
  > {+まず+}内容を確{+かめ+}、要{+るなら+}設定{+ファイル+}を{+直+}してください。

cdif --unit=mecab
  < [-ファイルの-]内容を[-確認してから-]、[-必要に応じて-]設定を[-修正し-]てください。
  > {+まず+}内容を{+確かめ+}、{+要るなら+}設定{+ファイル+}を{+直し+}てください。
```

- cdif's default unit is not characters: runs of hiragana, runs of
  katakana, Latin words and numbers are compared as units, and only
  kanji one by one.  Kana and English stay whole, so it already reads
  better than a character diff; kanji can still match across words
  (`確` in 確認/確かめ above)
- `--unit=mecab` (`--mecab`) splits Japanese with the MeCab
  morphological analyzer, so the marks fall on word boundaries:
  確認してから → 確かめ, 必要に応じて → 要るなら.  ASCII text is still
  compared word by word.  `--unit=char` compares by character
- sdif and watchdiff pass `--unit` on to cdif:

```sh
sdif --unit=mecab -W "$(tput cols)" draft.md corrected.md
git diff draft.md | sdif --unit=mecab -W "$(tput cols)"
diff -u draft.md corrected.md | cdif --unit=mecab
```

- cdif compares the words of a whole changed block, not line by line,
  so a paragraph broken at different places in the two versions shows
  only the real edits; the moved line breaks are not marked

## Reading the marks without color

The word marks are colors, which an agent reading the output, or a
reply pasted into a code block, does not see.  A colormap entry can be
a Perl function instead of a color, so the changed words can be
wrapped in text marks:

```sh
diff -u draft.md corrected.md |
  cdif --unit=mecab \
    --cm 'OCHANGE=sub{"[-$_-]"}' --cm 'NCHANGE=sub{"{+$_+}"}' \
    --cm 'DELETE=sub{"[-$_-]"}'  --cm 'APPEND=sub{"{+$_+}"}' |
  perl -pe 's/\e\[[\d;]*[mK]//g'
```

```
-[-ファイルの-]内容を[-確認してから-]、[-必要に応じて-]設定を[-修正し-]てください。
+{+まず+}内容を{+確かめ+}、{+要るなら+}設定{+ファイル+}を{+直し+}てください。
```

- `OCHANGE`/`NCHANGE` are the changed words on the old/new side,
  `DELETE`/`APPEND` words present on one side only.  Give each `--cm`
  separately: inside one comma-joined list the commas of the next entry
  end up in the function
- The `perl` filter drops the remaining colors
- The same options go to sdif through `--cdifopts`, for a two-column
  version in a code block; the marks may then be folded across lines

## git

cdif and sdif work as git pagers.  The sdif manual (App::sdif, GIT)
gives this configuration:

```
~/.gitconfig
    [pager]
        log  = sdif | less
        show = sdif | less
        diff = sdif | less
~/.cdifrc
    option default --mecab
```

These are the user's settings: suggest them, do not write them.  To
see a diff this way once, pipe it: `git diff | sdif`, `git log -p |
cdif`.

## watchdiff

```sh
watchdiff -i 5 -- git status --short       # every 5 seconds
watchdiff -s -- df -h                      # -s: print only when it changed
```

It clears the screen and redraws by default; `-p --no-clear` prints
each result in turn instead.  `--unit` is passed on to cdif.

## Verify

```sh
printf 'a b c\n' > /tmp/o; printf 'a x c\n' > /tmp/n
diff /tmp/o /tmp/n | cdif --cm 'OCHANGE=sub{"[-$_-]"}' --cm 'NCHANGE=sub{"{+$_+}"}' | perl -pe 's/\e\[[\d;]*[mK]//g'
#   1c1
#   < a [-b-] c
#   ---
#   > a {+x+} c
sdif -W 80 /tmp/o /tmp/n | head -3
```
