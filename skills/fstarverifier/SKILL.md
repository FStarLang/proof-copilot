---
name: fstarverifier
description: Verify F* code with fstar.exe and interpret errors
---

## Invocation

This skill is used when:
- Verifying F* (.fst) or interface (.fsti) files
- Interpreting F* error messages
- Debugging verification failures

## Verification Commands

```bash
# Verify a single file (stage3 fstar.exe includes Pulse support)
fstar.exe Module.fst

# With project include paths and caching
fstar.exe --cache_checked_modules --cache_dir _cache \
  --already_cached Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore \
  --include path/to/spec --include path/to/impl \
  Module.fst

# Verify interface first, then implementation (always in this order)
fstar.exe Module.fsti
fstar.exe Module.fst
```

### Diagnostic Flags

| Flag | Purpose |
|------|---------|
| `--query_stats` | Show per-query timing and success/failure |
| `--split_queries always` | Send each assertion as a separate Z3 query |
| `--log_queries` | Write `.smt2` files for Z3 query inspection |
| `--z3refresh` | Restart Z3 between queries (detect flaky proofs) |
| `--print_full_names` | Show fully qualified names (catch symbol confusion) |
| `--print_implicits` | Show implicit arguments (debug unification) |
| `--detail_errors` | More precise error locations |

```bash
# Combined debugging
fstar.exe --query_stats --split_queries always --z3refresh Module.fst
```

### Resource Limit Options (in-file)

```fstar
#push-options "--z3rlimit 10"        // SMT timeout (target ≤ 10)
#push-options "--fuel 1 --ifuel 1"   // Recursion unfolding depth
#push-options "--z3rlimit 10 --fuel 0 --ifuel 0"  // Tight: no unfolding
```

## Error Interpretation

### "Could not prove post-condition"

**Cause:** SMT cannot establish the postcondition from available facts.

**Solutions:**
1. Add intermediate `assert` statements to locate the gap
2. Call relevant lemmas explicitly
3. Use `Seq.equal` / `Set.equal` for collection equality (not `==`)
4. Call `FS.all_finite_set_facts_lemma()` before FiniteSet reasoning
5. Check that the right definitions are in scope (`--print_full_names`)

### "Identifier not found: X"

**Cause:** Symbol not in scope.

**Solutions:**
1. Check `open` declarations and `module X = ...` aliases
2. F* is order-sensitive — definitions must precede their use
3. Check for typos; use `--print_full_names` on a working reference

### "rlimit exhausted" / "Query cancelled"

**Cause:** Proof too complex for SMT within the time limit.

**Solutions:**
1. Factor proof into smaller lemmas (most effective)
2. Add intermediate assertions as stepping stones
3. Reduce fuel: `--fuel 0 --ifuel 0`
4. Add explicit type annotations
5. Use `{:pattern ...}` on quantifiers for controlled instantiation
6. Make definitions `[@@"opaque_to_smt"]` and `reveal_opaque` manually

**Do not** just increase rlimit — find the root cause instead.

### "Expected type X, got type Y"

**Cause:** Type mismatch, often involving refinements.

**Solutions:**
1. Add explicit type annotations: `(x <: refined_type)`
2. Check refinement predicates match
3. For machine integers, ensure bounds are established

### "Subtyping check failed"

**Cause:** Cannot prove a refinement type's predicate.

**Solutions:**
1. Add an `assert` establishing the predicate just before the problematic expression
2. Call a lemma that establishes the needed fact
3. Check that arithmetic bounds are in scope

### "Not a subtype of the expected type"

**Cause:** Return value doesn't match declared return type refinement.

**Solutions:**
1. Add assertions establishing the ensures clause
2. Check all branches of match/if return the correct type
3. For Lemma types, ensure the postcondition is provable

### "Patterns are incomplete"

**Cause:** Match expression doesn't cover all cases.

**Solutions:**
1. Add missing cases
2. If intentional, add a wildcard `| _ -> ...` with the right type
3. Suppress with `--warn_error -321` only if you've verified completeness

## Verification Strategy

### For New Code
1. Write the `.fsti` interface first with full pre/post conditions
2. Verify the `.fsti`
3. Implement the `.fst` with `admit()` placeholders to validate structure
4. Remove admits one at a time, adding lemmas as needed
5. Reduce rlimits and harden

### For Failing Proofs
1. Run with `--query_stats` to find slow/cancelled queries
2. Use `--split_queries always` to isolate which assertion fails
3. Add `assert` statements to binary-search the failure point
4. Factor the failing part into a separate lemma
5. If the lemma fails, simplify to a minimal reproducer

### For Flaky Proofs
1. Run with `--z3refresh` to detect order-dependent proofs
2. Reduce rlimit to 10 — if it fails, the proof needs work
3. Avoid relying on Z3's internal heuristic ordering
4. Add explicit intermediate assertions to guide Z3

## Additional Resources

- [Proof-oriented Programming in F*](https://github.com/FStarLang/PoP-in-FStar) — book with patterns and explanations
- `FSTAR_HOME/ulib/` — standard library sources
- `FSTAR_HOME/tests/` — test suite with small verification examples
- See the `proofdebugging` skill for systematic debugging workflows
