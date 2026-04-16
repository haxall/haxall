//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Nov 2023  Brian Frank  Creation
//   21 May 2024  Brian Frank  Port into xetoEnv
//

using util
using xeto
using haystack

**
** CompUtil
**
@Js
class CompUtil
{

  ** Return if name is a slot that cannot be directly changed in an Comp
  static Bool isReservedSlot(Str name)
  {
    name == "id" || name == "spec"
  }

  ** Check that the xeto can be loaded or raise exception
  static Void checkLoad(Namespace ns, Str xeto)
  {
    parse(ns, xeto)
  }

  ** Parse xeto to dict root
  internal static Dict parse(Namespace ns, Str xeto)
  {
    ns.io.readXeto(xeto) as Dict ?: throw Err("Expecting one dict root")
  }

  static Dict compSaveToAstSlots(Comp comp, Str name, Dict? opts := null)
  {
    // map all component paths by id so we can efficiently resolve links
    byId := Ref:Str[:]
    todo := Comp[,]
    Comp? cur  := comp
    while (cur != null)
    {
      path := byId[cur.id]
      cur.eachChild |child, childName|
      {
        byId[child.id] = path == null ? childName : "${path}.${childName}"
        todo.push(child)
      }
      cur = todo.pop
    }
    return doCompSaveToAstSlots(comp, name, byId, opts ?: Etc.dict0)
  }

  private static Dict doCompSaveToAstSlots(Comp comp, Str name, Ref:Str byId, Dict opts)
  {
    ast   := Str:Obj?[:]
    ast["name"]  = name
    ast["type"]  = comp.spec.type.id
    ast["maybe"] = comp.spec.isMaybe ? Marker.val : null

    slots := Dict[,]
    comp.each |val, slotName|
    {
      // links need to be encoded as slot meta
      if (slotName == "links") return

      links := comp.links.listOn(slotName)
      if (links.size > 1) throw UnsupportedErr("TODO:FIXIT handle fan-in link encoding")

      slotSpec := comp.spec.slot(slotName)
      if (slotSpec.isTransient) return

      // slot tags
      slot := Str:Obj?[:]

      // slot meta
      slotSpec.metaOwn.each |v, n|
      {
        // we handle link and val encoding special
        if (n == "val") return
        slot[n] = v
      }

      if (slotSpec.isComp)
      {
        // TODO:FIXIT - can you link into a comp?
        slot.addAll(Etc.dictToMap(doCompSaveToAstSlots(val, slotName, byId, opts)))
        // slots.add(doCompSaveToAstSlots(val, slotName, byId, opts))
      }
      else
      {
        slot["name"]  = slotName
        slot["type"]  = slotSpec.type.id
        slot["maybe"] = slotSpec.isMaybe ? Marker.val : null
        slot["val"]   = XetoUtil.toHaystack(val)
        link := links.first
        if (link != null)
        {
          compPath := byId[link.fromRef]
          if (compPath == null) echo("BROKEN LINK: ${link} ${compPath} ${byId}")
          slot["link"] = "${compPath}.${link.fromSlot}"
        }
      }
      slots.add(Etc.makeDict(slot))
    }

    echo("=== ${comp} ($name)")
    echo(ast)
    if (!slots.isEmpty)
    {
      g := Etc.makeDictsGrid(null, slots)
      g.dump
      ast["slots"] = g
    }
    return Etc.makeDict(ast)
  }

  ** Encode a component into a xeto string
  ** Options:
  **   - noId: Marker to remove id from display
  static Str compSaveToXeto(Namespace ns, Comp comp, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    dict := compSaveToDict(comp, opts)
    if (opts.has("noId")) dict = Etc.dictRemove(dict, "id")
    return ns.io.writeXetoToStr(dict, opts)
  }

  ** Encode a component into a sys.comp::Comp dict representation (with children)
  static Dict compSaveToDict(Comp comp, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    acc := Str:Obj[:]
    spec := comp.spec
    links := comp.links
    acc["id"] = comp.id
    acc["spec"] = comp.spec.id
    comp.each |v, n|
    {
      // skip transients
      slot := spec.slot(n, false)
      if (slot != null && slot.meta.has("transient")) return

      // skip default scalar values if not maybe
      if (slot != null && !slot.isMaybe && v == slot.meta["val"]) return

      // strip dict defaults
      if (slot != null && v is Dict) v = compSaveDictStripDefaults(slot.type, v)

      // skip linked slots
      if (links.isLinked(n)) return

      // recurse component sub-tree
      if (v is Comp) v = compSaveToDict(v, opts)

      // save this name/value pair
      acc[n] = v
    }
    return Etc.dictFromMap(acc)
  }

  ** Strip dict tags that are defaults
  static Dict compSaveDictStripDefaults(Spec type, Dict dict)
  {
    acc := Str:Obj[:]
    dict.each |v, n|
    {
      slot := type.slot(n, false)
      if (n != "spec" && slot != null && !slot.isMaybe && v == slot.meta["val"]) return
      if (n == "dis" && v == type.name) return
      acc[n] = v
    }
    return Etc.dictFromMap(acc)
  }

  ** Return true if the spec is a link root
  static Bool isLinkRoot(Spec spec)
  {
    spec.parent == null || !spec.parent.isComp
  }

  ** Given slot spec, get top-level type that scopes declaration of 'link' meta tag
  static Spec toLinkScope(Spec slot)
  {
    p := slot.parent
    while (!isLinkRoot(p)) p = p.parent
    return p
  }

  ** Get the root component to use for link path resolution.
  static Comp toLinkRoot(Comp comp, Spec slot)
  {
    // get type that scopes the link meta tag declaration
    scope := toLinkScope(slot)

    // walk up my comp tree to find that type
    while (comp.spec.type !== scope)
    {
      if (comp.parent == null)
      {
        if (comp.spec.type !== scope.type)
          Console.cur.warn("CompUtil.toLinkRoot $scope, $comp, $comp.spec.type")
        return comp
      }
      comp = comp.parent
    }

    return comp
  }

  ** Encode a component into a sys.comp::Comp dict representation (no children)
  static Dict toFeedDict(Comp comp)
  {
    acc := Str:Obj[
      "id":   comp.id,
      "spec": comp.spec.id,
    ]
    comp.each |v, n|
    {
      if (v is Comp) return
      acc[n] = v
    }
    return Etc.dictFromMap(acc)
  }

  ** Return grid format used for BlockView feed protocol
  static Grid toFeedGrid(Dict gridMeta, Str cookie, Dict[] dicts, [Ref:Ref]? deleted)
  {
    gb := GridBuilder()
    gb.capacity = dicts.size + (deleted == null ? 0 : deleted.size)
    if (gridMeta.isEmpty) gb.setMeta(Etc.dict1("cookie", cookie))
    else gb.setMeta(Etc.dictSet(gridMeta, "cookie", cookie))
    gb.addCol("id").addCol("comp")
    dicts.each |dict|
    {
      gb.addRow2(dict.id, dict)
    }
    if (deleted != null)
    {
      deleted.each |id| { gb.addRow2(id, null) }
    }
    return gb.toGrid
  }

}

