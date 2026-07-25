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

Each skill assumes the corresponding tool is installed, via CPAN or
Homebrew:

```sh
cpanm -n App::Greple                     # CPAN
brew install tecolicom/tap/app-greple    # Homebrew

cpanm -n App::optex App::optex::textconv          # CPAN
brew install tecolicom/tap/app-optex-textconv     # Homebrew
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
open standard and contain no Claude-specific extensions.  Copy the
skill directory into your tool's skills location, for example:

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
- **Exclude** features that duplicate what an LLM agent already does
  natively (e.g. translation modules that call an LLM backend)

Every recipe in these skills is verified against the actual tools
before being documented.

## License

MIT
