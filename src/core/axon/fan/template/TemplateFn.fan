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
    process(fn.spec.slot("returns"), null, null)
  }

  private Obj? process(Spec x, TemplateObjBuilder? b, Spec? prev)
  {
    if (x.type.lib.name == "sys.template")
    {
      switch (x.type.name)
      {
        case "Bind":    return processBind(x)
        case "If":      return processIfElse(x, b, prev)
        case "Else":    return processIfElse(x, b, prev)
        case "Switch":  return processSwitch(x, b)
        case "Foreach": return processForeach(x, b)
      }
    }
    if (x.type.isDict) return processDict(x)
    return ns.instantiate(x)
  }

  private Dict processDict(Spec x)
  {
    b := TemplateObjBuilder()
    processBlock(x, b)
    return b.finalizeDict
  }

  private Obj? processBind(Spec x)
  {
    var(x)
  }

  private Obj? processIfElse(Spec x, TemplateObjBuilder? b, Spec? prev)
  {
    if (b == null) throw Err("Cannot use If/Else outside of container obj")

    ifClause := x
    isElse := false
    if (x.type.name == "Else")
    {
      if (prev == null || prev.type.name != "If") throw Err("Unexpected Else block")
      ifClause = prev
      isElse = true
    }

    cond := var(ifClause)
    if (cond isnot Bool) throw Err("If cond not Bool: $cond")
    if (isElse) cond = !cond

    if (cond) processBlock(x, b)

    return null  // only used in obj builder
  }

  private Obj? processSwitch(Spec x, TemplateObjBuilder? b)
  {
    isTop := b == null
    if (b == null) b = TemplateObjBuilder()

    cond := var(x)
    if (cond == null) return null


    Spec? match := null
    Spec? def := null
    x.slots.each |slot|
    {
      if (def != null) throw Err("Unexpected Switch block after Default")
      switch (slot.type.qname)
      {
        case "sys.template::Case":
           matchVal := slot.meta["match"] ?: throw Err("Case missing 'match' meta tag")
           if (cond == matchVal && match == null) match = slot
        case "sys.template::Default":
          def = slot
        default: throw Err("Unexpected Switch block: $slot.type")
      }
    }

    if (match == null) match = def
    if (match != null) processBlock(match, b)

    return isTop ? b.finalizeObj : null
  }

  private Obj? processForeach(Spec x, TemplateObjBuilder? b)
  {
    isTop := b == null
    if (b == null) b = TemplateObjBuilder()

    coll := var(x)
    if (coll == null) return null

    if (coll is List)
    {
      ((List)coll).each |v| { processIt(x, b, v) }
    }
    else if (coll is Grid)
    {
      ((Grid)coll).each |v| { processIt(x, b, v) }
    }
    else throw ArgErr("Expecting Foreach to be collection, not $coll.typeof")
    return isTop ? b.finalizeObj : null
  }

  private Void processIt(Spec x, TemplateObjBuilder b, Obj? v)
  {
    itStack.push(v)
    processBlock(x, b)
    itStack.pop
  }

  private Void processBlock(Spec x, TemplateObjBuilder b)
  {
    Spec? prev := null
    x.slots.each |slot|
    {
      b.add(slot.name, process(slot, b, prev))
      prev = slot
    }
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

**************************************************************************
** TemplateObjBuilder
**************************************************************************

@Js
internal class TemplateObjBuilder
{
  Str:Obj acc := [:] { ordered = true }
  Int autoIndex

  Void add(Str name, Obj? val)
  {
    if (val == null) return

    if (XetoUtil.isAutoName(name)) name = XetoUtil.autoName(autoIndex++)

    acc.add(name, val)
  }

  Obj? finalizeObj()
  {
    if (acc.size == 1 && acc.keys.first == "_0") return acc["_0"]
    return finalizeDict
  }

  Dict finalizeDict()
  {
    Etc.dictFromMap(acc)
  }
}

