---
name: pulseverifier
description: Verify Pulse separation logic code and interpret errors
---

## Invocation

This skill is used when:
- Verifying Pulse files (`#lang-pulse` directive)
- Debugging separation logic proof failures
- Managing resources (fold/unfold, permissions, memory)

## Verification Commands

With fstar2 stage3, Pulse support is built into `fstar.exe` — no `--ext pulse` needed.

```bash
# Verify a Pulse file
fstar.exe Module.fst

# With project paths
fstar.exe --cache_checked_modules --cache_dir _cache \
  --already_cached Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore \
  --include path/to/spec --include path/to/impl \
  Module.fst
```

Always verify `.fsti` before `.fst`.

## Pulse File Structure

```fstar
module MyModule
#lang-pulse
open Pulse.Lib.Pervasives

// Pure specs (available to Pulse code)
let my_spec (x: int) : int = x + 1

// Pulse function
fn my_fn (r: ref int) (#v: erased int)
requires r |-> v
returns res: int
ensures r |-> (v + 1) ** pure (res == my_spec v)
{
  let x = !r;
  r := x + 1;
  x + 1
}
```

## Pulse-Specific Errors

### "Application of stateful computation cannot have ghost effect"

**Cause:** Calling a stateful (`stt`) function inside a ghost context.

**How this happens:**
- Variables bound with `with x y. _` are ghost
- If an `if` condition depends on ghost values, both branches become ghost
- Stateful operations (read, write, array access) cannot be ghost

**Solutions:**
1. Read from actual data structures, not ghost witnesses:
```pulse
// WRONG: ghost_seq is ghost from 'with'
let val = Seq.index ghost_seq idx;
let data = !some_ref;  // Error: ghost context

// RIGHT: Read from the actual array
let val = arr.(idx);   // Concrete
```

2. Perform stateful work before entering ghost conditionals

3. Restructure to separate the stateful read from the ghost reasoning

### "Expected a term with non-informative (erased) type"

**Cause:** Trying to bind a concrete type from a ghost expression.

**Solutions:**
1. Keep ghost values ghost: `let x : erased (list entry) = ...`
2. Use assertions instead of bindings: `assert (pure (Cons? ghost_list))`
3. Read concrete data from actual data structures, not ghost state

### "Could not prove post-condition" (separation logic)

**Cause:** Resources don't match the expected slprop.

**Diagnosis:**
1. Check fold/unfold balance — every `unfold` needs a matching `fold`
2. Verify `rewrite` statements are correct
3. Ensure all resources are accounted for (nothing leaked or extra)

**Solutions:**
1. Add explicit fold/unfold:
```pulse
unfold (my_pred args);
// ... work with exposed resources ...
fold (my_pred args);
```

2. Use rewrite for type-level equality:
```pulse
rewrite (pred x) as (pred y);  // when x == y is provable
```

3. For range predicates:
```pulse
// Extract element from range
get_at ptrs contents lo hi idx;
// ... work with element ...
put_at ptrs contents lo hi idx;  // Restore range
```

### "Ill-typed application" in fold/unfold

**Cause:** Predicate arguments don't match the definition.

**Solutions:**
1. Check all arguments match the predicate signature
2. Add explicit type annotations to implicit arguments
3. Verify the predicate definition hasn't changed

### "Cannot prove pure fact"

**Cause:** A `pure (...)` assertion in the slprop cannot be established.

**Solutions:**
1. Add intermediate `assert (pure (...))` steps
2. Call F* lemmas to establish the needed fact
3. Check arithmetic bounds and machine integer properties

## Resource Management

### Fold/Unfold Balance

Every predicate manipulation must be balanced:

```pulse
// Unfold to access internals
unfold (is_valid table spec);

// Now individual fields are accessible as slprops
// ... work with them ...

// Fold to restore the abstraction
fold (is_valid table spec);
```

### Memory Safety Rules

- **Never `drop_` non-empty resources** — this is a memory leak
- **Acceptable drops**: Empty/null/ghost resources only
  ```pulse
  drop_ (LL.is_list null_ptr []);  // OK: empty list is null
  // drop_ (LL.is_list ptr (hd::tl));  // WRONG: memory leak!
  ```
- **Box allocations** need `B.free`: `let b = B.alloc v; ... B.free b`
- **Array resources** must be returned or freed

### Permission Tracking

```pulse
// Full permission: can read and write
arr |-> contents            // shorthand for #full_perm

// Fractional permission: read-only
A.pts_to arr #p contents   // p is a fraction, can only read

// Split/join permissions as needed in concurrent code
```

## Common Proof Patterns

### FiniteSet Reasoning
```pulse
// MUST call before FiniteSet assertions
FS.all_finite_set_facts_lemma();
assert (pure (FS.cardinality (FS.remove x s) == FS.cardinality s - 1));
```

### Extensional Equality
```pulse
assert (pure (Seq.equal s1 s2));  // NOT: s1 == s2
```

### Machine Integer Bounds
```pulse
// Establish bounds through an invariant chain
assert (pure (SZ.v idx < len));
assert (pure (len <= SZ.v capacity));
assert (pure (SZ.fits (SZ.v capacity)));
assert (pure (SZ.fits (SZ.v idx + 1)));  // Therefore idx+1 fits
let next = idx `SZ.add` 1sz;
```

### Calling F* Lemmas from Pulse
```pulse
// Just call them — they're ghost and cost nothing at runtime
my_arithmetic_lemma arg1 arg2;
assert (pure (conclusion_of_lemma));
```

### Loop Invariants
```pulse
while (!i <^ len)
invariant exists* vi v_acc.
  R.pts_to i vi **
  R.pts_to acc v_acc **
  A.pts_to arr #p s **
  pure (
    SZ.v vi <= Seq.length s /\
    v_acc == compute_partial s (SZ.v vi)
  )
{
  // loop body
}
```

**Do NOT use `invariant b. exists* ...`** style.

## Verification Checklist

Before considering Pulse code complete:
- [ ] No `admit()` calls
- [ ] No `assume_` calls
- [ ] No `drop_` of non-empty resources
- [ ] Interface (.fsti) verified before implementation (.fst)
- [ ] All fold/unfold balanced
- [ ] rlimits ≤ 10 throughout
- [ ] `--query_stats` shows no cancelled queries

## Additional Resources

- `FSTAR_HOME/pulse/test/` — Pulse test cases and examples
- `FSTAR_HOME/pulse/lib/pulse/lib/` — Pulse library sources
- See the `fstarverifier` skill for general F* error interpretation
- See the `proofdebugging` skill for systematic debugging workflows
