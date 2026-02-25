//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Sep 2009  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** Top level function in the namespace
**
@Js
const class TopFn : Fn, Thunk
{
  new make(Loc loc, Str name, Dict meta, FnParam[] params, Expr body := Literal.nullVal)
    : super(loc, name, params, body)
  {
    this.meta = meta
    this.isSu         = meta.has("su")
    this.isAdmin      = this.isSu || meta.has("admin")
    this.isDeprecated = meta.has("deprecated")
  }

  ** Func def metadata
  override const Dict meta

  ** Qualified name if function was resolved against xeto namespace
  const Str? qname

  ** Return true
  override Bool isTop() { true }

  ** Is this function tagged as admin-only
  const override Bool isAdmin

  ** Is this function tagged as superuser-only
  const override Bool isSu

  ** Return if this function has been deprecated
  const override Bool isDeprecated

  ** Is this a lazy function that accepts un-evaluated arguments
  virtual Bool isLazy() { false }

  ** Return only name
  override Str toStr() { name }

  ** Thunk.callList implementation
  override Obj? callList(Obj?[]? args := null)
  {
    call(AxonContext.curAxon, args ?: noArgs)
  }

  ** Thunk.callComp implementation
  override Obj? callComp(Comp self, Obj? arg)
  {
    AxonContext.curAxon.callInNewFrame(this, [arg], Loc.unknown, ["this":self])
  }

  ** Add check call
  @NoDoc override Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    cx.checkCall(this)
    return super.callx(cx, args, callLoc)
  }

  ** Display string taking into account old tags in defMeta
  Str dis()
  {
    defMeta := meta["defMeta"] as Dict ?: Etc.dict0

    disKey := meta["disKey"] ?: defMeta["disKey"]
    if (disKey != null) return Etc.disKey(disKey.toStr)

    dis := meta["dis"] ?: defMeta["dis"]
    if (dis != null) return dis.toStr

    return name
  }

  internal static const Obj?[] noArgs := Obj?[,]
}

