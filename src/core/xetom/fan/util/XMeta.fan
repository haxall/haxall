//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Aug 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** Extended meta computation
**
@Js
internal class XMeta
{
  ** Constructor
  new make(MNamespace ns)
  {
    this.ns = ns
  }

  ** Walk each lib that is both loaded and has xmeta
  once Lib[] libs()
  {
    // walk loaded libs that hasXMeta
    ns.libs.findAll |lib| { lib.hasXMeta }
  }

  Dict? xmeta(Str qname, Bool checked := true)
  {
    // lookup spec
    spec := ns.spec(qname, checked)
    if (spec == null) return null

    // get meta as map
    acc := Etc.dictToMap(spec.meta)

    // build list of parent specs to check (don't take and/or into account yet)
    instanceNames := Str:Str[:]
    instanceNames.ordered = true
    addInheritanceInstanceNames(instanceNames, spec)

    // walk the instanceNames from the spec itself down to Obj
    instanceNames.each |instanceName|
    {
      // walk loaded libs with xmeta
      libs.each |lib|
      {
        merge(acc, lib.instance(instanceName, false))
      }
    }

    return Etc.dictFromMap(acc)
  }

  SpecEnum? xmetaEnum(Str qname, Bool checked := true)
  {
    // lookup spec
    spec := ns.spec(qname, checked)
    if (spec == null || !spec.isEnum) return null

    // self meta
    self := xmeta(qname)

    // default key meta from declared
    accByKey := Str:Map[:]
    nameToKey := Str:Str[:]
    spec.enum.each |item, key|
    {
      nameToKey[item.name] = key
      accByKey[key] = Etc.dictToMap(item.meta)
    }

    // walk loaded libs with xmeta
    enumInstanceName := instanceName(spec) + "-enum"
    libs.each |lib|
    {
      xmeta := lib.instance(enumInstanceName, false)
      if (xmeta == null) return
      xmeta.each |v, n|
      {
        // first map name to key (might no be same pL2 vs L2)
        key := nameToKey[n]
        if (key == null) return

        // lookup current xmeta map of Str:Obj
        acc := accByKey[key]
        if (acc == null) return

        // merge in
        merge(acc, v as Dict)
      }
    }

    // turn key maps into dicts
    byKey := accByKey.map |map->Dict| { Etc.dictFromMap(map) }

    // return wraper MEnumXMeta instance
    return MEnumXMeta(spec.enum, self, byKey)
  }

  private Void addInheritanceInstanceNames(Str:Str acc, Spec x)
  {
    name := instanceName(x)
    acc[name] = name
    if (x.isCompound && x.isAnd)
      x.ofs.each |of| { addInheritanceInstanceNames(acc, of) }
    else if (x.base != null)
      addInheritanceInstanceNames(acc, x.base)
  }

  private Str instanceName(Spec spec)
  {
    "xmeta-" + spec.lib.name + "-" + spec.name
  }

  private Void merge(Str:Obj acc, Dict? xmeta)
  {
    if (xmeta == null) return
    xmeta.each |v, n|
    {
      if (acc[n] == null && n != "id" && n != "spec") acc[n] = v
    }
  }

  const MNamespace ns
}

