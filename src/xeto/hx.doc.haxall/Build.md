<!--
title:      Build
author:     Brian Frank
created:    16 Feb 2022
copyright:  Copyright (c) 2022, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
Most users should just use the prebuilt [distribution](Setup).  However
if you want to get your hands dirty and build from source, then follow
this guide.

To build Haxall from source requires the following projects:
  1. [Fantom](#fantom) language and runtime
  2. [Project Haystack](#project-haystack) core definitions
  3. [Xeto](#xeto) core Xeto libraries
  4. [Haxall](#haxall) repo itself

All of these projects are available on GitHub.

# Fantom
In most cases, the simplest solution is to just install the latest version
of [Fantom](https://fantom.org/) rather than building from scratch:

  1. [Download](https://fantom.org/download) and unzip latest version

  2. See [Fantom Setup](fan.docTools::Setup)

  3. Make sure `fan` or `fan.bat` is in your executable path

There are cases where the current version of the Haxall repo requires
building Fantom from source.  We call this a *bootstrap* build because Fantom
is used to compile Fantom itself.  See the [Bootstrap](fan.docTools::Bootstrap)
chapter for details.

# Project Haystack
Once Fantom is installed, you can clone and rebuild the Project Haystack pods:

1. Pull the [Haystack-Defs GitHub](https://github.com/Project-Haystack/haystack-defs) repo

2. Setup an empty "fan.props" in repo root directory

3. CD to your `{haystack-defs}` root directory and run `fan -version`; verify
your Env Path is as follows: 'haystack-defs (work), fantom (home)'

4. Run `{haystack-defs}/src/build.fan`; should build to `{haystack-defs}/lib/`

# Xeto
You also need to clone the Xeto repo:

1. Pull the [Xeto GitHub](https://github.com/Project-Haystack/xeto) repo

You do not need to do anything else with this repo.

# Haxall
To build Haxall from source:

1. Pull from [Haxall GitHub](https://github.com/haxall/haxall) repo

2. Setup "fan.props" in repo root of Haxall with this line:

         path=/path-to/haystack-defs;/path-to/xeto

3. CD to your `{haxall}` root directory and run `fan -version`; verify your
Env Path is as follows: 'haxall (work), xeto, haystack-defs,fantom (home)'

4. Set the environment variable `FAN_BUILD_JDKHOME` to point to your JDK install

5. Run `{haxall}/src/build.fan`; should build to `{haxall}/lib/`

Note that when building from source as described here, the batch files
in `{haxall}/bin` cannot be used directly.  Instead you can run the Haxall command
line using the `fan <pod>` launcher like this:

    fan hx version

