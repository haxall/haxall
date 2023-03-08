//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2022  Brian Frank  Creation
//

using util

**
** XetoFactory maps between Xeto and Fantom types
**
@Js
internal const class XetoFactory
{
  new make()
  {
    b := XetoFactoryBuilder()
    this.fromXeto = b.fromXeto
    this.fromFantom = b.fromFantom
  }

  const Str:XetoScalarItem fromXeto
  const Type:XetoScalarItem fromFantom
}

**************************************************************************
** XetoFactoryBuilder
**************************************************************************

@Js
internal class XetoFactoryBuilder
{
  new make()
  {
    // sys pod
    pod := Pod.find("sys")
    add(XetoStrItem("sys::Str", pod.type("Str")))
    add(XetoDateTimeItem("sys::DateTime", pod.type("DateTime")))
    addScalar("sys::Bool",     pod.type("Bool"))
    addScalar("sys::Int",      pod.type("Int"))
    addScalar("sys::Float",    pod.type("Float"))
    addScalar("sys::Duration", pod.type("Duration"))
    addScalar("sys::Date",     pod.type("Date"))
    addScalar("sys::Time",     pod.type("Time"))
    addScalar("sys::Uri",      pod.type("Uri"))
    addScalar("sys::Version",  pod.type("Version"))

    // haystack
    pod = Pod.find("haystack")
    addScalar("sys::Marker",   pod.type("Marker"))
    addScalar("sys::Number",   pod.type("Number"))
    addScalar("sys::Ref",      pod.type("Ref"))
    addScalar("ph::NA",        pod.type("NA"))
    addScalar("ph::Remove",    pod.type("Remove"))
    addScalar("ph::Coord",     pod.type("Coord"))
    addScalar("ph::XStr",      pod.type("XStr"))
    addScalar("ph::Symbol",    pod.type("Symbol"))

    // graphics
    pod = Pod.find("graphics")
    addScalar("ion.ui::Color",       pod.type("Color"))
    addScalar("ion.ui::FontStyle",   pod.type("FontStyle"))
    addScalar("ion.ui::FontWeight",  pod.type("FontWeight"))
    addScalar("ion.ui::Insets",      pod.type("Insets"))
    addScalar("ion.ui::Point",       pod.type("Point"))
    addScalar("ion.ui::Size",        pod.type("Size"))
    addScalar("ion.ui::Stroke",      pod.type("Stroke"))
  }

  private Void addScalar(Str xeto, Type fantom)
  {
    add(XetoScalarItem(xeto, fantom))
  }

  private Void add(XetoScalarItem x)
  {
    fromXeto.add(x.xeto, x)
    fromFantom.add(x.fantom, x)
  }

  Str:XetoScalarItem fromXeto := [:]
  Type:XetoScalarItem fromFantom := [:]
}

**************************************************************************
** XetoScalarItem
**************************************************************************

@Js
internal const class XetoScalarItem
{
  new make(Str xeto, Type fantom)
  {
    this.xeto   = xeto
    this.fantom = fantom
  }

  const Str xeto
  const Type fantom

  virtual Obj? parse(XetoCompiler c, Str str, FileLoc loc)
  {
    fromStr := fantom.method("fromStr", false)
    if (fromStr == null)
    {
      c.err("Fantom type '$fantom' missing fromStr", loc)
      return str
    }

    try
    {
      return fromStr.call(str)
    }
    catch (Err e)
    {
      c.err("Invalid '$xeto' value: $str.toCode", loc)
      return str
    }
  }

  override Str toStr() { "$xeto <=> $fantom" }
}

@Js
internal const class XetoStrItem : XetoScalarItem
{
  new make(Str xeto, Type fantom) : super(xeto, fantom) {}
  override Obj? parse(XetoCompiler c, Str str, FileLoc loc) { str }
}

@Js
internal const class XetoDateTimeItem : XetoScalarItem
{
  new make(Str xeto, Type fantom) : super(xeto, fantom) {}
  override Obj? parse(XetoCompiler c, Str str, FileLoc loc)
  {
    // allow UTC timezone to be omitted if "Z" offset
    if (str.endsWith("Z")) str += " UTC"
    return super.parse(c, str, loc)
  }
}