//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xetom
using xetoc
using haystack

**
** ValidateTest
**
@Js
class ValidateTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Rules
//////////////////////////////////////////////////////////////////////////

  Void testRules()
  {
    ns := createNamespace(["sys"])
    reg := ((MNamespace)ns).validateRules

    r := reg.rules.find { it.id == Ref("sys::overMaxVal") }
    verifyEq(r.level, ValidateLevel.err)
    verifyEq(r.on, Ref("sys::Spec.maxVal"))
    verifyEq(r.typeof.qname, "xetom::ValidateSysOverMaxVal")
    verifyEq(r.unless, Ref[Ref("sys::maxValUnit")])

    // every unless target in the namespace is ordered before its rule
    verifyEq(reg.rules.any |x| { !x.unless.isEmpty }, true)
    reg.rules.each |x, i|
    {
      x.unless.each |u|
      {
        ui := reg.rules.findIndex { it.id == u }
        if (ui != null) verify(ui < i, "$u.id must order before $x.id")
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Engine
//////////////////////////////////////////////////////////////////////////

  Void testEngine()
  {
    ns := createNamespace(["sys"])
    lib := ns.compileTempLib("Foo: Dict { num: Number <maxVal:100> }")
    spec := lib.spec("Foo")

    // clean subject reports no items
    r := ns.validate(Etc.dict1("num", n(50)), spec)
    verifyEq(r.hasErrs, false)
    verifyEq(r.items.size, 0)

    // over maxVal traces end to end thru rule registry + msg render
    r = ns.validate(Etc.dict2("id", Ref("x"), "num", n(123)), spec)
    verifyEq(r.hasErrs, true)
    item := r.items.first
    verifyEq(item.rule, Ref("sys::overMaxVal"))
    verifySame(item.level, ValidateLevel.err)
    verifyEq(item.slot, "num")
    verifyEq(item.val, n(123))
    verifyEq(item.subjectId, Ref("x"))
    verifyEq(item.msg, "Number 123 > maxVal 100")

    // missing required slot; item is positioned on the missing slot
    r = ns.validate(Etc.dict0, spec)
    item = r.items.first
    verifyEq(item.rule, Ref("sys::missingSlot"))
    verifyEq(item.slot, "num")
    verifyEq(item.msg, "Missing required slot 'num'")

    // validateAll: no spec tag
    r = ns.validateAll([Etc.dict1("id", Ref("y"))])
    item = r.items.first
    verifyEq(item.rule, Ref("sys::missingSpecRef"))
    verifyEq(item.subjectId, Ref("y"))
  }

  Void testEngineUnless()
  {
    ns := createNamespace(["sys"])
    lib := ns.compileTempLib("A: Dict { num: Number <minVal:10%, maxVal:100%> }")

    verifyEngine(ns, lib, "A", ["num":n(50, "%")],  [,])
    verifyEngine(ns, lib, "A", ["num":n(5, "%")],   ["sys::underMinVal"])
    verifyEngine(ns, lib, "A", ["num":n(200, "%")], ["sys::overMaxVal"])

    // unit mismatch fires the unit rules in registry order; underMinVal
    // would also fire on 5 < 10 but is suppressed by its unless: @minValUnit
    verifyEngine(ns, lib, "A", ["num":n(5)], ["sys::maxValUnit", "sys::minValUnit"])
  }

  Void testEngineTypes()
  {
    ns := createNamespace(["sys"])
    lib := ns.compileTempLib(
      Str<|Foo: Dict { num: Number?, str: Str?, date: Date?, i: Int?, u: Unit? }
           Ssn: Scalar <pattern:"\\d{3}-\\d{2}-\\d{4}">
           Bar: Dict { ssn: Ssn? }
           Baz: Dict { num: Number? <maxVal:100> }
           Refs: Dict { refs: MultiRef? }
           |>)
    hay := Etc.dict1("haystack", Marker.val)

    // ok
    verifyEngine(ns, lib, "Foo", ["num":n(1), "str":"x", "date":Date.today], [,])

    // wrong types
    verifyEngine(ns, lib, "Foo", ["num":"bad"], ["sys::invalidType"])
    verifyEngine(ns, lib, "Foo", ["str":n(2)],  ["sys::invalidType"])

    // strings not allowed for sys scalars at any fidelity
    verifyEngine(ns, lib, "Foo", ["date":"2024-01-01"], ["sys::invalidType"])
    verifyEngine(ns, lib, "Foo", ["date":"2024-01-01"], ["sys::invalidType"], hay)

    // invalid type gates constraint rules: no overMaxVal noise
    verifyEngine(ns, lib, "Baz", ["num":"bad"], ["sys::invalidType"])

    // Unit has no haystack kind: Str ok at haystack, invalid at full
    verifyEngine(ns, lib, "Foo", ["u":"%"], ["sys::invalidType"])
    verifyEngine(ns, lib, "Foo", ["u":"%"], [,], hay)

    // custom scalar as string: invalid at full fidelity, ok at haystack
    verifyEngine(ns, lib, "Bar", ["ssn":"123-45-6789"], ["sys::invalidType"])
    verifyEngine(ns, lib, "Bar", ["ssn":"123-45-6789"], [,], hay)

    // haystack erases Int to Number: bare Number ok at haystack only
    verifyEngine(ns, lib, "Foo", ["i":n(5)], ["sys::invalidType"])
    verifyEngine(ns, lib, "Foo", ["i":n(5)], [,], hay)

    // Int/Float/Duration are not haystack kinds but at haystack
    // fidelity must be Number and never Str
    verifyEq(ns.spec("sys::Int").isHaystack, false)
    verifyEq(ns.spec("sys::Float").isHaystack, false)
    verifyEq(ns.spec("sys::Duration").isHaystack, false)
    verifyEngine(ns, lib, "Foo", ["i":"5"], ["sys::invalidType"])
    verifyEngine(ns, lib, "Foo", ["i":"5"], ["sys::invalidType"], hay)

    // MultiRef accepts Ref or list of Refs (ignoreRefs: type check only)
    ignore := Etc.dict1("ignoreRefs", Marker.val)
    verifyEngine(ns, lib, "Refs", ["refs":Ref("a")], [,], ignore)
    verifyEngine(ns, lib, "Refs", ["refs":[Ref("a"), Ref("b")]], [,], ignore)
    verifyEngine(ns, lib, "Refs", ["refs":Obj["x"]], ["sys::invalidType"], ignore)

    // bare value validation
    r := ns.validate(Date.today, ns.spec("sys::Date"))
    verifyEq(r.items.size, 0)
    r = ns.validate("foo", ns.spec("sys::Date"))
    verifyEq(r.items.join(",") { it.rule.id }, "sys::invalidType")

    // nested dict without spec tag checked as standard dict; item
    // positioned with dotted slot path
    lib2 := ns.compileTempLib("Parent: Dict { child: Child }\nChild: Dict { num: Number? <maxVal:10> }")
    r = ns.validate(Etc.dict1("child", Etc.dict1("num", n(99))), lib2.spec("Parent"))
    verifyEq(r.items.join(",") { it.rule.id }, "sys::overMaxVal")
    verifyEq(r.items.first.slot, "child.num")
    r = ns.validate(Etc.dict1("child", Etc.dict1("num", n(5))), lib2.spec("Parent"))
    verifyEq(r.items.size, 0)
  }

  Void testEngineChoices()
  {
    ns := nsTest
    lib := ns.compileTempLib(
      Str<|Foo: Dict {
             a: DuctSection
             b: PipeSection?
             c: HeatingProcess <multiChoice>
             d: Fluid?
           }
           |>)

    // ok; multiChoice allows both heating processes
    verifyEngine(ns, lib, "Foo", ["discharge":m, "hotWaterHeating":m, "naturalGasHeating":m], [,])

    // missing required for a and c; maybe b/d not required
    verifyEngine(ns, lib, "Foo", [:], ["sys::missingChoice", "sys::missingChoice"])

    // conflicting duct section
    verifyEngine(ns, lib, "Foo", ["discharge":m, "return":m, "elecHeating":m, "hotWaterHeating":m],
      ["sys::conflictingChoice"])

    // air with a gas is the allowed special case; air with water conflicts
    verifyEngine(ns, lib, "Foo", ["discharge":m, "elecHeating":m, "air":m, "co2":m], [,])
    verifyEngine(ns, lib, "Foo", ["discharge":m, "elecHeating":m, "air":m, "water":m],
      ["sys::conflictingChoice"])

    // item detail for missing choice
    r := ns.validate(Etc.dict1("elecHeating", m), lib.spec("Foo"))
    item := r.items.first
    verifyEq(item.rule, Ref("sys::missingChoice"))
    verifyEq(item.slot, "a")
    verifyEq(item.msg, "Missing required choice 'ph::DuctSection'")

    // conflict msg detail
    r = ns.validate(Etc.makeDict(Str:Obj["discharge":m, "return":m, "elecHeating":m]), lib.spec("Foo"))
    conflict := r.items.find { it.rule == Ref("sys::conflictingChoice") }
    verifyEq(conflict.slot, "a")
    verifyEq(conflict.msg, "Conflicting choice 'ph::DuctSection': DischargeDuctSection, ReturnDuctSection")
  }

  Void testEngineRefs()
  {
    ns := nsTest
    lib := ns.compileTempLib(
      Str<|Foo: Dict {
             a: Ref
             b: Ref?
             c: Ref<of:Bar>
             d: MultiRef<of:Bar>
             e: MultiRef?<of:Bar>
             equipRef: Ref?<of:Equip>
           }
           Bar: Dict {}
           |>)

    refFoo  := Ref("to-foo-1")
    refBar  := Ref("to-bar-1")
    refBar2 := Ref("to-bar-2")
    refEq1  := Ref("to-eq-1")
    refEqX  := Ref("to-eq-x")

    recs[refFoo]  = Etc.makeDict(["id":refFoo,  "spec":Ref("temp::Foo")])
    recs[refBar]  = Etc.makeDict(["id":refBar,  "spec":Ref("temp::Bar")])
    recs[refBar2] = Etc.makeDict(["id":refBar2, "spec":Ref("temp::Bar")])
    recs[refEq1]  = Etc.makeDict(["id":refEq1,  "spec":Ref("ph::AcElecMeter")])
    recs[refEqX]  = Etc.makeDict(["id":refEqX,  "spec":Ref("bad.lib::BadSpec")])

    initContext(lib).asCur |cx|
    {
      // ok including multiref as single Ref and Ref list
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":refBar], [,])
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":[refBar, refBar2]], [,])
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":refBar, "equipRef":refEq1], [,])

      // unresolved refs; suppresses target checks on same value
      verifyEngine(ns, lib, "Foo", ["a":Ref("to-err-1"), "c":refBar, "d":refBar],
        ["sys::unresolvedRef"])
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":[refBar, Ref("to-err-2")]],
        ["sys::unresolvedRef"])

      // wrong target types for Ref, MultiRef list, MultiRef single
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refFoo, "d":refBar],
        ["sys::refTargetType"])
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":[refBar, refFoo]],
        ["sys::refTargetType"])
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":refBar, "e":refFoo],
        ["sys::refTargetType"])

      // target as lib instance
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":Ref("hx.test.xeto::refs-a"), "d":refBar],
        ["sys::refTargetType"])

      // ref to a spec: target is Spec not Equip
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":refBar, "equipRef":Ref("ph::Site")],
        ["sys::refTargetType"])

      // target spec not found
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":refBar, "equipRef":refEqX],
        ["sys::refTargetSpec"])

      // ignoreRefs skips all target checking
      verifyEngine(ns, lib, "Foo", ["a":Ref("to-err-3"), "c":refFoo, "d":refBar], [,],
        Etc.dict1("ignoreRefs", Marker.val))

      // item details
      r := ns.validate(Etc.makeDict(Str:Obj["a":refFoo, "c":refFoo, "d":refBar]), lib.spec("Foo"))
      item := r.items.first
      verifyEq(item.rule, Ref("sys::refTargetType"))
      verifyEq(item.slot, "c")
      verifyEq(item.msg, "Ref target must be '${lib.name}::Bar', target is '${lib.name}::Foo'")
    }
  }

  Void testEngineScalars()
  {
    ns := nsTest
    lib := ns.compileTempLib(
      Str<|Foo: Dict {
             bool: Bool?
             date: Date?
             number: Number?
             int: Int?
             float: Float?
             duration: Duration?
             str: Str?
             uri: Uri?
             ref: Ref?
             unit: Unit?
             tz: TimeZone?
             ssn: TestSsn?
             color: Color?
           }
           Color: Enum { red, blue }
           |>)

    // haystack kinds: exact type both fidelities, never Str
    verifyScalarVal(ns, lib, "bool",   true,          true,  true)
    verifyScalarVal(ns, lib, "date",   Date.today,    true,  true)
    verifyScalarVal(ns, lib, "date",   "2024-01-01",  false, false)
    verifyScalarVal(ns, lib, "number", n(5),          true,  true)
    verifyScalarVal(ns, lib, "number", "5",           false, false)
    verifyScalarVal(ns, lib, "str",    "x",           true,  true)
    verifyScalarVal(ns, lib, "uri",    `file.txt`,    true,  true)
    verifyScalarVal(ns, lib, "uri",    "file.txt",    false, false)
    verifyScalarVal(ns, lib, "ref",    Ref("a"),      true,  true)

    // Int/Float/Duration: Fantom type at full, Number erasure at haystack
    verifyScalarVal(ns, lib, "int",      5,             true,  false)
    verifyScalarVal(ns, lib, "int",      n(5),          false, true)
    verifyScalarVal(ns, lib, "int",      "5",           false, false)
    verifyScalarVal(ns, lib, "float",    5f,            true,  false)
    verifyScalarVal(ns, lib, "float",    n(5),          false, true)
    verifyScalarVal(ns, lib, "duration", 5min,          true,  false)
    verifyScalarVal(ns, lib, "duration", n(5, "min"),   false, true)

    // non-haystack sys scalars: Fantom type at full, Str at haystack
    verifyScalarVal(ns, lib, "unit", Unit("%"),        true,  false)
    verifyScalarVal(ns, lib, "unit", "%",              false, true)
    verifyScalarVal(ns, lib, "tz",   TimeZone.utc,     true,  false)
    verifyScalarVal(ns, lib, "tz",   "UTC",            false, true)

    // custom scalar: Scalar wrapper at full, Str at haystack
    verifyScalarVal(ns, lib, "ssn", Scalar("hx.test.xeto::TestSsn", "123-45-6789"), true, false)
    verifyScalarVal(ns, lib, "ssn", "123-45-6789", false, true)

    // enum: Str key at haystack; full fidelity currently rejects Str
    // TODO: is Str key the legal full fidelity form for unbound enums?
    verifyScalarVal(ns, lib, "color", "red", false, true)
  }

  Void testEngineConstraints()
  {
    ns := nsTest
    lib := ns.compileTempLib(
      Str<|A: Dict { pct: Number? <unit:"%"> }
           B: Dict { scale: Number? <unitless> }
           C: Dict { pow: Number? <quantity:"power"> }
           D: Dict { u: Unit? <quantity:"power"> }
           E: Dict { color: TestPrintEnum? }
           F: Dict { name: Str? <nonEmpty, minSize:3, maxSize:5> }
           G: Dict { ssn: TestSsn? }
           H: Dict { fixed: Str? <invariant> "x" }
           I: Dict { u: Unit? <invariant> "%" }
           J: Dict { n: Number? <invariant> 123kW }
           K: Dict { i: Int? }
           L: Dict { s: MySizeStr? }
           M: Dict { tz: TestPrintEnumKeys? }
           N: Dict { tags: List? <nonEmpty, minSize:2, maxSize:3, of:Str> }
           MySizeStr: Scalar <nonEmpty, minSize:2, maxSize:4>
           |>)
    hay := Etc.dict1("haystack", Marker.val)

    // unit
    verifyEngine(ns, lib, "A", ["pct":n(50, "%")],  [,])
    verifyEngine(ns, lib, "A", ["pct":n(50)],       ["sys::wrongUnit"])
    verifyEngine(ns, lib, "A", ["pct":n(50, "kW")], ["sys::wrongUnit"])

    // unitless
    verifyEngine(ns, lib, "B", ["scale":n(2)],      [,])
    verifyEngine(ns, lib, "B", ["scale":n(2, "%")], ["sys::unitless"])

    // number unit quantity
    verifyEngine(ns, lib, "C", ["pow":n(5, "kW")], [,])
    verifyEngine(ns, lib, "C", ["pow":n(5)],       ["sys::wrongQuantity"])
    verifyEngine(ns, lib, "C", ["pow":n(5, "°C")], ["sys::wrongQuantity"])

    // unit enum quantity: Unit instance at full, Str key at haystack
    verifyEngine(ns, lib, "D", ["u":Unit("kW")], [,])
    verifyEngine(ns, lib, "D", ["u":Unit("°C")], ["sys::wrongQuantity"])
    verifyEngine(ns, lib, "D", ["u":"kW"], [,], hay)
    verifyEngine(ns, lib, "D", ["u":"°C"], ["sys::wrongQuantity"], hay)

    // enum keys: Scalar wrapper at full, Str key at haystack
    verifyEngine(ns, lib, "E", ["color":toEnum("alpha")], [,])
    verifyEngine(ns, lib, "E", ["color":toEnum("bad")],   ["sys::wrongEnumKey"])
    verifyEngine(ns, lib, "E", ["color":"alpha"], [,], hay)
    verifyEngine(ns, lib, "E", ["color":"bad"],   ["sys::wrongEnumKey"], hay)

    // pattern: Scalar wrapper at full, Str at haystack
    verifyEngine(ns, lib, "G", ["ssn":toSsn("123-45-6789")], [,])
    verifyEngine(ns, lib, "G", ["ssn":toSsn("bad")], ["sys::patternMismatch"])
    verifyEngine(ns, lib, "G", ["ssn":"123-45-6789"], [,], hay)
    verifyEngine(ns, lib, "G", ["ssn":"bad"], ["sys::patternMismatch"], hay)

    // string sizes; blank fires both nonEmpty and underMinSize
    verifyEngine(ns, lib, "F", ["name":"abcd"],   [,])
    verifyEngine(ns, lib, "F", ["name":"ab"],     ["sys::underMinSize"])
    verifyEngine(ns, lib, "F", ["name":"abcdef"], ["sys::overMaxSize"])
    verifyEngine(ns, lib, "F", ["name":"  "],     ["sys::nonEmpty", "sys::underMinSize"])

    // invariant with fidelity narrowing for Unit
    verifyEngine(ns, lib, "H", ["fixed":"x"], [,])
    verifyEngine(ns, lib, "H", ["fixed":"y"], ["sys::invariantVal"])
    verifyEngine(ns, lib, "I", ["u":Unit("%")], [,])
    verifyEngine(ns, lib, "I", ["u":"%"], [,], hay)
    verifyEngine(ns, lib, "I", ["u":"m"], ["sys::invariantVal"], hay)

    // invariant number
    verifyEngine(ns, lib, "J", ["n":n(123, "kW")], [,])
    verifyEngine(ns, lib, "J", ["n":n(123, "W")],  ["sys::invariantVal"])

    // Int/Float inherit unitless from sys; Number erasure keeps checking it
    verifyEngine(ns, lib, "K", ["i":n(5)],       [,], hay)
    verifyEngine(ns, lib, "K", ["i":n(5, "kW")], ["sys::unitless"], hay)

    // constraint meta declared on named scalar type instead of slot
    verifyEngine(ns, lib, "L", ["s":"ab"],     [,], hay)
    verifyEngine(ns, lib, "L", ["s":" "],      ["sys::nonEmpty", "sys::underMinSize"], hay)
    verifyEngine(ns, lib, "L", ["s":"a"],      ["sys::underMinSize"], hay)
    verifyEngine(ns, lib, "L", ["s":"abcde"],  ["sys::overMaxSize"], hay)

    // enum with remapped keys validates by key not name
    verifyEngine(ns, lib, "M", ["tz":"New_York"], [,], hay)
    verifyEngine(ns, lib, "M", ["tz":"newYork"],  ["sys::wrongEnumKey"], hay)

    // list sizes via shared size constraints
    verifyEngine(ns, lib, "N", ["tags":["a", "b"]], [,])
    verifyEngine(ns, lib, "N", ["tags":Str[,]], ["sys::nonEmpty", "sys::underMinSize"])
    verifyEngine(ns, lib, "N", ["tags":["a"]], ["sys::underMinSize"])
    verifyEngine(ns, lib, "N", ["tags":["a", "b", "c", "d"]], ["sys::overMaxSize"])
  }

  Scalar toEnum(Str key) { Scalar("hx.test.xeto::TestPrintEnum", key) }

  Scalar toSsn(Str val)  { Scalar("hx.test.xeto::TestSsn", val) }

  ** Verify value type conformance for the slot's type both as a
  ** top-level bare value and as a slot value, at full and haystack
  ** fidelity.  Expect zero items when ok, else single invalidType.
  Void verifyScalarVal(Namespace ns, Lib lib, Str slot, Obj val, Bool fullOk, Bool hayOk)
  {
    // type conformance only: ignoreRefs so unresolved refs don't report
    full := Etc.dict1("ignoreRefs", Marker.val)
    hay  := Etc.dict2("haystack", Marker.val, "ignoreRefs", Marker.val)
    foo  := lib.spec("Foo")
    type := foo.slot(slot).type
    dict := Etc.makeDict(Str:Obj[slot: val])

    verifyScalarReport("bare full $slot", ns.validate(val, type, full), fullOk)
    verifyScalarReport("bare hay $slot",  ns.validate(val, type, hay),  hayOk)
    verifyScalarReport("slot full $slot", ns.validate(dict, foo, full), fullOk)
    verifyScalarReport("slot hay $slot",  ns.validate(dict, foo, hay),  hayOk)
  }

  private Void verifyScalarReport(Str title, ValidateReport r, Bool ok)
  {
    if (ok)
    {
      verifyEq(r.items.size, 0, title)
    }
    else
    {
      verifyEq(r.items.size, 1, title)
      verifyEq(r.items.first.rule, Ref("sys::invalidType"), title)
    }
  }

  ** Validate tags against lib spec and verify item rule qnames
  Void verifyEngine(Namespace ns, Lib lib, Str specName, Str:Obj tags, Str[] expect, Dict? opts := null)
  {
    r := ns.validate(Etc.makeDict(tags), lib.spec(specName), opts)
    verifyEq(r.items.join(",") { it.rule.id }, expect.join(","))
  }

//////////////////////////////////////////////////////////////////////////
// Scalars
//////////////////////////////////////////////////////////////////////////

  Void testScalars()
  {
    verifyScalarErr(Date.today, "sys::Date", null)
    verifyScalarErr("foo", "sys::Date", "Type 'sys::Str' does not fit 'sys::Date'")

    verifyScalarErr("123-89-4567", "hx.test.xeto::TestSsn", null)
    verifyScalarErr("123-xx-4567", "hx.test.xeto::TestSsn", "String encoding does not match pattern for 'hx.test.xeto::TestSsn'")
  }

  Void verifyScalarErr(Obj? val, Str qname, Str? expect)
  {
    errs := XetoLogRec[,]
    fits := nsTest.fits(val, nsTest.spec(qname), logOpts("explain", errs))

    if (expect == null)
    {
      verifyEq(fits, true)
      verifyEq(errs.size, 0)
      return
    }

    verifyEq(fits, false)
    verifyEq(errs.size, 1)
    verifyEq(errs.first.msg, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Types
//////////////////////////////////////////////////////////////////////////

  Void testTypes()
  {
    src :=
    Str<|Foo: Dict {
           num: Number
           str: Str
         }|>

    // all ok
    verifyValidate(src, ["num":n(123), "str":"hi"], [,])

    // invalid types
    verifyValidate(src, ["num":"bad", "str":n(123), "ref":n(123)],
      [
        "Invalid 'sys::Number' string value: \"bad\"",
        "Slot 'num': String encoding does not match pattern for 'sys::Number'",
        "Slot 'str': Slot type is 'sys::Str', value type is 'sys::Number'",
      ],
      [
        "Slot 'num': Slot type is 'sys::Number', value type is 'sys::Str'",
        "Slot 'str': Slot type is 'sys::Str', value type is 'sys::Number'",
      ])
  }

//////////////////////////////////////////////////////////////////////////
// Fixed
//////////////////////////////////////////////////////////////////////////

  Void testFixed()
  {
    src :=
    Str<|Foo: {
           n: Number <invariant> 123kW
           u: Unit <invariant> "%"
         }
         |>

    // all ok
    verifyValidate(src, ["n":n(123, "kW"), "u":Unit("%"), ], [,])

    // range errors
    verifyValidate(src, ["n":n(123, "W"), "u":Unit("A")], [
      "Slot 'n': Must have invariant value '123kW'",
      "Slot 'u': Must have invariant value '%'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Numbers
//////////////////////////////////////////////////////////////////////////

  Void testNumbers()
  {
    src :=
    Str<|Foo: {
           a: Number <minVal:Number 10, maxVal:Number 20, quantity:"length">
           b: Number <quantity:"power">
           c: Number <unit:"kW", maxVal:100>
         }
         |>

    // all ok
    verifyValidate(src, ["a":n(10, "ft"), "b":n(2, "W"), "c":n(3, "kW")], [,])

    // range errors
    verifyValidate(src, ["a":n(21, "m"), "b":n(2, "W"), "c":n(100.4f, "kW")], [
      "Slot 'a': Number 21m > maxVal 20",
      "Slot 'c': Number 100.4kW > maxVal 100",
    ])

    // unit errors
    verifyValidate(src, ["a":n(20, "min"), "b":n(2, "kWh"), "c":n(3, "W")], [
      "Slot 'a': Number must be 'length' unit; 'min' has quantity of 'time'",
      "Slot 'b': Number must be 'power' unit; 'kWh' has quantity of 'energy'",
      "Slot 'c': Number 3W must have unit of 'kW'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Fidelity
//////////////////////////////////////////////////////////////////////////

  Void testFidelity()
  {
    src :=
    Str<|Foo: {
           i: Int?
           f: Float?
           d: Duration?
         }
         |>
    lib  := nsTest.compileTempLib(src)
    spec := lib.spec("Foo")

    // Haystack erases Int/Float/Duration to plain Number.  At full fidelity
    // a bare Number does not fit these Number subtypes; at haystack fidelity
    // it does.  A unit'd number still fails the Int/Float unitless constraint.
    initContext(lib).asCur |cx|
    {
      // full fidelity: bare Number does not fit Int/Float
      verifyFidelity(spec, ["i":n(1995)], null, [
        "Slot 'i': Slot type is 'sys::Int', value type is 'sys::Number'"])
      verifyFidelity(spec, ["f":n(72)], null, [
        "Slot 'f': Slot type is 'sys::Float', value type is 'sys::Number'"])

      // haystack fidelity: bare Number fits Int/Float/Duration
      verifyFidelity(spec, ["i":n(1995)], "haystack", [,])
      verifyFidelity(spec, ["f":n(72)], "haystack", [,])
      verifyFidelity(spec, ["d":n(30, "min")], "haystack", [,])

      // unitless still enforced even at haystack fidelity
      verifyFidelity(spec, ["i":n(2020, "°C")], "haystack", [
        "Slot 'i': Number 2020°C must be unitless"])
      verifyFidelity(spec, ["f":n(72, "%")], "haystack", [
        "Slot 'f': Number 72% must be unitless"])
    }
  }

  Void verifyFidelity(Spec spec, Str:Obj tags, Str? opt, Str[] expect)
  {
    instance := toInstance(tags)
    errs := XetoLogRec[,]
    opts := logOpts("explain", errs)
    if (opt != null) opts = Etc.dictSet(opts, opt, Marker.val)
    fits := nsTest.fits(instance, spec, opts)
    verifyErrs("Fidelity", instance, null, errs, expect)
    verifyEq(fits, errs.isEmpty)
  }

//////////////////////////////////////////////////////////////////////////
// Strs
//////////////////////////////////////////////////////////////////////////

  Void testStrs()
  {
    src :=
    Str<|Foo: {
           a: Str <pattern:"\\d{4}-\\d{2}-\\d{2}">
           b: MyDate
           c: Str <nonEmpty>
           d: MyNonEmpty
           e: Str <minSize:2, maxSize:4>
           f: MySizeStr
         }

         MyDate: Scalar <pattern:"\\d{4}-\\d{2}-\\d{2}">

         MyNonEmpty: Scalar <nonEmpty>

         MySizeStr: Scalar <minSize:2, maxSize:4>
         |>

    // all ok
    ok := ["a":"2024-11-07", "b":"1234-56-78", "c":"!", "d":"!", "e":"ab", "f":"abce"]
    verifyValidate(src, ok, [,])

    // bad pattern
    verifyValidate(src, ok.dup.setAll(["a":"2024-11-7", "b":"1234_56_78"]), [
      "Slot 'a': String encoding does not match pattern for 'temp::Foo.a'",
      "Slot 'b': String encoding does not match pattern for 'temp::MyDate'",
    ])

    // empty
    verifyValidate(src, ok.dup.setAll(["c":"", "d":" "]), [
      "Slot 'c': String must be non-empty",
      "Slot 'd': String must be non-empty",
    ])

    // minSize
    verifyValidate(src, ok.dup.setAll(["e":"", "f":"1"]), [
      "Slot 'e': String size 0 < minSize 2",
      "Slot 'f': String size 1 < minSize 2",
    ])

    // maxSize
    verifyValidate(src, ok.dup.setAll(["e":"12345", "f":"123456"]), [
      "Slot 'e': String size 5 > maxSize 4",
      "Slot 'f': String size 6 > maxSize 4",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Lists
//////////////////////////////////////////////////////////////////////////

  Void testList()
  {
    src :=
    Str<|Foo: {
           a: List<of:Str, nonEmpty>
           b: List<of:Str, minSize:1, maxSize:3>
           c: List<of:Number>
           d: List?<of:Uri>
         }
         |>

    // all ok
    ok := ["a":["1"], "b":["1"], "c":[,]]
    verifyValidate(src, ok, [,])

    // empty
    verifyValidate(src, ok.dup.setAll(["a":Str[,]]), [
      "Slot 'a': List must be non-empty",
    ])

    // minSize
    verifyValidate(src, ok.dup.setAll(["b":Str[,]]), [
      "Slot 'b': List size 0 < minSize 1",
    ])

    // maxSize
    verifyValidate(src, ok.dup.setAll(["b":["1", "2", "3", "4"]]), [
      "Slot 'b': List size 4 > maxSize 3",
    ])

    // item types
    verifyValidate(src, ok.dup.set("c", [n(123), Etc.dict0, 123, `uri`]), [
      "Slot 'c': List item type is 'sys::Number', item type is 'sys::Dict'",
      "Slot 'c': List item type is 'sys::Number', item type is 'sys::Uri'",
    ])

    // item types using list subtype, for compile-time we require nominal
    // typing but for fits-time we allow structure typing
    verifyRunTime(src, ok.dup.set("d", [`uri1`, n(123), Etc.dict0, `uri2`]), [
      "Slot 'd': List item type is 'sys::Uri', item type is 'sys::Number'",
      "Slot 'd': List item type is 'sys::Uri', item type is 'sys::Dict'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Enums
//////////////////////////////////////////////////////////////////////////

  Void testEnums()
  {
    src :=
    Str<|Foo: Dict {
           c: Color
           p: PrimaryFunction
           s: CurStatus
         }

         Color: Enum { red, blue }
         |>

    // all ok
    verifyValidate(src, ["s":"down", "p":"Bank Branch", "c":"red"], [,])

    // bad keys
    verifyValidate(src, ["c":"x", "p":"bankBranch", "s":"y"], [
      "Slot 'c': Invalid key 'x' for enum type 'temp::Color'",
      "Slot 'p': Invalid key 'bankBranch' for enum type 'ph::PrimaryFunction'",
      "Slot 's': Invalid key 'y' for enum type 'ph::CurStatus'",
    ])
  }

//////////////////////////////////////////////////////////////////////////
// Choices
//////////////////////////////////////////////////////////////////////////

  Void testChoices()
  {
    src :=
    Str<|Foo: Dict {
           a: DuctSection
           b: PipeSection?
           c: HeatingProcess <multiChoice>
         }
         |>

    // all ok
    verifyValidate(src, ["discharge":m, "hotWaterHeating":m, "natualGasHeating":m], [,])

    // missing required
    verifyValidate(src, [:], [
      "Slot 'a': Missing required choice 'ph::DuctSection'",
      "Slot 'c': Missing required choice 'ph::HeatingProcess'",
    ])

    // conflicting
    verifyValidate(src, ["discharge":m, "return":m, "elecHeating":m, "hotWaterHeating":m,], [
      "Slot 'a': Conflicting choice 'ph::DuctSection': DischargeDuctSection, ReturnDuctSection",
    ])
  }


//////////////////////////////////////////////////////////////////////////
// Refs
//////////////////////////////////////////////////////////////////////////

  Void testRefs()
  {
    src :=
    Str<|Foo: Dict {
           a: Ref
           b: Ref?
           c: Ref<of:Bar>
           d: MultiRef<of:Bar>
           e: MultiRef?<of:Bar>
           equipRef: Ref?<of:Equip>
           f: List?<of:Ref<of:Equip>>
         }

         Bar: Dict {}

         @to-foo-1: Foo {}
         @to-bar-1: Bar {}
         @to-bar-2: Bar {}
         @to-eq-1: AcElecMeter {}
         @to-eq-2: Ahu {}
         |>

    refFoo  := Ref("to-foo-1")
    refBar  := Ref("to-bar-1")
    refBar2 := Ref("to-bar-2")
    refBars := [refBar, refBar2]
    refEq1  := Ref("to-eq-1")
    refEq2  := Ref("to-eq-2")
    refEqX  := Ref("to-eq-x")
    refErr1 := Ref("to-err-1")
    refErr2 := Ref("to-err-2")
    refErr3 := Ref("to-err-3")
    refErr4 := Ref("to-err-4")
    refErr5 := Ref("to-err-5")

    recs[refFoo]  = Etc.makeDict(["id":refFoo,  "spec":Ref("temp::Foo")])
    recs[refBar]  = Etc.makeDict(["id":refBar,  "spec":Ref("temp::Bar")])
    recs[refBar2] = Etc.makeDict(["id":refBar2, "spec":Ref("temp::Bar")])
    recs[refEq1]  = Etc.makeDict(["id":refEq1,  "spec":Ref("ph::AcElecMeter")])
    recs[refEq2]  = Etc.makeDict(["id":refEq2,  "spec":Ref("ph::Ahu")])
    recs[refEqX]  = Etc.makeDict(["id":refEq1,  "spec":Ref("bad.lib::BadSpec")])

    // all ok
    ok := Str:Obj["a":refFoo, "c":refBar, "d":refBar]
    verifyValidate(src, ok, [,])
    verifyValidate(src, ok.dup.setAll(["d":refBars]), [,])

    // invalid multiref types
    verifyValidate(src, ok.dup.setAll(["d":n(123), "e":[n(123)], "u":refFoo]), [
      "Slot 'd': Slot type is 'sys::MultiRef', value type is 'sys::Number'",
      "Slot 'e': Slot type is 'sys::MultiRef', value type is 'sys::List'",
    ])

    // unresolved refs (in compiler this happens in Resolve step)
    verifyValidate(src, ["a":refErr1, "b":refErr2, "c":refErr3, "d":[refBar2, refErr4, refBar], "u":refErr5], [
      "Unresolved instance: to-err-1",
      "Unresolved instance: to-err-2",
      "Unresolved instance: to-err-3",
      "Unresolved instance: to-err-4",
      "Unresolved instance: to-err-5",
    ],
    [
      "Slot 'a': Unresolved ref @to-err-1",
      "Slot 'b': Unresolved ref @to-err-2",
      "Slot 'c': Unresolved ref @to-err-3",
      "Slot 'd': Unresolved ref @to-err-4",
      "Slot 'u': Unresolved ref @to-err-5",
    ])

    // invalid target types
    verifyValidate(src, ["a":refFoo, "b":refFoo, "c":refFoo, "d":[refBar2, refFoo], "e":refFoo, "equipRef":refEq1], [
      "Slot 'c': Ref target must be 'temp::Bar', target is 'temp::Foo'",
      "Slot 'd': Ref target must be 'temp::Bar', target is 'temp::Foo'",
      "Slot 'e': Ref target must be 'temp::Bar', target is 'temp::Foo'",
    ])

    // invalid target types in lib
    verifyValidate(src, ["a":refFoo, "b":refFoo, "c":Ref("hx.test.xeto::refs-a"), "d":[refBar2, Ref("hx.test.xeto::refs-a")]], [
      "Slot 'c': Ref target must be 'temp::Bar', target is 'hx.test.xeto::TestRefs'",
      "Slot 'd': Ref target must be 'temp::Bar', target is 'hx.test.xeto::TestRefs'",
    ])

    // ref type is spec (only in fitter)
    verifyRunTime(src, ok.dup.set("equipRef", Ref("ph::Site")), [
      "Slot 'equipRef': Ref target must be 'ph::Equip', target is 'sys::Spec'",
    ])

    // target type not found (only in fitter)
    verifyRunTime(src, ok.dup.set("equipRef", refEqX).set("enum", Ref("ph::WeatherCondEnum")), [
      "Slot 'equipRef': Ref target spec not found: 'bad.lib::BadSpec'",
    ])

    // list of refs
    verifyRunTime(src, ok.dup.set("f", [refEq1, refEq2]), [,])
  }

//////////////////////////////////////////////////////////////////////////
// Globals
//////////////////////////////////////////////////////////////////////////

  Void testGlobals()
  {
    // test ph global
    src :=
    Str<|Foo: PhEntity {}
         |>

    // invalid target types in lib
    verifyValidate(src, ["id":Ref.gen, "area":n(13, "ft"), "site":Date.today], [
      "Slot 'area': Number must be 'area' unit; 'ft' has quantity of 'length'",
      "Slot 'site': Global type is 'sys::Marker', value type is 'sys::Date'",
      ])


    // global in lib AST
    src =
    Str<|Foo: Dict {
           *baz: Number <quantity:"length", minVal:0>
         }
         |>


    // invalid target types in lib
    verifyCompileTime(src, toInstance(["baz":Uri("file.txt")]), [
      "Slot 'baz': Global type is 'sys::Number', value type is 'sys::Uri'",
      ])

    // invalid target types in lib
    verifyCompileTime(src, toInstance(["baz":n(123, "°C")]), [
      "Slot 'baz': Number must be 'length' unit; '°C' has quantity of 'temperature'",
      ])
  }

//////////////////////////////////////////////////////////////////////////
// Protocol
//////////////////////////////////////////////////////////////////////////

  Void testProtocol()
  {
    ns := createNamespace(["ph.protocols"])

    // quick tests for protocol regex

    // bacnet
    re := Regex(ns.spec("ph.protocols::BacnetAddr.addr").meta["pattern"])
    verifyEq(re.matches("AO123"), true)
    verifyEq(re.matches("ao123"), false)
    verifyEq(re.matches("AO"), false)
    verifyEq(re.matches("123"), false)
    verifyEq(re.matches("ABCD9"), true)
    verifyEq(re.matches("LAV9X"), false)

    re = Regex(ns.spec("ph.protocols::ModbusAddr.addr").meta["pattern"])
    verifyEq(re.matches("400000"),  true)
    verifyEq(re.matches("401234"),  true)
    verifyEq(re.matches("41abcd"),  false)
    verifyEq(re.matches("4123"),    false)
    verifyEq(re.matches("1234567"), false)
    verifyEq(re.matches("51234"),   false)
  }

//////////////////////////////////////////////////////////////////////////
// Patterns
//////////////////////////////////////////////////////////////////////////

  Void testPatterns()
  {
    ns := createNamespace(["sys"])

    // marker
    re := Regex(ns.spec("sys::Marker").meta["pattern"])
    verifyTrue(re.matches("✓"))
    verifyFalse(re.matches("foo"))

    // bool
    re = Regex(ns.spec("sys::Bool").meta["pattern"])
    verifyTrue(re.matches("true"))
    verifyTrue(re.matches("false"))
    verifyFalse(re.matches("foo"))

    // int
    re = Regex(ns.spec("sys::Int").meta["pattern"])
    [
      "0", "42", "-7", "1000000", "-2147483648", "9007199254740991"
    ].each |Str s| { verifyTrue(re.matches(s)) }
    [
      "01", "+42", "-05", "000", ".5", "42."
    ].each |Str s| { verifyFalse(re.matches(s)) }

    // float
    re = Regex(ns.spec("sys::Float").meta["pattern"])
    [
      "0.5", "-0.5", "12.34", "-100.0", "0.00001", "-0.0", "1e10",
      "1.2E+5", "10E2", "5e-3", "-1.5E-10", "0.1e-5", "0", "-42", "1000",
      "\"NaN\"", "\"INF\"", "\"-INF\""
    ].each |Str s| { verifyTrue(re.matches(s)) }
    [
      "01.5", "-05.2", "12.", "-5.", ".5", "-.123", "+1.5", "+0.5",
      "0x1A", "0o77", "\"+INF\"", "foo"
    ].each |Str s| { verifyFalse(re.matches(s)) }

    // number
    re = Regex(ns.spec("sys::Number").meta["pattern"])
    [
      "0.5", "-0.5", "12.34", "-100.0", "0.00001", "-0.0", "1e10",
      "1.2E+5", "10E2", "5e-3", "-1.5E-10", "0.1e-5", "0", "-42", "1000",
      "0.5/", "-0.5\$", "12.34_", "-100.0元", "0.00001gH₂O/kgAir", "-0.0%", "1e10foo",
      "1.2E+5abc", "10E2abc", "5e-3abc", "-1.5E-10abc", "0.1e-5abc", "0abc", "-42abc", "1000abc",
      "\"NaN\"", "\"INF\"", "\"-INF\""
    ].each |Str s| { verifyTrue(re.matches(s)) }
    [
      "01.5", "-05.2", "12.", "-5.", ".5", "-.123", "+1.5", "+0.5",
      "0x1A", "0o77", "\"+INF\"", "foo",
      "0@", "1.2#", "3e4="
    ].each |Str s| { verifyFalse(re.matches(s)) }
  }

//////////////////////////////////////////////////////////////////////////
// Verify
//////////////////////////////////////////////////////////////////////////

  ** Verify both compile time and fits time for spec called Foo in src
  Void verifyValidate(Str src, Str:Obj tags, Str[] expect, Str[]? runtimeExpect := null)
  {
    instance := toInstance(tags)
    verifyCompileTime(src, instance, expect)
    verifyRunTime(src, instance, runtimeExpect ?: expect)
  }

  ** Verify the instance bundled in the library source at compile time
  Void verifyCompileTime(Str src, Dict instance, Str[] expect)
  {
    // rewrite source to include the instance
    src = srcAddPragma(src)
    src = srcAppendInstance(src, instance)

    if (isDebug)
    {
      echo
      echo("####")
      echo(src)
    }

    // compile with logger
    errs := XetoLogRec[,]
    opts := logOpts("log", errs)
    Lib? lib
    try
      lib = nsTest.compileTempLib(src, opts)
    catch (Err e)
      {}


    verifyErrs("Compile Time", instance, null, errs, expect)
  }

  ** Verify the instance checked using fits explain after lib src is compiled.
  ** TODO: rejoin ns.validate here once the new engine reaches parity; these
  ** fixtures then become the old-vs-new compare harness
  Void verifyRunTime(Str src, Obj instance, Str[] expect)
  {
    src = srcAddPragma(src)
    instance = toInstance(instance)
    lib  := nsTest.compileTempLib(src)
    spec := lib.spec("Foo")
    errs := XetoLogRec[,]
    opts := logOpts("explain", errs)
    initContext(lib).asCur |cx|
    {
      fits := nsTest.fits(instance, spec, opts)
      verifyErrs("Fits Time", instance, null, errs, expect)
      verifyEq(fits, errs.isEmpty)
    }
  }

  ** Create opts with log to use for both compiler and fits
  Dict logOpts(Str key, XetoLogRec[] acc)
  {
    logger := |XetoLogRec rec| { acc.add(rec) }
    return Etc.dict1(key, Unsafe(logger))
  }

  ** Create opts with log to use for both compiler and fits
  TestContext initContext(Lib lib)
  {
    cx := TestContext()
    cx.recs = recs.map |d->Dict|
    {
      specRef := d->spec.toStr
      if (!specRef.contains("temp")) return d
      specName := XetoUtil.qnameToName(specRef)
      return Etc.dictSet(d, "spec", Ref("$lib.name::$specName"))
    }
    return cx
  }

  ** Verify actual errors from compiler/fits against expected results
  Void verifyErrs(Str title, Obj instance, ValidateReport? r, XetoLogRec[] actual, Str[] expect)
  {
    if (isDebug)
    {
      echo("\n-- $title [$actual.size]")
      echo(actual.join("\n"))
      echo(expect.join("\n"))
      echo
    }

    normExpect := Str[,]
    actual.each |arec, i|
    {
      a := normTempLibName(arec.msg)
      e := expect.getSafe(i) ?: "-"
      if (a != e)
      {
        echo("FAIL: $a")
        echo("      $e")
      }
      verifyEq(a, e)
      normExpect.add(e)
    }

    verifyEq(actual.size, expect.size)

    if (r != null)
    {
      verifyEq(r.items.size, normExpect.size)
      r.items.each |item, i| { verifyItem(instance, item, normExpect[i]) }
    }
  }

  private Void verifyItem(Obj instance, ValidateItem actual, Str expect)
  {
    level := ValidateLevel.err
    msg   := expect
    slot  := null
    if (msg.startsWith("Slot '"))
    {
      end := msg.index("':")
      slot = msg[6..<end]
      msg  = msg[end+2..-1].trim
    }

    verifySame(actual.level, level)
    verifySame(actual.subject, instance as Dict ?: Etc.dict0)
    verifyEq(actual.slot, slot)
    verifyEq(normTempLibName(actual.msg), msg)
  }

  ** To instance with tags sorted alphabetically
  private Dict toInstance(Obj x)
  {
    if (x is Dict) return x
    tags := (Str:Obj)x
    names := tags.keys.sort
    acc := Str:Obj[:] { ordered = true }
    names.each |n| { acc[n] = tags[n] }
    return Etc.makeDict(acc)
  }

  ** Add pragma with depends
  private Str srcAddPragma(Str src)
  {
    """pragma: Lib <
         version: "0.0.0"
         depends: { {lib:"sys"}, {lib:"ph"}, {lib:"hx.test.xeto"} }
       >
       """ + src
  }

  ** Append @x instance to the soruce
  private Str srcAppendInstance(Str src, Dict instance)
  {
    ns := nsTest
    buf := StrBuf()
    buf.add(src).add("\n\n").add("@x: ")
    ns.io.writeXeto(buf.out, Etc.dictRemove(instance, "id"))
    return buf.toStr.replace("@x: {", "@x: Foo {")
  }

  ** Namespace to use
  once Namespace nsTest()
  {
    createNamespace(["sys", "ph", "hx.test.xeto"])
  }

  ** TestContext recs for target resolution
  Ref:Dict recs := [:]

  ** Verbose debug flag
  Bool isDebug  := false

}

