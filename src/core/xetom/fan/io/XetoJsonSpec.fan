//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Aug 2026  Mike Jarmy  Creation
//

using xeto
using haystack

**
** Position resolution shared by XetoJsonReader and XetoJsonWriter.  Both
** codecs must agree on which spec applies at a given position; if they
** disagree then 'box=auto' emits values the reader cannot recover.
**
** The codec never synthesizes the reserved structural tags 'spec' and 'of'.
** It carries and repositions what the payload or the in-memory value already
** declares - boxing covers everything else.
**
@Js
@NoDoc class XetoJsonSpec
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns)
  {
    this.ns = ns
  }

//////////////////////////////////////////////////////////////////////////
// Positions
//////////////////////////////////////////////////////////////////////////

  ** Resolve a spec ref.  Returns null if unresolvable and checked is false.
  Spec? resolve(Obj? ref, Bool checked := true)
  {
    if (ref == null) return null
    return ns.spec(ref.toStr, checked)
  }

  ** Spec for a dict position: its own 'spec' tag wins over the context spec.
  Spec? dictSpec(Dict dict, Spec? context, Bool checked := true)
  {
    resolve(dict.get(XetoUtil.specTag), checked) ?: context
  }

  ** Spec for a tag within a dict of the given spec.
  Spec? member(Spec? spec, Str name)
  {
    spec == null ? null : members(spec).get(name, false)
  }

  ** Cached 'Spec.members' - slots plus globals.
  SpecMap members(Spec spec)
  {
    memberCache.getOrAdd(spec.qname) |->SpecMap| { spec.members }
  }

  ** Spec for the items of a list position.  A list spec need not declare
  ** 'of'; without it the items are untyped.
  Spec? listOf(Spec? listSpec)
  {
    listSpec?.of(false)
  }

  ** Default row spec for a grid: the instance 'of' wins, else the grid
  ** spec's own 'of'.  Callers supply ofRef from the wire meta or from
  ** 'XetoUtil.gridOfSpecRef'.
  Spec? rowSpec(Obj? ofRef, Spec? gridSpec, Bool checked := true)
  {
    resolve(ofRef, checked) ?: gridSpec?.of(false)
  }

//////////////////////////////////////////////////////////////////////////
// Boxing
//////////////////////////////////////////////////////////////////////////

  ** Would the plain (unboxed) encoding of val decode back to an identical
  ** value in a position whose expected spec is 'expected'?  This is the
  ** 'box=auto' predicate.  Conservative: it may answer false where a box is
  ** not strictly required, but never true where one is.  JsonTest
  ** cross-checks it against real encode/decode.
  Bool plainRoundTrips(Obj? val, Spec? expected)
  {
    if (val == null) return true

    et := expected?.type

    // a JSON bool always decodes as Bool
    if (val is Bool) return true

    // a JSON number decodes as its lexical type unless the position names
    // one of the interchangeable numeric types
    if (val is Int) return isNumeric(et) ? et === ns.sys.int : true
    if (val is Float)
    {
      f := (Float)val
      // special floats have no JSON number form; they encode as strings
      if (f.isNaN || f == Float.posInf || f == Float.negInf)
        return et === ns.sys.float
      return isNumeric(et) ? et === ns.sys.float : true
    }

    // Number always needs the position to say Number: its plain form is
    // either a bare number, which reads back Int or Float, or a quoted string
    if (val is Number) return et === ns.sys.number

    // everything else encodes as a quoted string, which decodes as Str
    // unless the position names the value's own type
    if (et == null || !et.isScalar) return val is Str
    return et === ns.specOf(val, false)
  }

  ** Is the spec one of the interchangeable numeric types.  Other Number
  ** subtypes such as Duration are excluded: they bind to distinct Fantom
  ** types that a bare JSON number cannot produce.
  private Bool isNumeric(Spec? x)
  {
    x === ns.sys.int || x === ns.sys.float || x === ns.sys.number
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const MNamespace ns
  private Str:SpecMap memberCache := [:]
}

