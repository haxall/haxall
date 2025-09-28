//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Sep 2025  Brian Frank  Creation
//

using xeto
using xetom
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
        case "Bind":    return processBind(x)
        case "If":      return processIf(x)
        case "Foreach": return processFor(x)
      }
    }
    if (x.type.isDict) return processDict(x)
    return ns.instantiate(x)
  }

  private Dict processDict(Spec x)
  {
    acc := Str:Obj[:]
    acc.ordered = true
    autoIndex := 0
    x.slots.each |slot|
    {
      // process slot
      val := process(slot)
      if (val == null) return null

      // check for auto-name
      name := slot.name
      if (XetoUtil.isAutoName(name))
      {
        // if val is a list, then its a spread operation
        if (val is List)
        {
          ((List)val).each |item|
          {
            if (item == null) return
            acc.add(XetoUtil.autoName(autoIndex++), item)
          }
          return
        }

        // ensure serial auto-names
        name = XetoUtil.autoName(autoIndex++)
      }
      acc.add(name, val)
    }
    return Etc.dictFromMap(acc)
  }

  private Obj? processBind(Spec x)
  {
    var(x)
  }

  private Obj? processIf(Spec x)
  {
    cond := var(x)
    if (cond isnot Bool) throw Err("If cond not Bool: $cond")
    if (cond)
    {
      acc := Obj?[,]
      processIt(acc, x, null)
      return acc
    }
    else
    {
      return null
    }
  }

  private Obj? processFor(Spec x)
  {
    coll := var(x)
    if (coll == null) return null
    acc := Obj?[,]
    if (coll is List)
    {
      ((List)coll).each |v| { processIt(acc, x, v) }
    }
    else if (coll is Grid)
    {
      ((Grid)coll).each |v| { processIt(acc, x, v) }
    }
    else throw ArgErr("Expecting For-each to be collection, not $coll.typeof")
    return acc
  }

  private Void processIt(Obj?[] acc, Spec x, Obj? v)
  {
    itStack.push(v)
    x.slots.each |slot|
    {
      acc.add(process(slot))
    }
    itStack.pop
  }

  private Obj? var(Spec spec)
  {
    path := spec.meta["var"]?.toStr ?: throw Err("$spec.type.name missing 'var'")
    names := path.toStr.split('.')
    first := names.first
    val := first == "it" ? itStack.peek : args.getChecked(first)
    if (names.size > 1) throw Err("Dotted path: $path")
    return val
  }

  private TemplateFn fn
  private LibNamespace ns
  private AxonContext cx
  private Str:Obj? args
  private Obj?[] itStack := [,]
}

