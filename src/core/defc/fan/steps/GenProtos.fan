//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 May 2019  Brian Frank  Creation
//

using haystack
using def

**
** GenProtos recursively processes 'children' prototypes
**
internal class GenProtos : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    // only run this if generating a DefDocEnv
    if (!compiler.genDocEnv) return

    // direct subtypes of entity
    entities = index.subtypes(index.etc.entity)

    // process each def
    eachDef |def| { processDef(def) }

    // validate
    acc.each |proto| { if (proto.loc != null) validate(proto) }

    // store generated prototypes
    compiler.index.protosRef = acc.vals.sort
  }

  private Void processDef(CDef def)
  {
    // check for "children" tag on def
    pair := def.meta["children"]
    if (pair == null) return

    try
    {
      // verify tag value is a list of Dicts
      dicts := Dict[,]
      ((List)pair.val).each |item|
      {
        if (item is Dict)
          dicts.add(item)
        else
          err("Invalid children proto type: $def [$item.typeof]", def.loc)
      }

      // process as prototypes
      processDefChildren(def, dicts)
    }
    catch (Err e) err("Cannot process children: $def", def.loc, e)
  }

  private Void processDefChildren(CDef def, Dict[] dicts)
  {
    if (def.children != null) throw Err()
    parent := defToProto(def)
    def.children = computeChildren(parent, dicts, def.loc)
  }

  private Dict defToProto(CDef def)
  {
    usage := index.implements(def) ?: [def]
    acc := Str:Obj[:]
    usage.each |x| { acc[x.name] = Marker.val }
    return Etc.makeDict(acc)
  }

  private CProto[] computeChildren(Dict parent, Obj?[] list, CLoc? loc)
  {
    acc := CProto[,]
    list.each |item|
    {
      dict := item as Dict
      if (dict == null) return // reported in processDef
      cproto := addProto(index.ns.proto(parent, dict), loc)
      acc.add(cproto)
    }
    return acc
  }

  private CProto addProto(Dict dict, CLoc? loc)
  {
    // check if proto already generated
    hashKey := CProto.toHashKey(dict)
    dup := acc[hashKey]
    if (dup != null) return dup.setLoc(loc)

    // compute implemented defs
    reflect := index.ns.reflect(dict)
    implements := index.nsMap(reflect.defs)

    // create prototype and add to our accumulator
    proto := CProto(hashKey, dict, implements).setLoc(loc)
    acc.add(hashKey, proto)
    reflects.add(hashKey, reflect)

    // recurisvely generate children
    children := Str:CProto[:] { ordered = true }
    implements.each |def|
    {
      pair := def.meta["children"]
      if (pair == null) return
      computeChildren(dict, pair.val, null).each |x|
      {
        children[x.hashKey] = x
      }
    }
    proto.children = children.vals

    return proto
  }

  private Void validate(CProto proto)
  {
    // only validate protos with location
    loc := proto.loc
    if (loc == null) return

    // lookup previously computed refletion
    reflect := reflects.getChecked(proto.hashKey)

    // make sure it has one of the core entity tags
    entity := entities.find |e| { proto.dict.has(e.name) }
    if (entity == null)
      err("Missing entity base tag: $proto", loc)

    // verify tag maps to a formal definition
    proto.dict.each |v, n|
    {
      if (reflect.def(n, false) == null)
        err("Invalid proto tag '$n'", loc)
    }

  }

  private Str:CProto acc := [:]
  private Str:Reflection reflects := [:]
  private CDef[]? entities
}


