# Quarantined v1/v2 source

Directive **D1**: *"flag all previous code we had as BAD CODE."*

**Nothing in this tree may be imported, extended, or copied into `packages/` or
`apps/`.** `tools/lint` rule `NO-LEGACY-IMPORT` fails the build on any attempt,
and this directory is excluded from the analyzer.

One honest qualification, because a false verdict is as useless as no verdict:
this is not incompetent code. It is prototype-grade code with an unusually good
privacy model, written to prove a different product. It goes because it encodes
the wrong domain and because its structure makes the v3 requirements —
testability, algorithm reuse, config-driven behaviour — unreachable without
rewriting the same files anyway.

The file-by-file verdicts, and the nine ideas that genuinely carry forward, are in
[`docs/v3/LEGACY_AUDIT.md`](../docs/v3/LEGACY_AUDIT.md).

**Deleted at P2 exit.** If nothing here has been needed by then, nothing will be,
and a dead tree is a tax on every search and every future contributor's mental
model.
