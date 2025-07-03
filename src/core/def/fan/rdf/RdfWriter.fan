//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jan 2019  Matthew Giannini  Creation
//

using rdf
using xeto
using haystack

**
** Base class for RDF writers
**
@NoDoc @Js abstract class RdfWriter : GridWriter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(RdfOutStream out, Dict? opts := null)
  {
    if (opts == null) opts = Etc.emptyDict
    this.out = out
    this.ns  = opts["ns"] as DefNamespace ?: throw ArgErr("Opts must include ns")
    out.setNs("owl", "http://www.w3.org/2002/07/owl#")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private RdfOutStream out
  private DefNamespace ns

  ** Maps symbol libraries that are used in the grid.
  protected [Str:DefLib] libs := [:]

  ** If specified in the grid meta, this namespace will be used for
  ** Refs instead of generating blank nodes.
  private Str? refBaseUri := null

  ** If a tag's value is a Dict, then we stash them here while writing the
  ** parent Dict.
  private [Iri:Dict] nestedDicts := [:] { ordered = true }

//////////////////////////////////////////////////////////////////////////
// Haystack Types
//////////////////////////////////////////////////////////////////////////

  once Iri binIri()    { Iri(ns.symbolToUri("bin")) }
  once Iri coordIri()  { Iri(ns.symbolToUri("coord")) }
  once Iri markerIri() { Iri(ns.symbolToUri("marker")) }
  once Iri naIri()     { Iri(ns.symbolToUri("na")) }
  once Iri numberIri() { Iri(ns.symbolToUri("number")) }
  once Iri refIri()    { Iri(ns.symbolToUri("ref")) }
  once Iri xstrIri()   { Iri(ns.symbolToUri("xstr")) }
  once Iri dictIri()   { Iri(ns.symbolToUri("dict")) }
  once Iri gridIri()   { Iri(ns.symbolToUri("grid")) }

//////////////////////////////////////////////////////////////////////////
// RDF Writer
//////////////////////////////////////////////////////////////////////////

  override This writeGrid(Grid grid)
  {
    inspectSymbols(grid)
    writePrefixes(grid)
    writeSyntheticStmts
    grid.each |row|
    {
      writeOntology(row)
      writeDict(row)
      writeNested
    }
    out.finish
    return this
  }

  private Void writePrefixes(Grid grid)
  {
    libs.each |lib|
    {
      // This makes an assumption that every symbol in this library
      // shares the same prefix
      iri := symbolIri(lib.symbol)
      out.setNs(lib.name, iri.ns)
    }

    this.refBaseUri = grid.meta["refBaseUri"]?.toStr
    if (refBaseUri != null) out.setNs("ref", refBaseUri)
  }

  private Void writeSyntheticStmts()
  {
    // ph:hasTag
    hasTag := Iri("ph:hasTag")
    out.writeStmt(hasTag, rdfType, owlObjectProp)
    out.writeStmt(hasTag, rdfsRange, markerIri)
  }

  private Void writeNested()
  {
    while (!nestedDicts.isEmpty)
    {
      subject := nestedDicts.keys.first
      dict    := nestedDicts.remove(subject)
      writeInstOntology(dict, subject)
      writeDict(dict, subject)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Ontology
//////////////////////////////////////////////////////////////////////////

  ** Inspects the dict and writes any ontology-specific RDF statements
  ** based on the Dict type and its tags
  private Void writeOntology(Dict dict)
  {
    symbol := dict["def"] as Symbol
    if (symbol != null) writeDefOntology(symbol, dict)
    else writeInstOntology(dict)
  }

  private Void writeDefOntology(Symbol symbol, Dict dict)
  {
    def    := ns.def(symbol.toStr)
    choice := ns.def("choice")
    subj   := toSubject(dict)

    if (ns.fitsMarker(def))
    {
      // indicate that the marker def is an OWL class
      out.writeStmt(subj, rdfType, owlClass)

      // write that this def is a sub-class of all its declared supertypes
      ns.supertypes(def).each |superDef|
      {
        writeStmt(subj, rdfsSubClassOf, superDef.symbol)
      }
    }
    else if (ns.fits(def, choice))
    {
      // don't do anything for choice since it is abstract concept
      if (def == choice) return

      // the "of" tag specifies the range for this choice
      of := def["of"] as Symbol
      if (of == null) return

      out.writeStmt(subj, rdfType, owlObjectProp)
      writeStmt(subj, rdfsRange, of)
    }
    else if (ns.fitsVal(def))
    {
      // handle non-marker tags
      // 1. direct sub-types of scalar become datatypes
      // 2. other value tags become properties

      // TODO: don't write anything for val since it is abstract concept???
      if (def == ns.def("val")) return

      if (isScalar(def))
      {
        // it's a datatype
        out.writeStmt(subj, rdfType, owlDatatypeProp)

        // sub-class from appropriate xsd datatype
        out.writeStmt(subj, rdfsSubClassOf, toDatatype(def))
      }
      else
      {
        // it's a property
        symbolType := def.symbol.type
        propType   := isRef(def) ? owlObjectProp : owlDatatypeProp
        out.writeStmt(subj, rdfType, propType)

        // domain: the domain is every entity this is a tag on
        DefUtil.resolveList(ns, def["tagOn"]).each |entityDef|
        {
          writeStmt(subj, rdfsDomain, entityDef.symbol)
        }

        // range: walk supertypes to find closest type to either "val" or "scalar"
        writeStmt(subj, rdfsRange, toRange(def))
      }
    }
  }

  private Bool isScalar(Def def)
  {
    ns.supertypes(def).contains(ns.def("scalar"))
  }

  private Bool isRef(Def def)
  {
    ns.fits(def, ns.def("ref"))
  }

  private Symbol toRange(Def def)
  {
    // the range of a Ref is determined by its "of" tag
    if (isRef(def)) return def["of"] ?: ns.def("entity").symbol

    inheritance := ns.inheritance(def)
    kind        := inheritance.find { isScalar(it) }
    if (kind == null)
    {
      // find best direct sub-type of val (for list, dict, grid)
      kind = inheritance.find { ns.supertypes(it).contains(ns.def("val")) }
    }
    if (kind == null) throw ArgErr("Cannot determine range for ${def}. Inheritance: ${inheritance}")
    return kind.symbol
  }

  ** Get the IRI for the datatype of this def
  private static Iri toDatatype(Def def)
  {
    switch (def.name)
    {
      case "bool":     return Xsd.boolean
      case "curVal":   return rdfsLiteral
      case "date":     return Xsd.date
      case "dateTime": return Xsd.dateTime
      case "number":   return Xsd.double
      case "ref":      return Xsd.anyURI
      case "symbol":   return Xsd.anyURI
      case "time":     return Xsd.time
      case "uri":      return Xsd.anyURI
      case "writeVal": return rdfsLiteral
      default:         return Xsd.string
    }
  }

  private Void writeInstOntology(Dict dict, Iri? subject := null)
  {
    subj := subject ?: toSubject(dict)

    // the instance is a member of its entity class
    types := ns.reflect(dict).entityTypes
    types.each |def| { writeStmt(subj, rdfType, def.symbol) }

    // map all marker tags to "hasTag"
    dict.each |val, tagName|
    {
      if (val !== Marker.val) return

      typeDef := ns.def(tagName, false)
      if (typeDef == null) return

      // TODO: we don't have def for ph:hasTag yet
      writeStmt(subj, Iri("ph:hasTag"), typeDef.symbol)
    }
  }

  private static const Iri owlClass          := Iri("owl:Class")
  private static const Iri owlDatatypeProp   := Iri("owl:DatatypeProperty")
  private static const Iri owlObjectProp     := Iri("owl:ObjectProperty")
  private static const Iri rdfType           := Iri("rdf:type")
  private static const Iri rdfsSubClassOf    := Iri("rdfs:subClassOf")
  private static const Iri rdfsSubPropertyOf := Iri("rdfs:subPropertyOf")
  private static const Iri rdfsDatatype      := Iri("rdfs:Datatype")
  private static const Iri rdfsLiteral       := Iri("rdfs:Literal")
  private static const Iri rdfsDomain        := Iri("rdfs:domain")
  private static const Iri rdfsRange         := Iri("rdfs:range")
  private static const Iri rdfsLabel         := Iri("rdfs:label")

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  private Void writeDict(Dict dict, Iri? subject := null)
  {
    subj   := subject ?: toSubject(dict)
    isInst := subj.isBlankNode
    writeStmt(subj, rdfsLabel, dict.dis)
    dict.each |val, tagName|
    {
      // don't write marker values for instances
      if (isInst && val === Marker.val) return

      // don't write "id" tags since they are the "subject"
      if (isIdTag(tagName)) return

      // tagName is the predicate
      pred := toPredicate(tagName)
      if (pred == null) return

      writeStmt(subj, pred, val)
    }
  }

  private static Bool isIdTag(Str tagName)
  {
    "id" == tagName || "def" == tagName
  }

  private Iri toSubject(Dict dict)
  {
    // map Refs to their Iri representation
    id := dict["id"] as Ref
    if (id != null) return refToIri(id)

    symbol := dict["def"] as Symbol
    if (symbol != null) return symbolIri(symbol)

    // Generate an anonymous blank node
    return Iri.bnode
  }

  private Iri? toPredicate(Str tagName)
  {
    def := ns.def(tagName, false)
    if (def == null)
    {
      // if we don't have a def for the tag name, then generate a blank node
      return Iri.bnode(tagName)
    }

    // map ph:doc => rdfs:comment
    if (def == ns.def("doc")) return Iri("rdfs:comment")

    return symbolIri(def.symbol)
  }

  private Void writeStmt(Iri subj, Iri pred, Obj val)
  {
    if (val is List)
    {
      // TODO:??? we currently recurse on individual elements instead of writing
      // a "collection" value. Not sure we are doing the right thing here.
      // This makes sense when the prediciate is "ph:is", but not when the value
      // actually is a List (e.g. weatherSyncIds)
      (val as List).each |elem| { writeStmt(subj, pred, elem) }
      return
    }

    // Map the value type to possibly more specific object and/or type
    kind      := Kind.fromVal(val, false)
    object    := val
    Iri? type := null
    if (Kind.marker === kind) object = markerIri
    else if (Kind.number === kind)
    {
      // TODO: it is better to write numbers are simple numerical values
      // We do not currently write any unit information.
      num := val as Number
      object = num.isInt ? num.toInt : num.toFloat
    }
    else if (Kind.ref === kind)
    {
      // if it is a Ref, map it to its Iri representation
      object = refToIri(object)
    }
    else if (Kind.symbol === kind) object = symbolIri(val)
    else if (Kind.coord === kind)  type = coordIri
    else if (Kind.na === kind)     object = naIri
    else if (Kind.bin === kind)    type = binIri
    else if (Kind.xstr === kind)   type = xstrIri
    else if (Kind.dict === kind)
    {
      // Stash the nested Dict and remember its subject IRI.
      // Then write the object of this tag as the IRI to this nested dict.
      // The nested Dict will be written after its parent is finished.
      dict     := (Dict)val
      dictSubj := toSubject(dict)
      nestedDicts[dictSubj] = dict

      return writeStmt(subj, pred, dictSubj)
    }
    else if (Kind.grid === kind)
    {
      x := XStr("ZincGrid", ZincWriter.gridToStr(val))
      return writeStmt(subj, pred, x)
    }

    // write
    out.writeStmt(subj, pred, object, type)
  }

//////////////////////////////////////////////////////////////////////////
// Inspect
//////////////////////////////////////////////////////////////////////////

  private Void inspectSymbols(Grid grid)
  {
    // always map library containing definition of "^val"
    mapDef("val")

    // map column names as symbols
    grid.cols.each |col| { mapDef(col.name) }

    // scan all grid cells and map all values that are symbols
    grid.each |row|
    {
      row.each |val, tag| { mapVal(val) }
    }
  }

  private Void mapDef(Str symbol)
  {
    def := ns.def(symbol, false)
    if (def == null) return
    libs[def.lib.name] = def.lib
  }

  private Void mapVal(Obj? val)
  {
    if (val is Symbol) mapDef(val.toStr)
    else if (val is List)
    {
      (val as List).each |elem| { mapVal(elem) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private Iri symbolIri(Symbol symbol) { Iri(ns.symbolToUri(symbol.toStr)) }

  ** If refBaseUri is defined, generate an Iri with that prefix. Otherwise
  ** generate a blank node representation with the label set to the Ref's id.
  private Iri refToIri(Ref ref)
  {
    id := ref.toProjRel.id
    return this.refBaseUri == null
      ? Iri.bnode(id)
      : Iri(refBaseUri, id)
  }
}

