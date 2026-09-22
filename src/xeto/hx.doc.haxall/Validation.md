<!--
title:      Validation
author:     Brian Frank
created:    21 Sep 2026
copyright:  Copyright (c) 2026, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
Validation checks data against its spec and reports what is wrong.  It
checks the [constraints](doc.xeto::Constraints) declared in the spec such
as `maxVal` and `minSize`, required tags, choices, and the targets of refs.
Libraries add their own checks on top of this.

Every check is defined by a [sys::ValidateRule] instance.  The rule
declares what it applies to and its message; the id such as
`sys::overMaxVal` is a stable name tools use to attach documentation,
quick fixes, and translations to a problem.  The sys library defines
about thirty rules covering the constraints built into Xeto.

Validation returns a [fan.xeto::ValidateReport] of
[fan.xeto::ValidateItem]s.  Each item names the rule which reported it,
the subject, the slot within that subject, the offending value, and a
rendered message.

# Running Validation

From Fantom use [fan.xeto::Namespace.validate] to check one value, or
`validateAll` to check a list of recs against each one's own `spec` tag:

```fantom
report := ns.validate(rec, spec)
if (report.hasErrs) report.items.each |item| { echo(item) }
```

From Axon use [validate()] which returns a grid with a row per item:

```
readAll(equip).validate                 // against each rec's spec tag
readAll(vav).validate(G36ReheatVav)     // against an explicit spec
readAll(equip).validate(null, {graph})  // also check required points
validate(123, Str)                      // check a bare value
```

Options:
  - `graph`: also check queries such as the points an equip requires
  - `ignoreRefs`: skip checking that refs resolve and hit their target type
  - `ignoreUnresolvedRefs`: skip checking that refs resolve, but still
    check the target type of refs that do; use when validating a data
    subset whose refs point outside the available context
  - `ignoreMissingSlots`: skip checking for missing required slots; use
    when validating partially authored data such as a form in progress

# Rules

A rule is an instance of [sys::ValidateRule] defined in a library's
`validation.xeto` file:

```xeto
@overMaxVal: ValidateRule {
  on: Number
  unless: @maxValUnit
  msg: "Number $val > maxVal $maxVal"
}
```

  - **on**: the types the rule applies to.  The engine only runs a rule
    where the value's spec is one of these types, so a rule on `Number`
    never runs on a `Str`.  List several types when a check spans them:
    `on: {Ref, MultiRef}`.  You can also name a single slot of a type
    such as `on: Meter.elecRef` to check just that one slot.
  - **unless**: skip this rule when another one already reported on the
    same value.  Keeps one mistake from producing three messages.
  - **level**: "err" or "warn"; defaults to "err"
  - **msg**: the message template

Where you register the rule decides what it sees:

  - on a dict type such as `ph::Meter` the rule runs once on each
    instance, and looks across its tags
  - on a value type such as `Number` the rule runs on each value of
    that type wherever it appears
  - on a slot such as `Meter.elecRef` the rule runs only on that slot

The `msg` template substitutes `$name` variables:

  - `$val`: the value
  - `$slot`: its dotted slot path
  - `$type`: the declared type
  - `$valType`: the actual type of the value
  - `$size`: size of a string or list

Any other name resolves against the spec meta, so a rule on `maxVal` can
say `$maxVal`, and then against whatever args the check supplied.

# Rules in Axon

To implement a rule, write a func and tag it with the rule it implements:

```xeto
// validation.xeto
@minMax: ValidateRule {
  on: Meter
  msg: "$val is above max"
}

// funcs.xeto
checkMinMax: Func <validateRule:@minMax> {
  spec: Spec, val: Obj?, returns: Obj?
  <axon:"if (val->min > val->max) {slot:\"min\"}">
}
```

The func takes the spec and value at the position the rule fired on.  For
a rule on a dict type the value is the instance itself, and for a rule on
a value type it is that value.

Return null or an empty list when there is nothing wrong.  Otherwise
return a dict per problem, or a list of dicts:

```
null                          // nothing wrong
{}                            // one problem at this position
{slot:"min"}                  // one problem, reported against the min tag
{slot:"min", limit:10}        // ... and $limit in the message
[{slot:"min"}, {slot:"max"}]  // two problems
```

The `slot` tag is how a rule on an entity reports against the tag which
is actually wrong, so a form can highlight that one field.  Any other
tags become message variables.

# Rules in Fantom

A Fantom rule is a class named "Validate" plus the rule name, in the pod
bound to the rule's library.  So `acme.rules::minMax` is implemented by
`ValidateMinMax` in the pod bound to `acme.rules`:

```fantom
const class ValidateMinMax : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    min := s.dict?.get("min") as Number
    max := s.dict?.get("max") as Number
    if (min != null && max != null && min > max) s.emitOn("min")
  }
}
```

`ValidateState` is the position being checked: `val` is the value, `dict`
is it as a dict, `spec` is its spec, and `num` and `list` are convenience
accessors.  Report a problem with `emit` to report at this position, or
`emitOn` to report against a tag of the current dict.  Both take an
optional dict of message variables.

**Note**: *the Fantom APIs used for custom rules are published in the implementation
pod `xetom`.  They are open source, but are subject to change.*

# When Rules Run

Fantom rules run everywhere, including while compiling a library.  Axon
rules need a runtime to call the func, so they are skipped when compiling
libraries and only run at runtime.  UI will run the validation engine in
the browser client side, so you must not assume a full server runtime is
available.

# Debugging

Use `validateRules()` in Axon to see every rule in the namespace, in the
order the engine runs them:

```
validateRules()                                // all rules
validateRules.findAll(r => r.missing("impl"))  // declared but unimplemented
```

The `impl` column names the func or Fantom class implementing each rule.

