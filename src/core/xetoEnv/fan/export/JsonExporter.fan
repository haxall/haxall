//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Aug 2024  Brian Frank  Creation
//

using xeto
using xeto::Lib
using haystack::Dict
using haystack::Etc
using haystack::Marker
using haystack::Ref

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
    this.isEffective = XetoUtil.optBool(opts, "effective", false)
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
    lib.specs.each |spec| { doSpec(spec.name, spec) }
    objEnd.propEnd
    return this
  }

  override This spec(Spec spec)
  {
    doSpec(spec.qname, spec)
    return this
  }

  override This instance(Dict instance)
  {
    prop(instance.id.id).obj
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
  private This doSpec(Str name, Spec spec)
  {
    prop(name).obj
    prop("spec").val(specRef).propEnd
    if (spec.isType) specBase(spec)
    else specType(spec)
    meta(isEffective ? spec.meta : spec.metaOwn)
    slots(isEffective ? spec.slots : spec.slotsOwn)
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
  private This slots(SpecSlots slots)
  {
    if (slots.isEmpty) return this
    prop("slots").obj
    slots.each |slot| { doSpec(slot.name, slot) }
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
    w(s.toCode)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Ref specRef := Ref("sys::Spec")
  private Bool[] firsts := Bool[true]    // object state stack
  private Bool lastWasEnd
  private Bool isEffective
}

