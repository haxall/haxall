//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Aug 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** JSON Exporter
**
@Js
class JsonExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  override This start()
  {
    w("{").nl
  }

  override This end()
  {
    nl.w("}").nl
  }

  override This lib(Lib lib)
  {
    prop(lib.name).obj
    libPragma(lib)
    lib.specs.each |x| { doSpec(x.name, x, 0) }
    nonNestedInstances(lib).each |x| { instance(x) }
    objEnd.propEnd
    return this
  }

  override This spec(Spec spec)
  {
    doSpec(spec.qname, spec, 0)
    return this
  }

  override This instance(Dict instance)
  {
    relId := XetoUtil.qnameToName(instance.id.id)
    prop(relId).obj

    spec := instance["spec"]
    if (spec != null) dictPair("spec", spec)

    instance.each |v, n|
    {
      if (n == "spec") return
      dictPair(n, v)
    }

    objEnd.propEnd
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Xeto Constructs
//////////////////////////////////////////////////////////////////////////

  ** Library pragma is the library meta
  private This libPragma(Lib lib)
  {
    prop("pragma").obj
    meta(lib.meta)
    objEnd.propEnd
    return this
  }

  ** Spec implementation with given qname or name
  private This doSpec(Str name, Spec spec, Int depth)
  {
    prop(name).obj
    prop("id").val(spec.id).propEnd
    prop("spec").val(specRef).propEnd
    if (spec.isType) specBase(spec)
    else specType(spec)
    effective := this.isEffective && depth <= 1
    meta(effective  ? spec.meta  : spec.metaOwn)
    slots(effective ? spec.slots : spec.slotsOwn, depth)
    objEnd.propEnd
    return this
  }

  ** Spec type
  private This specType(Spec spec)
  {
    prop("type").str(spec.type.qname).propEnd
  }

  ** Spec base
  private This specBase(Spec spec)
  {
    if (spec.base == null) return this
    return prop("base").str(spec.base.qname).propEnd
  }

  ** Spec slots
  private This slots(SpecMap slots, Int depth)
  {
    if (slots.isEmpty) return this
    prop("slots").obj
    slots.each |slot| { doSpec(slot.name, slot, depth+1) }
    objEnd.propEnd
    return this
  }

  ** Write meta data tags - does not include {}
  private This meta(Dict meta)
  {
    tags := Etc.dictNames(meta)
    tags.moveTo("version", 0)
    tags.each |n| { dictPair(n, meta[n]) }
    return this
  }

  ** value
  private This val(Obj x)
  {
    if (x is Dict) return dict(x)
    if (x is List) return list(x)
    if (x === Marker.val) return str("\u2713")
    if (x is Bool) return literal(x.toStr)
    if (x is Float) return str(Number.make(x).toStr)
    return str(x.toStr)
  }

  private This dict(Dict x)
  {
    obj
    x.each |v, n| { dictPair(n, v) }
    objEnd
    return this
  }

  private This dictPair(Str n, Obj v)
  {
    prop(n).val(v).propEnd
  }

  private This list(Obj[] x)
  {
    obj("[")
    x.each |item|
    {
      open.indent.val(item).close
    }
    objEnd("]")
    return this
  }

//////////////////////////////////////////////////////////////////////////
// JSON Constructors
//////////////////////////////////////////////////////////////////////////

  ** Open a new value to deal with trailing comma
  private This open()
  {

    if (firsts.peek) firsts[-1] = false
    else w(",").nl
    firsts.push(true)
    lastWasEnd = false
    return this
  }

  ** Close a value to deal with trailing comma
  private This close()
  {
    if (lastWasEnd) nl
    firsts.pop
    lastWasEnd = true
    return this
  }

  ** Start property
  private This prop(Str name)
  {
    open.indent.str(name).w(": ")
  }

  ** End property
  private This propEnd()
  {
    close
  }

  ** Start object - does **not** start value
  private This obj(Str bracket := "{")
  {
    w(bracket).nl
    indentation++
    return this
  }

  ** End object - does endVal
  private This objEnd(Str bracket := "}")
  {
    if (lastWasEnd) nl
    lastWasEnd = false
    indentation--
    indent.w(bracket)
    return this
  }

  ** String literal
  private This str(Str s)
  {
    wc('"')
    s.each |char|
    {
      switch (char)
      {
        case '\b': wc('\\').wc('b')
        case '\f': wc('\\').wc('f')
        case '\n': wc('\\').wc('n')
        case '\r': wc('\\').wc('r')
        case '\t': wc('\\').wc('t')
        case '\\': wc('\\').wc('\\')
        case '"':  wc('\\').wc('"')
        default:
          if (char < 0x20)
            wc('\\').wc('u').w(char.toHex(4))
          else
            wc(char)
      }
    }
    wc('"')
    return this
  }

  ** Unquoted literal
  private This literal(Str s)
  {
    s.each |char| { wc(char) }
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Bool[] firsts := Bool[true]    // object state stack
  private Bool lastWasEnd
}

