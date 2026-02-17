<!--
title:      Namespace
author:     Brian Frank
created:    19 Aug 2025
copyright:  Copyright (c) 2025, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
Every [Runtime] defines a *namespace* which is its collection of Xeto
libraries.  The namespace defines the scope for:
  - what specs are available
  - what Axon functions are available
  - what extensions to run

Libraries are identified by their xeto lib dotted name. The first part
of the name called the *prefix* is owned by specific organizations or
project:
  - "sys.*": core xeto system libs
  - "ph.*": Project Haystack ontology libs
  - "hx.*": all Haxall and SkySpark libs

If you are creating your own extension then you should define a unique
prefix for your org and register it on [http://xeto.dev].

# Basis
Every lib in a given runtime has one of three *basis* which determines
how that lib was included into the namespace:

  - **boot**: the system determined that the library at bootstrap time
    as required by the system to run.  Boot libs cannot be modified.
  - **sys**: the lib is enabled at the system level
  - **proj**: the lib is enabled at the project level

In the Haxall daemon, there is just one runtime and one namespace that
serves as both the sys and the proj.  In a multi-tenant system like SkySpark
each runtime defines its own unique namespace.  The sys namespace always
includes boot libs and sys level libs.  The proj namepsace always includes
everything in the sys level namespace and its own enabled libs.  Plus every
project has a special lib named "proj" we call the *companion lib*.

# Definition
See [TODO Xeto lib](https://github.com/Project-Haystack/xeto/blob/master/src/xeto/doc.xeto/Libs.md)
docs for how to create a standard library.

Haxall supports the following extra lib meta:
  - `hxSysOnly`: marks the lib to be used only at the boot/system level
  - `libExt`: defines an extension to run when the lib is enabled

# Management
Boot libs are managed in the `hxm::HxBoot` class by vendors. All other libs
are administered via [managed recs](ManagedRecs).

You can also manage libs with these Axon functions:
  - [libs()]: list the libs and their status in the runtime namespace
  - [libAdd()]: add one or more libs to the runtime namespace
  - [libRemove()]: remove one or more libs to the runtime namespace

In Fantom you manage the libs via the [fan.hx::Runtime.libs] API.

# Funcs
Any funcs defined in the lib are published into the Axon namespace. The
implementation must be:
 1. Axon source code defined in `axon` meta
 2. Fantom binding

## Axon Funcs
Funcs defined in axon include their source via the func `axon` meta tag.  Typically
you include it using the heredoc syntax as follows:

    myAdd: Func { a:Number, b:Number, returns: Number
      <axon:---
      a + b
      --->
    }

Note that the parameters to the func are defined on the spec itself, as well as the
return type.

## Fantom Funcs
Fantom functions are defined as a static method in a class always called "FooFuncs"
where "Foo" is derived:
  - from your extension type name
  - from the last part of your library dotted name

The funcs class must define a static method that matches the xeto spec signature.
And the methods must be annotated with the [fan.xeto::Api] facet.

Register your Fantom pod as the implementation for the Xeto lib with the
indexed prop "xeto.bindings". The convention is to name your Fantom pod to
match the Xeto lib name by replacing dots with camel case.  For example the
Xeto lib "acme.foo.bar" should use the Fantom pod name of "acmeFooBar".

Example:

    // xeto spec
    myAdd: Func { a:Number, b:Number, returns: Number }

    // build.fan register your pod as the implementation
    index = ["xeto.bindings":"acme.mylib"]

    // Fantom funcs as static method
    class MylibFuncs
    {
      @Api static Number myAdd(Number a, Number b) { a + b }
    }


It is critical to consider security when implementing functions in Fantom.
Fantom funcs run outside of the Axon security sandbox, so its up your code
to enforce any security constraints.  Never create functions which would allow
unconstrained access to the underlying OS.
