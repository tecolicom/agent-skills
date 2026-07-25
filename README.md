# tecolicom agent-skills

[Agent Skills](https://agentskills.io) for tecolicom command-line tools.
Skills teach coding agents (Claude Code, Gemini CLI, GitHub Copilot,
Cursor, OpenCode, and other Agent Skills-compatible tools) when and how
to use these tools effectively.

## Available skills

| Skill | Tool | What it teaches |
|-------|------|-----------------|
| [greple](skills/greple/SKILL.md) | [App::Greple](https://github.com/kaz-utashiro/greple) | Block-oriented search: AND search within functions/paragraphs, whole-block output, region-restricted search, cross-line phrase search |

Each skill assumes the corresponding tool is installed, via CPAN or
Homebrew:

```sh
cpanm App::Greple                        # CPAN
brew install tecolicom/tap/app-greple    # Homebrew
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

## License

MIT
