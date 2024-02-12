//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Apr 2010  Brian Frank  Refactor of axon vs axond
//

using haystack

**
** AxonErr is the base class of `SyntaxErr` and `EvalErr`.
**
@Js
const abstract class AxonErr : Err
{
  new make(Str? msg, Loc loc, Err? cause := null) : super(msg, cause)
  {
    this.loc = loc
  }

  override Str toStr()
  {
    str := super.toStr
    if (!loc.isUnknown) str += " [$loc]"
    return str
  }

  const Loc loc
}

**
** SyntaxErr is thrown during parse phase.
**
@Js
const class SyntaxErr : AxonErr
{
  new make(Str? msg, Loc loc, Err? cause := null) : super(msg, loc, cause) {}
}

**
** EvalErr is thrown during the evaluation phase.
**
@Js
const class EvalErr : AxonErr
{
  new make(Str? msg, AxonContext cx, Loc loc, Err? cause := null) : super(msg, loc, cause)
  {
    axonTrace = cx.traceToStr(loc)
  }

  ** Axon trace of call stack and scope variables
  const Str axonTrace
}

**
** EvalTimeoutErr is thrown when an expr exceeds a timeout
** limit (configured by 'evalTimeout' on 'projMeta' of project).
**
@Js @NoDoc
const class EvalTimeoutErr : EvalErr
{
  new make(Duration timeout, AxonContext cx, Loc loc) : super(msg.toLocale, cx, loc)
  {
    meta = Etc.makeDict(["more":Marker.val, "timeout": timeout.toLocale])
  }

  ** Meta to use for Grid.meta to indicate timeout
  const Dict meta
}

**
** ThrowErr is an exception explicitly thrown by Axon code using a 'throw' expression.
**
@Js @NoDoc
const class ThrowErr : EvalErr
{
  new make(AxonContext cx, Loc loc, Dict tags) : super(tags.dis, cx, loc)
  {
    this.tags = tags
  }

  ** Tags for exception - always has "err" marker and "dis" string.
  const Dict tags
}

