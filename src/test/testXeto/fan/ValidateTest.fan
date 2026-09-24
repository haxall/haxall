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
    verifyEq(r.typeof.qname, "xetom::ValidateOverMaxVal")
    verifyEq(r.unless, Ref[Ref("sys::maxValUnit")])

    // on resolves to the types the rule applies to; several types when
    // the check spans unrelated ones such as Ref and MultiRef
    verifyOn(reg, "sys::overMaxVal", ["sys::Number"])
    verifyOn(reg, "sys::underMinSize", ["sys::Scalar", "sys::List"])
    verifyOn(reg, "sys::unresolvedRef", ["sys::Ref", "sys::MultiRef"])
    verifyOn(reg, "sys::wrongQuantity", ["sys::Number", "sys::Unit"])

    // every rule resolves all of its on targets
    reg.rules.each |x| { verify(!x.on.isEmpty, "$x.id has no on target") }

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

  private Void verifyOn(ValidateRules reg, Str rule, Str[] expect)
  {
    r := reg.rules.find { it.qname == rule } ?: throw Err(rule)
    verifyEq(r.on.map |Spec x->Str| { x.qname }, expect, rule)
  }

  ** A lib binds its rules to Fantom classes of the same name in its
  ** bound pod, and a rule declared without a class loads unbound
  Void testRulesCustom()
  {
    ns  := createNamespace(["sys", "hx.test.xeto"])
    reg := ((MNamespace)ns).validateRules

    // custom rule binds to testXeto::ValidateTestCodePrefix by name
    r := reg.rules.find { it.qname == "hx.test.xeto::testCodePrefix" } ?: throw Err("testCodePrefix")
    verifyEq(r.typeof.qname, "testXeto::ValidateTestCodePrefix")
    verifyEq(r.isBound, true)
    verifyEq(r.on.map |Spec x->Str| { x.qname }, ["hx.test.xeto::TestRuleSubject"])

    // rule with no class loads unbound: present but never runs
    u := reg.rules.find { it.qname == "hx.test.xeto::testUnbound" } ?: throw Err("testUnbound")
    verifyEq(u.isBound, false)

    // sys rules bind thru the same convention
    verifyEq(reg.rules.find { it.qname == "sys::overMaxVal" }.typeof.qname,
             "xetom::ValidateOverMaxVal")

    // the custom rule runs against its on type
    spec := ns.spec("hx.test.xeto::TestRuleSubject")
    verifyEq(ns.validate(Etc.dict1("code", "T100"), spec).items.size, 0)
    items := ns.validate(Etc.dict1("code", "X100"), spec).items
    verifyEq(items.size, 1)
    verifyEq(items[0].rule, Ref("hx.test.xeto::testCodePrefix"))
    verifyEq(items[0].msg, "Code 'X100' must start with 'T'")

    // and not against other types
    verifyEq(ns.validate(Etc.dict1("code", "X100"), ns.spec("sys::Dict")).items.size, 0)
  }

  ** A rule is implemented by whatever names it: a func tags itself with
  ** the rule id, the same way a Fantom class is named for the rule
  Void testRulesFunc()
  {
    ns  := createNamespace(["sys", "hx.test.xeto"])
    reg := ((MNamespace)ns).validateRules

    // the rule instance is plain; the func claimed it
    r := reg.rules.find { it.qname == "hx.test.xeto::testFuncMinMax" } ?: throw Err("testFuncMinMax")
    verifyEq(r.typeof.qname, "xetom::ValidateFuncRule")
    verifyEq(r.isBound, true)
    verifyEq(r.impl, "hx.test.xeto::testValidateMinMax")
  }

  ** Func rules skip under a context which cannot call funcs, such as
  ** a plain xeto context without an Axon runtime; the Fantom bound
  ** rule on the same subject still fires
  Void testRulesFuncNoAxon()
  {
    ns   := createNamespace(["sys", "hx.test.xeto"])
    spec := ns.spec("hx.test.xeto::TestRuleSubject")
    TestContext().asCur |cx|
    {
      items := ns.validate(Etc.dictx("id", Ref("x"), "min", n(20), "max", n(10)), spec).items
      verifyEq(items.map |x->Ref| { x.rule }, Ref[Ref("hx.test.xeto::testMinMax")])
    }
  }

  ** Rule registered on an entity type: fires at the instance, so the
  ** func's val is the dict itself and it reports across tags
  Void testRulesOnEntity()
  {
    ns   := createNamespace(["sys", "hx.test.xeto"])
    spec := ns.spec("hx.test.xeto::TestRuleSubject")
    rule := Ref("hx.test.xeto::testFuncMinMax")

    TestAxonContext(ns).asCur |cx|
    {
      // null return is a miss
      verifyFuncRule(ns, spec, rule, ["min":n(1), "max":n(10)], null)

      // dict with slot reports against that tag, not the instance
      verifyFuncRule(ns, spec, rule, ["min":n(20), "max":n(10)], "min", n(20),
        "Func: 20 must be below max")
    }
  }

  ** Rule registered on a scalar type: fires at each value of that type,
  ** so the func's val is the scalar and it reports on its own position
  Void testRulesOnScalar()
  {
    ns   := createNamespace(["sys", "hx.test.xeto"])
    spec := ns.spec("hx.test.xeto::TestRuleSubject")
    even := ns.spec("hx.test.xeto::TestRuleEven").qname
    rule := Ref("hx.test.xeto::testFuncEven")

    TestAxonContext(ns).asCur |cx|
    {
      verifyFuncRule(ns, spec, rule, ["even":Scalar(even, "ab")], null)

      // empty dict reports at the rule's own frame, which is the slot
      // holding the value
      verifyFuncRule(ns, spec, rule, ["even":Scalar(even, "abc")], "even",
        Scalar(even, "abc"), "Func: abc must be even")
    }
  }

  ** Rule registered on one slot of a type: fires only at that slot, not
  ** at every value which happens to share its type
  Void testRulesOnSlot()
  {
    ns   := createNamespace(["sys", "hx.test.xeto"])
    spec := ns.spec("hx.test.xeto::TestRuleSubject")
    rule := Ref("hx.test.xeto::testFuncNote")

    TestAxonContext(ns).asCur |cx|
    {
      verifyFuncRule(ns, spec, rule, ["note":"ok"], null)
      verifyFuncRule(ns, spec, rule, ["note":" "], "note", " ",
        "Func: note ' ' cannot be blank")

      // 'other' is the same Str type but is not the rule's slot
      verifyFuncRule(ns, spec, rule, ["note":"ok", "other":" "], null)
    }
  }

  ** Validate tags against spec and verify whether rule reported an item.
  ** Other rules may fire on the same subject, so select just this rule.
  private Void verifyFuncRule(Namespace ns, Spec spec, Ref rule, Str:Obj tags,
                              Str? slot, Obj? val := null, Str? msg := null)
  {
    subject := Etc.makeDict(tags.dup.set("id", Ref("x")))
    items := ns.validate(subject, spec).items.findAll |x| { x.rule == rule }
    if (slot == null) return verifyEq(items.size, 0, "$rule on $tags")
    verifyEq(items.size, 1, "$rule on $tags")
    verifyEq(items[0].slot, slot)
    verifyEq(items[0].val, val)
    verifyEq(items[0].msg, msg)
    verifyEq(items[0].subjectId, Ref("x"))
  }

  ** The ph rules check agreement between a rec and the recs it points
  ** to, which the ontology cannot express as slot declarations
  Void testPhRules()
  {
    ns   := createNamespace(["sys", "ph"])
    cx   := TestContext()
    site := Ref("s1")
    other := Ref("s2")
    equip := Ref("e1")
    ws    := Ref("w1")
    cx.recs[site]  = Etc.makeDict(["id":site, "spec":Ref("ph::Site"), "site":m, "tz":"New_York"])
    cx.recs[other] = Etc.makeDict(["id":other, "spec":Ref("ph::Site"), "site":m, "tz":"Chicago"])
    cx.recs[equip] = Etc.makeDict(["id":equip, "spec":Ref("ph::Equip"), "equip":m, "siteRef":other])
    cx.recs[ws]    = Etc.makeDict(["id":ws, "spec":Ref("ph::WeatherStation"), "tz":"Denver"])
    space := Ref("sp1")
    system := Ref("sy1")
    cx.recs[space]  = Etc.makeDict(["id":space, "spec":Ref("ph::Space"), "space":m, "siteRef":other])
    cx.recs[system] = Etc.makeDict(["id":system, "spec":Ref("ph::System"), "system":m, "siteRef":other])
    system2 := Ref("sy2")
    systemOk := Ref("sy3")
    cx.recs[system2]  = Etc.makeDict(["id":system2, "spec":Ref("ph::System"), "system":m, "siteRef":other])
    cx.recs[systemOk] = Etc.makeDict(["id":systemOk, "spec":Ref("ph::System"), "system":m, "siteRef":site])

    // equipOk is in site; equipChild is in site but its parent is not
    equipOk := Ref("e2"); equipChild := Ref("e3")
    cx.recs[equipOk]    = Etc.makeDict(["id":equipOk, "spec":Ref("ph::Equip"), "equip":m, "siteRef":site])
    cx.recs[equipChild] = Etc.makeDict(["id":equipChild, "spec":Ref("ph::Equip"), "equip":m,
                                        "siteRef":site, "equipRef":equip])

    // a two rec equipRef cycle
    loopA := Ref("la"); loopB := Ref("lb")
    cx.recs[loopA] = Etc.makeDict(["id":loopA, "spec":Ref("ph::Equip"), "equip":m, "siteRef":site, "equipRef":loopB])
    cx.recs[loopB] = Etc.makeDict(["id":loopB, "spec":Ref("ph::Equip"), "equip":m, "siteRef":site, "equipRef":loopA])

    pt := ns.spec("ph::NumberPoint")
    cx.asCur |x|
    {
      // point with no site or weather station
      verifyPhRule(ns, pt, ["kind":"Number"], "ph::pointMissingSiteRef")

      // tz is advisory, not an error
      items := ns.validate(phPoint(["siteRef":site]), pt).items
      tzItem := items.find |i| { i.rule == Ref("ph::pointMissingTz") } ?: throw Err("no tz item")
      verifySame(tzItem.level, ValidateLevel.warn)
      verifyEq(ns.validate(phPoint(["siteRef":site]), pt).numWarns, 1)

      // tz must match the site it belongs to
      verifyPhRule(ns, pt, ["siteRef":site, "tz":"New_York"], null)
      verifyPhRule(ns, pt, ["siteRef":site, "tz":"Chicago"], "ph::pointSiteTz", "tz",
        "Point tz 'Chicago' does not match site tz 'New_York'")

      // a weather point matches against its station instead
      verifyPhRule(ns, pt, ["weatherStationRef":ws, "tz":"Denver"], null)
      verifyPhRule(ns, pt, ["weatherStationRef":ws, "tz":"Chicago"], "ph::pointSiteTz")

      // equipRef must lead to the same site as siteRef
      verifyPhRule(ns, pt, ["siteRef":other, "equipRef":equip, "tz":"Chicago"], null)
      verifyPhRule(ns, pt, ["siteRef":site, "equipRef":equip, "tz":"New_York"],
        "ph::refSite", "siteRef", "equipRef leads to site @s2, not siteRef @s1")

      // spaceRef and systemRef cross check the same way
      verifyPhRule(ns, pt, ["siteRef":other, "spaceRef":space, "tz":"Chicago"], null)
      verifyPhRule(ns, pt, ["siteRef":site, "spaceRef":space, "tz":"New_York"],
        "ph::refSite", "siteRef", "spaceRef leads to site @s2, not siteRef @s1")
      verifyPhRule(ns, pt, ["siteRef":other, "systemRef":system, "tz":"Chicago"], null)
      verifyPhRule(ns, pt, ["siteRef":site, "systemRef":system, "tz":"New_York"],
        "ph::refSite", "siteRef", "systemRef leads to site @s2, not siteRef @s1")

      // systemRef is a MultiRef: a list is checked the same as a Ref
      verifyPhRule(ns, pt, ["siteRef":other, "systemRef":[system], "tz":"Chicago"], null)
      verifyPhRule(ns, pt, ["siteRef":site, "systemRef":[system], "tz":"New_York"],
        "ph::refSite", "siteRef", "systemRef leads to site @s2, not siteRef @s1")

      // every mismatched target in the list reports
      items2 := ns.validate(phPoint(["siteRef":site, "systemRef":[system, system2],
        "tz":"New_York"]), pt).items.findAll |i| { i.rule == Ref("ph::refSite") }
      verifyEq(items2.size, 2)

      // a list mixing a match and a mismatch reports just the mismatch
      items2 = ns.validate(phPoint(["siteRef":site, "systemRef":[systemOk, system],
        "tz":"New_York"]), pt).items.findAll |i| { i.rule == Ref("ph::refSite") }
      verifyEq(items2.size, 1)

      // refSite walks the whole chain: a grandparent in another site is
      // caught even when the direct parent agrees
      verifyPhRule(ns, pt, ["siteRef":site, "equipRef":equipOk, "tz":"New_York"], null)
      verifyPhRule(ns, pt, ["siteRef":site, "equipRef":equipChild, "tz":"New_York"],
        "ph::refSite", "siteRef", "equipRef leads to site @s2, not siteRef @s1")

      // a cycle is reported instead of walking forever
      items2 = ns.validate(phPoint(["siteRef":site, "equipRef":loopA, "tz":"New_York"]),
        pt).items.findAll |i| { i.rule == Ref("ph::refCycle") }
      verifyEq(items2.size, 1)
      verifyEq(items2[0].slot, "equipRef")
      verify(items2[0].msg.startsWith("equipRef forms a cycle:"))

      // refSite is suppressed on a cycle so one tangle is one message
      verifyEq(ns.validate(phPoint(["siteRef":site, "equipRef":loopA, "tz":"New_York"]),
        pt).items.findAll |i| { i.rule == Ref("ph::refSite") }.size, 0)
    }
  }

  ** Point value constraints must agree with the point's own unit
  Void testPhPointVals()
  {
    ns := createNamespace(["sys", "ph"])
    pt := ns.spec("ph::NumberPoint")
    hay := Etc.dict1("haystack", Marker.val)

    // min/max carrying the point's unit is clean
    verifyPointVals(ns, pt, ["unit":"kW", "minVal":n(0, "kW"), "maxVal":n(10, "kW")], [,])

    // wrong unit on either tag reports against that tag
    verifyPointVals(ns, pt, ["unit":"kW", "maxVal":n(10, "°C")], ["ph::pointValUnit"])
    verifyPointVals(ns, pt, ["unit":"kW", "minVal":n(0, "°C")], ["ph::pointValUnit"])

    // unitless min/max is a mismatch too
    verifyPointVals(ns, pt, ["unit":"kW", "maxVal":n(10)], ["ph::pointValUnit"])

    // min above max
    verifyPointVals(ns, pt, ["unit":"kW", "minVal":n(10, "kW"), "maxVal":n(1, "kW")],
      ["ph::pointMinMax"])

    // equal is allowed
    verifyPointVals(ns, pt, ["unit":"kW", "minVal":n(5, "kW"), "maxVal":n(5, "kW")], [,])

    // a unit mismatch suppresses the comparison rather than comparing
    // values which are not comparable
    verifyPointVals(ns, pt, ["unit":"kW", "minVal":n(10, "kW"), "maxVal":n(1, "°C")],
      ["ph::pointValUnit"])
  }

  private Void verifyPointVals(Namespace ns, Spec spec, Str:Obj tags, Obj[] expect)
  {
    hay := Etc.dict1("haystack", Marker.val)
    rec := Etc.makeDict(tags.dup.setAll(["id":Ref("p1"), "spec":Ref("ph::NumberPoint"),
                                         "point":m, "kind":"Number"]))
    only := ["ph::pointValUnit", "ph::pointMinMax"]
    items := ns.validate(rec, spec, hay).items.findAll |i| { only.contains(i.rule.id) }
    actual := items.map |i->Str| { i.rule.id }.sort.join(",")
    verifyEq(actual, expect.map |x->Str| { x.toStr }.sort.join(","), "$tags -> $items")
  }

  ** Build a ph point rec with the given tags
  private Dict phPoint(Str:Obj tags)
  {
    Etc.makeDict(tags.dup.setAll(["id":Ref("p1"), "spec":Ref("ph::NumberPoint"),
                                  "point":m, "kind":"Number"]))
  }

  ** Verify which ph rule fires on a point, if any
  private Void verifyPhRule(Namespace ns, Spec spec, Str:Obj tags, Str? rule,
                            Str? slot := null, Str? msg := null)
  {
    items := ns.validate(phPoint(tags), spec).items.findAll |x|
    {
      x.rule.id.startsWith("ph::") && x.rule != Ref("ph::pointMissingTz")
    }
    if (rule == null) return verifyEq(items.size, 0, "$tags -> $items")
    verifyEq(items.size, 1, "$tags -> $items")
    verifyEq(items[0].rule, Ref(rule))
    if (slot != null) verifyEq(items[0].slot, slot)
    if (msg != null) verifyEq(items[0].msg, msg)
  }

  ** A rule registered on a type fires once at the subject but can report
  ** against the offending tag, so tools know which field to flag
  Void testRulesEmitOn()
  {
    ns   := createNamespace(["sys", "hx.test.xeto"])
    spec := ns.spec("hx.test.xeto::TestRuleSubject")

    // min below max is clean
    verifyEq(ns.validate(Etc.dictx("id", Ref("x"), "min", n(1), "max", n(10)), spec).items.size, 0)

    // min above max reports on the min tag, not the subject; the item
    // takes its slot, val, and msg vars from the slot it reports on
    items := ns.validate(Etc.dictx("id", Ref("x"), "min", n(20), "max", n(10)), spec).items
    verifyEq(items.size, 1)
    item := items[0]
    verifyEq(item.rule, Ref("hx.test.xeto::testMinMax"))
    verifyEq(item.slot, "min")
    verifyEq(item.val, n(20))
    verifyEq(item.subjectId, Ref("x"))
    verifyEq(item.msg, "Value 20 must be below max")
  }

  ** Rules only run where their on types apply: a constraint declared on
  ** the wrong value type is never checked, and a rule listing unrelated
  ** types such as Ref and MultiRef reaches both
  Void testRulesDispatch()
  {
    ns  := nsTest
    lib := ns.compileTempLib(
      Str<|Num:    Dict { v: Number <maxVal:100> }
           Sized:  Dict { v: Str <maxSize:3> }
           Custom: Scalar <maxSize:3>
           Wrap:   Dict { v: Custom }
           Refs:   Dict { r: Ref<of:Bar>, m: MultiRef<of:Bar> }
           Bar:    Dict {}
           |>)

    // each constraint fires only for the value type it is declared on
    verifyEngine(ns, lib, "Num",   ["v":n(123)], ["sys::overMaxVal"])
    verifyEngine(ns, lib, "Sized", ["v":"abcd"], ["sys::overMaxSize"])
    verifyEngine(ns, lib, "Num",   ["v":n(50)],  [,])
    verifyEngine(ns, lib, "Sized", ["v":"abc"],  [,])

    // size rules reach any scalar, not just Str
    hay := Etc.dict1("haystack", Marker.val)
    verifyEngine(ns, lib, "Wrap", ["v":"abc"],  [,], hay)
    verifyEngine(ns, lib, "Wrap", ["v":"abcd"], ["sys::overMaxSize"], hay)

    // ref rules list both Ref and MultiRef, which are unrelated sealed types
    bar := Ref("to-bar-1")
    recs[bar] = Etc.makeDict(["id":bar, "spec":Ref("temp::Bar")])
    initContext(lib).asCur |cx|
    {
      verifyEngine(ns, lib, "Refs", ["r":bar, "m":bar], [,])
      verifyEngine(ns, lib, "Refs", ["r":Ref("no-such-1"), "m":bar], ["sys::unresolvedRef"])
      verifyEngine(ns, lib, "Refs", ["r":bar, "m":Ref("no-such-2")], ["sys::unresolvedRef"])
      verifyEngine(ns, lib, "Refs", ["r":bar, "m":[bar, Ref("no-such-3")]], ["sys::unresolvedRef"])
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

    // validateAll: spec tag which does not resolve
    r = ns.validateAll([Etc.dict2("id", Ref("y"), "spec", Ref("bad.lib::Nope"))])
    item = r.items.first
    verifyEq(r.items.size, 1)
    verifyEq(item.rule, Ref("sys::unknownSpecRef"))
    verifyEq(item.subjectId, Ref("y"))
    verifyEq(item.msg, "Unknown 'spec' ref: bad.lib::Nope")

    // value which maps to no spec at all
    r = ns.validate(Etc.dict1("num", Regex("x")), spec)
    item = r.items.first
    verifyEq(item.rule, Ref("sys::unknownType"))
    verifyEq(item.slot, "num")
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

    // exact type always fits; message names erased type at haystack
    verifyEngine(ns, lib, "Foo", ["u":Unit("%")], [,], hay)
    verifyTypeMsg(ns, lib, ["u":TimeZone.utc], null, "Invalid type 'sys::TimeZone', expecting 'sys::Unit'")
    verifyTypeMsg(ns, lib, ["u":TimeZone.utc], hay,  "Invalid type 'sys::TimeZone', expecting 'sys::Unit' or 'sys::Str'")
    verifyTypeMsg(ns, lib, ["i":"5"], hay,  "Invalid type 'sys::Str', expecting 'sys::Int' or 'sys::Number'")
    verifyTypeMsg(ns, lib, ["date":"x"], hay,  "Invalid type 'sys::Str', expecting 'sys::Date'")

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

      // unknown tags with ref values get existence checks; id/spec skipped
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":refBar, "xref":refBar2], [,])
      r2 := ns.validate(Etc.makeDict(Str:Obj["a":refFoo, "c":refBar, "d":refBar, "xref":Ref("to-err-9")]), lib.spec("Foo"))
      verifyEq(r2.items.join(",") { it.rule.id }, "sys::unresolvedRef")
      verifyEq(r2.items.first.slot, "xref")

      // unknown tags with ref lists resolve their items too
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":refBar, "xrefs":[refBar, refBar2]], [,])
      r2 = ns.validate(Etc.makeDict(Str:Obj["a":refFoo, "c":refBar, "d":refBar, "xrefs":[refBar, Ref("to-err-8")]]), lib.spec("Foo"))
      verifyEq(r2.items.join(",") { it.rule.id }, "sys::unresolvedRef")
      verifyEq(r2.items.first.slot, "xrefs")
      verifyEngine(ns, lib, "Foo", ["a":refFoo, "c":refBar, "d":refBar, "notRefs":["x", "y"]], [,])

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

  Void testEngineQueries()
  {
    ns := nsTest
    lib := ns.compileTempLib(
      Str<|QEquip: Equip {
             points: Query {
               ta: ZoneAirTempSensor
               tb: ZoneCo2Sensor?
             }
           }
           |>)
    graph := Etc.dict1("graph", Marker.val)

    // equip A has exactly one of each; B has none; C has dup discharge
    a := Ref("q-a"); b := Ref("q-b"); c := Ref("q-c")
    site := Ref("q-site")
    recs[site] = Etc.makeDict(Str:Obj["id":site, "spec":Ref("ph::Site"), "site":m])
    recs[a] = Etc.makeDict(Str:Obj["id":a, "spec":Ref("ph::Ahu"), "equip":m, "siteRef":site])
    recs[b] = Etc.makeDict(Str:Obj["id":b, "spec":Ref("ph::Ahu"), "equip":m, "siteRef":site])
    recs[c] = Etc.makeDict(Str:Obj["id":c, "spec":Ref("ph::Ahu"), "equip":m, "siteRef":site])
    addPt := |Str id, Str spec, Ref equip|
    {
      ref := Ref(id)
      recs[ref] = Etc.makeDict(Str:Obj[
        "id":ref, "spec":Ref(spec), "equipRef":equip, "point":m, "kind":"Number"])
    }
    addPt("q-a1", "ph.points::ZoneAirTempSensor", a)
    addPt("q-a2", "ph.points::ZoneCo2Sensor", a)
    addPt("q-c1", "ph.points::ZoneAirTempSensor", c)
    addPt("q-c2", "ph.points::ZoneAirTempSensor", c)

    initContext(lib).asCur |cx|
    {
      // queries are not checked without the graph opt
      r := ns.validate(recs[b], lib.spec("QEquip"))
      verifyEq(r.items.size, 0)

      // exactly one match per constraint; maybe absent ok
      r = ns.validate(recs[a], lib.spec("QEquip"), graph)
      verifyEq(r.items.size, 0)

      // missing required constraint
      r = ns.validate(recs[b], lib.spec("QEquip"), graph)
      item := r.items.first
      verifyEq(r.items.size, 1)
      verifyEq(item.rule, Ref("sys::missingQuery"))
      verifyEq(item.slot, "points")
      verifyEq(item.msg, "Missing required Point: ta")

      // ambiguous match
      r = ns.validate(recs[c], lib.spec("QEquip"), graph)
      item = r.items.first
      verifyEq(r.items.size, 1)
      verifyEq(item.rule, Ref("sys::ambiguousQuery"))
      verifyEq(item.slot, "points")
      verifyEq(item.msg, "Ambiguous match for Point: ta [@q-c1 \"q-c1\", @q-c2 \"q-c2\"]")
    }

    // marker constraint forms mirroring AxonTest.testQuery
    lib2 := ns.compileTempLib(
        Str<|MAhu: Equip {
               points: Query {
                 temp: Point {discharge, temp}
                 flow: Point {discharge, flow}
               }
             }
             DTemp: {discharge, temp}
             DFlow: {discharge, flow}
             DPressure: {discharge, pressure}
             SAhu: Equip { points: { DTemp, DFlow, DPressure? } }
             |>)

    x := Ref("q-x"); y := Ref("q-y"); z := Ref("q-z")
    recs[x] = Etc.makeDict(Str:Obj["id":x, "spec":Ref("ph::Ahu"), "equip":m, "siteRef":site])
    recs[y] = Etc.makeDict(Str:Obj["id":y, "spec":Ref("ph::Ahu"), "equip":m, "siteRef":site])
    recs[z] = Etc.makeDict(Str:Obj["id":z, "spec":Ref("ph::Ahu"), "equip":m, "siteRef":site])
    addMarkerPt := |Str id, Ref equip, Str marker|
    {
      ref := Ref(id)
      recs[ref] = Etc.makeDict(Str:Obj[
        "id":ref, "spec":Ref("ph::Point"), "equipRef":equip, "siteRef":site,
        "point":m, "kind":"Number", "discharge":m, marker:m])
    }
    addMarkerPt("q-x1", x, "temp")
    addMarkerPt("q-x2", x, "flow")
    addMarkerPt("q-z1", z, "temp")
    addMarkerPt("q-z2", z, "temp")
    addMarkerPt("q-z3", z, "flow")
    addMarkerPt("q-z4", z, "pressure")
    addMarkerPt("q-z5", z, "pressure")

    initContext(lib2).asCur |cx2|
    {
      // inline marker constraints and shape types with exactly one each
      verifyEngine(ns, lib2, "MAhu", recsTags(x), [,], graph)
      verifyEngine(ns, lib2, "SAhu", recsTags(x), [,], graph)

      // multiple missing constraints; shapes display by type qname
      verifyEngine(ns, lib2, "MAhu", recsTags(y),
        ["sys::missingQuery", "sys::missingQuery"], graph)
      r := ns.validate(recs[y], lib2.spec("SAhu"), graph)
      verifyEq(r.items.join(",") { it.rule.id }, "sys::missingQuery,sys::missingQuery")
      verifyEq(r.items.first.msg, "Missing required Point: ${lib2.name}::DTemp")

      // ambiguous for required and even for maybe constraints
      verifyEngine(ns, lib2, "MAhu", recsTags(z), ["sys::ambiguousQuery"], graph)
      verifyEngine(ns, lib2, "SAhu", recsTags(z),
        ["sys::ambiguousQuery", "sys::ambiguousQuery"], graph)
    }
  }

  ** Map rec id to its tags map for verifyEngine
  Str:Obj recsTags(Ref id)
  {
    acc := Str:Obj[:]
    recs[id].each |v, n| { acc[n] = v }
    return acc
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

    // Int/Float/Duration: Fantom type always, Number erasure at haystack
    verifyScalarVal(ns, lib, "int",      5,             true,  true)
    verifyScalarVal(ns, lib, "int",      n(5),          false, true)
    verifyScalarVal(ns, lib, "int",      "5",           false, false)
    verifyScalarVal(ns, lib, "float",    5f,            true,  true)
    verifyScalarVal(ns, lib, "float",    n(5),          false, true)
    verifyScalarVal(ns, lib, "duration", 5min,          true,  true)
    verifyScalarVal(ns, lib, "duration", n(5, "min"),   false, true)

    // non-haystack sys scalars: Fantom type always, Str erasure at haystack
    verifyScalarVal(ns, lib, "unit", Unit("%"),        true,  true)
    verifyScalarVal(ns, lib, "unit", "%",              false, true)
    verifyScalarVal(ns, lib, "tz",   TimeZone.utc,     true,  true)
    verifyScalarVal(ns, lib, "tz",   "UTC",            false, true)

    // custom scalar: Scalar wrapper always, Str erasure at haystack
    verifyScalarVal(ns, lib, "ssn", Scalar("hx.test.xeto::TestSsn", "123-45-6789"), true, true)
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

    // list items are frames: type errors report invalidType with
    // dotted item paths; nulls report listNullItem at list level
    verifyEngine(ns, lib, "N", ["tags":Obj["a", n(3)]], ["sys::invalidType"])
    verifyEngine(ns, lib, "N", ["tags":Obj[n(1), n(2)]], ["sys::invalidType", "sys::invalidType"])
    verifyEngine(ns, lib, "N", ["tags":Obj?["a", null]], ["sys::listNullItem"])
    r2 := ns.validate(Etc.dict1("tags", Obj["a", n(3)]), lib.spec("N"))
    verifyEq(r2.items.first.slot, "tags.1")
    verifyEq(r2.items.first.val, n(3))
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

  Void verifyTypeMsg(Namespace ns, Lib lib, Str:Obj tags, Dict? opts, Str msg)
  {
    r := ns.validate(Etc.makeDict(tags), lib.spec("Foo"), opts)
    verifyEq(r.items.size, 1)
    verifyEq(r.items.first.msg, msg)
  }

  ** Unknown tags holding scalar wrappers validate against the spec
  ** they name for themselves; dicts under unknown tags are open
  ** content and pass
  Void testEngineUnknownTags()
  {
    ns   := nsTest
    lib  := ns.lib("sys")
    ssn  := "hx.test.xeto::TestSsn"

    verifyEngine(ns, lib, "Dict", ["x":Scalar(ssn, "123-45-6789")], [,])
    verifyEngine(ns, lib, "Dict", ["x":Scalar(ssn, "123-45-678x")], ["sys::patternMismatch"])
    verifyEngine(ns, lib, "Dict", ["x":Etc.dict1("spec", Ref("ph::Point"))], [,])
  }

  ** The ignoreMixins opt skips mixin composition at the specx choke
  ** point, so mixin contributed members are not resolved or checked
  Void testEngineIgnoreMixins()
  {
    ns   := nsTest
    lib  := ns.lib("ph")
    tags := ["id":Ref("s"), "site":m, "gnum":n(-5)]

    // hx.test.xeto mixin contributes required newSlot and the global
    // gnum: Number <minVal:0>
    verifyEngine(ns, lib, "Site", tags, ["sys::missingSlot", "sys::underMinVal"])

    // with ignoreMixins newSlot is not required and gnum is just an
    // unknown tag
    verifyEngine(ns, lib, "Site", tags, [,], Etc.dict1("ignoreMixins", Marker.val))
  }

//////////////////////////////////////////////////////////////////////////
// Scalars
//////////////////////////////////////////////////////////////////////////

  Void testScalars()
  {
    verifyScalarErr(Date.today, "sys::Date", null)
    verifyScalarErr("foo", "sys::Date", "Invalid type 'sys::Str', expecting 'sys::Date'")

    verifyScalarErr("123-89-4567", "hx.test.xeto::TestSsn", null)
    verifyScalarErr("123-xx-4567", "hx.test.xeto::TestSsn", "String encoding does not match pattern for 'hx.test.xeto::TestSsn'")
  }

  Void verifyScalarErr(Obj? val, Str qname, Str? expect)
  {
    // haystack fidelity so scalar strings validate by pattern
    r := nsTest.validate(val, nsTest.spec(qname), Etc.dict1("haystack", Marker.val))
    verifyEq(r.items.join("\n") { it.dis }, expect ?: "")
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

    // invalid types; compile fails fast on the scalar decode err
    // before the Validate step runs
    verifyValidate(src, ["num":"bad", "str":n(123), "ref":n(123)],
      [
        "Invalid 'sys::Number' string value: \"bad\"",
      ],
      [
        "Slot 'num': Invalid type 'sys::Str', expecting 'sys::Number'",
        "Slot 'str': Invalid type 'sys::Number', expecting 'sys::Str'",
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
        "Slot 'i': Invalid type 'sys::Number', expecting 'sys::Int'"])
      verifyFidelity(spec, ["f":n(72)], null, [
        "Slot 'f': Invalid type 'sys::Number', expecting 'sys::Float'"])

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
    opts := opt == null ? Etc.dict0 : Etc.dict1(opt, Marker.val)
    r := nsTest.validate(instance, spec, opts)
    verifyEq(r.items.join("\n") { it.dis }, expect.join("\n"))
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

    // at runtime full fidelity requires custom scalars to be Scalar
    // wrappers, so plain Str values for b/d/f are invalid types (see
    // testEngineConstraints for runtime checks with typed values)
    bInvalid := "Slot 'b': Invalid type 'sys::Str', expecting 'temp::MyDate'"
    dInvalid := "Slot 'd': Invalid type 'sys::Str', expecting 'temp::MyNonEmpty'"
    fInvalid := "Slot 'f': Invalid type 'sys::Str', expecting 'temp::MySizeStr'"

    // all ok at compile
    ok := ["a":"2024-11-07", "b":"1234-56-78", "c":"!", "d":"!", "e":"ab", "f":"abce"]
    verifyValidate(src, ok, [,], [bInvalid, dInvalid, fInvalid])

    // bad pattern
    verifyValidate(src, ok.dup.setAll(["a":"2024-11-7", "b":"1234_56_78"]), [
      "Slot 'a': String encoding does not match pattern for 'sys::Str'",
      "Slot 'b': String encoding does not match pattern for 'temp::MyDate'",
    ], [
      "Slot 'a': String encoding does not match pattern for 'sys::Str'",
      bInvalid, dInvalid, fInvalid,
    ])

    // empty
    verifyValidate(src, ok.dup.setAll(["c":"", "d":" "]), [
      "Slot 'c': Must be non-empty",
      "Slot 'd': Must be non-empty",
    ], [
      bInvalid,
      "Slot 'c': Must be non-empty",
      dInvalid, fInvalid,
    ])

    // minSize
    verifyValidate(src, ok.dup.setAll(["e":"", "f":"1"]), [
      "Slot 'e': Size 0 < minSize 2",
      "Slot 'f': Size 1 < minSize 2",
    ], [
      bInvalid, dInvalid,
      "Slot 'e': Size 0 < minSize 2",
      fInvalid,
    ])

    // maxSize
    verifyValidate(src, ok.dup.setAll(["e":"12345", "f":"123456"]), [
      "Slot 'e': Size 5 > maxSize 4",
      "Slot 'f': Size 6 > maxSize 4",
    ], [
      bInvalid, dInvalid,
      "Slot 'e': Size 5 > maxSize 4",
      fInvalid,
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
      "Slot 'a': Must be non-empty",
    ])

    // minSize
    verifyValidate(src, ok.dup.setAll(["b":Str[,]]), [
      "Slot 'b': Size 0 < minSize 1",
    ])

    // maxSize
    verifyValidate(src, ok.dup.setAll(["b":["1", "2", "3", "4"]]), [
      "Slot 'b': Size 4 > maxSize 3",
    ])

    // item types report as per-item frames at dotted paths
    verifyValidate(src, ok.dup.set("c", [n(123), Etc.dict0, 123, `uri`]), [
      "Slot 'c.1': Invalid type 'sys::Dict', expecting 'sys::Number'",
      "Slot 'c.3': Invalid type 'sys::Uri', expecting 'sys::Number'",
    ])

    // item types using list subtype
    verifyRunTime(src, ok.dup.set("d", [`uri1`, n(123), Etc.dict0, `uri2`]), [
      "Slot 'd.1': Invalid type 'sys::Number', expecting 'sys::Uri'",
      "Slot 'd.2': Invalid type 'sys::Dict', expecting 'sys::Uri'",
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

    // at runtime full fidelity requires enum values to be Scalar
    // wrappers, so plain Str values are invalid types (see
    // testEngineConstraints for runtime checks with typed values)
    enumInvalid := [
      "Slot 'c': Invalid type 'sys::Str', expecting 'temp::Color'",
      "Slot 'p': Invalid type 'sys::Str', expecting 'ph::PrimaryFunction'",
      "Slot 's': Invalid type 'sys::Str', expecting 'ph::CurStatus'",
    ]

    // all ok at compile
    verifyValidate(src, ["s":"down", "p":"Bank Branch", "c":"red"], [,], enumInvalid)

    // bad keys
    verifyValidate(src, ["c":"x", "p":"bankBranch", "s":"y"], [
      "Slot 'c': Invalid key 'x' for enum type 'temp::Color'",
      "Slot 'p': Invalid key 'bankBranch' for enum type 'ph::PrimaryFunction'",
      "Slot 's': Invalid key 'y' for enum type 'ph::CurStatus'",
    ], enumInvalid)
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
      "Slot 'd': Invalid type 'sys::Number', expecting 'sys::MultiRef'",
      "Slot 'e': Invalid type 'sys::List', expecting 'sys::MultiRef'",
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

    // target type not found (runtime only)
    verifyRunTime(src, ok.dup.set("equipRef", refEqX).set("enum", Ref("ph::WeatherCondEnum")), [
      "Slot 'equipRef': Ref target spec not found: @to-eq-x",
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
      "Slot 'site': Invalid type 'sys::Date', expecting 'sys::Marker'",
      ])


    // global in lib AST
    src =
    Str<|Foo: Dict {
           *baz: Number <quantity:"length", minVal:0>
         }
         |>


    // invalid target types in lib
    verifyCompileTime(src, toInstance(["baz":Uri("file.txt")]), [
      "Slot 'baz': Invalid type 'sys::Uri', expecting 'sys::Number'",
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
// Compile Time
//////////////////////////////////////////////////////////////////////////

  ** Custom rules from the depends run at compile time on our instances;
  ** the runtime side of these rules is covered by testRulesCustom
  Void testCompileDependRules()
  {
    src :=
    Str<|Foo: TestRuleSubject
         |>

    verifyCompileTime(src, toInstance(["code":"T100"]), [,])
    verifyCompileTime(src, toInstance(["code":"X100"]), [
      "Code 'X100' must start with 'T'",
    ])

    // the Fantom bound testMinMax rule fires while its func twin
    // testFuncMinMax skips: there is no context at compile to call
    // funcs (their runtime behavior is covered by testRulesOnEntity)
    verifyCompileTime(src, toInstance(["min":n(20), "max":n(10)]), [
      "Slot 'min': Value 20 must be below max",
    ])
  }

  ** A lib's own rules never run at compile time: the registry is built
  ** from the depends only, so they first apply at runtime
  Void testCompileOwnLibRules()
  {
    src := srcAddPragma(
      Str<|Foo: Dict { code: Str? }

           @ruleCode: ValidateRule {
             on: Foo
             msg: "Code '$code' must start with 'T'"
           }

           @bad: Foo { code: "X100" }
           |>)
    lib := nsTest.compileTempLib(src)
    verifyEq(lib.instance("bad")->code, "X100")
  }

  ** Warn level items report to the warn stream and do not fail the
  ** compile; err level items fail it
  Void testCompileWarns()
  {
    // ph pointTz is a warn: point compiles with a warning
    src := srcAddPragma(
      Str<|@site: ph::Site { dis: "Site" }
           @pt: ph::Point { siteRef: @site }
           |>)
    errs := XetoLogRec[,]
    lib := nsTest.compileTempLib(src, logOpts("log", errs))
    verifyEq(lib.instances.size, 2)
    verifyEq(errs.size, 1)
    verifyEq(errs.first.level, LogLevel.warn)
    verifyEq(errs.first.msg, "Point should have tz")

    // ph pointMissingSiteRef is an err: the compile fails
    src = srcAddPragma(
      Str<|@pt: ph::Point { tz: "New_York" }
           |>)
    errs.clear
    try { nsTest.compileTempLib(src, logOpts("log", errs)); fail } catch (Err e) {}
    verifyEq(errs.first.msg, "Point must have siteRef or weatherStationRef")
  }

  ** Missing required slots are not compile errors since instances
  ** inherit from their spec; at runtime they report
  Void testCompileMissingSlots()
  {
    src :=
    Str<|Foo: Dict {
           req: Str
           opt: Str?
         }|>

    verifyValidate(src, ["req":"x"], [,])
    verifyValidate(src, [:], [,], [
      "Slot 'req': Missing required slot 'req'",
    ])
  }

  ** Spec meta values validate against their meta member specs; This
  ** typed meta such as minVal follows the plain numeric idiom and is
  ** not checked
  Void testCompileMeta()
  {
    verifyCompileMeta("Foo: Dict <metaSized:\"abc\">", null)
    verifyCompileMeta("Foo: Dict <metaSized:\"ab\">", "Size 2 < minSize 3")
    verifyCompileMeta("Foo: Dict { a: Str <metaSized:\"ab\"> }", "Size 2 < minSize 3")
    verifyCompileMeta("Foo: Scalar <minVal:0, maxVal:1> \"0\"", null)
  }

  private Void verifyCompileMeta(Str src, Str? expect)
  {
    errs := XetoLogRec[,]
    try
      nsTest.compileTempLib(srcAddPragma(src), logOpts("log", errs))
    catch (Err e)
      {}
    verifyEq(errs.map |x->Str| { x.msg }, expect == null ? Str[,] : Str[expect])
  }

  ** Items report at the source loc of the offending value, refined by
  ** walking the item's slot path back thru the AST
  Void testCompileLocs()
  {
    src := srcAddPragma(
      Str<|Foo: Dict {
             num: Number <maxVal:5>
             tags: List<of:Number>
           }

           @a: Foo {
             num: 10
             tags: { Number 1, Uri "x" }
           }
           |>)
    errs := XetoLogRec[,]
    try { nsTest.compileTempLib(src, logOpts("log", errs)) } catch (Err e) {}
    verifyEq(errs.size, 2)
    verifyEq(errs[0].msg, "Slot 'num': Number 10 > maxVal 5")
    verifyEq(errs[0].loc.line, 11)
    verifyEq(errs[1].msg.contains("Slot 'tags.1'"), true)
    verifyEq(errs[1].loc.line, 12)
  }

  ** Data compiles validate thru the engine: scalar roots, dict roots,
  ** and custom rules from the namespace
  Void testCompileData()
  {
    ns := nsTest

    ssnOk := ns.io.readXeto(Str<|hx.test.xeto::TestSsn "123-45-6789"|>)
    verifyEq(ssnOk, Scalar("hx.test.xeto::TestSsn", "123-45-6789"))

    verifyErrMsg(XetoCompilerErr#, "String encoding does not match pattern for 'hx.test.xeto::TestSsn'")
    {
      ns.io.readXeto(Str<|hx.test.xeto::TestSsn "123-45-678x"|>)
    }

    verifyErrMsg(XetoCompilerErr#, "Code 'X100' must start with 'T'")
    {
      ns.io.readXeto(Str<|hx.test.xeto::TestRuleSubject { code: "X100" }|>)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Verify
//////////////////////////////////////////////////////////////////////////

  ** Verify both compile time and run time for spec called Foo in src
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

  ** Verify the instance checked using ns.validate after lib src is compiled
  Void verifyRunTime(Str src, Obj instance, Str[] expect)
  {
    src = srcAddPragma(src)
    instance = toInstance(instance)
    lib  := nsTest.compileTempLib(src)
    spec := lib.spec("Foo")
    initContext(lib).asCur |cx|
    {
      r := nsTest.validate(instance, spec)
      recs := r.items.map |item->XetoLogRec|
      {
        XetoLogRec(item.level.isErr ? LogLevel.err : LogLevel.warn, null, item.dis, FileLoc.unknown, null)
      }
      verifyErrs("Run Time", instance, r, recs, expect)
    }
  }

  ** Create opts with log for the compiler
  Dict logOpts(Str key, XetoLogRec[] acc)
  {
    logger := |XetoLogRec rec| { acc.add(rec) }
    return Etc.dict1(key, Unsafe(logger))
  }

  ** Create context with the recs remapped to the compiled temp lib
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

  ** Verify actual errors from compiler/validator against expected results
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

**************************************************************************
** ValidateTestCodePrefix
**************************************************************************

@Js
const class ValidateTestCodePrefix : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    code := s.dict?.get("code") as Str
    if (code != null && !code.startsWith("T")) s.emit(Etc.dict1("code", code))
  }
}

**************************************************************************
** ValidateTestMinMax
**************************************************************************

** Cross-tag rule: registered on the entity type, but reports against
** the offending tag rather than the subject
@Js
const class ValidateTestMinMax : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    min := s.dict?.get("min") as Number
    max := s.dict?.get("max") as Number
    if (min != null && max != null && min > max) s.emitOn("min")
  }
}

