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
  static FixLinks load(Str:Str anchors := Str:Str[:])
  {
    libs := XetoEnv.cur.repo.libs
    ns := XetoEnv.cur.createNamespaceFromNames(libs)
    return make(ns, anchors)
  }

  private new make(Namespace ns, Str:Str anchors)
  {
    this.ns = ns
    this.anchors = anchors
  }

  ** Fix link "x".  The oldBase must be old qname such as docHaystack::Overview
  Str fix(Str oldBase, Str x)
  {
    // handle absolute URIs
    if (x.startsWith("/") || x.contains("//")) return x

    // parse base
    if (!oldBase.contains("::")) throw Err("Base must be qname")
    baseLib  := XetoUtil.qnameToLib(oldBase)
    baseName := XetoUtil.qnameToName(oldBase)

    // parse into libName::docName.slotName#frag
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

    // handle funcs without trailing ()
    if (libName == null && frag == null)
    {
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
      newFrag := anchors[oldLib + "::" + docName + "#" + frag] ?: frag
      return newDocLink + "#" + newFrag
    }

    return x
  }

  ** Kitchen sink namespace
  const Namespace ns

  ** Map of old qnames to new anchor names:
  **   docTools::Setup#windowsServices = fantom-programs-as-windows-services
  const Str:Str anchors

  ** Map old doc lib to new doc lib
  Str? toNewDocLib(Str lib)
  {
    switch (lib)
    {
      case "docHaystack": return "ph.doc"
      case "docHaxall":   return "ph.hx.haxall"
      case "docSkySpark": return "ph.hx.skyspark"
      default:            return null
    }
  }

  ** Print warning and return orig link
  Str warn(Str link, Str msg)
  {
    echo("WARN: FixLink - $msg [$link]")
    return link
  }

}

