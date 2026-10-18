# Built by an LLM, deliberately and in the open

The fork's additions to this repository (specs, nix flake, gate, fork
tests, fixtures' notes, these pages and the carried fixes in `Sources/`)
were written by [Claude Code](https://claude.com/claude-code) running
Anthropic's **Claude Opus 5.5**. The upstream code the fork is built on
was not; [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) says where it
comes from. Commit provenance is part of the record and can be inspected
with `git log`; a human owns every decision, reviews every pull request,
and is accountable for what ships.

That is the disclaimer. The rest of this file is why it is a design note
rather than an apology, and what you can check for yourself.

## Why say it at all

An LLM writes plausible code, and plausible is not correct. A reader who
does not know how a repository was produced cannot calibrate how hard to
look at it. This plugin keeps an age identity in the Secure Enclave, so
the bar is higher than usual: the fork must not change a byte of the
formats, and must not rewrite the crypto.

## The method is spec-driven development

[`SPEC.md`](../SPEC.md) and one `SPEC.md` per node (`Sources/`, `Tests/`,
`fixtures/`, `nix/`) are the law, not a description written afterwards.
They carry `§V` invariants (what must stay true), `§T` tasks (what is
decided and what is not), `§B` bugs (each paired with the invariant that
now catches it) and `§R` research (the measurements the constraints rest
on). Their format and federation are checked by the gate, so "the spec
says so" is a statement about a file that was parsed, not one that was
skimmed.

## The guardrails are git hooks that also run on CI

Entering the dev shell (`nix develop`) points git at the tracked hooks,
which run [hk](https://github.com/jdx/hk) against one definition of the
gate in [`hk.pkl`](../hk.pkl). The fork CI,
[`ci.yml`](../.github/workflows/ci.yml), runs that same definition on a
macOS runner, so a laptop and a runner cannot disagree. The build treats
warnings as errors, upstream's tests run as upstream wrote them, and line
coverage has a floor in [`.coverage`](../.coverage) that may only rise.

## What a reader should check

1. **Does the gate run for you?** `nix develop`, then `hk check --all`.
   If a claim here is false, that is where it shows.
2. **Are the formats still upstream's?** `fixtures/` holds identities,
   recipients and sessions made by upstream binaries; the fork's tests
   read them.
3. **Does `§B` look like a real bug log or a curated one?** It records
   the upstream bugs found while the fork was built, each with the
   invariant that now catches it.
4. **Is `§R` checkable?** Several rows say how to recount them; the rest
   cite a file or a probe.

## Why there are no counts here

Sibling projects print how many invariants, bugs and gate steps they
hold, generated from the specs and `hk.pkl` so the numbers cannot drift.
This repository has no generator for them yet, so this page names none
rather than quote numbers that would go stale.

## Accountability

The fork's maintainer, named in [`LICENSE.txt`](../LICENSE.txt), is
responsible for the fork's code, including the parts a model wrote and
the parts nobody caught. "The LLM wrote it" explains provenance; it never
transfers responsibility.
