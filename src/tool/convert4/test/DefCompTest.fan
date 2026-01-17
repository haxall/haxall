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
** DefCompTest
**
class DefCompTest : HaystackTest
{
  Void testParse()
  {
    // simple example
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
         "inA":["is":Symbol("number"), "defVal":n(0)],
         "inB":["is":Symbol("number"), "defVal":n(0), "foo":"bar"],
         "out":["is":Symbol("number"), "ro":m],
       ],
       """do
            out = inA + inB

            // line3
          end""")

    // no body
    verifyParse(
      Str<|defcomp
             cell1: {marker, foo:"!"}
           end|>,
       [
         "cell1":["marker":m, "foo":"!"],
       ],
       "null")
  }

  Void verifyParse(Str src, Str:Map params, Str body)
  {
    p := AxonSigParser(src).parseCompDef

    if (false)
    {
      echo("#####")
      echo(src)
      echo
      p.params.each |c| { echo("$c.name $c.meta") }
      echo("--->")
      echo(p.body)
      echo("<---")
    }

    verifyEq(p.params.size, params.size)
    params.each |expect, name|
    {
      c := p.params.find { it.name == name } ?: throw Err(name)
      verifyDictEq(c.meta, expect)
    }
    verifyEq(p.body, body)
  }
}

