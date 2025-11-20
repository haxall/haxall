//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** RDF Turtle Exporter
**
** TODO
**   - mapping all scalars to xsd:string
**   - list and dict slots not supported
**   - query constraints not implemented
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
    types := lib.types

    prefixDefs(lib)
    ontologyDef(lib)

    if (isSys)
    {
      sysDefs
      types = types.dup.moveTo(types.find { it.name == "Obj" }, 0)
    }

    types.each |x| { if (!XetoUtil.isAutoName(x.name)) cls(x) }
    lib.mixins.each |x| { if (!XetoUtil.isAutoName(x.name)) cls(x) }
    lib.instances.each |x| { instance(x) }
    return this
  }

  override This spec(Spec spec)
  {
    this.isSys = spec.lib.name == "sys"
    if (spec.isType) return cls(spec)
    if (spec.isGlobal) return global(spec)
    throw Err(spec.name)
  }

//////////////////////////////////////////////////////////////////////////
// Preludes
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
    w("@prefix sh: <http://www.w3.org/ns/shacl#> .").nl
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

  ** Extra definitions in the sys library
  private This sysDefs()
  {
    w(
    Str<|sys:Class
           a rdfs:Class ;
           a sh:NodeShape ;
           rdfs:comment "Xeto meta class" ;
           rdfs:label "Class"@en ;
           rdfs:subClassOf rdfs:Class ;
         .
         sys:HasMarkerShape
           a sh:NodeShape ;
           sh:targetSubjectsOf sys:hasMarker ;
           sh:property [
              sh:path sys:hasMarker ;
              sh:class sys:Marker ;
           ]
           .
  |>)
  }

//////////////////////////////////////////////////////////////////////////
// Definitions
//////////////////////////////////////////////////////////////////////////

  private This cls(Spec x)
  {
    qname(x.qname).nl

    // classes
    w("  a sys:Class ;").nl
    w("  a rdfs:Class ;").nl

    // choices (and enums) are instances of themselves;
    // everything is also a SHACL shape
    if (isSelfInstance(x)) w("  a ").qname(x.qname).w(" ;").nl
    else w("  a sh:NodeShape ;").nl

    // supertype
    if (x.base != null) w("  rdfs:subClassOf ").qname(x.base.qname).w(" ;").nl
    else  w("  rdfs:subClassOf rdfs:Resource ;").nl

    // label and comment properties
    labelAndDoc(x)

    // expand enum items as self-referential class/instances
    if (x.isEnum)
    {
      w(".").nl
      enum(x)
      return this
    }

    // slots are either hasMarker, or property shapes
    props := Spec[,]
    x.slotsOwn.each |s|
    {
      if (s.isMarker) hasMarker(s)
      else props.add(s)
    }
    if (!props.isEmpty)
    {
      w("  sh:targetClass ").qname(x.qname).w(" ;").nl
      props.each |s| { propShape(s) }
    }

    w(".").nl

    // generate slot properties
    x.slotsOwn.each |s|
    {
      slot(s)
    }

    return this
  }

  private Bool isSelfInstance(Spec x)
  {
    if (x.isChoice)
    {
      // Choice and first level of Choice inheritance are not
      if (x.base.lib.name == "sys") return false
      return true
    }
    return false
  }

  private Void hasMarker(Spec slot)
  {
    if (slot.isMaybe) return // what to do here?
    prop := isSys ? ":hasMarker" : "sys:hasMarker"
    w("  ").w(prop).w(" ").qname(slot.qname).w(" ;").nl
  }

  private Void propShape(Spec slot)
  {
    // build constraints
    sh := Str:Obj[:]
    sh.ordered = true
    hasMinCount := !slot.isMaybe
    hasMaxCount := true

    // value type
    type := slot.type
    if (type.isRef || type.isMultiRef)
    {
      of := slot.of(false)?.qname ?: "sys::Entity"
      sh["class"] = qnameToUri(of)
      if (type.isMultiRef) hasMaxCount = false
    }
    else if (type.isEnum)
    {
      sh["class"] = qnameToUri(type.qname)
    }
    else if (type.isChoice)
    {
      sh["class"] = qnameToUri(type.qname)
      if (slot.meta.has("multiChoice")) hasMaxCount = false
    }
    else
    {
      // all scalars map to string for now
      sh["datatype"] = "xsd:string"
    }

    // cardinality minCount/maxCount
    if (hasMinCount) sh["minCount"] = "1"
    if (hasMaxCount) sh["maxCount"] = "1"

    // write property shape
    w("  sh:property [").nl
    w("    sh:path ").qname(slot.qname).w(" ;").nl
    sh.each |v, n| { w("    sh:").w(n).w(" ").w(v).w(" ;").nl }
    w("  ] ;").nl
  }

  private This enum(Spec x)
  {
    x.enum.each |item, key|
    {
      uri := enumItemUri(item)
      w(uri).nl
      w("  a sys:Class ;").nl
      w("  a ").w(uri).w(" ;").nl
      w("  rdfs:label ").literal(key).w("; ").nl
      w("  rdfs:subClassOf ").qname(x.qname).w("; ").nl
      w(".").nl
    }
    return this
  }

  private Str enumItemUri(Spec item)
  {
    qnameToUri(item.qname)
  }

  private This global(Spec x)
  {
    // don't generate globals, just class properties
    // prop(x)
    return this
  }

  private This slot(Spec x)
  {
    prop(x)
  }

  private This prop(Spec x)
  {
    if (x.isMarker) return propMarker(x)
    return propVal(x)
  }

  private This propMarker(Spec x)
  {
    qname(x.qname).nl
    w("  a sys:Marker ;").nl
    labelAndDoc(x)
    w(".").nl
    return this
  }

  private This propVal(Spec x)
  {
    qname(x.qname).nl
    w("  a rdf:Property ;").nl
    if (!x.base.isType)
      w("  rdfs:subClassOf ").qname(x.base.qname).w("; ").nl
    labelAndDoc(x)
    type := globalType(x)
    // if (type != null) w("  rdfs:range ").w(type).w(" ;").nl
    w(".").nl
    return this
  }

  private Str? globalType(Spec x)
  {
    type := x.type
    if (type.qname == "sys::Str") return "xsd:string"
    if (type.qname == "sys::Int") return "xsd:integer"
    if (type.isEnum) return qnameToUri(type.qname)
    if (type.isChoice) return qnameToUri(type.qname)
    if (type.isRef || type.isMultiRef) return x.of(false)?.qname ?: "sys:Entity"
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
    dis := instance.dis.trim
    members := spec.members

    markers := Str:Spec[:]
    refs    := Str:Spec[:]
    enums   := Str:Spec[:]
    vals    := Str:Spec[:]
    instance.each |v, n|
    {
      if (n == "id") return
      if (n == "dis" || n == "disMacro") return

      slot := members.get(n, false)
      if (slot == null) return
      if (slot.isChoice) return // handled below

      type := slot.type
      if (v == Marker.val)  markers[n] = slot
      else if (v is Ref)    refs[n] = slot
      else if (type.isEnum) enums[n] = slot
      else vals[n] = slot
    }

    this.id(id).nl
    w("  rdf:type ").qname(spec.qname).w(" ;").nl
    w("  rdfs:label ").literal(dis).w(" ;").nl
    markers.keys.sort.each |n| { instanceMarker(instance, n, markers[n]) }
    refs.keys.sort.each  |n| { instanceRef(instance, n, refs[n]) }
    enums.keys.sort.each |n| { instanceEnum(instance, n, enums[n]) }
    vals.keys.sort.each  |n| { instanceVal(instance, n, vals[n]) }
    spec.slots.each |s| { if (s.isChoice) instanceChoice(instance, s) }
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

  private Void instanceEnum(Dict instance, Str name, Spec slot)
  {
    key := instance[name]?.toStr
    if (key == null) return
    item := slot.type.enum.spec(key, false)
    if (item == null) return
    w("  ").qname(slot.qname).w(" ").w(enumItemUri(item)).w(" ;").nl
  }

  private Void instanceVal(Dict instance, Str name, Spec slot)
  {
    val := instance[name]
    if (val == null) return
    w("  ").qname(slot.qname).w(" ").literal(val.toStr).w(" ;").nl
  }

  private Void instanceChoice(Dict instance, Spec slot)
  {
    selected := ns.choice(slot).selections(instance, false)
    selected.each |x|
    {
      w("  ").qname(slot.qname).w(" ").qname(x.qname).w(" ;").nl
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

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

  ** Output Xeto lib::name qualified name
  private This id(Ref id)
  {
    w(qnameToUri(id.toStr))
  }

  ** Quoted string literal
  private This literal(Str s)
  {
    lines := s.splitLines
    if (lines.size <= 1)
    {
      w(lines[0].toCode('"').replace(Str<|\$|>, Str<|$|>))
    }
    else
    {
      indent := "    "
      w(Str<|"""|>).nl
      lines.each |line| { w(indent).w(line.toCode(null).replace(Str<|\$|>, Str<|$|>)).nl }
      w("    ").w(Str<|"""|>)
    }
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Bool isSys
}

