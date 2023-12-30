//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Aug 2023  Brian Frank  Creation
//

using xeto

**
** MNameDict is used to wrap a NameDict so it can be a haystack::Dict.
** Eventually once we get rid of haystack::Dict this class can go away.
**
@Js
const class MNameDict : haystack::Dict
{
  static const MNameDict empty := make(NameDict.empty)

  static new wrap(NameDict wrapped)
  {
    if (wrapped.isEmpty) return empty
    return make(wrapped)
  }

  private new make(NameDict wrapped)
  {
    this.wrapped = wrapped
  }

  const NameDict wrapped

  override Bool isEmpty() { wrapped.isEmpty }
  override Bool has(Str n) { wrapped.has(n) }
  override Bool missing(Str n) { wrapped.missing(n) }
  @Operator override Obj? get(Str n, Obj? def := null) { wrapped.get(n, def) }
  override Void each(|Obj, Str| f) { wrapped.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { wrapped.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null) { wrapped.trap(n, a) }

}