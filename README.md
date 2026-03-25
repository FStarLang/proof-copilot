# fstar-copilot

A [GitHub Copilot CLI](https://docs.github.com/copilot/concepts/agents/about-copilot-cli) plugin for [F*](https://fstar-lang.org) proof-oriented programming.

## What's Included

### Agents

| Agent | Description |
|-------|-------------|
| **fstar-coder** | An expert F* programmer that authors formal specifications, implements solutions, and proves correctness — all verified with `fstar.exe`. |

### Skills

| Skill | Description |
|-------|-------------|
| **smtprofiling** | Debug F* queries sent to Z3, diagnosing proof instability and performance issues. Covers `.smt2` extraction, quantifier profiling, cascade detection, and systematic performance tuning. |

## Prerequisites

- **F\*** — Install from [fstar-lang.org](https://fstar-lang.org) or build from source. `fstar.exe` must be available on your PATH or configured via `FStar.fst.config.json` in your project.
- **Z3** — The SMT solver used by F*. Typically installed alongside F*.
- **GitHub Copilot CLI** — Install from [github.com/github/copilot-cli](https://github.com/github/copilot-cli).

## Installation

```bash
copilot plugin install FStarLang/fstar-copilot
```

## Usage

### Using the FStarCoder agent

You can invoke the agent in several ways:

1. **Via the `/agent` command** — type `/agent` in an interactive session and select `fstar-coder`.

2. **Naturally in a prompt** — mention the agent by name:
   ```
   Use the fstar-coder agent to implement a verified binary search
   ```

3. **Via command line**:
   ```bash
   copilot --agent=fstar-coder --prompt "Implement a verified binary search over a sorted sequence"
   ```

### Using the smtprofiling skill

The smtprofiling skill is automatically available when proof performance issues arise. You can also invoke it directly:

```
Use the smtprofiling skill to diagnose why this proof is slow
```

## Roadmap

Future versions will add:
- **PulseCoder** agent for concurrent separation logic programming
- **fstarverifier** skill for general F* verification workflows
- **pulseverifier** skill for Pulse-specific verification
- **fstarmcp** skill with MCP server integration for incremental typechecking

## License

Apache 2.0 — see [LICENSE](LICENSE).
