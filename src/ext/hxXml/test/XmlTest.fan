//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Nov 2011  Brian Frank  Creation
//

using xml
using axon
using hx

**
** XML test suite
**
class XmlTest : HxTest
{

  @HxTestProj
  Void test()
  {
    addLib("xml")

    xml := "<foo/>"
    verifyXml(xml, "xmlName",   "foo")
    verifyXml(xml, "xmlPrefix", null)
    verifyXml(xml, "xmlVal",    null)
    verifyXml(xml, "xmlAttrs",  XAttr[,])
    verifyXml(xml, "xmlElems",  XElem[,])
    verifyXml(xml, "xmlAttr(\"x\", false)",  null)
    verifyErr(EvalErr#) { verifyXml("<foo/>", "xmlAttr(\"x\")",  null) }

    xml =
      "<doc xmlns='http://def/' xmlns:q='http://q/'>
         <a x='x-val' q:y='y-val'/>
         <q:b>some text</q:b>
       </doc>"
    verifyXml(xml, Str<|xmlElems.map(xmlName)|>,  Obj?["a", "b"])

    verifyXml(xml, Str<|xmlElem("a").xmlName|>,   "a")
    verifyXml(xml, Str<|xmlElem("a").xmlQname|>,  "a")
    verifyXml(xml, Str<|xmlElem("a").xmlPrefix|>, "")
    verifyXml(xml, Str<|xmlElem("a").xmlNs|>,     `http://def/`)
    verifyXml(xml, Str<|xmlElem("a").xmlVal|>,    null)

    verifyXml(xml, Str<|xmlElem("b").xmlName|>,   "b")
    verifyXml(xml, Str<|xmlElem("b").xmlQname|>,  "q:b")
    verifyXml(xml, Str<|xmlElem("b").xmlPrefix|>, "q")
    verifyXml(xml, Str<|xmlElem("b").xmlNs|>,     `http://q/`)
    verifyXml(xml, Str<|xmlElem("b").xmlVal|>,    "some text")

    verifyXml(xml, Str<|xmlElem("a").xmlAttrs.map(xmlName)|>, Obj?["x", "y"])

    verifyXml(xml, Str<|xmlElem("a").xmlAttr("x").xmlName|>,   "x")
    verifyXml(xml, Str<|xmlElem("a").xmlAttr("x").xmlQname|>,  "x")
    verifyXml(xml, Str<|xmlElem("a").xmlAttr("x").xmlPrefix|>, null)
    verifyXml(xml, Str<|xmlElem("a").xmlAttr("x").xmlNs|>,     null)
    verifyXml(xml, Str<|xmlElem("a").xmlAttr("x").xmlVal|>,    "x-val")

    verifyXml(xml, Str<|xmlElem("a").xmlAttr("y").xmlName|>,   "y")
    verifyXml(xml, Str<|xmlElem("a").xmlAttr("y").xmlQname|>,  "q:y")
    verifyXml(xml, Str<|xmlElem("a").xmlAttr("y").xmlPrefix|>, "q")
    verifyXml(xml, Str<|xmlElem("a").xmlAttr("y").xmlNs|>,     `http://q/`)
    verifyXml(xml, Str<|xmlElem("a").xmlAttr("y").xmlVal|>,    "y-val")
  }

  Void verifyXml(Str xml, Str expr, Obj? expected)
  {
    // echo("---> $expr")
    actual := eval("xmlRead($xml.toCode).$expr")
    verifyEq(expected, actual)
  }

}

