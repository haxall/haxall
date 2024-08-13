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
    this.refSpec = ns.spec("sys::Ref")
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
    prefixDefs(lib)
    ontologyDef(lib)
    lib.types.each |x| { if (!XetoUtil.isAutoName(x.name)) cls(x) }
    lib.globals.each |x| { global(x) }
    if (lib.name == "sys") sysDefs
    return this
  }

  override This spec(Spec spec)
  {
    if (spec.isType) return cls(spec)
    if (spec.isGlobal) return global(spec)
    throw Err(spec.name)
  }

  override This instance(Dict instance)
  {
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Definitions
//////////////////////////////////////////////////////////////////////////

  private This cls(Spec x)
  {
    qname(x.qname).nl
    w("  a owl:Class ;").nl
    w("  rdfs:label \"").w(x.name).w("\"@en ;").nl

    if (x.base != null)
      w("  rdfs:subClassOf ").qname(x.base.qname).w(" ;").nl

    /*
    w("  owl:equivalentClass [").nl
    w("    a owl:Class ;").nl
    w("    ] ;").nl
    */
    w(".").nl
    return this
  }

  private This global(Spec x)
  {
    if (x.isMarker) return globalMarker(x)
    if (x.isa(refSpec)) return globalRef(x)
    return globalProp(x)
  }

  private This globalMarker(Spec x)
  {
    qname(x.qname).nl
    w("  a sys:Marker ;").nl
    w("  rdfs:label \"").w(x.name).w("\"@en ;").nl
    w(".").nl
    return this
  }

  private This globalRef(Spec x)
  {
    of := x.of(false)?.qname ?: "sys::Dict"
    qname(x.qname).nl
    w("  a owl:ObjectProperty ;").nl
    w("  rdfs:label \"").w(x.name).w("\"@en ;").nl
    w("  rdfs:range \"").qname(of).w(" ;").nl
    w(".").nl
    return this
  }

  private This globalProp(Spec x)
  {
    return this
  }

  ** Extra definitions in the sys library
  private This sysDefs()
  {
    w(
    Str<|:hasMarker
           a owl:ObjectProperty ;
           rdfs:label \"Has Marker\"@en ;
           rdfs:range sys:Marker ;
         .
         |>)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Generate prefixes for libraries dependencies
  private Void prefixDefs(Lib lib)
  {
    w("@prefix owl: <http://www.w3.org/2002/07/owl#> .").nl
    w("@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .").nl
    w("@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .").nl
    w("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .").nl
    lib.depends.each |x| { prefixDef(ns.lib(x.name)) }
    prefixDef(lib)
    nl
  }

  ** Generate ontology def
  private Void ontologyDef(Lib lib)
  {
    w(libUri(lib)).w(" a owl:Ontology ;").nl
    w("rdfs:label \"").w(lib.name).w(" Ontology\"@en ;").nl
    if (!lib.depends.isEmpty)
    {
      w("owl:imports ")
      lib.depends.each |x, i|
      {
        if (i > 0) w(",").nl.w(Str.spaces(12))
        w(libUri(ns.lib(x.name)))
      }
      w(" .").nl
    }
    nl
  }

  ** Generate prefix declaration for given library
  private Void prefixDef(Lib lib)
  {
    w("@prefix ").prefix(lib.name).w(": ").w(libUri(lib)).w(" .").nl
  }

  ** Convert library to its RDF URI
  private Str libUri(Lib lib)
  {
    "<http://xeto.dev/rdf/${lib.name}-${lib.version}#>"
  }

  ** Output a library name as a prefix; turtle spec isn't clear what
  ** is allowed, but NCName in XML namespaces allows dot
  private This prefix(Str libName)
  {
    w(libName)
  }

  ** Output Xeto lib::name qualified name
  private This qname(Str qname)
  {
    w(qname.replace("::", ":"))
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const Spec refSpec
}

