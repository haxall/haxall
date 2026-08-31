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
    box := opts["box"] ?: "none"
    if (box != "none" && box != "auto" && box != "all")
      throw ArgErr("Invalid JSON scalar boxing mode: ${box}")
    this.instanceScalarOpts = Etc.dict1("box", box)
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

    instanceValues = true

    spec := instance["spec"]
    if (spec != null) dictPairPlain("spec", spec)

    instance.each |v, n|
    {
      if (n == "spec") return
      if (n == "id") dictPairPlain(n, v)
      else dictPair(n, v)
    }

    instanceValues = false

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
    globals(spec.globalsOwn, depth)
    objEnd.propEnd
    return this
  }

  ** Spec type
  private This specType(Spec spec)
  {
    prop("type").str(spec.type.qname).propEnd
    // Preserve the declaration identity of a concrete slot that specializes
    // a global. Effective metadata alone carries the narrowed constraints but
    // cannot reconstruct the normative RDF subproperty relationship.
    if (spec.base != null && !spec.base.isType)
      prop("base").str(spec.base.qname).propEnd
    return this
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

  ** Global declarations are not ordinary effective slots, but downstream
  ** schema translators need their identity to preserve global contracts.
  private This globals(SpecMap globals, Int depth)
  {
    if (globals.isEmpty) return this
    prop("globals").obj
    globals.each |globalSlot| { doSpec(globalSlot.name, globalSlot, depth+1) }
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
    return scalar(x)
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
    if (instanceValues && (n == "id" || n == "spec"))
      return dictPairPlain(n, v)
    return prop(n).val(v).propEnd
  }

  ** Structural identity fields stay plain even when instance values use
  ** lossless scalar boxes, so consumers can locate and type each record.
  private This dictPairPlain(Str n, Obj v)
  {
    prop(n)
    JetoWriter(ns, out, null, boxNone).writeVal(v)
    return propEnd
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

  ** Schema data retains the established unboxed JSON format. An explicit
  ** instance transport mode may box runtime scalars so their types survive.
  private This scalar(Obj x)
  {
    JetoWriter(ns, out, null, instanceValues ? instanceScalarOpts : boxNone).writeVal(x)
    return this
  }

  private static const Dict boxNone := Etc.dict1("box", "none")

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

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Bool[] firsts := Bool[true]    // object state stack
  private Bool lastWasEnd
  private Bool instanceValues
  private const Dict instanceScalarOpts
}
