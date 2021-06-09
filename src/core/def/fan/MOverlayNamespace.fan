//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Feb 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** MOverlayNamespace is used to wrap a base namespace and add an
** optional overlay library.
**
** The overlay can enable/disable specific libs from the base.  This
** is controlled by the enabled function passed into the constructor.
** It is implemented via a Bool list which is indexed by the Lib.index
** method for fast lookup.  Any lookup or iteration of the defs delegates
** to the base, but must check the def's lib enabled state.  In this
** way we share all the def instances and lookup tables of the base.
**
** Because Features are also used to lookup and iterate defs, we must clone
** each of the Features for the overlay with a reference to this namespace.
** We create custom lib lookup tables based on their enabled state.  We
** assume that all filetypes from base are enabled in the overlay; their
** lookup is delegated to the base because they use a special map which
** includes MimeType keys.
**
** MOverlayNamespace can include an optional MOverlayLib which sits above
** the enabled libs from the base.  It has the ability to override defs
** from the base.
**
@NoDoc @Js
const class MOverlayNamespace : MNamespace
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(Namespace base, MOverlayLib? olib, |Lib->Bool| enabled)
  {
    ref := AtomicRef(this)
    this.base        = base
    this.olib        = olib
    this.enabled     = base.libsList.map |lib->Bool| { enabled(lib) }
    this.libsList    = toLibsList(base, this.enabled, olib)
    this.libsMap     = Str:Lib[:].addList(this.libsList) { it.name }
    this.features    = base.features.map |MFeature f->Feature| { f.overlay(ref) }
    this.featuresMap = Str:Feature[:].addList(this.features) { it.name }
  }

  private static Lib[] toLibsList(Namespace base, Bool[] enabled, MOverlayLib? olib)
  {
    acc := base.libsList.findAll |lib| { enabled[lib.index] }
    if (olib != null) acc.add(olib)
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Base namespace to delegate to
  internal const MBuiltNamespace base

  ** Extra project specific library defs
  internal const MOverlayLib? olib

  ** Return if given library is enabled by this overlay
  Bool isEnabled(Lib lib) { enabled[lib.index] }
  private const Bool[] enabled

//////////////////////////////////////////////////////////////////////////
// MNamespace
//////////////////////////////////////////////////////////////////////////

  override MQuick quick() { base.quick }

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  override Def? def(Str symbol, Bool checked := true)
  {
    if (olib != null)
    {
      odef := olib.def(symbol, false)
      if (odef != null) return odef
    }
    def := base.def(symbol, false)
    if (def != null && isEnabled(def.lib)) return def
    if (checked) throw UnknownDefErr(symbol.toStr)
    return null
  }

  override Def[] defs()
  {
    capacity := base.defsMap.size
    if (olib != null) capacity += olib.defs.size
    acc := Def[,]
    acc.capacity = capacity
    eachDef |def| { acc.add(def) }
    return acc
  }

  override Void eachDef(|Def| f)
  {
    if (olib != null) olib.defs.each(f)
    base.eachDef |def|
    {
      if (olib != null && olib.hasDef(def.symbol.toStr)) return
      if (isEnabled(def.lib)) f(def)
    }
  }

  override Obj? eachWhileDef(|Def->Obj?| f)
  {
    if (olib != null)
    {
      r := olib.defs.eachWhile(f)
      if (r != null) return r
    }
    return base.eachWhileDef |def->Obj?|
    {
      if (olib != null && olib.hasDef(def.symbol.toStr)) return null
      if (isEnabled(def.lib)) return f(def)
      return null
    }
  }

  override const Feature[] features

  override Feature? feature(Str name, Bool checked := true)
  {
    f := featuresMap[name]
    if (f != null) return f
    if (checked) throw UnknownFeatureErr(name)
    return null
  }

  override const Lib[] libsList

  override Lib? lib(Str name, Bool checked := true)
  {
    f := libsMap[name]
    if (f != null) return f
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override Filetype[] filetypes()
  {
    base.filetypes
  }

  override Filetype? filetype(Str name, Bool checked := true)
  {
    base.filetype(name, checked)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal const Str:Lib libsMap
  internal const Str:Feature featuresMap
}

