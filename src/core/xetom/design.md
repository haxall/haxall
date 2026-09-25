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
are validated against the spec they name for themselves - a value that
declares its own type must satisfy it.  Dicts under unknown tags are
open content and pass: running entity rules on such fragments would be
far stricter than a self consistency check.  Other unknown tag values
are untyped data and pass.  A tag-less dict value is accepted against a
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

Items point at what is wrong, never at where the rule happened to run.
A missing tag reports on that tag, and the query rules report on the
unsatisfied constraint (`points.zoneTemp`, or `points._0` when auto
named) via `emitOn` from the query frame, where the name is a member of
the query spec and the value is null.  So a tool can show each required
point on its own without parsing messages.  The name is the
constraint's **key in the query**, never `constraint.name`: merging a
base query renumbers auto named slots, so a subtype's own `_0` may be
keyed `_2` while its name stays `_0` and collides with the base's.

## Query Anchors

`doValidateQuery` partitions the extent before matching.  A rec whose
spec tag resolves to a constraint of the query, or to an override of
one up its base chain, is anchored - by the constraint's key, found
thru its qname - and matches that constraint alone;
the rest are free and match the constraints with no anchored rec
structurally.  The anchor test compares qnames, never `isa`: query
items are anonymous sugar, so siblings with equal tags are computed
subtypes of each other and `isa` would bind a rec to all of them.
This is what makes validation agree with graph compose, which stamps
the template slot qname as the spec tag.

## Compile Time

The same engine runs inside the xetoc pipeline: the `Validate` step runs
after `Assemble`, when instances and specs are their real
implementations.  Items route into the compiler err/warn streams as
they emit via the `Validator.onEmit` hook, with locs refined by walking
the item's slot path back thru the AST.
`CheckErrors` keeps only the checks with no runtime analog: AST
shape (names, inheritance, covariance, member structure) and named
list items (names do not survive reification).

Spec meta values validate against their meta member specs with two
exemptions: a `None` value clears an inherited tag and is a compile
convention with nothing to check, and `This` typed meta such as
`minVal` and `val` is skipped because the idiom of plain numerics for
custom scalar ranges means the value type never matches the resolved
self type.  Companion compiles validate at haystack fidelity since
their values originate from haystack data such as comp saves.

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
the namespace but must never enumerate it.  The step skips entirely
when compiling sys itself, whose rule catalog does not exist yet.

`xetoc::CompileValidator` overrides the engine's resolution hooks
(`resolveSpec`, `resolveInstance`, `cns`) to overlay the lib under
compile, which is not in the namespace yet.  All value-to-spec mapping
funnels thru `resolveSpec` (see `XetoUtil.specOf`), so overriding it
covers dict spec tags, scalar wrappers, and Fantom bindings alike.  It
is its own `CNamespace` because choice subtype discovery must enumerate
the assembled own lib - `ANamespace` cannot be reused there since its
AST tops never `isa` an assembled spec.  Three opts keep parity with
the old CheckErrors behavior: `ignoreMixins` (the `specx` choke point
enumerates a namespace still under construction), `ignoreMissingSlots`
(instances inherit from their spec), and `ignoreUnresolvedRefs`
(Resolve already settled existence, so what does not resolve here is
an extern).

## Intrinsics

Five rules are emitted by `Validator` directly instead of being
dispatched: `missingSpecRef`, `unknownSpecRef`, `missingSlot`,
`unknownType`, `invalidType`.  They run in order before any other rule
because they gate the walk - there is no point reporting a `maxVal`
problem on a value which is not even a number.
`ValidateIntrinsicRule.isApplicable` is always false so normal dispatch
passes them over.

# Sugar

See [Sugar](doc.xeto::Sugar) for the semantics.  `MSugar` flattens a
sugar spec to its nominal anchor and effective constraints.

The `sugar` flag is an inherited flag bit, so every subtype of a sugar
spec is sugar without re-declaring the marker, and And types pick it
up from their ofs.  The compiler also sets it on every query item:
inline query constraints are anonymous sugar, anchored by the item's
type and constrained by its body.  The flattened form is computed lazily and cached on
`MSpec` like `MFunc`: it is a pure function of declared state (bases
and slotsOwn), so nothing new is stored in xetolibs or on the wire and
remote namespaces recompute it on demand.

The walk descends through sugar bases only and stops at the first
nominal spec in each branch; those nominal specs reduced to the most
specific are the anchor candidates.  The anchor's own body tags are
never constraints.  Subtypes are walked first so their constraint slots
win over their supertypes'.  Only required markers and invariant
scalars are constraints; other slots are defaults for instantiation,
and query slots participate in validation, never matching.

Mixin contributed constraints are namespace dependent, so `XSpec`
recomputes with the mixins which target the sugar chain.

Sugar enters the type system in two relations.  `Spec.isa` is the type
relation: `XetoUtil.isa` walks the nominal chain first and only when
both specs are sugar falls back to the computed rule (anchor is-a and
constraint superset), so the nominal hot path pays one flag test.  It
uses the namespace independent flattening; AST specs stay nominal.
`Namespace.fits` is the membership relation built on it: the value's
spec is-a the target, or for a sugar target a dict whose spec is-a the
anchor and whose tags satisfy the constraints.  Fits uses the spec as
given: pass the `specx` extended spec to include mixin constraints.
Invariants compare at full or haystack fidelity because dicts may come
from either.  The core after resolving the value's spec is
`XetoUtil.fits`, which the validator shares for query extents so its
`specOf` hook (the compile-time overlay) applies.

There is no sugar specific validation rule.  An instance asserting a
sugar spec has its constraints checked by the standard walk: constraint
markers are required slots (`missingSlot`) and invariants are checked
by `invariantVal`.
