//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jan 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** Feature implementation
**
@NoDoc @Js
const class MFeature : Feature
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor with builder stub
  new make(BFeature b)
  {
    this.name   = b.name
    this.prefix = name + ":"
    this.nsRef  = b.nsRef
  }

  ** Create copy of this feature for overlay namespace
  internal MFeature overlay(AtomicRef overlayNsRef)
  {
    typeof.make([BFeature(name, overlayNsRef)])
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Feature name such as "filetype"
  const override Str name

  ** Symbol prefix such as "filetype:"
  const Str prefix

  ** Parent namespace
  Namespace ns() { nsRef.val }
  private const AtomicRef nsRef

//////////////////////////////////////////////////////////////////////////
// Feature
//////////////////////////////////////////////////////////////////////////

  ** Return feature def itself
  override Def self() { ns.def(name) }

  ** Resolve a definition by name within this feature namespace
  override Def? def(Str name, Bool checked := true)
  {
    def := ns.def(nameToSymbol(name), false)
    if (def != null) return def
    if (checked) throw createUnknownErr(name)
    return null
  }

  ** Build a list of all defs within this feature.  This call
  ** can be expensive so prefer `eachDef` or `findDefs`.
  override Def[] defs()
  {
    acc := allocList(listCapacity.val)
    eachDef |def| { acc.add(def) }
    listCapacity.val = acc.size
    return acc
  }
  private const AtomicInt listCapacity := AtomicInt(32)

  ** Iterate all the definitions within this feature namespace
  override Void eachDef(|Def| f)
  {
    ns.eachDef |def|
    {
      if (def.symbol.type.isKey && def.symbol.toStr.startsWith(prefix)) f(def)
    }
  }

  ** Find all defs which match given predicate function
  override Def[] findDefs(|Def->Bool| f)
  {
    acc := allocList(32)
    eachDef |def| { if (f(def)) acc.add(def) }
    return acc
  }

  ** Flatten to grid
  override final Grid toGrid()
  {
    Etc.makeDictsGrid(null, defs.sort)
  }

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  ** Is this the feature for Filetype
  virtual Bool isFiletype() { false }

  ** Primary mixin type such as Filetype#
  virtual Type defType() { Def# }

  ** Construct MDef subclass such as MFiletype
  virtual Def createDef(BDef b) { MDef(b) }

  ** Make UnknownXxxxErr
  virtual Err createUnknownErr(Str name) { UnknownDefErr(name) }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Allocate list of the proper Def subclass type
  private Def[] allocList(Int capacity)
  {
    List(defType, capacity)
  }

  ** Convert name such as "zinc" to a symbol such as "filetype:zinc"
  private Str nameToSymbol(Str name)
  {
    StrBuf(prefix.size + name.size).add(prefix).add(name).toStr
  }

}

