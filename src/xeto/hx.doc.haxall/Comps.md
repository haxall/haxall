<!--
title:      Comps
author:     Brian Frank
created:    5 Mar 2026
copyright:  Copyright (c) 2026, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
The [sys.comp](doc.xeto::Comps) library define a general purpose ontology for modeling
component/block oriented systems.  Haxall provides a specific implementation
of these specs for component oriented applications that all leverage a standard
set of Fantom APIs and data flow engine.  This framework is used for the Ion
user interface stack and the SkySpark rule engine.

The key Fantom APIs are:

- [fan.xeto::Comp]\: mixin for all Haxall components
- [fan.xeto::CompObj]\: base class for all Haxall components
- [fan.xeto::CompSpace]\: top-level application for managing a tree of components
  and their execution

# Slots

Component slots come in two flavors: *fields* and *methods*.  A slot typed
as a [sys::Func] with one parameter is a method, and anything else is a field.
For example:

```xeto
MyComp : Comp {
  field: Str
  method: Func { arg: Str, returns: Str }
}
```

See [CompFuncs](doc.xeto::Comps#compfunc) for details on component methods.

# Links

The Haxall component engine uses a standardized data flow engine based
on *links*.  Xeto defines a standardized link model described [here](doc.xeto::Comps#links).
Haxall uses this model to automatically propagate links between component slots
during execution.

Links are always defined on the *to/target* component and refer back
to the *from/source* component/slot. They are just normal dicts that use
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

# Composition

The Xeto spec for a component can use composition via the [sys.comp::Spec.compTree]
meta tag.  This tag defines a graph of children components and links that is
implicitly mounted into the component during construction.  The `compTree` tag
is a string literal that specifies the child graph formatted as a Xeto instance
tree.  The root of the graph must be the [sys::This] type.

Here is a simple example that creates a compound block with internal links
that chains the top level `in` thru two nested blocks to the top level `out`:

```xeto
MyComposite : Comp {
  in: Number
  out: Number
  <compTree: ---
  @root: This {
    @a: MyIncrement {
      links: {
        in: Link { fromRef:@root, fromSlot:"in" }
      }
    }
    @b: MyIncrement {
      links: {
        in: Link { fromRef:@a, fromSlot:"out" }
      }
    }
    links: {
      out: Link { fromRef:@b, fromSlot:"out" }
    }
  }
  --->
}

```

