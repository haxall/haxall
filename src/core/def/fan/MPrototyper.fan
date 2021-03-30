//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 May 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** Generator for Namespace.proto
**
@NoDoc @Js
internal class MPrototyper
{
  ** Constructor
  new make(MNamespace ns, Dict parent)
  {
    this.ns = ns
    this.parent = parent
    this.parentReflect = ns.reflect(parent)
  }

  ** Implementation for 'Namespace.proto' and 'Namespace.protos'
  Dict[] generate(Dict? proto)
  {
    computeFlattenTags
    computeRefTags
    process(proto)
    return results
  }

//////////////////////////////////////////////////////////////////////////
// Compute Flatten Tags
//////////////////////////////////////////////////////////////////////////

  ** Reflect all the defs implemented by the parent and compute
  ** list of tags which are "flattened" into children protos.  For
  ** example children of a 'duct' will flatten the specific 'ductSection'.
  private Void computeFlattenTags()
  {
    // walk each def implemented by the parent
    flattenTerms := Def[,]
    parentReflect.defs.each |implemented|
    {
      // check for 'childrenFlatten' tag on the def
      cf := implemented["childrenFlatten"]
      if (cf == null) return

      // check each of the childrenFlatten tags and see if applies
      DefUtil.resolveList(ns, cf).each |toFlatten|
      {
        flattenTerms.addNotNull(applyFlattenTag(parentReflect, toFlatten))
      }
    }

    // turn terms (which might include conjuncts) into marker tag names
    this.flattenTagNames = DefUtil.termsToTags(flattenTerms)
  }

  ** If given def should be flattened into children of current parent
  ** then return tag to apply.  For example if flattening 'ductSectionType'
  ** and the parent has 'discharge' then return "discharge" to add
  ** as a marker into all the children
  private Def? applyFlattenTag(Reflection parentReflect, Def toFlatten)
  {
    // ensure its a tag and not a conjunct or something else
    if (!toFlatten.symbol.type.isTag) throw Err("Invalid childrenFlatten tag: $toFlatten")

    // find any term in parent that fits tag to flatten
    return parentReflect.defs.find |parentTerm| { ns.fits(parentTerm, toFlatten) }
  }

//////////////////////////////////////////////////////////////////////////
// Compute Ref Tags
//////////////////////////////////////////////////////////////////////////

  ** Apply any refs that model containedBy
  private Void computeRefTags()
  {
    acc := Str:Ref[:]
    parentId := parent["id"] as Ref

    // walk all the containedBy tags
    ns.lazy.containedByRefs.each |refDef|
    {
      // if parent has this tag, then copy it into children
      refName := refDef.name
      val := parent[refName] as Ref
      if (val != null) acc[refName] = val

      // check if parent itself is target of this ref
      if (parentId != null)
      {
        of := DefUtil.resolve(ns, refDef["containedBy"])
        if (of != null && of.symbol.hasTerm(parent))
          acc[refName] = parentId
      }
    }

    this.refTags = acc
  }

//////////////////////////////////////////////////////////////////////////
// Process
//////////////////////////////////////////////////////////////////////////

  ** Generate explicit proto or using reflection
  private Void process(Dict? proto)
  {
    if (proto != null)
      processDict(proto)
    else
      processReflect
  }

  ** Generate children from all implemented defs
  private Void processReflect()
  {
    // optimize to never expand "points"
    if  (parent.has("point")) return

    parentReflect.defs.each |def|
    {
      children := def["children"] as List
      if (children != null) processList(children)
    }
  }

  ** Generate a list of proto dicts
  private Void processList(Obj?[] children)
  {
    children.each |x|
    {
      if (x isnot Dict) return
      processDict(x)
    }
  }

  ** Process a single dict to a proto
  private Void processDict(Dict declared)
  {
    // if we have already processed a dict that looks like this skip it
    key := Etc.dictHashKey(declared)
    if (processed[key] != null) return
    processed[key] = key

    // map tags to an accumulator maintaining declared order
    acc := Str:Obj[:] { ordered = true }

    // first add flattening marker tags
    flattenTagNames.each |tagName| { acc[tagName] = Marker.val }

    // add declare tags
    declared.each |v,n| { if (v != null) acc[n] = v }

    // default dis/navName
    addDis(acc)

    // add ref tags
    refTags.each |v, n| { acc[n] = v }

    // add to our accumulators
    results.add(Etc.makeDict(acc))
  }

  private Void addDis(Str:Obj acc)
  {
    if (!ns.isSkySpark) return
    if (acc["site"] != null) return
    s := StrBuf()
    tag := "dis"
    acc.each |v, n|
    {
      if (v != Marker.val) return
      if (n == "space" || n == "equip" || n == "point")
      {
        tag = "navName"
      }
      else
      {
        s.join(n.capitalize, "-")
      }
    }
    if (s.isEmpty || acc[tag] != null) return
    acc[tag] = s.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns
  const Dict parent
  const Reflection parentReflect
  private Str[]? flattenTagNames
  private [Str:Ref]? refTags
  private Obj:Obj processed := [:]
  private Dict[] results := [,]
}