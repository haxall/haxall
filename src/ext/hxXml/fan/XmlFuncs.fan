//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Nov 2011  Brian Frank  Creation
//

using xml
using xeto
using axon
using hx

**
** XML Axon functions
**
const class XmlFuncs
{

  **
  ** Parse an XML document from an I/O handle and return root element.
  **
  ** Examples:
  **   xmlRead("<foo/>")
  **   xmlRead(`io/test.xml`)
  **
  @Api @Axon { admin = true }
  static XElem xmlRead(Obj? handle)
  {
    Context.cur.rt.exts.io.read(handle) |in| { XParser(in).parseDoc.root }
  }

  **
  ** Get the unqualified local name of an element or attribute:
  **   <foo>    >>  "foo"
  **   <x:foo>  >>  "foo"
  **
  @Api @Axon
  static Str xmlName(Obj node)
  {
    if (node is XElem) return ((XElem)node).name
    if (node is XAttr) return ((XAttr)node).name
    throw ArgErr("Not XElem or XAttr: $node.typeof")
  }

  **
  ** Get the qualified local name of an element or attribute
  ** which includes both its prefix and unqualified name:
  **   <foo>    >>  "foo"
  **   <x:foo>  >>  "x:foo"
  **
  @Api @Axon
  static Str xmlQname(Obj node)
  {
    if (node is XElem) return ((XElem)node).qname
    if (node is XAttr) return ((XAttr)node).qname
    throw ArgErr("Not XElem or XAttr: $node.typeof")
  }

  **
  ** Get the namespace prefix of an element or attribute.
  ** If node is an element in the default namespace then
  ** return "".  If no namespace is specified return null.
  **
  ** Examples:
  **   <foo>               >>  null
  **   <x:foo>             >>  "x"
  **   <foo xmlns='...'/>  >>  ""
  **
  @Api @Axon
  static Str? xmlPrefix(Obj node)
  {
    if (node is XElem) return ((XElem)node).prefix
    if (node is XAttr) return ((XAttr)node).prefix
    throw ArgErr("Not XElem or XAttr: $node.typeof")
  }

  **
  ** Get the namespace URI of an element or attribute.
  ** If no namespace was specified return null.
  **
  ** Example:
  **   xmlRead("<foo xmlns='bar'/>").xmlNs  >>  `bar`
  **
  @Api @Axon
  static Uri? xmlNs(Obj node)
  {
    if (node is XElem) return ((XElem)node).ns?.uri
    if (node is XAttr) return ((XAttr)node).ns?.uri
    throw ArgErr("Not XElem or XAttr: $node.typeof")
  }

  **
  ** If node is an attribute, then return its value string.
  ** If node is an element return its first text child
  ** node, otherwise null.  If node is null, then return null.
  **
  ** Examples:
  **   xmlRead("<x/>").xmlVal                      >>  null
  **   xmlRead("<x>hi</x>").xmlVal                 >>  "hi"
  **   xmlRead("<x a='v'/>").xmlAttr("a").xmlVal   >>  "v"
  **   xmlRead("<x/>").xmlAttr("a", false).xmlVal  >>  null
  **
  @Api @Axon
  static Str? xmlVal(Obj? node)
  {
    if (node == null) return null
    if (node is XAttr) return ((XAttr)node).val
    if (node is XElem) return ((XElem)node).text?.val
    throw ArgErr("Not XElem or XAttr: $node.typeof")
  }

  **
  ** Get an attribute from an element by its non-qualified local name.
  ** If the attribute is not found and checked is false then
  ** return null otherwise throw XErr.
  **
  ** Examples:
  **   xmlRead("<x a='v'/>").xmlAttr("a").xmlVal   >>  "v"
  **   xmlRead("<x/>").xmlAttr("a", false).xmlVal  >>  null
  **
  @Api @Axon
  static XAttr? xmlAttr(XElem elem, Str name, Bool checked := true)
  {
    elem.attr(name, checked)
  }

  **
  ** Get list of all an elements attributes.
  **
  ** Example:
  **   attrs: xmlRead("<x a='' b=''/>").xmlAttrs
  **   attrs.map(xmlName)  >>  ["a", "b"]
  **
  @Api @Axon
  static XAttr[] xmlAttrs(XElem elem) { elem.attrs }

  **
  ** Find an element by its non-qualified local name. If there are
  ** multiple child elements with the name, then the first one is
  ** returned. If the element is not found and checked is false
  ** then return null otherwise throw XErr.
  **
  ** Example:
  **   xmlRead("<d><a/></d>").xmlElem("a")
  **
  @Api @Axon
  static XElem? xmlElem(XElem elem, Str name, Bool checked := true)
  {
    elem.elem(name, checked)
  }

  **
  ** Get the children elements. If this element contains
  ** text or PI nodes, then they are excluded in the result.
  **
  ** Example:
  **   elems: xmlRead("<d><a/><b/></d>").xmlElems
  **   elems.map(xmlName)  >>  ["a", "b"]
  **
  @Api @Axon
  static XElem[] xmlElems(XElem elem) { elem.elems }

}

