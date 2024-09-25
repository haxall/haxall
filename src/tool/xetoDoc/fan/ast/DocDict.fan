//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using haystack

**
** DocDict encodes meta and instances
**
@Js
const class DocDict
{
  ** Empty doc dict
  static const DocDict empty := doMake(Etc.dict0)

  ** Constructor
  static new make(Dict dict)
  {
    if (dict.isEmpty) return empty
    dict = Etc.dictRemove(dict, "doc") // pull out as parsed DocBlock
    if (dict.isEmpty) return empty
    return doMake(dict)
  }

  private new doMake(Dict dict) { this.dict = dict }

  ** Dict value
  const Dict dict

  ** Convenience for 'dict.get'
  Obj? get(Str name) { dict.get(name) }

  ** Encode to a JSON object tree
  Obj? encode()
  {
    // TODO: probably need to a much more sophisticated encoding
    if (dict.isEmpty) return null
    acc := Str:Obj[:]
    acc.ordered = true
    dict.each |v, n|
    {
      acc[n] = v.toStr
    }
    return acc
  }

  ** Decode from a JSON object tree
  static DocDict decode([Str:Obj]? obj)
  {
    if (obj == null || obj.isEmpty) return empty
    return doMake(Etc.dictFromMap(obj))
  }
}

