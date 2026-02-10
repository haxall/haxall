<!--
title:      Exts
author:     Brian Frank
created:    8 Feb 2022
copyright:  Copyright (c) 2022, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
A xeto lib enabled into the [Namespace] can publish an *extension*.
An extension is a Fantom class that enables background processing including:
  - spawning background threads
  - servicing HTTP requests
  - managing runtime state outside of database

# Code
To create an extension follow these steps:
  1. Create your Xeto lib
  2. Define your extension type in lib meta via `libExt`
  3. Create Fantom type with the same name
  4. Bind your pod via the indexed prop "xeto.bindings"
  5. You can create funcs as described in [Namespace chapter](Namespace#funcs)

Example code:

    // acme.custom lib.xeto
    pragma: Lib <
      doc: "My custom extension"
      version: "1.0.0"
      depends: {
        { lib: "sys",  versions: BuildVar "ph.depend" }
        { lib: "axon", versions: BuildVar "hx.depend" }
        { lib: "hx",   versions: BuildVar "hx.depend" }
      }
      libExt: MyCustomExt
    >
    MyCustomExt: Ext  // need to define spec

    // build.fan - add this line into your pod build script
    index = ["xeto.bindings":"acme.custom"]

    // MyCustomExt.fan - create Fantom class that matches name from lib.xeto
    using hx
    const class MyCustomExt : ExtObj
    {
      override Void onStart() { log.info("$typeof started!") }

      override Void onStop() { log.info("$typeof stopped!") }
    }

# Lifecycle
The lifecycle of an ext follows the overall [runtime lifecycle](Runtime#lifecycle):
  1. Instantiation (constructor)
  2. [fan.hx::Ext.onStart]
  3. [fan.hx::Ext.onReady]
  4. [fan.hx::Ext.onSteadyState] (see [Runtime#steady-state])

The shutdown lib life cycle is:
  1. [fan.hx::Ext.onUnready]
  2. [fan.hx::Ext.onStop]

In the instantiation phase, only basic information from the runtime
is available.  You must wait until onStart to access services and lookup
other libs.  The lifecycle callbacks are invoked on a dedicated background
actor for your extension.

While your lib is running, you can schedule periodic housekeeping.
To use this feature override the [fan.hx::Ext.houseKeepingFreq] which
causes periodic callbacks to [fan.hx::Ext.onHouseKeeping].

# Settings
Every extension can be configured with a dict we call *ext settings*.  You
can create a statically typed class for your setting:
  1. Create a subclass of [fan.hx::Settings]
  2. Override [fan.hx::Ext.settings] to covariantly return your type

Here is an example:

    const class TaskExt : Ext
    {
      ** Settings record
      override TaskSettings settings() { super.settings }
    }

    const class TaskSettings : Settings
    {
      ** Constructor
      new make(Dict d, |This| f) : super(d) { f(this) }

      ** Max threads for the task actor pool
      @Setting { restart=true }
      const Int maxThreads:= 50
    }

The [fan.hx::Ext.onSettings] callback is invoked whenever the settings are modified.

You can manage settings via these Axon APIs:
  - [extSettings()]
  - [extSettingsUpdate()]

# Web
To add HTTP handling to your extension:

  1. Create a subclass of [fan.hx::ExtWeb]
  2. Override [fan.hx::Ext.web] with an instance of your subclass

Here is a very simple example:

    const class FooExt : Ext
    {
      override const FooWeb web := FooWeb(this)
    }

    const class FooWeb : ExtWeb
    {
      new make(FooExt ext) : super(ext) {}

      override Void onGet()
      {
        res.headers["Content-Type"] = "text/plain; charset=utf-8"
        res.out.printLine("Foo hello world: $req.modRel")
      }
    }

Libs plug into the URI namespace as follows:
  - Haxall: `/{extName}`
  - SkySpark: `/api/{projName}/ext/{extName}`

# Stub
The `hx stub` tool will generate all the boiler plate code and structure for
a new library.  Run the following on the command line to see options:

    hx help stub
