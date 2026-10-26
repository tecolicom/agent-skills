# tecolicom agent-skills

[Agent Skills](https://agentskills.io) for tecolicom command-line tools.
Skills teach coding agents (Claude Code, Gemini CLI, GitHub Copilot,
Cursor, OpenCode, and other Agent Skills-compatible tools) when and how
to use these tools effectively.

## Available skills

| Skill | Tool | What it teaches |
|-------|------|-----------------|
| [greple](skills/greple/SKILL.md) | [App::Greple](https://github.com/kaz-utashiro/greple) | Block-oriented search: AND search within functions/paragraphs, whole-block output, region-restricted search, cross-line phrase search |
| [textconv](skills/textconv/SKILL.md) | [App::optex::textconv](https://github.com/kaz-utashiro/optex-textconv) | Let any command (cat, grep, diff, greple) read PDF, Office documents, and git objects as text |
| [dozo](skills/dozo/SKILL.md) | [App::dozo](https://github.com/tecolicom/App-dozo) | Run commands inside the Docker image a project expects, with the repository mounted and paths preserved |
| [side-by-side](skills/side-by-side/SKILL.md) | [App::ansicolumn](https://github.com/tecolicom/ANSI-Tools), [App::mdee](https://github.com/tecolicom/App-mdee), [App::sdif](https://github.com/kaz-utashiro/sdif-tools) | Show two texts next to each other (original/translation, two versions): ansicolumn -V, mdee -V, sdif -V on conflict markers, cdif --lxl on line pairs, plain text in any agent's reply, or in color inside a Claude Code reply via a MessageDisplay hook |

Each skill assumes the corresponding tool is installed, via CPAN or
Homebrew:

```sh
cpanm -n App::Greple                     # CPAN
brew install tecolicom/tap/app-greple    # Homebrew

cpanm -n App::optex App::optex::textconv          # CPAN
brew install tecolicom/tap/app-optex-textconv     # Homebrew

cpanm -n App::dozo                       # CPAN (also needs Docker)
brew install tecolicom/tap/app-dozo      # Homebrew

cpanm -n App::ansicolumn App::mdee App::sdif                      # CPAN
brew install tecolicom/tap/app-ansi-tools tecolicom/tap/app-mdee tecolicom/tap/app-sdif   # Homebrew
```

## Installation

### Claude Code

Add this repository as a plugin marketplace, then install skills as
plugins:

```
/plugin marketplace add tecolicom/agent-skills
/plugin install greple@tecolicom
```

### Other Agent Skills-compatible tools

The `SKILL.md` files follow the [Agent Skills](https://agentskills.io)
open standard and contain no Claude-specific extensions.  (The
side-by-side skill has one section on a Claude Code display hook; its
other methods work with any agent.)  Copy the skill directory into
your tool's skills location, for example:

```sh
# location varies by tool; see your tool's documentation
cp -r skills/greple ~/.config/<your-tool>/skills/
```

Consult your tool's documentation for the exact skills directory:
Gemini CLI, GitHub Copilot, Cursor, JetBrains Junie, OpenCode,
OpenHands, and others support the format.

## Design policy

Recipes are selected by what they add to an agent's own abilities:

- **Include** features that let an agent do what it cannot do by
  itself: block-oriented search, region-restricted matching,
  invisible-character detection, reading Office files
- **Include** features that collapse many search-and-read round-trips
  into one command: co-occurrence (AND) search, printing the whole
  function or section containing a match
- **Include** interfaces that are tedious for humans but natural for
  agents, such as inline Perl functions (`--cm 'sub{...}'`,
  `--callback`) and machine-readable output — agents generate these
  without friction
- **Include** features that protect the agent's context, such as
  excluding minified and generated files from search results — a
  single matching line of minified CSS floods the output with
  thousands of useless characters
- **Include** layout that the agent cannot produce correctly by
  itself when a person has to read the result, such as two texts
  side by side with CJK-aware folding — `column`, `paste` and
  `fold -s` break only at spaces and misalign anything else

Three kinds of features are deliberately left out:

- **Duplicating the model's own abilities** — translation modules that
  call an LLM backend, for instance.  An agent translates natively
- **Saving human keystrokes** — command aliases and colorized echo.
  Typing effort and on-screen appearance are human concerns; an agent
  is better served by the explicit, environment-independent form
- **Duplicating the agent's existing tools** — selecting text by line
  number, which file-reading tools already do.  Line numbers are a
  volatile reference anyway; agents locate code by content, not by
  position

Every recipe in these skills is verified against the actual tools
before being documented.

## License

MIT
