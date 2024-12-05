//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Dec 2024  Brian Frank  Move to xetoEnv and make full dict
//

using util
using xeto
using haystack::Dict
using haystack::Ref

**
** Implementation for LibDepend
**
@NoDoc @Js
const class MLibDepend : Dict, LibDepend
{
  new makeFields(Str name, LibDependVersions versions := LibDependVersions.wildcard, FileLoc loc := FileLoc.unknown)
  {
    this.name = name
    this.versions = versions
    this.loc = loc
  }

  new make(Dict dict)
  {
    name = dict->lib
    versions = dict->versions
    loc = FileLoc.unknown
  }

  static once Ref specRef() { Ref("sys::LibDepend") }

  const override Str name

  const override LibDependVersions versions

  const FileLoc loc

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str n, Obj? def := null)
  {
    if (n == "lib")  return name
    if (n == "versions") return versions
    if (n == "spec") return specRef
    return def
  }

  override Bool has(Str n) { n == "lib" || n == "versions" || n == "spec" }

  override Bool missing(Str n) { !has(n) }

  override Obj? trap(Str n, Obj?[]? a := null)
  {
    v := get(n)
    if (v != null) return v
    throw Err(n)
  }

  override Void each(|Obj, Str| f)
  {
    f(name, "lib")
    f(versions, "versions")
    f(specRef, "spec")
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    r := f(name, "lib");         if (r != null) return r
    r = f(versions, "versions"); if (r != null) return r
    r = f(specRef, "spec");      if (r != null) return r
    return null
  }

  override This map(|Obj val, Str n->Obj| f)
  {
    makeFields(f(name, "lib"), f(versions, "versions"), loc)
  }

  override Str toStr() { "$name $versions" }
}

