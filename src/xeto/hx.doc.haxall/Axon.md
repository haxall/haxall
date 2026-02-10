<!--
title:      Axon
author:     Brian Frank
created:    6 Jul 2010
copyright:  Copyright (c) 2010, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
Axon is a programming language used for scripting within Haxall and SkySpark.
Most functionality can be accessed through Axon:
  - query [Folio] tag database
  - perform data transformations such as rollups and normalizations
  - creating your own function libraries
  - computations for the [rule engine](hx.rule::doc) are written in Axon
  - create custom reports
  - scripts for data import
  - background tasks for data synchronization and maintenance

One of the pivotal features is that all queries to the database/analytics
engine are full Axon expressions:

    // find all the records with power tag
    power

    // same as above
    readAll(power)

    // find all recs with power and read history data for yesterday
    readAll(power).hisRead(yesterday)

    // find peak kW for yesterday for all power recs
    readAll(power).hisRead(yesterday).hisRollup(max, 1day)

This design allows great flexibility scaling up from simple queries
to powerful data transformation pipelines - all using a single general
purpose syntax.

# Language Overview
Axon is a full general purpose programming language characterized
as follows:

  - **simple**: the language syntax is minimal and designed to
    be fully learned in a single session
  - **functional**: everything is a function (the language
    is *not* object oriented); closures are heavily used by the
    language and the library to concisely express data
    transformations
  - **dynamic typing**: you do not declare types for variables
  - **tag oriented**: the language is designed to work in conjunction
    with the `Folio` database tag model
  - **component oriented**: Axon provides specialized syntax to
    create software components
  - **time-series oriented**: the language has dedicated syntax and
    a rich library of functions for working with time series data
    such as time, date, and date range literals
  - **unit oriented**: all numbers in Axon and Folio can be annotated
    with an explicit [unit](Units) of measurement which is checked and
    carried through during arithmetic

Experienced programmers should be able to pick up Axon very quickly,
however, a grounding in functional programming will definitely help.

The [AxonLang] chapter digs into the syntax of the Axon language.

# Funcs
Functions are defined in two locations:

1. In Xeto libs as methods within the [sys::Funcs] mixin

2. As [managed recs](ManagedRecs) in the companion library

Here is an example of a simple function defined in a xeto lib:

```xeto
+Funcs {

  // add in Axon
  addExample: Func { a: Number, b: Number, returns: Number
    <axon:---
     a + b
     --->
  }

}
```

Note the spec slots define the parameters and return types and the
spec `axon` metadata defines the function body.

# Top-Level Namespace
The top-level namespace of a runtime project is defined by:
  1. libs enabled by the runtime
  2. companion lib funcs [func records](ManagedRecs#func-companion-recs)

The following functions are useful for working with the top-level
function namespace:
  - [funcs()]: list or match functions defined in the top-level namespace
  - [func()]: resolve a function in the top-level namespace

## Qualified Names
The name used in a function call can be either *qualified* or *unqualified*.
Qualified functions specify an explicit library namespace using double
colons:

    hx.point::toPoints  // qualified to "hx.point::Funcs.toPoints"

Unqualified function names are resolved by the implicit namespace
which is searched in this order:
  1. local namespace of function (parameter/variable names)
  2. funcs in the namespace

## Function Overrides
If an lib function is tagged as [axon::Spec.overridable], then you can *override*
it by declaring a function record with the same name.  Functions resolved
as a project rec take priority over the function defined by the extension.

Attempts to override an ext function not marked as [axon::Spec.overridable] will report
an error and your rec function will not be accessible.

You can access the built-in function in your override using its qualified name:

    geoTz(val) => do
      // handle special case
      if (val["geoCountry"] == "RU") return "Moscow"

      // route back to built-in version
      return geo::geoTz(val)
    end

