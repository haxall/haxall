//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using concurrent
using util

**
** Environment for the Xeto data and spec handling.
** There is one instance for the VM accessed via `XetoEnv.cur`.
**
@Js
const abstract class XetoEnv
{
  ** Current default environment for the VM
  static XetoEnv cur()
  {
    env := curRef.val as XetoEnv
    if (env != null) return env
    curRef.compareAndSet(null, Type.find("xetoc::LocalEnv").make)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Install an environment only if one is not currently installed
  @NoDoc
  static Void install(XetoEnv env)
  {
    curRef.compareAndSet(null, env)
  }

  ** Reload the entire data env.  This creates a new environment,
  ** rescans the local file system for installed libs, and all previously
  ** loaded libraries with be reloaded on first access.  Any
  ** references to Lib or Specs must no longer be used.
  static Void reload()
  {
    curRef.val = Type.find("xetoc::LocalEnv").make
  }

  ** Is this a remote environment loaded over a network transport.
  ** Remote environments must load libraries asynchronously and do
  ** not support the full feature set.
  abstract Bool isRemote()

  ** None singleton value
  abstract Obj none()

  ** Marker singleton value
  abstract Obj marker()

  ** NA singleton value
  abstract Obj na()

  ** Return generic 'sys::Dict'
  @NoDoc abstract Spec dictSpec()

  ** Empty dict singleton
  @NoDoc abstract Dict dict0()

  ** Create a Dict with one name/value pair
  @NoDoc abstract Dict dict1(Str n, Obj v)

  ** Create a Dict with two name/value pairs
  @NoDoc abstract Dict dict2(Str n0, Obj v0, Str n1, Obj v1)

  ** Create a Dict with three name/value pairs
  @NoDoc abstract Dict dict3(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2)

  ** Create a Dict with four name/value pairs
  @NoDoc abstract Dict dict4(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3)

  ** Create a Dict with five name/value pairs
  @NoDoc abstract Dict dict5(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4)

  ** Create a Dict with six name/value pairs
  @NoDoc abstract Dict dict6(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4, Str n5, Obj v5)

  ** Create a Dict from a map name/value pairs.
  @NoDoc abstract Dict dictMap(Str:Obj map)

  ** Coerce one of the following values to a dict:
  **   - null return empty dict
  **   - if Dict return it
  **   - if Str:Obj wrap it as dict
  **   - raise exception for anything else
  abstract Dict dict(Obj? x)

  ** Construct instance of `Ref`
  abstract Ref ref(Str id, Str? dis := null)

  ** Spec for Fantom `sys::Type` or the typeof given object
  abstract Spec? specOf(Obj? val, Bool checked := true)

  ** Name table for this environment
  @NoDoc abstract NameTable names()

  ** Registry of installed libs
  @NoDoc abstract LibRegistry registry()

  ** Get or load library by the given library name.
  ** If the library is found but cannot be compiled, then raise an exception.
  abstract Lib? lib(Str name, Bool checked := true)

  ** Get or load library asynchronously by the given library name.
  ** Once loaded then invoke callback with library or err.
  abstract Void libAsync(Str name, |Err?, Lib?| f)

  ** Load a list of library names asynchronously and invoke callback once
  ** all are loaded.
  @NoDoc abstract Void libAsyncList(Str[] names, |Err?| f)

  ** Get the 'sys' library
  @NoDoc abstract Lib sysLib()

  ** Get or load type by the given qualified name
  abstract Spec? type(Str qname, Bool checked := true)

  ** Get or load spec by the given qualified name:
  **   - type: "foo.bar::Baz"
  **   - slot: "foo.bar::Baz.qux"
  abstract Spec? spec(Str qname, Bool checked := true)

  ** Get or load instance by the given qualified name
  abstract Dict? instance(Str qname, Bool checked := true)

  ** Derive a new spec from the given base type, additional meta, and
  ** slots.  The spec is not associated with any library and a synthetic
  ** qname is generated.
  abstract Spec derive(Str name, Spec base, Dict meta, [Str:Spec]? slots := null)

  ** Create default instance for the given spec.
  ** Raise exception if spec is abstract.
  **
  ** Options:
  **   - 'graph': marker tag to instantiate graph of recs (will auto-generate ids)
  **   - 'abstract': marker to supress error if spec is abstract
  **   - 'id': Ref tag to include in new instance
  abstract Obj? instantiate(Spec spec, Dict? opts := null)

  ** Compile Xeto source code into a temp library.
  ** Raise exception if there are any syntax or semantic errors.
  abstract Lib compileLib(Str src, Dict? opts := null)

  ** Compile a Xeto data file into an in-memory value. Raise exception if
  ** there are any syntax or semantic errors.  If the file contains a scalar
  ** value or one dict, then it is returned as the value.  If the file contains
  ** two or more dicts then return a Dict[] of the instances.  Also
  ** see `writeData` to encode data back to Xeto text format.
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

  ** Parse pragma file into AST
  @NoDoc abstract Dict parsePragma(File file, Dict? opts := null)

  ** Parse instance of LibDependVersions
  @NoDoc abstract LibDependVersions parseLibDependVersions(Str s, Bool checked)

  ** Return if the given instance fits the spec via structural typing.
  abstract Bool fits(XetoContext cx, Obj? val, Spec spec, Dict? opts := null)

  ** Return if spec 'a' fits spec 'b' based on structural typing.
  @NoDoc abstract Bool specFits(Spec a, Spec b, Dict? opts := null)

  ** Query a relationship using the given subject and query spec.
  ** Call given callback function until it returns non-null and return
  ** as overall result of the method.
  @NoDoc abstract Obj? queryWhile(XetoContext cx, Dict subject, Spec query, Dict? opts, |Dict->Obj?| f)

  ** Generate an AST for the given Lib or Spec as a Dict tree.
  @NoDoc abstract Dict genAst(Obj libOrSpec, Dict? opts := null)

  ** Pretty print object to output stream.
  @NoDoc abstract Void print(Obj? val, OutStream out := Env.cur.out, Dict? opts := null)

  ** Debug dump of environment
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)

}