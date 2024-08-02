//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Aug 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::Etc
using haystack::Marker
using haystack::Ref
using haystack::Remove
using haystack::UnknownNameErr

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
  Void eachXMetaLib(|Lib| f)
  {
    // walk loaded libs
    ns.entriesList.each |entry|
    {
      // skip if not loaded
      if (!entry.status.isLoaded) return

      // skip if we didn't mark it containing xmeta
      lib := entry.get
      if (!lib.hasXMeta) return

      f(lib)
    }
  }

  Dict? xmeta(Str qname, Bool checked := true)
  {
    // lookup spec
    spec := ns.spec(qname, checked)
    if (spec == null) return null

    // get meta as map
    acc := Etc.dictToMap(spec.meta)

    // build list of parent specs to check (don't take and/or into account yet)
    instanceNames := Str[,]
    for (p := spec; p != null; p = p.base)
      instanceNames.add(instanceName(p))

    // walk loaded libs with xmeta
    eachXMetaLib |lib|
    {
      // walk the instanceNames to and build up all tags
      instanceNames.each |instanceName|
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
    eachXMetaLib |lib|
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

