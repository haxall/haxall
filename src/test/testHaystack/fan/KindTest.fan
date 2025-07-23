//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jan 2016  Brian Frank  Create
//

using xeto
using haystack

**
** KindTest
**
@Js
class KindTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    verifyBasics(Kind.obj,      "Obj",      "")
    verifyBasics(Kind.bin,      "Bin",      Bin.defVal)
    verifyBasics(Kind.bool,     "Bool",     false)
    verifyBasics(Kind.coord,    "Coord",    Coord.defVal)
    verifyBasics(Kind.date,     "Date",     Date.today )
    verifyBasics(Kind.dateTime, "DateTime", DateTime.defVal)
    verifyBasics(Kind.dict,     "Dict",     Etc.dict0, true)
    verifyBasics(Kind.grid,     "Grid",     Etc.makeEmptyGrid, true)
    verifyBasics(Kind.list,     "List",     Obj?[,], true)
    verifyBasics(Kind.marker,   "Marker",   Marker.val)
    verifyBasics(Kind.na,       "NA",       NA.val)
    verifyBasics(Kind.number,   "Number",   Number.zero)
    verifyBasics(Kind.ref,      "Ref",      Ref.nullRef)
    verifyBasics(Kind.symbol,   "Symbol",   Symbol("marker"))
    verifyBasics(Kind.remove,   "Remove",   Remove.val)
    verifyBasics(Kind.str,      "Str",      "")
    verifyBasics(Kind.time,     "Time",     Time.defVal)
    verifyBasics(Kind.uri,      "Uri",      ``)
    verifyBasics(Kind.xstr,     "XStr",     XStr.defVal)
  }

  Void verifyBasics(Kind kind, Str name, Obj defVal, Bool isCollection := false)
  {
    verifyEq(kind.name, name)
    verifyEq(kind.signature, name == "List" ? "Obj[]" : name)
    verifyEq(kind.paramName, null)
    verifyValEq(kind.defVal, defVal)
    verifyEq(kind.isCollection, isCollection)
  }


//////////////////////////////////////////////////////////////////////////
// FromStr
//////////////////////////////////////////////////////////////////////////

  Void testFromStr()
  {
    // basic kinds
    verifyFromStr("Obj",    "Obj")
    verifyFromStr("Number", "Number")
    verifyFromStr("Bin",    "Bin")
    verifyFromStr("Dict",   "Dict")
    verifyFromStr("Grid",   "Grid")

    // list kinds
    verifyFromStr("Obj[]",     "List", Kind.obj)
    verifyFromStr("Ref[]",     "List", Kind.ref)
    verifyFromStr("Grid[]",    "List", Kind.grid)
    verifyFromStr("Ref[][]",   "List", Kind.ref.toListOf)
    verifyFromStr("Str[][][]", "List", Kind.str.toListOf.toListOf)

    // parameterized kinds
    verifyFromStr("Ref<ahu>",    "Ref",  null, "ahu")
    verifyFromStr("Dict<site>",  "Dict", null, "site")
    verifyFromStr("Grid<point>", "Grid", null, "point")

    // parameterized list kinds
    verifyFromStr("Ref<equip>[]",  "List",  Kind.fromStr("Ref<equip>"))
    verifyFromStr("Ref<equip>[][]",  "List",  Kind.fromStr("Ref<equip>").toListOf)

    verifySame(Kind.fromStr("List"), Kind.fromStr("Obj[]"))
    verifyEq(Kind.fromStr("Foo", false), null)
    verifyEq(Kind.fromStr("Foo[]", false), null)
    verifyErr(UnknownKindErr#) { x := Kind.fromStr("Foo") }
    verifyErr(UnknownKindErr#) { x := Kind.fromStr("[]") }
    verifyErr(UnknownKindErr#) { x := Kind.fromStr("Foo<site>") }
    verifyErr(UnknownKindErr#) { x := Kind.fromStr("Obj<site>") }
    verifyErr(UnknownKindErr#) { x := Kind.fromStr("List<site>") }
    verifyErr(UnknownKindErr#) { x := Kind.fromStr("Str<site>") }
    verifyErr(UnknownKindErr#) { x := Kind.fromStr("Number<site>") }


    verifySame(Kind.fromDefName("str"),      Kind.str)
    verifySame(Kind.fromDefName("marker"),   Kind.marker)
    verifySame(Kind.fromDefName("dateTime"), Kind.dateTime)
    verifySame(Kind.fromDefName("grid"),     Kind.grid)
    verifyNull(Kind.fromDefName("bad", false))
    verifyErr(UnknownKindErr#) { Kind.fromDefName("bad") }
    verifyErr(UnknownKindErr#) { Kind.fromDefName("bad", true) }
  }

  Void verifyFromStr(Str sig, Str name, Kind? of := null, Str? tag := null)
  {
    kind := Kind.fromStr(sig)
    //echo("--- $sig >> $kind")
    verifyEq(kind.signature, sig)
    verifyEq(kind.name, name)
    verifyKindEq(kind.of, of)
    verifyEq(kind.paramName, tag)
    verifyKindEq(Kind.fromStr(sig), kind)
  }

  Void verifyKindEq(Kind? a, Kind? b)
  {
    if (a == null) return verifyEq(a, b)
    if (a.paramName != null) return verifyEq(a, b)
    if (a.of?.paramName != null) return verifyEq(a, b)
    if (a.of?.of?.paramName != null) return verifyEq(a, b)
    verifySame(a, b)
  }

//////////////////////////////////////////////////////////////////////////
// FromVal
//////////////////////////////////////////////////////////////////////////

  Void testFromVal()
  {
    verifyFromVal(Bin("text/plain"),         "Bin")
    verifyFromVal(true,                      "Bool")
    verifyFromVal(Coord(0f, 0f),             "Coord")
    verifyFromVal(Date.today,                "Date")
    verifyFromVal(Etc.dict0,             "Dict")
    verifyFromVal(Etc.makeDict(["a":"!"]),   "Dict")
    verifyFromVal(Etc.makeEmptyGrid,         "Grid")
    verifyFromVal([,],                       "Obj[]")
    verifyFromVal(["a","b"],                 "Str[]")
    verifyFromVal(["a",null],                "Str[]")
    verifyFromVal(["a",null, n(2)],          "Obj[]")
    verifyFromVal(Marker.val,                "Marker")
    verifyFromVal(NA.val,                    "NA")
    verifyFromVal(Number(123),               "Number")
    verifyFromVal(Ref("a"),                  "Ref")
    verifyFromVal(Remove.val,                "Remove")
    verifyFromVal("string",                  "Str")
    verifyFromVal(DateTime.now.time,         "Time")
    verifyFromVal(`file.txt`,                "Uri")
    verifyFromVal(XStr("T", "v"),            "XStr")
  }

  Void verifyFromVal(Obj? val, Str sig)
  {
    verifyEq(Kind.fromVal(val).signature, sig)
    verifyEq(Kind.fromType(val.typeof).signature, sig)
    if (sig.endsWith("[]")) verifyEq(Kind.fromVal(val).isCollection, true)
  }

//////////////////////////////////////////////////////////////////////////
// FromType
//////////////////////////////////////////////////////////////////////////

  Void testFromType()
  {
    verifyFromType(#a.params[0].type, "Uri")
    verifyFromType(#a.params[1].type, "Uri")

    verifyFromType(#b.params[0].type, "Str[]")
    verifyFromType(#b.params[1].type, "Str[]")
    verifyFromType(#b.params[2].type, "Str[]")

    verifyFromType(#c.params[0].type, "Dict[]")
    verifyFromType(#c.params[1].type, "Dict[]")
    verifyFromType(#c.params[2].type, "Dict[]")
  }

  private Void a(Uri a, Uri? b) {}
  private Void b(Str[] a, Str?[] b, Str?[]? c) {}
  private Void c(Dict[] a, Dict?[] b, Dict?[]? c) {}

  Void verifyFromType(Type t, Str sig)
  {
    verifyEq(Kind.fromType(t).signature, sig)
  }

//////////////////////////////////////////////////////////////////////////
// List Inference
//////////////////////////////////////////////////////////////////////////

  Void testInferredList()
  {
    dict0 := Etc.dict0
    dict1 := Etc.makeDict(["a":"A"])
    dict2 := Etc.makeDict(["a":"A", "b":"B"])
    dict3 := Etc.makeDict(["a":"A", "b":"B", "c":"C"])

    verifyInferredList(Obj?["a", "b"], Str[]#)
    verifyInferredList(Obj?[null, "a", "b"], Str?[]#)
    verifyInferredList(Obj?[null, null, "a", "b"], Str?[]#)
    verifyInferredList(Obj?["a", `u`], Obj?[]#)
    verifyInferredList(Obj?["a", null, `u`], Obj?[]#)
    verifyInferredList(Obj?[Ref("a")], Ref[]#)
    verifyInferredList(Obj?[Ref("a"), null], Ref?[]#)
    verifyInferredList(Obj?[Ref("a"), Ref("b")], Ref[]#)
    verifyInferredList(Obj?[Ref("a"), Ref("b"), dict1], Obj?[]#)
    verifyInferredList(Obj?[dict1, dict2, dict3], Dict[]#)
    verifyInferredList(Obj?[dict0, dict2, null, dict2], Dict?[]#)
    verifyInferredList(Obj?[null, null, dict1, dict0, null, dict3], Dict?[]#)
  }

  Void verifyInferredList(Obj?[] list, Type expected)
  {
    x := Kind.toInferredList(list)
    verifyEq(x.isImmutable, true)
    verifyEq(x.typeof, expected)
  }

//////////////////////////////////////////////////////////////////////////
// List Utils
//////////////////////////////////////////////////////////////////////////

  Void testListUtils()
  {
    // isList
    verifyEq(Kind("Number").isList, false)
    verifyEq(Kind("List").isList, true)
    verifyEq(Kind("Dict[]").isList, true)

    // of
    verifyEq(Kind("Number").of, null)
    verifyEq(Kind("List").of, Kind.obj)
    verifyEq(Kind("Ref[]").of, Kind.ref)
    verifyEq(Kind("Ref<foo>[]").of, Kind("Ref<foo>"))

    // isListOf
    verifyEq(Kind("Number").isListOf(Kind.ref), false)
    verifyEq(Kind("List").isListOf(Kind.ref), false)
    verifyEq(Kind("Dict[]").isListOf(Kind.ref), false)
    verifyEq(Kind("Ref[]").isListOf(Kind.ref), true)
    verifyEq(Kind("Ref<foo>[]").isListOf(Kind.ref), true)
    verifyEq(Kind("Ref<foo>[]").isListOf(Kind("Ref<bar>")), false)
    verifyEq(Kind("Ref<foo>[]").isListOf(Kind("Ref<foo>")), true)
  }

}

