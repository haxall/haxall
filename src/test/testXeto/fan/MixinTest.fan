//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Nov 2025  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** MixinTest
**
@Js
class MixinTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    ns        := createNamespace(["hx.test.xeto"])
    lib       := ns.lib("hx.test.xeto")
    str       := ns.spec("sys::Str")
    number    := ns.spec("sys::Number")
    site      := ns.spec("ph::Site")
    testSite  := lib.spec("TestSite")
    sitex     := ns.specx(site)
    testSitex := ns.specx(testSite)
    sitem     := lib.spec("Site")
    csm       := lib.spec("CurStatus")
    phasem    := lib.spec("Phase")
    specm     := lib.spec("Spec")
    funcs     := lib.spec("Funcs")
    phem      := ns.spec("ph.protocols::PhEntity")

    verifyEq(sitem.isType, false)
    verifyEq(sitem.isMixin, true)
    verifyEq(sitem.flavor, SpecFlavor.mixIn)
    verifyEq(sitem.meta["mixin"], Marker.val)
    verifySame(sitem.base, site)
    verifySame(sitem.type, site)
    verifyFlavor(ns, sitem, SpecFlavor.mixIn)

    verifyEq(ns.mixinsFor(str), Spec[,])
    verifyEq(ns.mixinsFor(site), Spec[sitem, phem])
    verifyEq(ns.mixinsFor(testSite), Spec[sitem, phem])
    verifyEq(ns.mixinsFor(testSite).isImmutable, true)

    verifyEq(ns.mixinsOwn(str), Spec[,])
    verifyEq(ns.mixinsOwn(site), Spec[sitem])
    verifyEq(ns.mixinsOwn(testSite), Spec[,])
    verifyEq(ns.mixinsOwn(testSite).isImmutable, true)

    verifyEq(lib.mixins.list, Spec[csm, funcs, phasem, lib.mixinFor(ns.spec("ph.points.sugar::ReturnFanRunCmd")), sitem, specm, lib.mixinFor(ns.spec("ph.points::ZoneAirTempSensor"))])
    verifySame(lib.mixinFor(site), sitem)
    verifyEq(lib.mixinFor(ns.spec("sys::Str"), false), null)
    verifyEq(lib.mixinFor(lib.spec("EquipA"), false), null)
    verifyErr(UnknownSpecErr#) { lib.mixinFor(ns.spec("sys::Str")) }
    verifyErr(UnknownSpecErr#) { lib.mixinFor(ns.spec("sys::Str"), true) }

    // verify mixin only inherits slots it overrides
    verifySame(sitem.slot("area").parent, sitem)
    verifySame(sitem.slot("area").base, site.slot("area"))
    verifySame(site.slot("weatherStationRef").parent, site)
    verifyEq(sitem.slot("weatherStationRef", false), null)

    // specx meta

    verifySame(str, ns.specx(str))
    verifySpecx(site, sitex)
    verifySpecx(testSite, testSitex)
    verifySame(sitex.metaOwn, site.metaOwn)
    verifyNotSame(sitex.meta, site.meta)
    verifySame(sitex.meta, sitex.meta)
    verifyDictEq(sitex.meta, ["doc":site.metaOwn["doc"], "foo":"building"])
    verifyDictEq(testSitex.meta, ["doc":testSite.metaOwn["doc"], "foo":"building"])

    // specx meta merge of orig slots
    areaDoc := site.slot("area").meta["doc"]
    areaMeta := ["doc":areaDoc, "val":n(0), "quantity":UnitQuantity.area, "maybe":m, "foo":"AreaEditor", "bar":"hello",
      "pattern":numberPattern]
    area := sitex.slot("area")
    verifySame(area.type, number)
    verifyDictEq(area.meta, areaMeta)
    verifyDictEq(testSitex.slot("area").meta, areaMeta)
    verifyNotSame(site.slotOwn("area"), area)
    verifySame(sitex.slotOwn("area"), area)
    verifySame(sitex.member("area"), area)
    verifySame(sitex.membersOwn.get("area"), area)
    verifySame(sitex.members.get("area"), area)
    verifyEq(sitem.slot("area").qname, "hx.test.xeto::Site.area")
    verifySame(sitem.slot("area").type, number)

    // specx new slots
    newSlot := sitex.slot("newSlot")
    verifyEq(testSite.slot("newSlot", false), null)
    verifySame(sitem.slot("newSlot"), newSlot)
    verifySame(testSitex.slot("newSlot"), newSlot)
    verifySame(ns.specx(testSitex.slot("newSlot")), newSlot)
    verifyEq(newSlot.name, "newSlot")
    verifyEq(newSlot.qname, "hx.test.xeto::Site.newSlot")
    verifySame(newSlot.type, str)
    verifyDictEq(newSlot.metaOwn, ["foo":"hi"])

    // lookup specx of global/slot
    spec := ns.spec("ph::PhEntity.area")
    verifySame(ns.specx(spec),  spec)
    spec = ns.spec("ph::Site.area")
    verifyDictEq(ns.specx(spec).meta, areaMeta)
  }

  Void verifySpecx(Spec m, Spec x)
  {
    verifySame(m.lib,        x.lib)
    verifySame(m.parent,     x.parent)
    verifySame(m.id,         x.id)
    verifySame(m.name,       x.name)
    verifySame(m.qname,      x.qname)
    verifySame(m.type,       x.type)
    verifySame(m.base,       x.base)
    verifySame(m.metaOwn,    x.metaOwn)
    verifySame(m.flavor,     x.flavor)
    verifySame(m.globalsOwn, x.globalsOwn)
    verifySame(m.loc,        x.loc)
    verifySame(m.binding,    x.binding)
    verifySame(m.fantomType, x.fantomType)
    verifySame(m.of(false),  x.of(false))
    verifySame(m.ofs(false), x.ofs(false))

    verifyEq(m.isMaybe,     x.isMaybe)
    verifyEq(m.isEnum,      x.isEnum)
    verifyEq(m.isChoice,    x.isChoice)
    verifyEq(m.isFunc,      x.isFunc)
    verifyEq(m.isType,      x.isType)
    verifyEq(m.isMixin,     x.isMixin)
    verifyEq(m.isGlobal,    x.isGlobal)
    verifyEq(m.isSlot,      x.isSlot)
    verifyEq(m.isNone,      x.isNone)
    verifyEq(m.isThis,      x.isThis)
    verifyEq(m.isScalar,    x.isScalar)
    verifyEq(m.isMarker,    x.isMarker)
    verifyEq(m.isRef,       x.isRef)
    verifyEq(m.isMultiRef,  x.isMultiRef)
    verifyEq(m.isDict,      x.isDict)
    verifyEq(m.isList,      x.isList)
    verifyEq(m.isGrid,      x.isGrid)
    verifyEq(m.isFile,      x.isFile)
    verifyEq(m.isQuery,     x.isQuery)
    verifyEq(m.isInterface, x.isInterface)
    verifyEq(m.isComp,      x.isComp)
    verifyEq(m.isAnd,       x.isAnd)
    verifyEq(m.isOr,        x.isOr)
    verifyEq(m.isCompound,  x.isCompound)
    verifyEq(m.inheritanceDigest, x.inheritanceDigest)
  }

//////////////////////////////////////////////////////////////////////////
// Globals
//////////////////////////////////////////////////////////////////////////

  ** Verify a mixin's declared globals are wired through the reflection
  ** APIs in both local and remote namespaces
  Void testGlobals()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestGlobals(ns) }
  }

  Void doTestGlobals(Namespace ns)
  {
    lib   := ns.lib("hx.test.xeto")
    site  := ns.spec("ph::Site")
    sitem := lib.mixinFor(site)

    // globals are partitioned out of the slot maps
    gdate := sitem.globalsOwn.get("gdate")
    verifyEq(sitem.slotsOwn.get("gdate", false), null)
    verifyEq(sitem.slots.get("gdate", false), null)
    verifySame(sitem.membersOwn.get("gdate"), gdate)
    verifySame(sitem.member("gdate"), gdate)

    // reflection of the global itself
    verifyEq(gdate.name, "gdate")
    verifyEq(gdate.qname, "hx.test.xeto::Site.gdate")
    verifySame(gdate.parent, sitem)
    verifyEq(gdate.isGlobal, true)
    verifyEq(gdate.flavor, SpecFlavor.global)
    verifyEq(gdate.isMaybe, true)
    verifyEq(gdate.type.qname, "sys::Date")

    // global with meta; globals are implicitly maybe - they have no
    // containing type to be required of
    gnum := sitem.globalsOwn.get("gnum")
    verifyEq(gnum.isGlobal, true)
    verifyEq(gnum.isMaybe, true)
    verifyEq(gnum.type.qname, "sys::Number")
    verifyEq(gnum.meta["minVal"], n(0))

    // globals never leak into the plain declared-scope view
    verifyEq(site.member("gdate", false), null)
    verifyEq(site.globals.get("gdate", false), null)

    // but specx is the namespace-effective view: mixin globals are
    // merged into globals/members while never becoming slots, and
    // own stays declared-only
    sitex := ns.specx(site)
    xg := sitex.globals.get("gdate")
    verifyEq(xg.qname, "hx.test.xeto::Site.gdate")
    verifyEq(xg.isGlobal, true)
    verifyEq(xg.isMaybe, true)
    verifyEq(xg.type.qname, "sys::Date")
    verifySame(sitex.member("gdate"), xg)
    verifyEq(sitex.slot("gdate", false), null)
    verifyEq(sitex.globalsOwn.get("gdate", false), null)

    // chain globals and subtypes flow thru the merged view too
    verifySame(sitex.globals.get("dis"), site.globals.get("dis"))
    verifyEq(ns.specx(ns.spec("hx.test.xeto::TestSite")).globals.get("gdate").qname, "hx.test.xeto::Site.gdate")
  }

//////////////////////////////////////////////////////////////////////////
// Member Resolution
//////////////////////////////////////////////////////////////////////////

  ** Verify declared slots resolve against mixin members in scope:
  ** untyped slots infer type, typed slots bind base with covariance
  Void testMemberResolve()
  {
    ns := createNamespace(["ph", "hx.test.xeto"])
    pragma := Str<|pragma: Lib < version: "0.0.0", depends: { {lib:"sys"}, {lib:"ph"}, {lib:"hx.test.xeto"} } >
                   |>

    // untyped slots infer from depend lib mixin members - both a
    // mixin slot (newSlot) and a mixin global (gdate)
    lib := ns.compileTempLib(pragma +
      Str<|Foo: Site {
             newSlot: "custom"
             gdate: "2026-01-01"
           }
           |>)
    newSlot := lib.spec("Foo").slot("newSlot")
    verifyEq(newSlot.type.qname, "sys::Str")
    verifyEq(newSlot.base.qname, "hx.test.xeto::Site.newSlot")
    gdate := lib.spec("Foo").slot("gdate")
    verifyEq(gdate.type.qname, "sys::Date")
    verifyEq(gdate.base.qname, "hx.test.xeto::Site.gdate")
    verifyEq(gdate.base.isGlobal, true)
    verifyEq(gdate.isMaybe, true)

    // own lib mixin members resolve too (gap in the old slotx design)
    lib2 := ns.compileTempLib(pragma +
      Str<|+ph::Site { *own: Number }
           Bar: Site { own: 123 }
           |>)
    own := lib2.spec("Bar").slot("own")
    verifyEq(own.type.qname, "sys::Number")
    verifyEq(own.isMaybe, true)
    verifyEq(own.base.isGlobal, true)

    // the three case rule: typed = required, typed maybe = maybe,
    // value only infers as maybe; the ? sugar and explicit <maybe>
    // meta are equivalent spellings
    lib3 := ns.compileTempLib(pragma +
      Str<|Req: Site { gdate: Date }
           Opt: Site { gdate: Date? }
           Opt2: Site { gdate: Date <maybe> }
           |>)
    verifyEq(lib3.spec("Req").slot("gdate").isMaybe, false)
    verifyEq(lib3.spec("Opt").slot("gdate").isMaybe, true)
    verifyEq(lib3.spec("Opt2").slot("gdate").isMaybe, true)

    // marker refs to a plain chain global follow the same rule: a
    // bare marker is an explicitly typed slot and required
    verifyEq(ns.spec("hx.test.xeto::ElecEquipA").slot("elec").isMaybe, false)
    verifyEq(ns.spec("hx.test.xeto::ElecEquipMaybeA").slot("elec").isMaybe, true)
    verifyEq(ns.spec("ph::PhEntity").globals.get("elec").isMaybe, true)

    // typed slot binds to the mixin member and covariance checks
    // (previously an unlinked silent shadow)
    verifyCompileErr(ns, pragma +
      "Bad: Site { newSlot: Date }\n",
      "conflicts inherited slot 'hx.test.xeto::Site.newSlot'")

    // declared global colliding with a mixin global is a dup
    verifyCompileErr(ns, pragma +
      "Baz: Site { *gdate: Str }\n",
      "Duplicate global: hx.test.xeto::Site.gdate")

    // two mixins contributing the same name coexist legally...
    ns.compileTempLib(pragma +
      Str<|+ph::Site { *gdate: Number }
           Qux: Site {}
           |>)

    // ...but a declared slot inheriting against the ambiguous name errs
    verifyCompileErr(ns, pragma +
      Str<|+ph::Site { *gdate: Number }
           Amb: Site { gdate: "x" }
           |>,
      "Ambiguous inherited member 'gdate' from multiple mixins")

    // a mixin extending sys::Enum is meta contribution, not an enum
    ns.compileTempLib(pragma + "+Enum <foo:\"list\">\n")
  }

//////////////////////////////////////////////////////////////////////////
// Validate
//////////////////////////////////////////////////////////////////////////

  Void testValidate()
  {
    ns   := createNamespace(["ph", "hx.test.xeto"])
    site := ns.spec("ph::Site")

    // mixin-contributed required slot must be enforced
    ok := Etc.dict4("id", ref("x"), "site", m, "dis", "Site",  "newSlot", "x")
    verifyValidateItems(ns, ok, site, Str[,])

    missing := Etc.dict3("id", ref("x"), "site", m, "dis", "Site")
    verifyValidateItems(ns, missing, site, [
      "Slot 'newSlot': Missing required slot 'newSlot'"
      ])

    // subtype inherits the mixin contribution
    testSite := ns.spec("hx.test.xeto::TestSite")
    verifyValidateItems(ns, missing, testSite, [
      "Slot 'newSlot': Missing required slot 'newSlot'"
      ])

    // globals restrict present tags: absence is legal (implicitly
    // maybe), but a present value must fit the global's type and meta
    okG := Etc.dictx("id", ref("x"), "site", m, "dis", "Site", "newSlot", "x",
      "gdate", Date("2026-01-01"), "gnum", n(4))
    verifyValidateItems(ns, okG, site, Str[,])

    badType := Etc.dictx("id", ref("x"), "site", m, "dis", "Site", "newSlot", "x",
      "gdate", "garbage")
    verifyValidateItems(ns, badType, site, [
      "Slot 'gdate': Invalid type 'sys::Str', expecting 'sys::Date'"
      ])

    badMeta := Etc.dictx("id", ref("x"), "site", m, "dis", "Site", "newSlot", "x",
      "gnum", n(-4))
    verifyValidateItems(ns, badMeta, site, [
      "Slot 'gnum': Number -4 < minVal 0"
      ])

    // plain chain globals restrict the same way
    badDis := Etc.dictx("id", ref("x"), "site", m, "dis", n(123), "newSlot", "x")
    verifyValidateItems(ns, badDis, site, [
      "Slot 'dis': Invalid type 'sys::Number', expecting 'sys::Str'"
      ])
  }

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  Void testEnum()
  {
    ns := createNamespace(["ph", "hx.test.xeto"])

    // verify Specx.enum uses extended slot meta
    spec := ns.spec("ph::CurStatus")
    specx := ns.specx(spec)
    verifyDictEq(specx.meta, Etc.dictToMap(spec.meta).set("qux", "_self_"))
    verifyEnumItem(spec, specx, "ok",     "green")
    verifyEnumItem(spec, specx, "down",    "yellow")
    verifyEnumItem(spec, specx, "disabled", null)

    // test Phase where names are different than keys
    spec = ns.spec("ph::Phase")
    specx = ns.specx(spec)
    verifyEnumItem(spec, specx, "L1", "Line 1")
    verifyEnumItem(spec, specx, "L1-L2", "Line 1 to Line 2")

    // Specx.enum raises exception for non-enum
    verifyErr(UnsupportedErr#) { ns.specx(ns.spec("ph::Site")).enum }
  }

  Void verifyEnumItem(Spec spec, Spec specx, Str key, Str? foo)
  {
    item  := spec.enum.spec(key)
    itemx := specx.enum.spec(key)
    if (foo == null)
    {
      verifySame(item, itemx)
      verifySame(spec.slot(item.name), specx.slot(item.name))
      return
    }
    verifyNotSame(item, itemx)
    verifyNotSame(spec.slot(item.name), specx.slot(item.name))
    verifySame(item, spec.slot(item.name))
    verifySame(itemx, specx.slot(item.name))
    verifyEq(item.meta["foo"], null)
    verifyEq(itemx.meta["foo"], foo)
    verifyDictEq(itemx.meta, Etc.dictSet(item.meta, "foo", foo))
  }

//////////////////////////////////////////////////////////////////////////
// Multi-File Mixin
//////////////////////////////////////////////////////////////////////////

  ** Verify hx.test.xeto defines +Funcs across funcs.xeto and funcs2.xeto
  Void testMultiFile()
  {
    ns    := createNamespace(["hx.test.xeto"])
    funcs := ns.lib("hx.test.xeto").spec("Funcs")

    // func declared in funcs.xeto
    verifyNotNull(funcs.slot("ping1", false))

    // func declared in the second file funcs2.xeto merged in
    fromSecond := funcs.slot("funcFrom2ndMixin", false)
    verifyNotNull(fromSecond)
    verifyEq(fromSecond.isFunc, true)
  }

  ** Only one declaration of a multi-file mixin may carry meta.
  Void testMultiFileMeta()
  {
    ns := createNamespace(["sys"])

    // meta on a single +Funcs block (with a second slots-only block) is fine
    lib := ns.compileTempLib(
      Str<|+Funcs <doc:"the funcs mixin"> { a: Func {} }
           +Funcs { b: Func {} }
           |>)
    funcs := lib.spec("Funcs")
    verifyEq(funcs.isMixin, true)
    verifyNotNull(funcs.slot("a", false))
    verifyNotNull(funcs.slot("b", false))

    // meta on two +Funcs blocks is an error
    verifyErrMsg(XetoCompilerErr#, "Multi-file mixin 'Funcs' meta already declared")
    {
      ns.compileTempLib(
        Str<|+Funcs <doc:"first"> { a: Func {} }
             +Funcs <doc:"second"> { b: Func {} }
             |>)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Depends Scope
//////////////////////////////////////////////////////////////////////////

  ** Compile semantics scope to the transitive depends closure: mixin
  ** members, meta vocabulary, and validate rules from a depend of a
  ** depend all apply to the lib under compile.  Uses real lib dir
  ** compiles since compileTempLib resolves against the entire
  ** namespace rather than a declared depends list.
  Void testDependsScope()
  {
    // mixin members resolve declared slots; hx.test.xeto is direct,
    // ph and ph.protocols only transitive
    lib := scopeCompile(["sys", "hx.test.xeto"],
      Str<|Foo: TestSite {
             newSlot: "custom"
             bacnetCurAddr: {addr:"AO4"}
           }
           |>)
    newSlot := lib.spec("Foo").slot("newSlot")
    verifyEq(newSlot.base.qname, "hx.test.xeto::Site.newSlot")
    addr := lib.spec("Foo").slot("bacnetCurAddr")
    verifyEq(addr.type.qname, "ph.protocols::BacnetAddr")
    verifyEq(addr.base.qname, "ph.protocols::PhEntity.bacnetCurAddr")
    verifyEq(addr.base.isGlobal, true)

    // the sys::Spec mixin tags of hx.test.xeto are visible thru
    // hx.test.xeto.deep
    lib = scopeCompile(["sys", "hx.test.xeto.deep"],
      Str<|Foo: Dict <metaQ, metaStr:"hello">
           |>)
    verifyEq(lib.spec("Foo").meta["metaQ"], Marker.val)
    verifyEq(lib.spec("Foo").meta["metaStr"], "hello")

    // rule hx.test.xeto::testCodePrefix on TestRuleSubject applies
    // to instances of hx.test.xeto.deep::DeepRuleSubject
    scopeCompile(["sys", "hx.test.xeto.deep"],
      Str<|@ok: DeepRuleSubject { code:"T100" }
           |>)
    Err? err
    try
      scopeCompile(["sys", "hx.test.xeto.deep"],
        Str<|@bad: DeepRuleSubject { code:"X100" }
             |>)
    catch (Err e) err = e
    verifyNotNull(err)
    verify(err.msg.contains("Code 'X100' must start with 'T'"), err.msg)
  }

  ** Compile a lib dir with the given declared depends against a
  ** namespace bigger than its closure
  private Lib scopeCompile(Str[] depends, Str src)
  {
    dir := tempDir + `scope/test.scope/`
    dir.delete
    pragma := StrBuf().add("pragma: Lib <\n  version: \"0.0.0\"\n  depends: {\n")
    depends.each |d| { pragma.add("    { lib: $d.toCode }\n") }
    pragma.add("  }\n>\n")
    (dir + `lib.xeto`).out.print(pragma.toStr).close
    (dir + `test.xeto`).out.print(src).close
    return XetoCompiler.init
    {
      it.ns      = createNamespace(["ph", "hx.test.xeto", "hx.test.xeto.deep"])
      it.libName = "test.scope"
      it.input   = dir
    }.compileLib
  }
}

