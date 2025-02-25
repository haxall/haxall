//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2024  Brian Frank  Creation
//

using xeto
using xeto::Lib
using haystack::Dict
using haystack::Etc
using haystack::Marker
using haystack::Ref

**
** RDF Turtle Exporter
**
@Js
class RdfExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  override This start()
  {
    return this
  }

  override This end()
  {
    return this
  }

  override This lib(Lib lib)
  {
    this.isSys = lib.name == "sys"
    prefixDefs(lib)
    ontologyDef(lib)
    lib.types.each |x| { if (!XetoUtil.isAutoName(x.name)) cls(x) }
    lib.globals.each |x| { global(x) }
    lib.instances.each |x| { instance(x) }
    if (isSys) sysDefs
    return this
  }

  override This spec(Spec spec)
  {
    if (spec.isType) return cls(spec)
    if (spec.isGlobal) return global(spec)
    throw Err(spec.name)
  }

//////////////////////////////////////////////////////////////////////////
// Definitions
//////////////////////////////////////////////////////////////////////////

  private This cls(Spec x)
  {
    if (x.isEnum) return enum(x)

    qname(x.qname).nl
    w("  a owl:Class ;").nl
    labelAndDoc(x)

    // supertype
    if (x.base != null)
      w("  rdfs:subClassOf ").qname(x.base.qname).w(" ;").nl

    /*
    w("  owl:equivalentClass [").nl
    w("    a owl:Class ;").nl
    w("    ] ;").nl
    */

    // markers
    x.slots.each |slot|
    {
      if (slot.isMarker && slot.base.isGlobal) hasMarker(slot)
    }

    w(".").nl
    return this
  }

  private Void hasMarker(Spec slot)
  {
    prop := isSys ? ":hasMarker" : "sys:hasMarker"
    w("  ").w(prop).w(" ").qname(slot.base.qname).w(" ;").nl
  }

  private This enum(Spec x)
  {
    qname(x.qname).nl
    w("  a rdfs:Datatype ;").nl
    labelAndDoc(x)
    w(".").nl

    qnameShape(x.qname).nl
    w("  a sh:NodeShape ;").nl
    w("  sh:targetClass ").qname(x.qname).w(" ;").nl
    w("  sh:property [").nl
    w("    sh:path rdf:value ;").nl
    w("    sh:in (").nl
    x.enum.each |spec, key|
    {
      w("    ").literal(key).nl
    }
    w("    ) ;").nl
    w("    sh:message ").literal("Must one of the $x.name enum values").w("@en ;").nl
    w("  ]").nl
    w(".").nl
    return this
  }

  private This global(Spec x)
  {
    if (x.isMarker) return globalMarker(x)
    if (x.isRef || x.isMultiRef) return globalRef(x)
    return globalProp(x)
  }

  private This globalMarker(Spec x)
  {
    qname(x.qname).nl
    w("  a sys:Marker ;").nl
    labelAndDoc(x)
    w(".").nl
    return this
  }

  private This globalRef(Spec x)
  {
    of := x.of(false)?.qname ?: "sys::Entity"
    qname(x.qname).nl
    w("  a owl:ObjectProperty ;").nl
    labelAndDoc(x)
    w("  rdfs:range ").qname(of).w(" ;").nl
    w(".").nl
    return this
  }

  private This globalProp(Spec x)
  {
    qname(x.qname).nl
    w("  a owl:DatatypeProperty ;").nl
    labelAndDoc(x)
    type := globalType(x.type)
    if (type != null) w("  rdfs:range ").w(type).w(" ;").nl
    w(".").nl
    return this
  }

  private Str? globalType(Spec type)
  {
    if (type.qname == "sys::Str") return "xsd:string"
    if (type.qname == "sys::Int") return "xsd:integer"
    if (type.isEnum) return qnameToUri(type.qname)
    return null
  }

  private This labelAndDoc(Spec x)
  {
    w("  rdfs:label \"").w(x.name).w("\"@en ;").nl
    doc := x.metaOwn.get("doc") as Str
    if (doc != null && !doc.isEmpty)
      w("  rdfs:comment ").literal(doc).w("@en ;").nl
    return this
  }

  ** Extra definitions in the sys library
  private This sysDefs()
  {
    w(
    Str<|sys:hasMarker
           a owl:ObjectProperty ;
           rdfs:label "Has Marker"@en ;
           rdfs:range sys:Marker ;
         .
         |>)
  }

//////////////////////////////////////////////////////////////////////////
// Instances
//////////////////////////////////////////////////////////////////////////

  override This instance(Dict instance)
  {
    id := instance.id

    // TODO - just hide op/filetype instances for now
    if (id.toStr.startsWith("ph::op:")) return this
    if (id.toStr.startsWith("ph::filetype:")) return this

    spec := ns.specOf(instance)
    dis := instance.dis

    markers := Str:Spec[:]
    refs    := Str:Spec[:]
    vals    := Str:Spec[:]
    instance.each |v, n|
    {
      if (n == "id") return
      if (n == "dis" || n == "disMacro") return

      slot := ns.global(n, false)
      if (slot == null) return

      if (v == Marker.val) markers[n] = slot
      else if (v is Ref) refs[n] = slot
      else vals[n] = slot
    }

    this.id(id).nl
    w("  rdf:type ").qname(spec.qname).w(" ;").nl
    w("  rdfs:label ").literal(dis).w(" ;").nl
    markers.keys.sort.each |n| { instanceMarker(instance, n, markers[n]) }
    refs.keys.sort.each |n| { instanceRef(instance, n, refs[n]) }
    vals.keys.sort.each |n| { instanceVal(instance, n, vals[n]) }
    w(".").nl
    return this
  }

  private Void instanceMarker(Dict instance, Str name, Spec slot)
  {
    w("  sys:hasMarker ").qname(slot.qname).w(" ;").nl
  }

  private Void instanceRef(Dict instance, Str name, Spec slot)
  {
    ref := instance[name]
    if (ref == null) return
    w("  ").qname(slot.qname).w(" ").id(ref).w(" ;").nl
  }

  private Void instanceVal(Dict instance, Str name, Spec slot)
  {
    val := instance[name]
    if (val == null) return
    w("  ").qname(slot.qname).w(" ").literal(val.toStr).w(" ;").nl
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Generate prefixes for libraries dependencies
  private Void prefixDefs(Lib lib)
  {
    w("# baseURI: ").w(libUri(lib)).nl
    nl
    w("@prefix owl: <http://www.w3.org/2002/07/owl#> .").nl
    w("@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .").nl
    w("@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .").nl
    w("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .").nl
    lib.depends.each |x| { prefixDef(ns.lib(x.name)) }
    prefixDef(lib)
    nl
  }

  ** Generate prefix declaration for given library
  private Void prefixDef(Lib lib)
  {
    w("@prefix ").prefix(lib.name).w(": <").w(libUri(lib)).w("#> .").nl
  }

  ** Generate ontology def
  private Void ontologyDef(Lib lib)
  {
    w("<").w(libUri(lib)).w("> a owl:Ontology ;").nl
    w("rdfs:label \"").w(lib.name).w(" Ontology\"@en ;")
    if (!lib.depends.isEmpty)
    {
      nl.w("owl:imports ")
      lib.depends.each |x, i|
      {
        if (i > 0) w(",").nl.w(Str.spaces(12))
        w("<").w(libUri(ns.lib(x.name))).w(">")
      }
    }
    nl.w(".").nl
    nl
  }

  ** Convert library to its RDF URI
  private Str libUri(Lib lib)
  {
    "http://xeto.dev/rdf/${lib.name}-${lib.version}"
  }

  ** Output a library name as a prefix; turtle spec isn't clear what
  ** is allowed, but NCName in XML namespaces allows dot
  private This prefix(Str libName)
  {
    w(libName)
  }

  ** Turn Xeto qname into RDF URI
  static Str qnameToUri(Str qname)
  {
    qname.replace("::", ":")
  }

  ** Output Xeto lib::name qualified name
  private This qname(Str qname)
  {
    w(qnameToUri(qname))
  }

  ** Output Xeto lib::name qualified name with "Shape" suffix
  private This qnameShape(Str qname)
  {
    this.qname(qname).w("Shape")
  }

  ** Output Xeto lib::name qualified name
  private This id(Ref id)
  {
    w(qnameToUri(id.toStr))
  }

  ** Quoted string literal
  private This literal(Str s)
  {
    w(s.toCode.replace(Str<|\$|>, Str<|$|>))
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Bool isSys
}

