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

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Name table for this namespace
  @NoDoc abstract NameTable names()

//////////////////////////////////////////////////////////////////////////
// Libs
//////////////////////////////////////////////////////////////////////////

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

  ** Get the given library by name synchronously.  If this is a local
  ** namespace, then the library will be compiled on its first access.
  ** If the library cannot be compiled then an exception is always raised
  ** regardless of checked flag.  If the namespace is remote then the
  ** library must already have been loaded, otherwise raise exception
  ** regardless of checked flag.  The checked flag only returns null if
  ** the library is not defined by this namespace.  Use `libAsync` to
  ** load a library in a remote namespace.
  abstract Lib? lib(Str name, Bool checked := true)

  ** Get or load library asynchronously by the given dotted name.
  ** Once loaded then invoke callback with library or err.
  abstract Void libAsync(Str name, |Err?, Lib?| f)

  ** Get the 'sys' library
  @NoDoc abstract Lib sysLib()

//////////////////////////////////////////////////////////////////////////
// Lookups
//////////////////////////////////////////////////////////////////////////

  ** Get or load type by the given qualified name.
  ** If the type's lib is not loaded, it is loaded synchronously.
  abstract Spec? type(Str qname, Bool checked := true)

  ** Get or load spec by the given qualified name:
  **   - type: "foo.bar::Baz"
  **   - global: "foo.bar::baz"
  **   - slot: "foo.bar::Baz.qux"
   ** If the spec's lib is not loaded, it is loaded synchronously.
  abstract Spec? spec(Str qname, Bool checked := true)

  ** Get or load instance by the given qualified name
  ** If the instance's lib is not loaded, it is loaded synchronously.
  abstract Dict? instance(Str qname, Bool checked := true)

  ** Resolve unqualified type name against all libs.  Raise exception if not
  ** fully loaded.  Raise exception if ambiguous types regardless of checked flag.
  @NoDoc abstract Spec? unqualifiedType(Str name, Bool checked := true)

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  ** Spec for Fantom `sys::Type` or the typeof given object
  abstract Spec? specOf(Obj? val, Bool checked := true)

  ** Return if the given instance fits the spec via structural typing.
  abstract Bool fits(XetoContext cx, Obj? val, Spec spec, Dict? opts := null)

  ** Return if spec 'a' fits spec 'b' based on structural typing.
  @NoDoc abstract Bool specFits(Spec a, Spec b, Dict? opts := null)

  ** Query a relationship using the given subject and query spec.
  ** Call given callback function until it returns non-null and return
  ** as overall result of the method.
  @NoDoc abstract Obj? queryWhile(XetoContext cx, Dict subject, Spec query, Dict? opts, |Dict->Obj?| f)

  ** Create default instance for the given spec.
  ** Raise exception if spec is abstract.
  **
  ** Options:
  **   - 'graph': marker tag to instantiate graph of recs (will auto-generate ids)
  **   - 'abstract': marker to supress error if spec is abstract
  **   - 'id': Ref tag to include in new instance
  abstract Obj? instantiate(Spec spec, Dict? opts := null)

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Derive a new spec from the given base type, additional meta, and
  ** slots.  The spec is not associated with any library and a synthetic
  ** qname is generated.  This feature is subject to change or removal.
  @NoDoc abstract Spec derive(Str name, Spec base, Dict meta, [Str:Spec]? slots := null)


}

