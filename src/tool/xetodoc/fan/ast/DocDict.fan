//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** DocDict encodes meta and instances
**
@Js
const class DocDict : DocVal
{
  ** Empty doc dict
  static const DocDict empty := doMake(DocTypeRef.dict, null, Str:DocVal[:])

  ** Make generic dict that contains only Marker, Str, or DocVal
  static new makeGeneric(Str:Obj acc)
  {
    acc = acc.map |v->DocVal|
    {
      if (v is DocVal) return v
      if (v is Str) return DocScalar.str(v)
      if (v === Marker.val) return DocScalar.marker
      throw Err("Unsupported geneirc val: $v [$v.typeof]")
    }
    return make(DocTypeRef.dict, null, acc)
  }

  ** Constructor
  static new make(DocTypeRef type, DocLink? link, Str:DocVal dict)
  {
    if (dict.isEmpty && link == null) return empty
    return doMake(type, link, dict)
  }

  private new doMake(DocTypeRef type, DocLink? link, Str:DocVal dict)
    : super.make(type, link)
  {
    this.dict = dict
  }

  ** Dict value
  const Str:DocVal dict

  ** Return true
  override Bool isDict() { true }

  ** Return this
  override DocDict asDict() { this }

  ** Convenience for 'dict.get'
  DocVal? get(Str name) { dict.get(name) }

  ** Convenience for 'dict.get' as string
  Str? getStr(Str name) { dict.get(name)?.toVal as Str }

  ** Return if given tag is defined
  Bool has(Str name) { dict.get(name) != null }

  ** Map list items to dict
  override Obj? toVal()
  {
    acc := Str:Obj[:]
    dict.each |v, n| { acc[n] = v.toVal }
    return Etc.dictFromMap(acc)
  }

  ** Encode to a JSON object tree or null if empty
  [Str:Obj]? encode()
  {
    if (dict.isEmpty) return null
    return encodeVal
  }

  ** Encode to top-level dict or null if empty
  static DocDict? decode([Str:Obj]? obj)
  {
    if (obj == null) return empty
    return DocVal.decodeVal(obj)
  }
}

