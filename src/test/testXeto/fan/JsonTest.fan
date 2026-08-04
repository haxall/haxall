//
// Copyright (c) 2026, Brian Frank
// All Rights Reserved
//
// History:
//   9 Jan 2026  Mike Jarmy
//

using util
using xeto
using xetom
using haystack

**
** JsonTest verifies the clean JSON codec.  The decode tests are organized by
** the rule of the resolution ladder they cover, so a failure names the rule.
**
@Js
class JsonTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Syntax Classes
//////////////////////////////////////////////////////////////////////////

  ** JSON syntax alone fixes the broad class.  A number takes its lexical
  ** form - Int without a fraction or exponent, otherwise Float - and never
  ** decodes as Number unless the position names Number.
  Void testSyntaxClasses()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyDecode(ns, "123", 123)
    verifyDecode(ns, "-7", -7)
    verifyDecode(ns, "0", 0)
    verifyDecode(ns, "72.0", 72.0f)
    verifyDecode(ns, "3.4", 3.4f)
    verifyDecode(ns, "1e3", 1000.0f)
    verifyDecode(ns, "true", true)
    verifyDecode(ns, "false", false)
    verifyDecode(ns, "null", null)
    verifyDecode(ns, Str<|"abc"|>, "abc")

    verifyEq(read(ns, "[]"), Obj[,])
    verifyDictEq(read(ns, "{}"), Etc.dict0)

    // a null value is absent, not a value; and never NA
    verifyDictEq(read(ns, Str<|{"a":1, "b":null}|>), Etc.dict1("a", 1))

    // a null list item is kept, which is where lists differ from dicts
    verifyEq(read(ns, Str<|["a", null]|>), Obj?["a", null])
  }

//////////////////////////////////////////////////////////////////////////
// Rule 1 - Boxed Scalar
//////////////////////////////////////////////////////////////////////////

  ** A box carries its own type, so it needs no context and is legal anywhere
  ** a scalar may appear.
  Void testRule1Box()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyDecode(ns, Str<|{"val":"72°F", "spec":"sys::Number"}|>, n(72, "°F"))

    // val is always a JSON string, even for a type with a native JSON form
    verifyDecode(ns, Str<|{"val":"100", "spec":"sys::Number"}|>, n(100))
    verifyDecode(ns, Str<|{"val":"true", "spec":"sys::Bool"}|>, true)

    // NA has no plain form in an untyped position, so the box is how it
    // travels; JSON null never means NA
    verifyDecode(ns, Str<|{"val":"NA", "spec":"sys::NA"}|>, NA.val)
    verifyDecode(ns, "null", null)

    // legal as a slot value, a list item, and a grid cell
    verifyDictEq(read(ns, Str<|{"a":{"val":"NA","spec":"sys::NA"}}|>),
                 Etc.dict1("a", NA.val))
    verifyEq(read(ns, Str<|[{"val":"2024-11-26","spec":"sys::Date"}]|>),
             Obj[Date.fromStr("2024-11-26")])

    // a spec that resolves to a non-scalar is not a box: it is an ordinary
    // dict typed by that spec
    verifyDictEq(read(ns, Str<|{"val":"x", "spec":"sys::Dict"}|>),
                 Etc.dict2("val", "x", "spec", Ref("sys::Dict")))
  }

//////////////////////////////////////////////////////////////////////////
// Rule 2 - Grid Column 'of'
//////////////////////////////////////////////////////////////////////////

  ** The column 'of' is the cell's expected spec: a parse default for a
  ** string, a coercion target for a number within the numeric family.
  Void testRule2ColOf()
  {
    ns := createNamespace(["hx.test.xeto"])

    Grid g := read(ns, Str<|{
                              "spec": "sys::Grid",
                              "cols": [
                                {"name": "ts", "of": "sys::DateTime"},
                                {"name": "v0", "of": "sys::Number"}
                              ],
                              "rows": [
                                {"ts": "2026-08-03T09:00:00-04:00 New_York", "v0": "NaN"},
                                {"ts": "2026-08-03T10:00:00-04:00 New_York", "v0": "73"},
                                {"ts": "2026-08-03T11:00:00-04:00 New_York", "v0": 73}
                              ]
                            }|>)

    verifyEq(g.size, 3)
    verifyValEq(g[0]->ts,
      DateTime.fromStr("2026-08-03T09:00:00-04:00 New_York"))

    // the column type makes Number's full string grammar available
    verify(((Number)g[0]->v0).isNaN)

    // a string cell and a bare number cell agree once the column says Number
    verifyValEq(g[1]->v0, n(73))
    verifyValEq(g[2]->v0, n(73))

    // 'of' survives into col meta so the writer can put it back on the wire
    verifyEq(XetoUtil.gridColSpecRef(g.col("ts")), Ref("sys::DateTime"))
    verifyEq(XetoUtil.gridColSpecRef(g.col("v0")), Ref("sys::Number"))
  }

//////////////////////////////////////////////////////////////////////////
// Rule 3 - Containing Dict Spec
//////////////////////////////////////////////////////////////////////////

  ** Every other value resolves through the spec of its containing dict, by
  ** matching the tag name to a member of that spec.
  Void testRule3DictSpec()
  {
    ns := createNamespace(["hx.test.xeto"])
    edge := ns.spec("hx.test.xeto::JsonEdge")

    // an explicit spec tag types the members
    json := Str<|{
                   "spec":"hx.test.xeto::JsonEdge",
                   "int":"5",
                   "unitless":"90"
                 }|>
    Dict d := read(ns, json)
    verifyValEq(d->int, 5)
    verifyValEq(d->unitless, n(90))
    verifyValEq(d->spec, Ref("hx.test.xeto::JsonEdge"))

    // the same members resolve from the root spec with no spec tag present
    d = read(ns, Str<|{"int":"5", "float":"72.0", "na":"NA"}|>, edge)
    verifyValEq(d->int, 5)
    verifyValEq(d->float, 72.0f)
    verifyValEq(d->na, NA.val)

    // the explicit tag beats the containing context
    d = read(ns, Str<|{"spec":"hx.test.xeto::JsonEdge", "int":"5"}|>,
             ns.spec("sys::Dict"))
    verifyValEq(d->int, 5)

    // the grid meta 'of' supplies the default row spec
    Grid g := read(ns, Str<|{
                              "spec": "sys::Grid",
                              "meta": {"of": "hx.test.xeto::JsonRow"},
                              "cols": [{"name":"v0"}],
                              "rows": [{"v0":"73"}]
                            }|>)
    verifyValEq(g.first->v0, n(73))
  }

//////////////////////////////////////////////////////////////////////////
// Fallback - Str
//////////////////////////////////////////////////////////////////////////

  ** No rule matched: a JSON string is a Str, verbatim, never guessed.  This
  ** is the no-sniffing invariant and it has no exceptions - not for markers,
  ** not for None, not for NA, not for the tag name 'id'.
  Void testFallbackStr()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyDictEq(read(ns, Str<|{"customTag":"72°F"}|>),
                 Etc.dict1("customTag", "72°F"))

    json := Str<|{
                   "d":"2024-11-26",
                   "mark":"✓",
                   "none":"∅",
                   "na":"NA",
                   "id":"abc"
                 }|>
    verifyDictEq(read(ns, json),
                 Etc.dict5("d", "2024-11-26", "mark", "✓", "none", "∅",
                           "na", "NA", "id", "abc"))

    // a member declared Str keeps the string even though it reads as a Number
    Dict d := read(ns, Str<|{"looksNum":"72°F"}|>,
                   ns.spec("hx.test.xeto::JsonEdge"))
    verifyValEq(d->looksNum, "72°F")

    // an id resolves as a Ref only when the spec declares one
    d = read(ns, Str<|{"id":"abc"}|>, ns.spec("hx.test.xeto::JsonRow"))
    verifyValEq(d->id, Ref("abc"))
  }

//////////////////////////////////////////////////////////////////////////
// Ladder Priority
//////////////////////////////////////////////////////////////////////////

  ** Self-description beats context, and overriding context is never a decode
  ** error.  Every case here is one where the context loses.
  Void testLadderPriority()
  {
    ns := createNamespace(["hx.test.xeto"])
    edge := ns.spec("hx.test.xeto::JsonEdge")

    // 1 beats 3: a box overrides the member spec
    Dict d := read(ns, Str<|{"int":{"val":"2024-11-26","spec":"sys::Date"}}|>,
                   edge)
    verifyValEq(d->int, Date.fromStr("2024-11-26"))

    // syntax beats 3 across families: a bool in a Number member stays Bool
    d = read(ns, Str<|{"unitless":true}|>, edge)
    verifyValEq(d->unitless, true)

    // a number in a Str member keeps its lexical type
    d = read(ns, Str<|{"looksNum":73}|>, edge)
    verifyValEq(d->looksNum, 73)

    // 2 beats 3: the column 'of' outranks the row spec's member
    Grid g := read(ns, Str<|{
                              "spec": "sys::Grid",
                              "meta": {"of": "hx.test.xeto::JsonRow"},
                              "cols": [{"name":"v0","of":"sys::Str"}],
                              "rows": [{"v0":"73"}]
                            }|>)
    verifyValEq(g.first->v0, "73")

    // 1 beats 2: a boxed cell overrides the column 'of'
    g = read(ns, Str<|{
                        "spec": "sys::Grid",
                        "cols": [{"name":"v0","of":"sys::Number"}],
                        "rows": [{"v0":{"val":"abc","spec":"sys::Str"}}]
                      }|>)
    verifyValEq(g.first->v0, "abc")

    // a bare number in a Bool column keeps its syntax type, and is no error
    g = read(ns, Str<|{
                        "spec": "sys::Grid",
                        "cols": [{"name":"b","of":"sys::Bool"}],
                        "rows": [{"b":73}]
                      }|>)
    verifyValEq(g.first->b, 73)

    // a row spec tag beats the grid meta 'of', so rows may differ in type
    g = read(ns, Str<|{
                        "spec": "sys::Grid",
                        "meta": {"of": "hx.test.xeto::JsonRow"},
                        "cols": [{"name":"spec"},{"name":"extra"},{"name":"v0"}],
                        "rows": [
                          {"v0":"73"},
                          {"spec":"hx.test.xeto::JsonRowB","extra":"x","v0":"74"}
                        ]
                      }|>)
    verifyValEq(g[0]->v0, n(73))
    verifyValEq(g[1]->v0, n(74))
    verifyValEq(g[1]->extra, "x")
  }

//////////////////////////////////////////////////////////////////////////
// Strict vs Lenient
//////////////////////////////////////////////////////////////////////////

  ** The 'lenient' option degrades an undecodable position to untyped instead
  ** of raising.  Degrading is silent at runtime, so these assertions are the
  ** only place the behavior is pinned.
  Void testStrictVsLenient()
  {
    ns := createNamespace(["hx.test.xeto"])
    edge := ns.spec("hx.test.xeto::JsonEdge")

    // unparseable scalar text
    json := Str<|{"int":"not-a-number"}|>
    verifyErr(null) { read(ns, json, edge) }
    verifyValEq(readDict(ns, json, edge, lenientOpts)->int, "not-a-number")

    // unresolvable spec ref; a name inside a loaded lib so that the lenient
    // path exercises the unchecked lookup rather than an unknown lib
    json = Str<|{"spec":"hx.test.xeto::NoSuchSpec", "a":"x"}|>
    verifyErr(null) { read(ns, json) }
    verifyValEq(readDict(ns, json, null, lenientOpts)->a, "x")

    // malformed box: val must be a JSON string
    json = Str<|{"val":5, "spec":"sys::Number"}|>
    verifyErr(IOErr#) { read(ns, json) }
    verifyDictEq(read(ns, json, null, lenientOpts),
                 Etc.dict2("val", 5, "spec", Ref("sys::Number")))

    // a structural grid error always raises, lenient or not
    json = Str<|{"spec":"sys::Grid","rows":[]}|>
    verifyErr(null) { read(ns, json) }
    verifyErr(null) { read(ns, json, null, lenientOpts) }

    // self-description overriding context is never gated by lenient
    json = Str<|{"int":{"val":"2024-11-26","spec":"sys::Date"}}|>
    verifyValEq(readDict(ns, json, edge)->int, Date.fromStr("2024-11-26"))
  }

//////////////////////////////////////////////////////////////////////////
// Malformed and Adversarial Payloads
//////////////////////////////////////////////////////////////////////////

  ** A structural error in the grid envelope always raises.  Everything else
  ** either degrades under lenient or is legal by invariant 2.
  Void testMalformed()
  {
    ns := createNamespace(["hx.test.xeto"])

    // cols is not a list
    verifyStructuralErr(ns, Str<|{"spec":"sys::Grid","cols":{},"rows":[]}|>)

    // rows absent
    verifyStructuralErr(ns, Str<|{"spec":"sys::Grid","cols":[]}|>)

    // a row that is not a dict
    verifyStructuralErr(ns,
      Str<|{"spec":"sys::Grid","cols":[{"name":"a"}],"rows":["x"]}|>)

    // a spec tag that is not a qname: raises strict, degrades lenient
    json := Str<|{"spec":5,"a":1}|>
    verifyErr(null) { read(ns, json) }
    verifyDictEq(read(ns, json, null, lenientOpts), Etc.dict2("spec", 5, "a", 1))

    // a box whose spec cannot be resolved
    json = Str<|{"val":"5","spec":"hx.test.xeto::NoSuchSpec"}|>
    verifyErr(null) { read(ns, json) }
    verifyDictEq(read(ns, json, null, lenientOpts),
                 Etc.dict2("val", "5", "spec", Ref("hx.test.xeto::NoSuchSpec")))

    // a box carrying tags beyond val, spec and dis: the box still wins and
    // the extras are dropped
    verifyDecode(ns, Str<|{"val":"5","spec":"sys::Int","extra":"x"}|>, 5)

    // duplicate keys resolve last-wins in the JSON parser itself
    verifyDictEq(read(ns, Str<|{"a":1,"a":2}|>), Etc.dict1("a", 2))

    // a col 'of' naming a non-scalar supplies no grammar, so the cell stays
    // a Str rather than raising
    Grid g := read(ns, Str<|{
                              "spec":"sys::Grid",
                              "cols":[{"name":"a","of":"sys::Dict"}],
                              "rows":[{"a":"x"}]
                            }|>)
    verifyValEq(g.first->a, "x")

    // an unresolvable col 'of' raises strict and leaves the cell untyped
    // under lenient
    json = Str<|{
                 "spec":"sys::Grid",
                 "cols":[{"name":"a","of":"hx.test.xeto::NoSuchSpec"}],
                 "rows":[{"a":"x"}]
                }|>
    verifyErr(null) { read(ns, json) }
    g = read(ns, json, null, lenientOpts)
    verifyValEq(g.first->a, "x")

    // a grid where a scalar is expected: self-description beats the position
    json = Str<|{"spec":"sys::Grid","cols":[{"name":"a"}],"rows":[{"a":"x"}]}|>
    g = read(ns, json, ns.spec("sys::Date"))
    verifyValEq(g.first->a, "x")

    // a dict where a scalar is expected, and a scalar where a dict is
    verifyDictEq(read(ns, Str<|{"a":1}|>, ns.spec("sys::Date")),
                 Etc.dict1("a", 1))
    verifyDecode(ns, Str<|"abc"|>, "abc", ns.spec("sys::Dict"))
  }

  ** A structural envelope error raises whether or not lenient is set
  private Void verifyStructuralErr(MNamespace ns, Str json)
  {
    verifyErr(null) { read(ns, json) }
    verifyErr(null) { read(ns, json, null, lenientOpts) }
  }

//////////////////////////////////////////////////////////////////////////
// Box Modes
//////////////////////////////////////////////////////////////////////////

  ** box=none is lossy exactly where the plain form cannot be recovered;
  ** auto and all recover it.  The default mode is none.
  Void testBoxModes()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyEq(XetoUtil.optBox(Etc.dict0), JsonBoxMode.none)

    // an untyped dict whose values have no recoverable plain form
    dict := Etc.dict4(
      "mark", m,
      "ref",  Ref("abc"),
      "num",  n(90),
      "date", Date.fromStr("2024-11-26"))

    verifyDictEq(roundTrip(ns, dict, boxNone), Etc.dict4(
      "mark", "✓",
      "ref",  "abc",
      "num",  90,
      "date", "2024-11-26"))

    verifyDictEq(roundTrip(ns, dict, boxAuto), dict)
    verifyDictEq(roundTrip(ns, dict, boxAll),  dict)

    // a Bool needs no box even under auto, but all boxes it anyway
    verifyEq(toJson(ns, true, boxAuto), "true")
    verifyEq(toJson(ns, true, boxAll),
      Str<|{
             "val":"true",
             "spec":"sys::Bool"
           }|>)

    // the box wire form: val first, then spec, both plain strings
    verifyEq(toJson(ns, Etc.dict1("a", m), boxAll),
      Str<|{
             "a":{
               "val":"✓",
               "spec":"sys::Marker"
             }
           }|>)

    // auto boxes nothing when the position already names every type
    edge := ns.spec("hx.test.xeto::JsonEdge")
    typed := Etc.dict3("int", 5, "float", 72.0f, "unitless", n(90))
    verifyEq(toJson(ns, typed, boxAuto, edge), toJson(ns, typed, boxNone, edge))
    verifyDictEq(roundTrip(ns, typed, boxAuto, edge), typed)
  }

  ** A Ref's display string has nowhere to travel in a plain encoding, so a
  ** box carries it in a third member and box=auto boxes any Ref holding one
  ** even where the position already names Ref.
  Void testRefDis()
  {
    ns := createNamespace(["hx.test.xeto"])
    specs := XetoJsonSpec(ns)
    refSpec := ns.spec("sys::Ref")

    withDis := Ref("xyz-123", "Carytown")
    noDis   := Ref("xyz-123")

    // decode
    Ref x := read(ns, Str<|{"val":"xyz-123","spec":"sys::Ref","dis":"Carytown"}|>)
    verifyEq(x.id, "xyz-123")
    verifyEq(x.disVal, "Carytown")

    // the dis member is optional
    x = read(ns, Str<|{"val":"xyz-123","spec":"sys::Ref"}|>)
    verifyEq(x.id, "xyz-123")
    verifyEq(x.disVal, null)

    // encode: dis comes after val and spec, and only when there is one
    verifyEq(toJson(ns, withDis, boxAll),
      Str<|{
             "val":"xyz-123",
             "spec":"sys::Ref",
             "dis":"Carytown"
           }|>)
    verifyEq(toJson(ns, noDis, boxAll),
      Str<|{
             "val":"xyz-123",
             "spec":"sys::Ref"
           }|>)

    // the predicate reports that a plain Ref cannot hold a dis, even in a
    // Ref position, which is what makes auto box it
    verifyEq(specs.plainRoundTrips(withDis, refSpec), false)
    verifyEq(specs.plainRoundTrips(withDis, null), false)
    verifyEq(specs.plainRoundTrips(noDis, refSpec), true)

    // so auto round trips the dis where none drops it
    verifyRefDis(roundTrip(ns, withDis, boxAuto, refSpec), "Carytown")
    verifyRefDis(roundTrip(ns, withDis, boxAll, refSpec), "Carytown")
    verifyRefDis(roundTrip(ns, withDis, boxNone, refSpec), null)

    // and inside a dict, typed or not
    verifyRefDis(((Dict)roundTrip(ns, Etc.dict1("a", withDis), boxAuto))->a,
                 "Carytown")
    verifyRefDis(((Dict)roundTrip(ns, Etc.dict1("id", withDis), boxAuto,
                                  ns.spec("hx.test.xeto::JsonRow")))->id,
                 "Carytown")

    // a dict's own 'dis' tag is ordinary data, reserved only inside a box
    verifyDictEq(roundTrip(ns, Etc.dict2("dis", "HQ", "n", 1), boxAll),
                 Etc.dict2("dis", "HQ", "n", 1))
  }

  private Void verifyRefDis(Obj? val, Str? dis)
  {
    ref := (Ref)val
    verifyEq(ref.id, "xyz-123")
    verifyEq(ref.disVal, dis)
  }

  ** The 'plainRoundTrips' predicate drives box=auto, so it must never claim a
  ** plain form survives when it does not.  It is allowed to be conservative
  ** in the other direction, which testOverBoxing measures.
  **
  ** Crossed over every scalar spec in the namespace rather than a hand
  ** written list, since a hand written list only covers what we thought of.
  Void testPlainRoundTrips()
  {
    ns := createNamespace(["hx.test.xeto"])
    jspec := XetoJsonSpec(ns)

    // each sample against no spec, its own spec, and a spec it is not
    wrong := ns.spec("sys::Date")
    errs := Str[,]

    samplePairs(ns).each |pair|
    {
      val := pair[0]
      Spec spec := pair[1]
      Spec?[null, spec, wrong].each |expect|
      {
        if (!jspec.plainRoundTrips(val, expect)) return
        if (plainSurvives(ns, val, expect)) return
        errs.add("$spec.qname sample=$val [$val.typeof] at ${expect?.qname}")
      }
    }

    if (!errs.isEmpty)
      fail("plainRoundTrips claimed these survive plainly:\n  " + errs.join("\n  "))
  }

  ** auto and all must round trip every scalar spec in the namespace.  This is
  ** the assertion that catches a binding whose encodeScalar and decodeScalar
  ** disagree, without anyone having to notice the binding by hand.
  Void testBoxModeSweep()
  {
    ns := createNamespace(["hx.test.xeto"])

    errs := Str[,]
    samplePairs(ns).each |pair|
    {
      val := pair[0]
      Spec spec := pair[1]
      [boxAuto, boxAll].each |opts|
      {
        mode := opts["box"]
        Spec?[null, spec].each |position|
        {
          try
          {
            x := roundTrip(ns, val, opts, position)
            if (sameVal(val, x)) return
            errs.add("$spec.qname box=$mode at ${position?.qname}: got $x [${x?.typeof}]")
          }
          catch (Err e)
            errs.add("$spec.qname box=$mode at ${position?.qname}: $e.toStr")
        }
      }
    }

    if (!errs.isEmpty)
      fail("box modes lost these scalars:\n  " + errs.join("\n  "))
  }

  ** 'plainRoundTrips' is documented conservative: it may say a box is needed
  ** where the plain form would in fact survive.  This measures how often, so
  ** the predicate cannot quietly get more pessimistic, and names the cases
  ** worth relaxing.
  Void testOverBoxing()
  {
    ns := createNamespace(["hx.test.xeto"])
    jspec := XetoJsonSpec(ns)

    over := Str[,]
    samplePairs(ns).each |pair|
    {
      val := pair[0]
      Spec spec := pair[1]
      Spec?[null, spec].each |expect|
      {
        if (jspec.plainRoundTrips(val, expect)) return
        if (!plainSurvives(ns, val, expect)) return
        over.add("$spec.qname at ${expect?.qname}")
      }
    }

    // a ceiling, not a target: raise it only with a reason
    verify(over.size <= maxOverBoxing,
      "over-boxing rose to $over.size (ceiling $maxOverBoxing):\n  " +
      over.join("\n  "))
  }

  ** write - read - write must be stable.  A value comparison can pass while
  ** the text drifts, so this asserts the text directly, over every scalar in
  ** the namespace at every box mode and both pretty modes.
  Void testIdempotence()
  {
    ns := createNamespace(["hx.test.xeto"])

    errs := Str[,]
    samplePairs(ns).each |pair|
    {
      val := pair[0]
      Spec spec := pair[1]
      [boxNone, boxAuto, boxAll].each |opts|
      {
        mode := opts->box
        Spec?[null, spec].each |position|
        {
          [true, false].each |pretty|
          {
            try
            {
              one := pretty ? toJson(ns, val, opts, position)
                            : toJsonCompact(ns, val, opts, position)
              x   := read(ns, one, position)
              two := pretty ? toJson(ns, x, opts, position)
                            : toJsonCompact(ns, x, opts, position)
              if (one == two) return
              errs.add("$spec.qname box=$mode pretty=$pretty " +
                       "at ${position?.qname}\n     1: $one\n     2: $two")
            }
            catch (Err e)
              errs.add("$spec.qname box=$mode: $e.toStr")
          }
        }
      }
    }

    if (!errs.isEmpty)
      fail("second pass differed:\n  " + errs.join("\n  "))
  }

  ** Compact output is what the server emits, and nothing else exercises it
  Void testCompact()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyEq(toJsonCompact(ns, "abc"), Str<|"abc"|>)
    verifyEq(toJsonCompact(ns, 123), "123")
    verifyEq(toJsonCompact(ns, null), "null")

    verifyEq(toJsonCompact(ns, Etc.dict2("a", 1, "b", "x")),
             Str<|{"a":1,"b":"x"}|>)

    verifyEq(toJsonCompact(ns, Obj?["a", 1, null]), Str<|["a",1,null]|>)

    verifyEq(toJsonCompact(ns, Etc.dict1("a", Etc.dict1("b", 2))),
             Str<|{"a":{"b":2}}|>)

    // a box, compact
    verifyEq(toJsonCompact(ns, m, boxAll),
             Str<|{"val":"✓","spec":"sys::Marker"}|>)

    // an empty dict and an empty list
    verifyEq(toJsonCompact(ns, Etc.dict0), "{}")
    verifyEq(toJsonCompact(ns, Obj[,]), "[]")

    gb := GridBuilder()
    gb.addCol("a")
    gb.addDictRow(Etc.dict1("a", "x"))
    verifyEq(toJsonCompact(ns, gb.toGrid),
      Str<|{"spec":"sys::Grid","cols":[{"name":"a"}],"rows":[{"a":"x"}]}|>)
  }

  ** escapeUnicode escapes every char above 0x7f, so the output is pure
  ** ASCII and still decodes to the original.  Asserted as the contract rather
  ** than as one hardcoded \\u form.
  Void testEscapeUnicode()
  {
    ns := createNamespace(["hx.test.xeto"])
    esc := Etc.dict1("escapeUnicode", m)

    // the sentinels, a non-ASCII unit symbol, and plain ASCII
    ["✓", "∅", "72°F", "abc"].each |s|
    {
      json := toJsonCompact(ns, s, esc)
      verifyAscii(json)
      verifyEq(read(ns, json), s)
    }

    // off by default, so the char passes through raw
    verifyEq(toJsonCompact(ns, "✓"), "\"✓\"")

    // applies inside a box
    json := toJsonCompact(ns, m, Etc.dictSet(esc, "box", "all"))
    verifyAscii(json)
    verifyValEq(read(ns, json), m)

    // and to a unit symbol carried by a Number
    json = toJsonCompact(ns, n(90, "°F"), esc)
    verifyAscii(json)
    verifyValEq(read(ns, json, ns.spec("sys::Number")), n(90, "°F"))

    // pretty mode escapes the same way
    verifyAscii(toJson(ns, Etc.dict1("a", "✓"), esc))
  }

  ** Verify no char above 0x7f survived the encoding
  private Void verifyAscii(Str s)
  {
    verify(s.all |c| { c <= 0x7f }, "non-ASCII in $s")
  }

  ** Haystack fidelity is full fidelity then coerced, so a lossless box mode
  ** must land on exactly XetoUtil.toHaystack of the original, at both a typed
  ** and an untyped position.
  **
  ** Buf is excluded: toHaystack has no haystack kind for it and falls back to
  ** Buf.toStr, which reports pos and size rather than content.
  Void testHaystackBoxMatrix()
  {
    ns := createNamespace(["hx.test.xeto"])

    vals := Obj[
      0, 72.0f, n(90), n(90, "kW"), Number.nan,
      m, NA.val, None.val, "abc",
      Ref("xyz-123"), Ref("xyz-123", "Carytown"),
      `file.txt`,
      Date.fromStr("2024-11-26"), Time.fromStr("14:30:00"),
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York"),
      Version.fromStr("4.0.9"), TimeZone.fromStr("Chicago"),
    ]

    errs := Str[,]
    vals.each |val|
    {
      expect := XetoUtil.toHaystack(val)
      spec := ns.specOf(val, false)
      [boxAuto, boxAll].each |opts|
      {
        mode := opts->box
        Spec?[null, spec].each |position|
        {
          try
          {
            // written at full fidelity, read back at haystack
            x := read(ns, toJson(ns, val, opts, position), position, haystackOpts)
            if (sameVal(expect, x)) return
            errs.add("$val [$val.typeof] box=$mode at ${position?.qname}: " +
                     "got $x [${x?.typeof}], want $expect [${expect?.typeof}]")
          }
          catch (Err e)
            errs.add("$val box=$mode at ${position?.qname}: $e.toStr")
        }
      }
    }

    if (!errs.isEmpty)
      fail("haystack fidelity mismatches:\n  " + errs.join("\n  "))
  }

//////////////////////////////////////////////////////////////////////////
// Scalar Sample Enumeration
//////////////////////////////////////////////////////////////////////////

  ** (value, own spec) pairs driving the sweeps: one canonical sample per
  ** scalar spec in the namespace, plus the pathological values that no
  ** per-spec default covers.
  private Obj[][] samplePairs(MNamespace ns)
  {
    acc := Obj[][,]
    scalarSamples(ns).each |val, spec| { acc.add(Obj[val, spec]) }
    return acc.addAll(edgeSamples(ns))
  }

  ** Values whose encoding is special even though their spec already has a
  ** sample: the specials that have no JSON number form, the unitless Number
  ** that reads back as Int or Float, a Str that looks like a marker, and a
  ** Ref whose dis only a box can carry.
  private Obj[][] edgeSamples(MNamespace ns)
  {
    num   := ns.spec("sys::Number")
    float := ns.spec("sys::Float")
    return [
      [Float.nan,    float],
      [Float.posInf, float],
      [Float.negInf, float],
      [Number.nan,   num],
      [n(90),        num],
      [n(3.4f),      num],
      [n(90, "kW"),  num],
      ["✓",          ns.spec("sys::Str")],
      [Ref("xyz-123", "Carytown"), ns.spec("sys::Ref")],
    ]
  }

  ** Every non-abstract scalar spec in the namespace paired with a sample
  ** value of that spec's own type.  The declared default from 'instantiate'
  ** is used where it is well typed, otherwise an explicit sample from
  ** scalarSupplements.  A spec with neither is excluded, and must say so in
  ** scalarSkips so that a coverage gap is visible rather than silent.
  private Spec:Obj scalarSamples(MNamespace ns)
  {
    acc := Spec:Obj[:]
    unusable := Str[,]

    eachScalarSpec(ns) |spec|
    {
      qname := spec.qname

      // supplement text is decoded by the spec's own binding
      str := scalarSupplements[qname]
      sample := str != null
                ? spec.binding.decodeScalar(str, false)
                : defaultSample(ns, spec)

      if (sample != null && ns.specOf(sample, false) === spec)
        acc[spec] = sample
      else if (scalarSkips[qname] == null)
        unusable.add("$qname (default=$sample [${sample?.typeof}])")
    }

    if (!unusable.isEmpty)
      fail("scalar specs with no usable sample; add to scalarSupplements or " +
           "scalarSkips with a reason:\n  " + unusable.join("\n  "))

    // guard against the sweep quietly emptying out
    verify(acc.size >= 15, "only $acc.size scalar samples found")
    return acc
  }

  ** Iterate every non-abstract scalar type in every loaded lib
  private Void eachScalarSpec(MNamespace ns, |Spec| f)
  {
    ns.libs.each |lib|
    {
      lib.types.each |spec|
      {
        if (!spec.isScalar) return
        if (spec.meta.has("abstract")) return
        f(spec)
      }
    }
  }

  ** The spec's declared default, or null if instantiate cannot produce one.
  ** A spec with no Fantom binding of its own falls back to the generic
  ** scalar binding, whose values are Scalar wrappers accepting any string, so
  ** a sample can be synthesized rather than hand written.
  private Obj? defaultSample(MNamespace ns, Spec spec)
  {
    if (spec.binding.type === Scalar#) return Scalar(spec.qname, "sample")

    try
      return ns.instantiate(spec)
    catch
      return null
  }

  ** Sample text for scalar specs whose declared default is absent or is not
  ** of the spec's own type.  Instantiator reads the 'val' meta verbatim and
  ** never decodes it, so a spec declaring no default yields a bare Str.  The
  ** text here is decoded by the spec's own binding, which keeps this map free
  ** of pod imports and constructor signatures.
  private static const Str:Str scalarSupplements := [
    // Instantiator short circuits isNone before the scalar path
    "sys::None":              "∅",

    // real bindings whose specs declare no default
    "sys::Span":              "2024-11-25",
    "sys::Buf":               "Zm9vYmFy",
    "sys::Filter":            "a and b",
    "sys::LibDependVersions": "4.5.x",
    "sys::TimeZone":          "Chicago",
    "sys::Unit":              "kW",
    "sys::UnitQuantity":      "volume",
    "sys::SpanMode":          "lastMonth",
    "sys.comp::CompLayout":   "1,2,8",
    "axon::AxonExpr":         "today()",
  ]

  ** Scalar specs deliberately outside the sweep, each with its reason
  private static const Str:Str scalarSkips := [
    "sys::Enum":     "base of every enum; carries no value of its own",
    "sys::BuildVar": "build time macro, never a runtime value",
  ]

  ** Ceiling for testOverBoxing
  private static const Int maxOverBoxing := 12

//////////////////////////////////////////////////////////////////////////
// Grids
//////////////////////////////////////////////////////////////////////////

  Void testGrid()
  {
    ns := createNamespace(["hx.test.xeto"])

    gb := GridBuilder()
    verifyRoundTrip(ns, gb.toGrid)

    gb = GridBuilder()
    gb.addCol("a").addCol("b")
    gb.addDictRow(Etc.dict2("a", 0, "b", "x"))
    gb.addDictRow(Etc.dict2("a", 1, "b", "y"))
    verifyRoundTrip(ns, gb.toGrid)

    // grid meta is untyped, so a marker there would decode as Str "✓"
    gb = GridBuilder()
    gb.setMeta(Etc.dict1("foo", "quux"))
    gb.addCol("a").addCol("b", Etc.dict1("dis", "B"))
    gb.addDictRow(Etc.dict2("a", 0, "b", "x"))
    gb.addDictRow(Etc.dict2("a", 1, "b", "y"))
    grid := gb.toGrid
    verifyRoundTrip(ns, grid)

    // the codec never synthesizes structural tags, so a plain grid comes back
    // with no 'spec' in meta and no 'of' in col meta
    Grid g := roundTrip(ns, grid)
    verifyEq(g.meta.has("spec"), false)
    verifyEq(g.col("a").meta.isEmpty, true)
    verifyEq(XetoUtil.gridColSpecRef(g.col("a")), null)

    // a Grid subtype supplies its default row spec from the schema
    g = read(ns, Str<|{
                        "spec": "hx.test.xeto::JsonHisGrid",
                        "cols": [{"name":"ts"},{"name":"v0"}],
                        "rows": [
                          {"ts":"2024-11-25T10:24:35-05:00 New_York","v0":"73"}
                        ]
                      }|>)
    verifyValEq(g.first->v0, n(73))
    verifyValEq(g.first->ts,
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York"))

    // and that subtype survives the round trip through grid meta
    verifyEq(XetoUtil.gridSpecRef(g), Ref("hx.test.xeto::JsonHisGrid"))
    Grid g2 := roundTrip(ns, g)
    verifyEq(XetoUtil.gridSpecRef(g2), Ref("hx.test.xeto::JsonHisGrid"))
    verifyValEq(g2.first->v0, n(73))

    // a typed column round trips its 'of' and keeps its cells plain
    gb = GridBuilder()
    gb.addCol("ts", Etc.dict1("of", Ref("sys::DateTime")))
    gb.addDictRow(Etc.dict1("ts",
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York")))
    grid = gb.toGrid
    verifyRoundTrip(ns, grid)
    verifyEq(XetoUtil.gridColSpecRef(((Grid)roundTrip(ns, grid)).col("ts")),
             Ref("sys::DateTime"))

    // a grid nested as a dict tag value
    env := Etc.dict2("sni", "/db/ph::Equip", "data", grid)
    Dict envx := roundTrip(ns, env)
    verifyValEq(envx->sni, "/db/ph::Equip")
    verifyGridEq(envx->data, grid)
  }

//////////////////////////////////////////////////////////////////////////
// Writer
//////////////////////////////////////////////////////////////////////////

  Void testPretty()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyEq(
      toJson(ns,
        Etc.dict3(
          "a", 1,
          "b", ["a", 1, [Etc.dict2("f", 4, "g", 5), 3, ["b", 4]]],
          "c", Etc.dict2(
            "d", 3,
            "e", Etc.dict2("f", 4, "g", 5)))),
      Str<|{
             "a":1,
             "b":[
               "a",
               1,
               [
                 {
                   "f":4,
                   "g":5
                 },
                 3,
                 [
                   "b",
                   4
                 ]
               ]
             ],
             "c":{
               "d":3,
               "e":{
                 "f":4,
                 "g":5
               }
             }
           }|>)

    gb := GridBuilder()
    gb.setMeta(Etc.dict1("foo", "quux"))
    gb.addCol("a").addCol("b", Etc.dict1("dis", "B"))
    gb.addDictRow(Etc.dict2("a", 0, "b", "x"))
    gb.addDictRow(Etc.dict2("a", 1, "b", "y"))
    grid := gb.toGrid

    verifyEq(
      toJson(ns, grid),
      Str<|{
             "spec":"sys::Grid",
             "meta":{
               "foo":"quux"
             },
             "cols":[
               {
                 "name":"a"
               },
               {
                 "name":"b",
                 "meta":{
                   "dis":"B"
                 }
               }
             ],
             "rows":[
               {
                 "a":0,
                 "b":"x"
               },
               {
                 "a":1,
                 "b":"y"
               }
             ]
           }|>)
  }

  ** The writer hoists a column 'of' out of col meta to sit beside 'name',
  ** and the grid spec to the top level rather than repeating it in meta.
  Void testWriteStructural()
  {
    ns := createNamespace(["hx.test.xeto"])

    gb := GridBuilder()
    gb.setMeta(Etc.dict2("spec", Ref("hx.test.xeto::JsonHisGrid"),
                         "of",   Ref("hx.test.xeto::JsonRow")))
    gb.addCol("ts", Etc.dict1("of", Ref("sys::DateTime")))
    gb.addDictRow(Etc.dict1("ts",
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York")))

    verifyEq(
      toJson(ns, gb.toGrid),
      Str<|{
             "spec":"hx.test.xeto::JsonHisGrid",
             "meta":{
               "of":"hx.test.xeto::JsonRow"
             },
             "cols":[
               {
                 "name":"ts",
                 "of":"sys::DateTime"
               }
             ],
             "rows":[
               {
                 "ts":"2024-11-25T10:24:35-05:00 New_York"
               }
             ]
           }|>)
  }

//////////////////////////////////////////////////////////////////////////
// Instances
//////////////////////////////////////////////////////////////////////////

  Void testInstances()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyRoundTrip(ns,
      ns.instance("hx.test.xeto::jsonScalarsA"),
      ns.spec("hx.test.xeto::JsonScalars"))

    verifyRoundTrip(ns,
      ns.instance("hx.test.xeto::jsonNestA"),
      ns.spec("hx.test.xeto::JsonNest"))
  }

  ** A list spec is not required to declare 'of'.  Without it the items are
  ** decoded untyped rather than raising "Missing 'of' meta".
  Void testListWithoutOf()
  {
    ns := createNamespace(["hx.test.xeto"])

    listSpec := ns.spec("sys::List")
    verifyEq(read(ns, Str<|["a", "b"]|>, listSpec), Obj["a", "b"])

    // a null item makes the list nullable; the codec does not enforce the
    // 'of' nullability, which is left to Namespace.validate
    verifyEq(read(ns, Str<|["a", null]|>, listSpec), Obj?["a", null])
    verifyEq(read(ns, "[]", listSpec), Obj[,])

    // an 'of' slot still types its items
    slot := ns.spec("hx.test.xeto::JsonNest").slot("dates")
    verifyEq(read(ns, Str<|["2024-11-26"]|>, slot),
             Obj[Date.fromStr("2024-11-26")])
    verifyEq(read(ns, Str<|["2024-11-26", null]|>, slot),
             Obj?[Date.fromStr("2024-11-26"), null])
  }

//////////////////////////////////////////////////////////////////////////
// Haystack Fidelity
//////////////////////////////////////////////////////////////////////////

  ** Haystack fidelity has no Int or Float, only Number, and erases any type
  ** that is not a haystack kind.  The ladder itself is unchanged.
  Void testHaystack()
  {
    ns := createNamespace(["hx.test.xeto"])

    // orig, expect pairs decoded with no position spec
    [
      Obj?[null,  null],
      Obj?[true,  true],
      Obj?["abc", "abc"],
      Obj?[n(1),  n(1)],
      Obj?[2,     n(2)],
      Obj?[3.4f,  n(3.4f)],

      // an untyped position never decodes by what a string looks like, so a
      // plain marker does not survive; box=auto is the lossless encoding
      Obj?[m, "✓"],
    ].each |pair| { verifyHaystack(ns, pair[0], pair[1]) }

    verifyHaystack(ns,
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York"),
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York"),
      ns.spec("sys::DateTime"))

    verifyHaystack(ns,
      [null, "true", 1, n(2)],
      [null, "true", n(1), n(2)])

    verifyHaystack(ns,
      Etc.dict5("z", m, "a", true, "b", "xyz", "c", n(1), "d", 2),
      Etc.dict5("z", "✓", "a", true, "b", "xyz", "c", n(1), "d", n(2)))

    // a box names a full fidelity type, so it coerces down on the way in
    verifyValEq(read(ns, Str<|{"val":"5","spec":"sys::Int"}|>,
                     null, haystackOpts), n(5))
    verifyValEq(read(ns, Str<|{"val":"72.0","spec":"sys::Float"}|>,
                     null, haystackOpts), n(72))
    verifyValEq(read(ns, Str<|{"val":"4.0.9","spec":"sys::Version"}|>,
                     null, haystackOpts), "4.0.9")

    // a typed grid column decodes the same at haystack fidelity
    json := Str<|{
                   "spec": "sys::Grid",
                   "cols": [{"name":"v0","of":"sys::Number"}],
                   "rows": [{"v0":"73kW"}, {"v0":73}]
                 }|>
    Grid g := read(ns, json, null, haystackOpts)
    verifyValEq(g[0]->v0, n(73, "kW"))
    verifyValEq(g[1]->v0, n(73))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Decode a JSON literal in a position with the given expected spec
  private Obj? read(MNamespace ns, Str json, Spec? spec := null,
                    Dict? opts := null)
  {
    XetoJsonReader(ns, json.in, spec, opts).readVal
  }

  ** Convenience for a read whose result is known to be a Dict
  private Dict readDict(MNamespace ns, Str json, Spec? spec := null,
                        Dict? opts := null)
  {
    (Dict)read(ns, json, spec, opts)
  }

  ** Verify a decoded value and its exact Fantom type
  private Void verifyDecode(MNamespace ns, Str json, Obj? expect,
                            Spec? spec := null)
  {
    x := read(ns, json, spec)
    verifyValEq(x, expect)
    verifySame(x?.typeof, expect?.typeof)
  }

  ** Does the plain encoding of val actually decode back to val in a position
  ** whose expected spec is 'spec'?
  private Bool plainSurvives(MNamespace ns, Obj? val, Spec? spec)
  {
    try
      return sameVal(val, roundTrip(ns, val, boxNone, spec))
    catch
      return false
  }

  ** Value comparison for the sweeps.
  private Bool sameVal(Obj? a, Obj? b)
  {
    if (a == null || b == null) return a == null && b == null
    if (a.typeof !== b.typeof) return false

    // NaN is not equal to itself
    if (a is Float) return ((Float)a).isNaN ? ((Float)b).isNaN : a == b

    // verifyValEq knows Buf by content, Ref by id plus dis, and collections
    if (a is Buf || a is Ref || a is List || a is Dict || a is Grid)
    {
      try
        { verifyValEq(a, b); return true }
      catch
        return false
    }

    // some scalar types define no value equality, so compare the canonical
    // string form - which is exactly the text encodeScalar writes
    return a == b || a.toStr == b.toStr
  }

  private Void verifyHaystack(
    MNamespace ns,
    Obj? orig,
    Obj? expect,
    Spec? spec := null)
  {
    str := toJson(ns, orig)

    x := read(ns, str, spec, haystackOpts)
    if (orig is Dict)
      verifyDictEq(x, expect)
    else
      verifyEq(x, expect)
  }

  private Void verifyRoundTrip(
    MNamespace ns,
    Obj? a,
    Spec? spec := null,
    Dict? opts := null)
  {
    str := toJson(ns, a, opts, spec)
    b := read(ns, str, spec)

    if (a is Dict)
      verifyDictEq(a, b)
    else if (a is Grid)
      verifyGridEq(a, b)
    else
      verifyEq(a, b)

    // a second pass must emit identical text
    verifyEq(toJson(ns, b, opts, spec), str)
  }

  private Str toJson(MNamespace ns, Obj? x, Dict? opts := null,
                     Spec? spec := null)
  {
    write(ns, x, Etc.dictSet(opts, "pretty", m), spec)
  }

  ** Compact encoding, which is the mode the server actually emits
  private Str toJsonCompact(MNamespace ns, Obj? x, Dict? opts := null,
                            Spec? spec := null)
  {
    write(ns, x, opts ?: Etc.dict0, spec)
  }

  ** Encode, and assert the result is well formed JSON independently of
  ** whatever the caller goes on to compare it against
  private Str write(MNamespace ns, Obj? x, Dict opts, Spec? spec)
  {
    buf := Buf()
    XetoJsonWriter(ns, buf.out, spec, opts).writeVal(x)
    str := buf.flip.readAllStr
    JsonInStream(str.in).readJson
    return str
  }

  ** Write then read back through the same position spec
  private Obj? roundTrip(MNamespace ns, Obj? x, Dict? opts := null,
                         Spec? spec := null)
  {
    read(ns, toJson(ns, x, opts, spec), spec)
  }

  private static const Dict haystackOpts := Etc.dict1("haystack", m)
  private static const Dict lenientOpts  := Etc.dict1("lenient", m)
  private static const Dict boxNone := Etc.dict1("box", "none")
  private static const Dict boxAuto := Etc.dict1("box", "auto")
  private static const Dict boxAll  := Etc.dict1("box", "all")
}

