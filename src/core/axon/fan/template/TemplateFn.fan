//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Sep 2025  Brian Frank  Creation
//

using xeto
using haystack
using concurrent

**
** TemplateFn is an function that processes a declarative xeto template
**
@Js @NoDoc
const class TemplateFn : TopFn
{
  new make(Spec spec, Dict meta, FnParam[] params)
    : super(Loc(spec.name), spec.name, meta, params, Literal.nullVal)
  {
    this.spec = spec
  }

  const Spec spec

  override Obj? doCall(AxonContext cx, Obj?[] args)
  {
    Templater(this, cx, args).call
  }
}

**************************************************************************
** Templater
**************************************************************************

@Js
internal class Templater
{
  new make(TemplateFn fn, AxonContext cx, Obj?[] args)
  {
    this.fn   = fn
    this.cx   = cx
    this.ns   = cx.ns
    this.args = toArgMap(fn, args)
  }

  private static Str:Obj toArgMap(TemplateFn fn, Obj?[] args)
  {
    map := Str:Obj?[:]
    fn.spec.func.params.each |p, i|
    {
      val := args.getSafe(i)
      map[p.name] = val  // don't handle def values
    }
    return map
  }

  Obj? call()
  {
    process(fn.spec.slot("returns"))
  }

  private Obj? process(Spec x)
  {
    if (x.type.lib.name == "sys.template")
    {
      switch (x.type.name)
      {
        case "Bind": return processBind(x)
      }
    }
    if (x.type.isDict) return processDict(x)
    return ns.instantiate(x)
  }

  private Dict processDict(Spec x)
  {
    acc := Str:Obj[:]
    acc.ordered = true
    x.slots.each |slot|
    {
      acc.addNotNull(slot.name, process(slot))
    }
    return Etc.dictFromMap(acc)
  }

  private Obj? processBind(Spec x)
  {
    resolve(x.meta["to"] ?: throw Err("Bind missing 'to' meta"))
  }

  Obj? resolve(Obj path)
  {
    names := path.toStr.split('.')
    val := args.getChecked(names.first)
    if (names.size > 1) throw Err("Dotted path: $path")
    return val
  }

  private TemplateFn fn
  private LibNamespace ns
  private AxonContext cx
  private Str:Obj? args
}

