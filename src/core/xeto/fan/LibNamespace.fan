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
** are supported. Create a new namespace via `XetoEnv.createNamespace`.
**
@Js
const mixin LibNamespace
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Is this a remote namespace loaded over a network transport.
  ** Remote environments must load libraries asynchronously and do
  ** not support the full feature set.
  @NoDoc abstract Bool isRemote()

  ** Environment used to create this namespace
  abstract XetoEnv env()

  ** Base64 digest for this namespace based on its lib versions
  abstract Str digest()

//////////////////////////////////////////////////////////////////////////
// Libs
//////////////////////////////////////////////////////////////////////////

  ** List the library name and versions in this namespace.
  abstract LibVersion[] versions()

  ** Lookup the version info for a library name in this namespace.
  abstract LibVersion? version(Str name, Bool checked :=true)

  ** Return if this namespace contains the given lib name.
  ** This is true if version will return non-null regardless of libStatus.
  abstract Bool hasLib(Str name)

  ** Return load status for the given library name:
  **   - 'notLoaded': library is included but has not been loaded yet
  **   - 'ok': library is included and loaded successfully
  **   - 'err': library is included but could not be loaded
  **   - null/exception if library not included
  abstract LibStatus? libStatus(Str name, Bool checked := true)

  ** Exception for a library with lib status of 'err', or null otherwise.
  ** Return null/exception if library not included
  abstract Err? libErr(Str name, Bool checked := true)

  ** Return true if the every library in this namespace has been
  ** loaded (successfully or unsuccessfully).  This method returns false
  ** is any libs have a load status of 'notLoaded'.  Many operations
  ** require a namespace to be fully loaded.
  @NoDoc abstract Bool isAllLoaded()

  ** Get the given library by name synchronously.  If the library is
  ** not loaded, then it is compiled on first access (server only).
  ** If the library is not included or cannot be comiled then raise
  ** an exception unless checked is false.
  abstract Lib? lib(Str name, Bool checked := true)

  ** List all libraries.  On first call, this will force all libraries to
  ** be loaded synchronously.  Any libs which cannot be compiled will log
  ** an error and be excluded from this list.
  abstract Lib[] libs()

  ** Load all libraries asynchronosly.  Once this operation completes
  ** successfully the `isAllLoaded` method will return 'true' and the
  ** `libs` method may be used even in JS environments.  Note that an
  ** error is reported only if the entire load failed.  Individual libs
  ** which cannot be loaded will logged on server, and be excluded from
  ** the final libs list.
  @NoDoc abstract Void libsAllAsync(|Err?, Lib[]?| f)

  ** Get or load library asynchronously by the given dotted name.
  ** This method automatically also loads the dependency chain.
  ** Once loaded then invoke callback with library or err.
  @NoDoc abstract Void libAsync(Str name, |Err?, Lib?| f)

  ** Get or load list of libraries asynchronously by the given dotted names.
  ** This method automatically also loads the dependency chain.
  ** Once loaded then invoke callback with libraries or err.  If a lib
  ** cannot be loaded then it is excluded from the callback list (so its
  ** possible the results list is not the same size as the names list).
  @NoDoc abstract Void libListAsync(Str[] names, |Err?, Lib[]?| f)

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
  **   - global/meta/func: "foo.bar::baz"
  **   - slot: "foo.bar::Baz.qux"
   ** See `lib` for behavior if the spec's lib is not loaded.
  abstract Spec? spec(Str qname, Bool checked := true)

  ** Lookup a spec async in the case the lib is not loaded yet.
  @NoDoc abstract Void specAsync(Str qname, |Err?, Spec?| f)

  ** Get or load instance by the given qualified name
   ** See `lib` for behavior if the instances's lib is not loaded.
  abstract Dict? instance(Str qname, Bool checked := true)

  ** Lookup an instance async in the case the lib is not loaded yet.
  @NoDoc abstract Void instanceAsync(Str qname, |Err?, Dict?| f)

  ** Lookup the extended meta for the given spec qname.  This is a merge
  ** of the spec's own meta along with any instance dicts in the namespace
  ** with a local id of "xmeta-{lib}-{spec}".  Only libs currently loaded are
  ** considered for the result.  If the spec is not defined then return
  ** null or raise an exception based on checked flag.  For example to register
  ** extended meta data on the 'ph::Site' spec you would create an instance
  ** dict with the local name of 'xmeta-ph-Site'.
  abstract Dict? xmeta(Str qname, Bool checked := true)

  ** Lookup the extended meta for an enum spec.  This returns a SpecEnum
  ** instance with resolved extended meta for all the enum items via a merge
  ** of all libs with instances named "xmeta-{lib}-{spec}-enum".
  abstract SpecEnum? xmetaEnum(Str qname, Bool checked := true)

  ** Iterate all the top-level types in libs.
  abstract Void eachType(|Spec| f)

  ** Iterate all top-level types in libs until callback returns non-null.
  abstract Obj? eachTypeWhile(|Spec->Obj?| f)

  ** Iterate all the instances in libs
  abstract Void eachInstance(|Dict| f)

  ** Iterate all the direct subtypes of given type
  abstract Void eachSubtype(Spec base, |Spec| f)

  ** Return if given type has at least one direct subtype.
  abstract Bool hasSubtypes(Spec base)

  ** Iterate instances that are nominally typed by given spec.
  ** The callback function includes the resolve spec for the instance.
  @NoDoc abstract Void eachInstanceThatIs(Spec type, |Dict, Spec| f)

//////////////////////////////////////////////////////////////////////////
// Unqualified Lookups
//////////////////////////////////////////////////////////////////////////

  ** Resolve unqualified type name against all loaded libs:
  **   - one match return it
  **   - zero return null or raise exception based on checked flag
  **   - two or more raise exception regardless of checked flag
  @NoDoc abstract Spec? unqualifiedType(Str name, Bool checked := true)

  ** List all unqualified types against loaded libs.
  @NoDoc abstract Spec[] unqualifiedTypes(Str name)

  ** Resolve unqualified function name against loaded libs:
  **   - one match return it
  **   - zero return null or raise exception based on checked flag
  **   - two or more raise exception regardless of checked flag
  @NoDoc abstract Spec? unqualifiedFunc(Str name, Bool checked := true)

  ** List all unqualified function names against loaded libs.
  @NoDoc abstract Spec[] unqualifiedFuncs(Str namee)

  ** Resolve unqualified global spec name against all loaded libs.
  **   - one match return it
  **   - zero return null or raise exception based on checked flag
  **   - two or more raise exception regardless of checked flag
  @NoDoc abstract Spec? unqualifiedGlobal(Str name, Bool checked := true)

  ** List all unqualified global specs name against all loaded libs.
  @NoDoc abstract Spec[] unqualifiedGlobals(Str name)

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  ** Spec for Fantom `sys::Type` or the typeof given object
  abstract Spec? specOf(Obj? val, Bool checked := true)

  ** Return if the given instance fits the spec via structural typing.
  ** Options:
  **   - 'graph': marker to also check graph of references such as required points
  **   - 'ignoreRefs': marker to ignore if refs resolve to valid target
  **   - 'haystack': marker tag to use Haystack level data fidelity
  abstract Bool fits(Obj? val, Spec spec, Dict? opts := null)

  ** Return if spec 'a' fits spec 'b' based on structural typing.
  @NoDoc abstract Bool specFits(Spec a, Spec b, Dict? opts := null)

  ** Query a relationship using the given subject and query spec.
  ** Call given callback function until it returns non-null and return
  ** as overall result of the method.
  @NoDoc abstract Obj? queryWhile(Dict subject, Spec query, Dict? opts, |Dict->Obj?| f)

  ** Create default instance for the given spec.
  ** Raise exception if spec is abstract.
  **
  ** Options:
  **   - 'graph': marker tag to instantiate graph of recs (will auto-generate ids)
  **   - 'abstract': marker to supress error if spec is abstract
  **   - 'id': Ref tag to include in new instance
  **   - 'haystack': marker tag to use Haystack level data fidelity
  abstract Obj? instantiate(Spec spec, Dict? opts := null)

  ** Return choice API for given spec. Callers should prefer the slot
  ** over the type since the slot determines maybe and multi-choice flags.
  ** Raise exception if `Spec.isChoice` is false.
  abstract SpecChoice choice(Spec spec)

  ** Analyze the subject dict and return its slot types. Use the given
  ** spec or if null, then use 'spec' tag on dict itself.  Reflection
  ** performs the following normalization:
  **   - maps every name/value pair to a ReflectSlot
  **   - maps every slot from spec (even if not defined by dict)
  **   - normalizes choice slots into ReflectSlot and hides markers
  @NoDoc abstract ReflectDict reflect(Dict subject, Spec? spec := null)

//////////////////////////////////////////////////////////////////////////
// Validation
//////////////////////////////////////////////////////////////////////////

  ** Validate a single value against a spec.  If spec is null,
  ** then validate against 'specOf(val)'. Should be called within an
  ** XetoContext context to verify external refs.
  abstract ValidateReport validate(Obj? val, Spec? spec := null, Dict? opts := null)

  ** Validate a graph of records using their configured 'spec' tag.
  ** Should be called within an XetoContext context to verify external refs.
  abstract ValidateReport validateAll(Dict[] subjects, Dict? opts := null)

//////////////////////////////////////////////////////////////////////////
// Compile
//////////////////////////////////////////////////////////////////////////

  ** Compile Xeto source code into a temp library.  All dependencies are
  ** resolved against this namespace.  Raise exception if there are any
  ** syntax or semantic errors.
  abstract Lib compileLib(Str src, Dict? opts := null)

  ** Compile a Xeto data file into an in-memory value. All dependencies are
  ** resolved against this namespace.  Raise exception if there are any
  ** syntax or semantic errors.  If the file contains a scalar value or
  ** one dict, then it is returned as the value.  If the file contains
  ** two or more dicts then return a Dict[] of the instances.
  **
  ** Options
  **   - externRefs: marker to allow unresolved refs to compile
  abstract Obj? compileData(Str src, Dict? opts := null)

  ** Convenience for `compileData` but always returns data as list of dicts.
  ** If the data is not a Dict nor list of Dicts, then raise an exception.
  abstract Dict[] compileDicts(Str src, Dict? opts := null)

  ** Write instance data in Xeto text format to an output stream.  If the
  ** value is a Dict[], then it is flattened in the output.  Use `compileData`
  ** to read data from Xeto text format.
  abstract Void writeData(OutStream out, Obj val, Dict? opts := null)

  ** Pretty print object to output stream.
  @NoDoc abstract Void print(Obj? val, OutStream out := Env.cur.out, Dict? opts := null)

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Debug dump of libs and status
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)
}

**************************************************************************
** LibStatus
**************************************************************************

@Js
enum class LibStatus
{
  ** The library has not been loaded into the namespace yet
  notLoaded,

   ** The library was successfully loaded into namespace
  ok,

  ** Load was attempted, but failed due to compiler error
  err

  @NoDoc Bool isOk() { this === ok }
  @NoDoc Bool isErr() { this === err }
  @NoDoc Bool isNotLoaded() { this === notLoaded }
  @NoDoc Bool isLoaded() { this !== notLoaded }
}

