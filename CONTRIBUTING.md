# Contributing

Thanks for helping with SpaceVibe. The code is [GPL-3.0-only](LICENSE); the SpaceVibe name and icon
are covered by the [trademark policy](TRADEMARK.md). By opening a pull request you agree that your
contribution is licensed under the same terms.

SpaceVibe is pre-release and built by one maintainer. Before a large change, open an issue or a
discussion first: the interface follows recorded decisions ([docs map](docs/README.md)), and a pull
request that goes against one cannot be merged however good the code is.

## Set up

macOS 15 or later, the Xcode Command Line Tools (Xcode itself is not needed) and Go 1.26.

```bash
scripts/test.sh     # Go tests, then Swift tests, all against temporary folders
scripts/dev.sh      # build, sign and relaunch the app
```

`scripts/dev.sh` reads your real `~/.claude` and `~/.codex`. To try a change that writes, point the
app at a temporary folder first: set `HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and `SPACEVIBE_HOME`.
Every other command is in [AGENTS.md](AGENTS.md).

## Rules that a pull request must keep

They are stated in full in [AGENTS.md](AGENTS.md); these are the ones contributors meet first.

- **Use `scripts/test.sh`, never bare `swift test`** (B2). The output must show
  `Test run with N tests ... passed` with N above 0.
- **Tests never touch a real configuration** (S-R1). Go tests use `t.TempDir()` or the fixture
  home; Swift tests use `CoreFixtureHome`.
- **No real data in a commit** (S-R2): no real skill, project, user or path names in fixtures,
  goldens, screenshots or docs. Fixtures come from `scripts/fixture-home.mjs`.
- **The app executes nothing and calls nothing** (S-R4, S-R5): no new process, signal, listener or
  network request.
- **Screens compose shared components and tokens.** A font, colour, radius or spacing literal in a
  screen folder fails [`StyleBoundaryTests`](Tests/SpaceVibeTests/StyleBoundaryTests.swift); the
  rules are in the [design language](docs/DESIGN-LANGUAGE.md).
- **Words have one meaning.** Labels, comments and docs use the terms in [GLOSSARY.md](GLOSSARY.md).
- **A change to documented behavior updates its page in the same pull request.** The
  [docs map](docs/README.md) names the one current document per topic.

Code, comments and tests are English.

## Commits and pull requests

- Write commit messages, pull request titles and bodies, and issues in English (B11). The
  [`english`](.github/workflows/english.yml) check fails a pull request whose title, body or commits
  are not; turn on the local hook once with `git config core.hooksPath scripts/git-hooks` to catch it
  before you push.
- [Conventional Commits](https://www.conventionalcommits.org) with a scope:
  `fix(core): skip a rollout that cannot be read`. One commit is one complete piece of work.
- One concern per pull request. Say what changed and why, and paste the test output.
- A change to the interface includes a before and an after screenshot taken on the fixture home,
  never on a real configuration.

## Reporting

- A bug or an idea: [open an issue](https://github.com/mxrsv/spacevibe/issues/new/choose).
- A question: [Discussions](https://github.com/mxrsv/spacevibe/discussions).
- A security problem: privately, as the [security policy](SECURITY.md) describes.
