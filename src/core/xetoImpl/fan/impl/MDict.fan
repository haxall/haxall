//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Feb 2023  Brian Frank  Creation (yet again)
//

using xeto

**
** MDict is used to wrap a Dict with a DataSpec
**
@Js
internal const class MDict : haystack::Dict
{
  new make(Dict wrapped, DataSpec spec)
  {
    this.wrapped = wrapped
    this.spec = spec
  }

  const override DataSpec spec
  const Dict wrapped

  @Operator override Obj? get(Str n, Obj? def := null) { wrapped.get(n, def) }
  override Bool isEmpty() { wrapped.isEmpty }
  override Bool has(Str n) { wrapped.has(n) }
  override Bool missing(Str n) { wrapped.missing(n) }
  override Void each(|Obj, Str| f) { wrapped.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { wrapped.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null) { wrapped.trap(n, a) }

}