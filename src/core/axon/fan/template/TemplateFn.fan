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
    this.gridSpec = ns.sysLib.spec("Grid")
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
    // template processing specs
    if (x.type.lib.name == "sys.template")
    {
      // these can run in or out of a collection builder
      switch (x.type.name)
      {
        case "Bind":    return processBind(x)
      }

      // rest of these can only be run inside a collection type
      if (b == null) throw Err("Cannot run $x.type.name outside of a collection spec")
      switch (x.type.name)
      {
        case "If":      processIfElse(x, b, prev)
        case "Else":    processIfElse(x, b, prev)
        case "Switch":  processSwitch(x, b)
        case "Foreach": processForeach(x, b)
        default:        throw Err("Unknown block type: $x.type.name")
      }
      return null
    }

    // collection processing
    if (x.type.isDict) return processDict(x)
    if (x.type.isComp) return processDict(x)
    if (x.type.isList) return processList(x)
    if (x.type.isa(gridSpec)) return processGrid(x)

    // scalar
    return ns.instantiate(x)
  }

  private Dict processDict(Spec x)
  {
    b := TemplateObjBuilder()
    processBlock(x, b)
    return b.finalizeDict
  }

  private Obj[] processList(Spec x)
  {
    b := TemplateObjBuilder()
    processBlock(x, b)
    return b.finalizeList
  }

  private Grid processGrid(Spec x)
  {
    b := TemplateObjBuilder()
    processBlock(x, b)
    return b.finalizeGrid
  }

  private Obj? processBind(Spec x)
  {
    var(x)
  }

  private Void processIfElse(Spec x, TemplateObjBuilder b, Spec? prev)
  {
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
  }

  private Void processSwitch(Spec x, TemplateObjBuilder b)
  {
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
  }

  private Void processForeach(Spec x, TemplateObjBuilder b)
  {
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
    else
    {
      throw ArgErr("Expecting Foreach to be collection, not $coll.typeof")
    }
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

    // parse out first name
    first := path
    dot := path.index(".")
    if (dot != null)
    {
      first = path[0..<dot]
      //if (first[-1] == '?') first = first[0..-2]
    }

    // get first name from arguments or current "it" variable
    val := first == "it" ? itStack.peek : args.getChecked(first)
    if (dot == null) return val

    // parse dotted path
    names := path.split('.')
    for (i := 1; i < names.size; ++i)
    {
      // get current name without trailing ?
      n := names[i]
      //if (n[-1] == '?') n = n[0..-2]

      // can only path into Dict
      if (val isnot Dict) throw UnresolvedErr("Cannot path $path in value $val [$val.typeof]")
      val = ((Dict)val).get(n)

      // null handling just short circuit
      if (val == null) return null
      /*
      {
        nullSafe := names[i-1][-1] == '?' // prev ended in "?"
        if (nullSafe) return null // okay
        throw UnresolvedErr("Cannot get '$n' in path '$path'")
      }
      */
    }

    return val
  }

  private TemplateFn fn
  private LibNamespace ns
  private AxonContext cx
  private Str:Obj? args
  private Obj?[] itStack := [,]
  private Spec gridSpec
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

  Obj[] finalizeList()
  {
    acc.vals
  }

  Grid finalizeGrid()
  {
    rows := Dict[,]
    acc.each |v|
    {
      row := v as Dict ?: throw Err("Grid row must be dict [$v.typeof]")
      rows.add(row)
    }
    return Etc.makeDictsGrid(null, rows)
  }
}

