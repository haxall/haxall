//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Nov 2018  Brian Frank  Creation
//

using concurrent
using haystack

**
** Namespace implementation created from DefBuilder
**
@NoDoc @Js
const class MBuiltNamespace : MNamespace
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** DefBuilder constructor
  new make(BNamespace b)
  {
    b.ref.val = this
    this.defsMap      = b.defsMap
    this.features     = b.features
    this.featuresMap  = b.featuresMap
    this.libsList     = b.libs
    this.libsMap      = b.libsMap
    this.filetypes    = b.filetypes
    this.filetypesMap = b.filetypesMap
    this.quick        = MQuick(this)
  }

//////////////////////////////////////////////////////////////////////////
// MNamespace
//////////////////////////////////////////////////////////////////////////

  override const MQuick quick

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  override Def? def(Str symbol, Bool checked := true)
  {
    def := defsMap[symbol]
    if (def != null) return def
    if (checked) throw UnknownDefErr(symbol.toStr)
    return null
  }

  override Def[] defs()
  {
    defsMap.vals
  }

  override Void eachDef(|Def| f)
  {
    defsMap.each(f)
  }

  override Obj? eachWhileDef(|Def->Obj?| f)
  {
    defsMap.eachWhile(f)
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

  override const Filetype[] filetypes

  override Filetype? filetype(Str name, Bool checked := true)
  {
    f := filetypesMap[name]
    if (f != null) return f
    if (checked) throw UnknownFiletypeErr(name)
    return null
  }


//////////////////////////////////////////////////////////////////////////
// Xeto
//////////////////////////////////////////////////////////////////////////

  ** Xeto environment
  override xeto::XetoEnv xetoEnv() { xeto::XetoEnv.cur }

  ** Xeto libs imported into namespace
  override xeto::Lib[] xetoLibs() { xeto::Lib#.emptyList }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal const Str:Def defsMap
  internal const Str:Feature featuresMap
  internal const Str:Lib libsMap
  internal const Str:Filetype filetypesMap
}

