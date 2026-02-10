//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using axon

**
** AST type
**
const class AType
{
  static const AType obj := AType("sys::Obj?")

  static AType fromDef(Dict def)
  {
    isTag := def["is"]
    if (isTag == null) return obj
    if (isTag is List) isTag = ((List)isTag).first
    x := isTag.toStr
    if (def.has("enum")) return AType(def->def.toStr.capitalize + "?")
    if (x == "expr") return AType("AxonExpr?")
    if (x == "filterStr") return AType("Filter?")
    return AType(x.capitalize + "?")
  }

  static AType fromFantom(Type type)
  {
    // specials
    sig := mapSpecial(type.qname) ?: type.name
    if (type.isNullable) sig = sig + "?"
    return make(sig)
  }

  static Str? mapSpecial(Str qname)
  {
    switch(qname)
    {
      case "axon::Fn":           return "sys::Func"
      case "haystack::Col":      return "sys::Obj"
      case "haystack::Row":      return "sys::Obj"
      case "haystack::Coord":    return "sys::Obj"
      case "haystack::DateSpan": return "sys::Obj"
      case "haystack::Symbol":   return "sys::Obj"
      case "haystack::Remove":   return "sys::Obj"
      case "haystack::Def":      return "sys::Obj"
      case "folio::Diff":        return "sys::Obj"
      case "axon::MStream":      return "sys::Obj"
      case "math::Matrix":       return "sys::Grid"
    }
    if (qname.startsWith("mlExt::")) return "sys::Obj"
    return null
  }

  new make(Str sig) { this.sig = sig }

  const Str sig

  override Str toStr() { sig }
}

