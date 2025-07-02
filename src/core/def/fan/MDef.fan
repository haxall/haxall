//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Jan 2019  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using haystack::Lib

**
** Def implementation
**
@NoDoc @Js
const class MDef : Def
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor with builder stub
  new make(BDef b)
  {
    this.symbol = b.symbol
    this.libRef = b.libRef
    this.meta   = b.meta
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Symbol key
  const override Symbol symbol

  ** Return simple name of definition
  override Str name() { symbol.name }

  ** Declaring lib
  override Lib lib() { libRef.val }
  internal const AtomicRef libRef

  ** Wrapped normalized meta data
  const Dict meta

  ** Return symbol string
  override Str toStr() { symbol.toStr }

  ** Equality is based on reference
  override final Bool equals(Obj? that) { this === that }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  @Operator override Obj? get(Str n, Obj? def := null) { meta.get(n, def) }
  override Bool isEmpty() { false }
  override Bool has(Str n) { meta.has(n) }
  override Bool missing(Str n) { meta.missing(n) }
  override Void each(|Obj, Str| f) { meta.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { meta.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null) { meta.trap(n, a) }

//////////////////////////////////////////////////////////////////////////
// Cache Fields
// NOTE: most caching must be in MLazy per namespace
//////////////////////////////////////////////////////////////////////////

  const AtomicRef inheritanceRef := AtomicRef(null)

}

