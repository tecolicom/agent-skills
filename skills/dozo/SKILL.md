---
name: dozo
description: Use when a project expects its commands to run inside a specific Docker image rather than on the host - typically signalled by a .dozorc file in the repository. Runs any command in the project's designated container with the repository mounted and the working directory preserved, so builds, tests, and tools behave as the project intends.
---

# dozo — run commands in the project's Docker environment

Some projects are meant to be built and tested inside a particular
Docker image, not on the host.  `dozo` runs a command in that image
with the repository mounted and the relative working directory
preserved, so paths behave exactly as they do on the host.

## When to use

- A `.dozorc` file exists in the repository (or its git top directory)
  — that file *is* the declaration that this project runs in a
  container, and it names the image
- The project documents a Docker image for builds or tests
- You need to run something under a different toolchain version than
  the host provides (for example, reproducing behavior under another
  Perl or Python release)

If the project has no such expectation, run commands on the host as
usual.  This skill is not about sandboxing.

## Prerequisites

- `dozo --version`, plus a working Docker daemon
- Install: `cpanm -n App::dozo` or `brew install tecolicom/tap/app-dozo`

## Usage

**Always pass `-B` (batch mode).**  Without it, dozo may allocate a
terminal and wait for input.  Add `-q` to suppress dozo's own
progress messages:

```sh
dozo -B -q COMMAND [args...]          # image comes from .dozorc
dozo -B -q -I IMAGE COMMAND [args...] # or name the image explicitly
```

Check what would run without running it:

```sh
dozo -B -n            # dry run: prints the full docker command and the mounts
```

## What dozo sets up

- **In a git repository, the git top directory is mounted** as `/work`
  and the working directory inside the container mirrors your position
  in the tree, so relative paths in commands keep working.  Outside a
  git repository, the current directory itself is mounted as `/work`
- Run `dozo -B -n` first if the mount point matters: it prints which
  host directory is mounted and what the container working directory
  will be
- Common environment variables are inherited: `LANG`, `TZ`, proxy
  settings, terminal settings
- `--rm` is used, so containers do not accumulate

## Caveats

- **API keys are inherited automatically** — `ANTHROPIC_API_KEY`,
  `OPENAI_API_KEY`, `DEEPL_AUTH_KEY` and similar variables are passed
  into the container.  Verify the image is trusted before running it,
  and use `dozo -B -n` to see exactly what gets passed
- The mount is read-write by default, so commands can modify the
  repository.  `-R` mounts read-only when a command should not write
- `-L` keeps a persistent container between invocations (useful when
  packages installed inside must survive), but such containers stay
  around until removed with `-K`
