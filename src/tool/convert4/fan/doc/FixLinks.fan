//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Feb 2026  Brian Frank  Creation
//

using xeto
using xetom

**
** FixLinks is used to convert from 3.x def links to 4.0 xeto links
**
class FixLinks
{
  ** Create a linker instance - this is fairly expensive so a FixLinks
  ** should be created once and then reused.
  static FixLinks load(FandocAnchorMap anchors := FandocAnchorMap.load)
  {
    libs := XetoEnv.cur.repo.libs
    ns := XetoEnv.cur.createNamespaceFromNames(libs)
    return make(ns, anchors)
  }

  private new make(Namespace ns, FandocAnchorMap anchors)
  {
    this.ns = ns
    this.anchors = anchors
  }

  ** Fix link "x".  The oldBase must be old qname such as docHaystack::Overview
  Str fix(Str oldBase, Str x)
  {
    // special pass thrus
    if (specialPassThru.contains(x)) return x

    // handle absolute URIs
    if (x.startsWith("/") || x.contains("//")) return x

    // parse base
    if (!oldBase.contains("::")) throw Err("Base must be qname")
    baseLib  := XetoUtil.qnameToLib(oldBase)
    baseName := XetoUtil.qnameToName(oldBase)

    // handle lib:oldLib
    if (x.startsWith("lib:"))
    {
      libName := oldNameToNewLibName(x[4..-1])
      return libName + "::index"
    }
    // parse into libName::docName.slotName#frag
    orig := x
    Str? libName  := null
    Str? docName  := x
    Str? slotName := null
    Str? frag     := null

    colons := x.index("::")
    if (colons != null)
    {
      libName = x[0..<colons]
      docName = x = x[colons+2..-1]
    }

    pound := x.indexr("#")
    if (pound != null)
    {
      frag    = x[pound+1..-1]
      docName = x = x[0..<pound]
    }

    dot := x.index(".")
    if (dot != null)
    {
      slotName = x[dot+1..-1]
      docName  = x = x[0..<dot]
    }

    // pass thru function()
    if (docName.endsWith("()"))
    {
      if (libName != null) echo("TODO: qname func: $x")
      return x
    }

    // handle lib-oldLib::index or ext-oldLib::doc
    if (libName != null && (libName.startsWith("lib-") || libName.startsWith("ext-")))
    {
      // map "task" to "hx.task"
      newLibName := oldNameToNewLibName(libName[4..-1])

      newPath := newLibName + "::" + docName
      if (frag != null)
      {
        // map new lib name to pod
        podName := SpecBindings.cur.libToPod(newLibName) ?: "-"
        frag = anchors.get(podName + "::pod", frag) ?: frag
        newPath += "#" + frag
      }
      return newPath
    }

    // handle doc#frag relative to current lib
    if (docName == "doc" && frag != null)
    {
      newLibName := oldNameToNewLibName(baseLib)
      podName := SpecBindings.cur.libToPod(newLibName) ?: "-"
      frag = anchors.get(podName + "::pod", frag) ?: frag
      return docName + "#" + frag
    }

    // handle unqualifed simple names
    if (libName == null && slotName == null && frag == null)
    {
      // try as global on PhEntity
      phGlobal := ns.spec("ph::PhEntity").members.get(docName, false)
      if (phGlobal != null) return phGlobal.qname

      // try as slot on types/mixins in my own lib
      m := tryAsMemberInLib(oldNameToNewLibName(baseLib), docName, true)
      if (m != null) return m

      // try as slot in other libs such connFoo -> hx.conn:SomeType.connFoo
      otherLibs := ["conn", "haystack", "obs"]
      for (i := 0; i<otherLibs.size; ++i)
      {
        otherLib := otherLibs[i]
        if (docName.startsWith(otherLib))
        {
          m = tryAsMemberInLib("hx.$otherLib", docName, false)
          if (m != null) return m
        }
      }

      // try as type
      types := ns.unqualifiedTypes(docName.capitalize)
      if (types.size == 1) return types.first.qname

      // if there is a dash, try to map conjunct to camel case
      if (docName.contains("-"))
      {
        typeName := XetoUtil.dashedToCamel(docName).capitalize
        types = ns.unqualifiedTypes(typeName)
        if (types.size == 1) return types.first.qname
      }

      // try as func
      func := ns.funcs.get(docName, false)
      if (func != null) return docName + "()"
    }

    // handle docs
    oldLib := libName ?: baseLib
    newDocLib := toNewDocLib(oldLib)
    if (newDocLib != null)
    {
      // keep it unqualified if that is how it was specified
      newDocLink := libName != null ? newDocLib+"::"+docName : docName
      if (frag == null) return newDocLink

      // handle frag
      podName := oldLib + "::" + (docName?.trimToNull ?: baseName)
      newFrag := anchors.get(podName, frag) ?: frag
      return newDocLink + "#" + newFrag
    }

    // try as Fantom
    if (libName != null)
    {
      pod := Pod.find(libName, false)
      if (pod != null)
      {
        type := pod.type(docName, false)
        if (type != null)
        {
          fan := "fan.$pod.name.lower::$type.name"
          if (slotName != null) fan += "." + slotName
          return fan
        }
      }
    }

    return orig
  }

  private Str? tryAsMemberInLib(Str? libName, Str docName, Bool unqualOk)
  {
    // resolve lib
    lib := ns.lib(libName, false)
    if (lib == null) return null

    // walk all the tops to see if we have member match
    tops := lib.specs.list
    for (i := 0; i<tops.size; ++i)
    {
      top := tops[i]
      m := tops[i].member(docName, false)
      if (m != null)
      {
        if (m.parent == top && unqualOk) return m.parent.name + "." + m.name
        return m.qname
      }
    }

    // no joy
    return null
  }

  ** Kitchen sink namespace
  const Namespace ns

  ** Map of old anchors ids to new ids
  **   docTools::Setup#windowsServices = fantom-programs-as-windows-services
  const FandocAnchorMap anchors

  ** Try to map oldLib name to new one
  Str oldNameToNewLibName(Str oldLib)
  {
    AExt.oldNameToLibName(null, oldLib)
  }

  ** Map old doc lib to new doc lib
  Str? toNewDocLib(Str lib)
  {
    switch (lib)
    {
      case "docIntro":    return "fan.doc.intro"
      case "docLang":     return "fan.doc.lang"
      case "docDomkit":   return "fan.doc.domkit"
      case "docFanr":     return "fan.doc.fanr"
      case "docTools":    return "fan.doc.tools"
      case "docHaystack": return "ph.doc"
      case "docHaxall":   return "hx.doc.haxall"
      case "docSkySpark": return "hx.doc.skyspark"
      case "docFresco":   return "hx.doc.fresco"
      case "docAppNotes": return "hx.doc.appnotes"
      case "docSkydive":  return "hx.doc.skydive"
      case "docTraining": return "hx.doc.training"
      default:            return null
    }
  }

  ** Print warning and return orig link
  Str warn(Str link, Str msg)
  {
    echo("WARN: FixLink - $msg [$link]")
    return link
  }

  Str[] specialPassThru := "association,contains,containedBy,is,relationship,tags,tagOn".split(',')
}

