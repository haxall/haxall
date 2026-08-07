//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jan 2026  Mike Jarmy  Creation
//

using xeto
using haystack
using util

**
** XetoJsonReader
**
@Js
class XetoJsonReader
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, InStream in, Spec? rootSpec := null, Dict? opts := null)
  {
    this.ns = ns
    this.in = in
    this.rootSpec = rootSpec
    this.xutil = XetoJsonUtil(ns)
    this.fidelity = XetoUtil.optFidelity(opts)
    this.lenient  = XetoUtil.optBool(opts, "lenient", false)
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Obj? readVal()
  {
    x := XetoJsonInStream(in).readJson
    return convert(x, rootSpec)
  }

  private Obj? convert(Obj? x, Spec? spec)
  {
    if (x is Dict) return convertDict(x, spec)
    if (x is List) return convertList(x, spec)
    return convertScalar(x, spec)
  }

  ** Convert a dict.  A grid row passes 'colOf' so that a column 'of'
  ** outranks the row spec's member for that cell; otherwise rows are
  ** ordinary dicts.
  private Obj? convertDict(Dict dict, Spec? context, [Str:Spec]? colOf := null)
  {
    // Rule 1: a boxed scalar carries its own type, which beats the context
    bspec := boxSpec(dict)
    if (bspec != null)
    {
      box := convertBox(dict, bspec)
      // null only when lenient and the box is malformed: fall through as a dict
      if (box != null) return box
    }

    // Rule 3: an explicit 'spec' tag beats the containing context
    spec := xutil.dictSpec(dict, context, !lenient)

    // check for Grid special case
    if (spec != null && spec.isGrid)
      return convertGrid(dict, spec)

    // map dict pairs; Dict.each already elides nulls, so a JSON null is
    // absent rather than carried through as a value
    acc := Str:Obj[:]
    if (dict.isOrdered) acc.ordered = true
    dict.each |v, k|
    {
      // spec is a reserved structural tag and is always a Ref
      if (k == "spec")
        acc[k] = toSpecRef(v)
      else
        acc[k] = convert(v, colOf?.get(k) ?: xutil.member(spec, k))
    }
    Dict out := Etc.dictFromMap(acc)

    // apply spec binding, if we are not haystack.  The spec need not be a
    // dict type: a scalar spec tag on a dict reaches here when a malformed
    // box degrades, and only a dict binding implements decodeDict.
    if ((spec != null) && spec.binding.isDict &&
        (fidelity !== XetoFidelity.haystack))
      out = spec.binding.decodeDict(out)
    return out
  }

//////////////////////////////////////////////////////////////////////////
// Boxed Scalars
//////////////////////////////////////////////////////////////////////////

  ** Rule 1: a dict with 'val' plus a 'spec' resolving to a scalar type is a
  ** boxed scalar.  Returns the box type, or null if this is an ordinary dict.
  private Spec? boxSpec(Dict dict)
  {
    if (dict.get("val") == null) return null
    ref := dict.get("spec")
    if (ref == null) return null
    spec := xutil.resolve(ref, !lenient)
    if (spec == null || !spec.type.isScalar) return null
    return spec
  }

  ** Parse a boxed scalar's 'val' with its own spec.  Returns null only when
  ** lenient and the box is malformed, which degrades it to an ordinary dict.
  private Obj? convertBox(Dict dict, Spec spec)
  {
    // val is always a JSON string, even for types with native JSON forms
    str := dict.get("val") as Str
    if (str == null)
    {
      if (lenient) return null
      throw IOErr("Boxed 'val' must be a Str [$spec.qname]")
    }

    x := decodeScalar(spec, str)

    // a boxed Ref carries its display string, which has no other place to go
    if (x is Ref)
    {
      dis := dict.get("dis") as Str
      if (dis != null) x = Ref.makeWithDis(x, dis)
    }

    // a box names a full fidelity type, so coerce down when haystack
    if (fidelity === XetoFidelity.haystack) return XetoUtil.toHaystack(x)
    return x
  }

  private Grid convertGrid(Dict dict, Spec gridSpec)
  {
    gb := GridBuilder()
    wireMeta := dict["meta"] as Dict

    // Rule 3: the default row spec is the instance 'of' then the schema 'of'.
    // 'of' is structural and sits beside 'spec', not inside meta
    gridOf := dict.get("of")
    rowSpec := xutil.rowSpec(gridOf, gridSpec, !lenient)

    // meta
    meta := convertGridMeta(wireMeta, gridSpec, gridOf)
    if (!meta.isEmpty) gb.setMeta(meta)

    // cols; 'of' is structural and sits beside 'name', not inside meta
    colOf := Str:Spec[:]
    cols := dict["cols"] as Obj?[] ?: throw Err("Grid missing 'cols' list")
    cols.each |Dict col|
    {
      name  := (Str)col->name
      ofRef := col.get("of")
      of    := xutil.resolve(ofRef, !lenient)
      if (of != null) colOf[name] = of
      gb.addCol(name, convertColMeta(col, ofRef))
    }

    // rows are just dicts, with the column 'of' layered on
    rows := dict["rows"] as Obj?[] ?: throw Err("Grid missing 'rows' list")
    rows.each |r|
    {
      gb.addDictRow(r == null ? null : convertDict(r, rowSpec, colOf) as Dict)
    }

    // done
    return gb.toGrid
  }

  ** Grid meta carries the grid spec and 'of' so that 'XetoUtil.gridSpecRef'
  ** and 'XetoUtil.gridOfSpecRef' can recover them.  The sys::Grid default is
  ** left out so a plain grid does not gain a meta tag it did not have.
  private Dict convertGridMeta(Dict? wire, Spec gridSpec, Obj? ofRef)
  {
    acc := Str:Obj[:]
    acc.ordered = true
    gt := gridSpec.type
    if (gt !== ns.sys.grid) acc["spec"] = gt.id
    if (ofRef != null) acc["of"] = Ref.fromStr(ofRef)
    if (wire != null) eachMetaTag(wire, acc)
    return Etc.dictFromMap(acc)
  }

  ** Column meta carries 'of' as a Ref so that 'XetoUtil.gridColSpecRef' can
  ** recover it.  Returns null when the column has no meta at all.
  private Dict? convertColMeta(Dict col, Obj? ofRef)
  {
    wire := col.get("meta") as Dict
    if (ofRef == null && wire == null) return null

    acc := Str:Obj[:]
    acc.ordered = true
    if (ofRef != null) acc["of"] = Ref.fromStr(ofRef)
    if (wire != null) eachMetaTag(wire, acc)
    return Etc.dictFromMap(acc)
  }

  ** Accumulate meta tags; 'of' and 'spec' are structural refs, not values
  private Void eachMetaTag(Dict wire, Str:Obj acc)
  {
    wire.each |v, k|
    {
      if (k == "of" || k == "spec")
        acc[k] = toSpecRef(v)
      else
        acc[k] = convert(v, null)
    }
  }

  ** A structural spec ref is always a Ref.  A value that is neither a Ref nor
  ** a Str is passed through rather than raising a cast error, which is what
  ** lenient needs when a payload puts something else in a 'spec' or 'of' tag.
  private Obj toSpecRef(Obj v)
  {
    if (v is Ref) return v
    if (v is Str) return Ref.fromStr(v)
    return v
  }

  private Obj?[] convertList(Obj?[] from, Spec? spec)
  {
    // a list spec need not declare 'of'; without it the items are untyped
    of := xutil.listOf(spec)

    if (from.contains(null))
      return from.map |Obj? v->Obj?| { convert(v, of) }
    else
      return from.map |Obj v->Obj| { convert(v, of) }
  }

  private Obj? convertScalar(Obj? x, Spec? spec)
  {
    // a string is never typed by what it looks like; without a spec for this
    // position it is a Str verbatim
    if (x is Str)
    {
      // a non-scalar position supplies no grammar to parse with; haystack
      // fidelity additionally only decodes against a haystack type
      if ((spec != null) && spec.type.isScalar &&
          ((fidelity !== XetoFidelity.haystack) || spec.type.isHaystack))
        return decodeScalar(spec, x)

      return x
    }

    // a JSON number keeps its lexical type unless the position names one of
    // the interchangeable numeric types; haystack has only Number
    if (x is Int || x is Float)
    {
      if (fidelity === XetoFidelity.haystack)
        return x is Int ? Number.makeInt(x) : Number.make(x)
      return xutil.coerceNum(x, spec)
    }

    return x
  }

  ** Decode a scalar against its spec.  When lenient an undecodable value
  ** degrades to the verbatim string rather than raising.
  private Obj? decodeScalar(Spec spec, Str str)
  {
    if (!lenient) return spec.binding.decodeScalar(str)
    try
      return spec.binding.decodeScalar(str, false) ?: str
    catch
      return str
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const MNamespace ns
  private InStream in
  private Spec? rootSpec
  private XetoJsonUtil xutil
  private XetoFidelity fidelity

  ** Degrade a position to untyped instead of raising when its value cannot
  ** be decoded: unparseable text, unresolvable spec ref, malformed box.
  ** Does not gate self-description: a box or a JSON native form overriding
  ** the context spec is always legal and never an error.
  private Bool lenient
}

**************************************************************************
** XetoJsonInStream
**************************************************************************

@Js
internal class XetoJsonInStream : JsonInStream
{
  internal new make(InStream in) : super(in) {}

  override Obj transformObj(Str:Obj? obj) { Etc.makeDict(obj) }
}

