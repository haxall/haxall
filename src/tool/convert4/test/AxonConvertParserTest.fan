//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jan 2026  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using concurrent

**
** AxonConvertParserTest
**
class AxonConvertParserTest : HaystackTest
{
  Void test()
  {
    // 0 params
    verifyParse(
      Str<|// ignore this
           () =>  1 + 2
           |>,
       [:],
       "1 + 2")

    // 1 params
    verifyParse(
      Str<|(a) => do
             "hello"
           end|>,
       [
         "a":[:],
       ],
       """do
            "hello"
          end""")

    // 2 params, defs
    verifyParse(
      Str<|(alpha: null, beta: 123) => do
             x: alpha
             x + beta // hi
           end|>,
       [
         "alpha":["axon":"null"],
         "beta":["axon":"123"],
       ],
       """do
            x: alpha
            x + beta // hi
          end""")

    // simple defcomp example
    verifyParse(
      Str<|defcomp
             inA: {is:^number, defVal:0}
             inB: {is:^number, defVal:0, foo:"bar"}
             out: {is:^number, ro}
             do
               out = inA + inB

               // line3
             end
           end|>,
       [
         "inA":["::type":"sys::Number", "axon":n(0)],
         "inB":["::type":"sys::Number", "axon":n(0), "foo":"bar"],
         "out":["::type":"sys::Number", "ro":m],
       ],
       """do
            out = inA + inB

            // line3
          end""")

    // defcomp no body
    verifyParse(
      Str<|defcomp
             cell1: {marker, foo:"!"}
           end|>,
       [
         "cell1":["marker":m, "foo":"!"],
       ],
       "null")

    // defcomp with rule mappings
    verifyParse(
      Str<|defcomp
             target: {}
             date: {}
             dat: {bind:"discharge and temp and equipRef=={{target->id}}", watch}
             all: {bindAll:"temp and equipRef=={{target->id}}"}
             outA: {bindOut:"outA and equipRef=={{target->id}}", toCurVal}
             outB: {bindOut:"outB and equipRef=={{target->id}}", toWriteLevel:14}
             sum: {is:^number}
             do
               sum = dat["curVal"] * 2
               outA = sum + 100
               outB = sum + 200
             end
           end|>,
      [
        "target":["::type":"sys::Entity"],
        "date":["::type":"sys::Date"],
        "dat":["::type":"sys::Entity", "ruleBind":"discharge and temp and equipRef=={{target->id}}"],
        "all":["::type":"sys::List", "of":Ref("sys::Entity"), "ruleBind":"temp and equipRef=={{target->id}}", "ruleNoWatch":m],
        "outA":["::type":"ph::Point", "ruleBind":"outA and equipRef=={{target->id}}", "ruleToCurVal":m],
        "outB":["::type":"ph::Point", "ruleBind":"outB and equipRef=={{target->id}}", "ruleToWriteLevel":n(14)],
        "sum":["::type":"sys::Number"]
      ],
      """do
           sum = dat["curVal"] * 2
           outA = sum + 100
           outB = sum + 200
         end""")
  }

  Void verifyParse(Str src, Str:Map params, Str body)
  {
    p := AxonConvertParser(src).parseSig

    if (false)
    {
      echo("#####")
      echo(src)
      echo
      p.aparams.each |x| { echo("$x.name: $x.type $x.meta") }
      echo("--->")
      echo(p.body)
      echo("<---")
    }

    verifyEq(p.aparams.size, params.size)
    params.each |Str:Obj expect, Str name|
    {
      t := expect.remove("::type") ?: "sys::Obj?"
      x := p.aparams.find { it.name == name } ?: throw Err(name)
      verifyEq(x.type.sig, t, "${name} ${x.type.sig} != ${t}")
      verifyDictEq(x.meta, expect)
    }
    verifyEq(p.body, body)
  }
}

