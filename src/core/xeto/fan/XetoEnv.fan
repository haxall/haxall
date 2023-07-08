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
    curRef.compareAndSet(null, Type.find("xetoc::MEnv").make)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Reload the entire data env.  This creates a new environment,
  ** rescans the local file system for installed libs, and all previously
  ** loaded libraries with be reloaded on first access.  Any
  ** references to Lib or Specs must no longer be used.
  static Void reload()
  {
    curRef.val = Type.find("xetoc::XetoEnv").make
  }

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
  @NoDoc abstract Dict dictMap(Str:Obj map, Spec? spec := null)

  ** Coerce one of the following values to a dict:
  **   - null return empty dict
  **   - if Dict return it
  **   - if Str:Obj wrap it as dict
  **   - raise exception for anything else
  abstract Dict dict(Obj? x)

  ** Construct instance of `Ref`
  abstract Ref ref(Str id, Str? dis := null)

  ** Data type for Fantom object
  abstract Spec? typeOf(Obj? val, Bool checked := true)

  ** Registry of installed libs
  @NoDoc abstract LibRegistry registry()

  ** Get or load library by the given qualified name
  abstract Lib? lib(Str qname, Bool checked := true)

  ** Get the 'sys' library
  @NoDoc abstract Lib sysLib()

  ** Get or load type by the given qualified name
  abstract Spec? type(Str qname, Bool checked := true)

  ** Get or load spec by the given qualified name:
  **   - lib: "foo.bar"
  **   - type: "foo.bar::Baz"
  **   - slot: "foo.bar::Baz.qux"
  abstract Spec? spec(Str qname, Bool checked := true)

  ** Derive a new spec from the given base type, additional meta, and
  ** slots.  The spec is not associated with any library and a synthetic
  ** qname is generated.
  abstract Spec derive(Str name, Spec base, Dict meta, [Str:Spec]? slots := null)

  ** Create default instance for the given spec.
  ** Raise exception if spec is abstract.
  **
  ** Options:
  **   - 'graph': marker tag to instantiate graph of recs
  **   - 'abstract': marker to supress error if spec is abstract
  abstract Obj? instantiate(Spec spec, Dict? opts := null)

  ** Compile Xeto source code into a temp library.
  ** Raise exception if there are any syntax or semantic errors.
  abstract Lib compileLib(Str src, Dict? opts := null)

  ** Compile Xeto data file into in-memory dict/scalar tree
  ** Raise exception if there are any syntax or semantic errors.
  abstract Obj? compileData(Str src, Dict? opts := null)

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