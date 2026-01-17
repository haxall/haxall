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
    p := AxonConvertParser(src).parseSig

    if (false)
    {
      echo("#####")
      echo(src)
      echo
      p.aparams.each |c| { echo("$c.name $c.meta") }
      echo("--->")
      echo(p.body)
      echo("<---")
    }

    verifyEq(p.aparams.size, params.size)
    params.each |expect, name|
    {
      c := p.aparams.find { it.name == name } ?: throw Err(name)
      verifyDictEq(c.meta, expect)
    }
    verifyEq(p.body, body)
  }
}

