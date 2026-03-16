<!--
title:      Comps
author:     Brian Frank
created:    5 Mar 2026
copyright:  Copyright (c) 2026, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
The [sys.comp](doc.xeto::Comps) library defines a general purpose ontology for modeling
component/block oriented systems.  Haxall provides a specific implementation
of these specs for component oriented applications that all leverage a standard
set of Fantom APIs and data flow engine.  This framework is used for the Ion
user interface stack and the SkySpark rule engine.

The key Fantom APIs are:

- [fan.xeto::Comp]\: mixin for all Haxall components
- [fan.xeto::CompObj]\: base class for all Haxall components
- [fan.xeto::CompSpace]\: top-level application for managing a tree of components
  and their execution

# Comps

Haxall components are modeled by the [fan.xeto::Comp] mixin and [fan.xeto::CompObj]
class.  All instances of `Comp` are created in the context of a `CompSpace`.
When created they are automatically bound to a Xeto [spec](fan.xeto::Spec) and
assigned a unique id.

There are two different mechanisms used to bind an instance of `Comp` to a spec:
1. A Fantom constructor will bind to the closest spec
2. Using [fan.xeto::CompSpace.create] will create a component with that exact
   spec and instantiate the closest Fantom class

The component's spec defines its slots. Slots come in two flavors: *fields*
and *methods*.  A slot typed as a [sys::Func] with one parameter is a method,
and any other non-function slot is a field.  For example:

```xeto
MyComp : Comp {
  field: Str
  method: Func { arg: Str, returns: Str }
}
```

You can add additional fields to a component instance using [fan.xeto::Comp.set]
and [fan.xeto::Comp.add].  We call these slots *dynamic* because they exist only
on the instance and not formally defined by spec.  However, you cannot define
a new dynamic method.  Methods can only be defined in the spec statically for all
instances of that type.

When a `Comp` is first created it will always have a unique id within the scope
of its `CompSpace`.  But it starts life *unmounted* and not part of the `CompSpace`.
It becomes *mounted* once it gets added somewhere under the [fan.xeto::CompSpace.root]
component.  Once mounted it will be executed and can be resolved via
[fan.xeto::CompSpace.readById].  You can check mount status via [fan.xeto::Comp.isMounted].

# CompSpace Lifecycle

All [fan.xeto::Comp] instances must be created in the context of a [fan.xeto::CompSpace]
in order to be bound to a [fan.xeto::Namespace].  You do this by installing an
instance of `CompSpace` as an actor local for the current thread.  It is then
used as the factory for all components on that thread.  The typical lifecycle
for a `CompSpace` is:

1. Define [fan.xeto::Namespace] for the components
2. Construct instance using [fan.xeto::CompSpace.make] with namespace
3. Install as the actor local via [fan.xeto::CompSpace.install]
4. Load the root via [fan.xeto::CompSpace.load], or will default to `CompObj` root
5. Start via [fan.xeto::CompSpace.start]
6. Execution loop calls to [fan.xeto::CompSpace.execute]
7. Stop via [fan.xeto::CompSpace.stop]
8. Uninstall via [fan.xeto::CompSpace.uninstall]

# Links

The Haxall component engine uses a standardized data flow engine based
on *links*.  Xeto defines a standardized link model described [here](doc.xeto::Comps#links).
Haxall uses this model to automatically propagate links between component slots
during execution.

Links are always defined on the *to/input* component and refer back
to the *from/output* component/slot. They are just normal dicts that use
the `fromRef` and `fromSlot` tags:

```xeto
// models link from @a.aSlot -> @b.bSlot
@b: Comp {
  links: {
    bSlot: Link { fromRef:@a, fromSlot:"aSlot" }
  }
}
```

The following table defines how links propagate based on slot type:

| From    | To      | Behavior
|---------|---------|---------------------------------------------------------
| field   | prop    | When *from* changes, push the new value to *to*
| field   | method  | When *from* changes, call *to* with new value as argument
| method  | field   | When *from* is called, push return value to *to*
| method  | method  | When *from* is called, call *to* with return value as argument

# Execution

Component execution is managed by the [fan.xeto::CompSpace.execute] method.
An external application must periodically call this method to perform one
execution cycle of the space.

During execution each component in the space that has been marked for
execution receives its [fan.xeto::Comp.onExecute] callback.  This callback
should be used to update the component outputs from inputs.  Components that
mutate their state based on clock time, should use [fan.xeto::CompContext.now]
to monitor elapsed time.

There are several ways a component can be scheduled for execution:

1. Explicitly call the [fan.xeto::Comp.execute] which sets a flag to execute
   the component on the next cycle (or current cycle if it has not been processed yet)

2. Schedule periodic executions by overriding [fan.xeto::Comp.onExecuteFreq]

3. Components are automatically schedule for execute if any non-transient slot
   is modified by set/add/remove

Whenever a component updates a field or calls a method, the new value is queued
to be pushed to any linked slots.  During execution each componet pushes any queued
updates, which may in turn cause the linked components to execute.  The CompSpace
automatically sorts component execution order by link topology.  However if there
are circular links then it may take several execution cycles to fully propagate
link changes.

# Axon

Haxall components can define custom execute logic using Axon by creating a
method named `onExecute`.  This method is called with the [fan.xeto::CompContext]
as an argument:

```xeto
MyIncrement : Comp {
  in: Number
  out: Number
  onExecute: Func <axon:"""this.set("out",  this->in + 1)""">
}
```

Note: today we don't allow the dot operator to get/set slots, so you must
use the [trap()], [get()], and [set()] functions.

