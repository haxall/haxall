//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent

**
** Library namespace is a pinned manifest of specific library versions.
** Namespaces may lazily load their libs, in which case not all operations
** are supported. Create a new namespace via `LibRepo.createNamespace`.
**
@Js
const mixin LibNamespace
{
  ** List the library name and versions in this namespace.
  abstract LibVersion[] versions()

  ** Lookup the version info for a library name in this namespace.
  abstract LibVersion? version(Str name, Bool checked :=true)

  ** Return true if the given library name is included in
  ** this namespace and has been loaded.
  abstract Bool isLoaded(Str name)

  ** Return true if the every library in this namespace has been loaded.
  ** Many operations require a namespace to be fully loaded.
  abstract Bool isAllLoaded()

  ** Get the given library by name.  If this is a local namespace, then the
  ** library will be compiled on its first access.  If the library cannot
  ** be compiled then an exception is raised.  If the namespace is remote
  ** then the library must already have been loaded or an exception is
  ** raised.  Use `libAsync` to load a library in a remote namespace.
  abstract Lib? lib(Str name, Bool checked := true)

  ** Get or load library asynchronously by the given dotted name.
  ** Once loaded then invoke callback with library or err.
  abstract Void libAsync(Str name, |Err?, Lib?| f)

  ** Get the 'sys' library
  @NoDoc abstract Lib sysLib()

}

