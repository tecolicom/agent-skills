---
name: textconv
description: Use when a document file cannot be read or searched as text - PDF, Microsoft Office files (docx/xlsx/pptx), or git objects like HEAD^:file. Lets ANY command (cat, grep, diff, wc, greple) operate on these files by transparently replacing them with their text content. Especially useful for diffing two Office documents or PDFs, which is otherwise impossible.
---

# textconv — read any document with any command

`optex -Mtextconv` (`-Mtc` for short) replaces document file names with
their extracted text before the command sees them.  The original file
is never modified.  This turns ordinary text tools into document tools.

## When to use

- **Reading Office files** (docx/xlsx/pptx) — most agent file readers
  cannot open these at all
- **Diffing documents** — `diff` between two `.docx` or two `.pdf`
  files, which is otherwise impossible
- **Searching inside documents** — grep or greple over PDFs and Office
  files
- **git objects** — treat `HEAD^:path/to/file` as a file for any
  command, not just `git show`

## Prerequisites

- Check with `optex --version`.  Install both the base command and the
  module:

```sh
cpanm -n App::optex App::optex::textconv          # CPAN
brew install tecolicom/tap/app-optex-textconv     # Homebrew (pulls in app-optex)
```

- PDF support requires `pdftotext` (poppler); Office XML formats work
  with the built-in converter, no external tool needed

## Usage

`-Mtc` goes **before** the command name:

```sh
optex -Mtc COMMAND [args...] FILE
```

Within one shell session, a helper function shortens this (a shell
alias in `~/.bashrc` does not apply to non-interactive commands, so
define a function instead):

```sh
tc() { optex -Mtc "$@"; }
tc cat report.pdf
```

## Recipes (all verified)

### Read a document as text

```sh
optex -Mtc cat report.pdf        # PDF to text
optex -Mtc cat notes.docx        # Word/Excel/PowerPoint to text
```

### Diff two documents

```sh
optex -Mtc diff OLD.docx NEW.docx      # what changed between two Word files
optex -Mtc diff OLD.pdf NEW.pdf
```

This is the strongest reason to use textconv: comparing two binary
documents is not something an agent can do on its own.

### Search inside documents

```sh
optex -Mtc grep -i keyword report.pdf
optex -Mtc greple -p -e WORD1 -e WORD2 report.pdf   # full greple power on a PDF
```

Combining with greple gives block-oriented search (paragraph-level AND
search, whole-section output) over PDF and Office files.  See the
`greple` skill for those patterns.  Note `optex -Mtc greple`, not
`optex greple -Mtc` — in the latter position `-M` is consumed by greple
itself.

### Treat git objects as files

```sh
optex -Mtc cat 'HEAD^:README.md'
optex -Mtc diff 'HEAD^:CLAUDE.md' 'HEAD:CLAUDE.md'
```

Works with any command, not only `git show`.  Must be run inside the
repository.

## Caveats

- **File names are replaced by `/dev/fd/N`** in command output.  With
  multiple files, `grep` prefixes lines with `/dev/fd/3` instead of the
  real name, and `grep -l` is useless.  Process one file at a time when
  the file name matters
- Files with no converter (plain text, source code) pass through
  untouched, so mixing them with documents is safe
- Extracted text is a plain-text approximation: tables, layout, and
  formatting are flattened
