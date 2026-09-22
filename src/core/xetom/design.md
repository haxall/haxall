<!--
author:     Brian Frank
created:    21 Sep 2026
copyright:  Copyright (c) 2026, SkyFoundry LLC, All Rights Reserved
-->

# xetom Design

The xetom pod is the Xeto runtime implementation: namespaces, specs,
instances, and the services over them.

# Validation

See [Validation](hx.doc.haxall::Validation) for what rules are and how to
write them.  This covers only how the engine is put together.

Files in `fan/validate/`:

- `Validator`: the walk, and the intrinsic checks it performs itself
- `ValidateState`: position in the walk; what a rule sees
- `ValidateRule`: one rule instance, and the factory which binds it
- `ValidateRules`: the namespace's rules ordered for `unless`
- `ValidateSysRules`: one class per sys rule
- `ValidateFuncRule`: rule implemented by a xeto func
- `MValidateItem`: reported item; renders msg from the rule and args

## Dispatch

`Validator.run` fires rules at every frame of the walk: the subject, each
slot, each list item.  `ValidateRules.eachApplicable` scans all the rules
and skips the ones whose `on` types do not match the position.

The scan is linear on purpose.  With a few hundred rules the isa tests
cost less than keeping an index, and registry order is also dispatch
order, which is what makes `unless` work without a merge step.

`on` is a MultiRef because some rules cover types with no common base:
`Ref` and `MultiRef` are both sealed, and the size rules take a `Scalar`
or a `List`.

A rule narrows again in its own check.  `overMaxVal` is registered on
`Number` and returns if the spec has no `maxVal`.  The `on` target is the
type test, the check body is the constraint test.

## Bindings

The implementation names the rule, never the other way around.  A Fantom
class is named for its rule, and a func tags itself `validateRule`.

This is not just symmetry.  An instance pointing at its func would need a
ref to a func slot, and xetoc rejects dotted refs in instance data.  A
func naming its rule is a plain instance ref which resolves today.

`ValidateRule.create` maps a rule's lib to its pod through `SpecBindings`
and reflects the class.  sys maps to xetom itself since sys registers its
bindings directly instead of through the `xeto.bindings` index.

An unimplemented rule becomes a `ValidateUnboundRule` so it stays in the
registry.  Func rules return from `onCheck` when there is no
`XetoContext`, which is how lib compiles skip them.

## Unknown Tags

The walk checks a dict tag with no declared slot or member two ways:
ref values get their targets resolved and checked, and Scalar wrappers
and spec tagged dicts are validated against the spec they name for
themselves - a value that declares its own type must satisfy it.  Other
unknown tag values are untyped data and pass.  A tag-less dict value is accepted against a
declared dict type and walked structurally; against any other type it
is an invalid type.

## Reporting Position

An item takes its slot path, value, and spec from the frame it is emitted
at, so `$val` and the other message variables always describe what the
item points at.

`emit` reports at the current frame.  `emitOn` pushes a frame for a tag
of the current dict, reports there, and pops.  It reuses the same frame
the walk itself pushes, which is why the message variables come out right
with no special handling.

## Compile Time

The same engine runs inside the xetoc pipeline: the `Validate` step runs
after `Assemble`, when instances and specs are their real
implementations.  Items route into the compiler err/warn streams as
they emit via the `Validator.onEmit` hook, with locs refined by walking
the item's slot path back thru the AST.
`CheckErrors` keeps only the checks with no runtime analog: AST
shape (names, inheritance, covariance, member structure), named list
items (names do not survive reification), and the spec meta value path,
which stays on `CheckVal` until the old Fitter engine retires.

Data compiles validate the root asm value directly - the engine walks
dicts, lists, and scalars just like at runtime.  A Grid has no instance
level checks: rows are columnar and carry no spec tags, so the col 'of'
versus declared row member conflict is reported by InferData, where the
AST typing lives.

Rules come only from the dependency chain: `ValidateRules.makeLibs`
builds the registry from the compile's depends, so a lib's own rules
never run on its own instances at compile time - they first apply at
runtime once the lib loads into a full namespace.  This scoping is also
what makes compile time work at all: the namespace is still under
construction during lib compiles (`MNamespace` compiles libs from its
own constructor), so compile-time code may point-lookup loaded libs thru
the namespace but must never enumerate it.  The step skips entirely when
sys is not in the depends, which is only the sys bootstrap itself.

`xetoc::CompileValidator` overrides the engine's resolution hooks
(`resolveSpec`, `resolveInstance`, `specOf`, `specx`, `cns`) to overlay
the lib under compile, which is not in the namespace yet.  It is its own
`CNamespace` because choice subtype discovery must enumerate the
assembled own lib - `ANamespace` cannot be reused there since its AST
tops never `isa` an assembled spec.  Two opts keep parity with the old
CheckErrors behavior: `ignoreUnresolvedRefs` (Resolve already settled
existence, so what does not resolve here is an extern) and
`ignoreMissingSlots` (instances inherit from their spec).

## Intrinsics

Five rules are emitted by `Validator` directly instead of being
dispatched: `missingSpecRef`, `unknownSpecRef`, `missingSlot`,
`unknownType`, `invalidType`.  They run in order before any other rule
because they gate the walk - there is no point reporting a `maxVal`
problem on a value which is not even a number.
`ValidateIntrinsicRule.isApplicable` is always false so normal dispatch
passes them over.
