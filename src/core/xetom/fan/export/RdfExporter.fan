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
@Js
class RdfExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
    if (opts.has("qudtMappings"))
    {
      mappingOpt := opts["qudtMappings"]
      this.qudtRef = mappingOpt as RdfQudtMappings
        ?: throw ArgErr("qudtMappings option must be RdfQudtMappings, not ${mappingOpt?.typeof}")
    }
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
    this.curLib = lib
    this.isSys = lib.name == "sys"
    validateSealedNamespace(lib)
    types := lib.types.list

    prefixDefs(lib)
    ontologyDef(lib)

    if (isSys)
    {
      sysDefs
      types = types.dup.moveTo(types.find { it.name == "Obj" }, 0)
    }

    types.each |x| { if (!XetoUtil.isAutoName(x.name)) cls(ns.specx(x)) }

    // A mixin contributes to its target's effective shape; it is not an RDF
    // class of its own. Emit each affected target once with all namespace
    // mixins applied, while its contributed slots retain their own qnames.
    mixinTargets := Str:Spec[][:]
    lib.mixins.each |contribution|
    {
      target := contribution.base
      if (target == null)
        throw UnsupportedErr("Mixin contribution ${contribution.qname} has no target spec")

      // +Spec declares metadata rather than application data. Known metadata
      // is consumed by its mapping rule; metadata without a rule is omitted.
      if (target.qname == "sys::Spec") return

      mixinTargets.getOrAdd(target.qname) { Spec[,] }.add(contribution)
    }
    mixinTargets.each |contributions, targetQname|
    {
      target := ns.spec(targetQname, false)
      if (target == null) target = contributions.first.base
      if (target == null) throw UnsupportedErr("Mixin target not found: ${targetQname}")
      mixinShape(target, contributions)
    }
    lib.instances.each |x| { instance(x) }
    return this
  }

  override This spec(Spec spec)
  {
    this.isSys = spec.lib.name == "sys"
    if (spec.isType) return cls(spec)
    if (spec.isGlobal) return global(spec)
    throw UnsupportedErr("RDF export target is neither a type nor a global: ${spec.qname}")
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
    w("@prefix skos: <http://www.w3.org/2004/02/skos/core#> .").nl
    w("@prefix qudt: <http://qudt.org/schema/qudt/> .").nl
    w("@prefix unit: <http://qudt.org/vocab/unit/> .").nl
    w("@prefix currency: <http://qudt.org/vocab/currency/> .").nl
    w("@prefix quantitykind: <http://qudt.org/vocab/quantitykind/> .").nl
    // Effective shapes may contain slots contributed by any active namespace
    // library, including mixins whose owner is not a direct dependency.
    // Declare every active prefix so all emitted qnames are valid Turtle.
    libs := ns.libs.dup.sort |a, b| { a.name <=> b.name }
    libs.each |x| { prefixDef(x) }
    if (!libs.any |x| { x.name == lib.name }) prefixDef(lib)
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
    // Vocabulary is declared from slotsOwn below, but validation uses the
    // effective slot view so subclasses receive inherited constraints.
    props   := Spec[,]
    markers := Spec[,]
    x.slots.each |s|
    {
      if (s.isMarker) markers.add(s)
      else props.add(s)
    }
    hasShape := !x.isEnum && (!props.isEmpty || markers.any |s| { !s.isMaybe })

    qname(x.qname).nl

    // classes
    w("  a sys:Class ;").nl
    w("  a rdfs:Class ;").nl

    // Classes with effective constraints are also SHACL node shapes.
    if (hasShape) w("  a sh:NodeShape ;").nl

    // Intersections are subclasses of every member. Unions reverse that
    // relationship below so each member is a subclass of the union.
    if (x.isCompound && x.isAnd)
    {
      w("  rdfs:subClassOf ")
      x.bases.each |base, i|
      {
        if (i > 0) w(", ")
        qname(base.qname)
      }
      w(" ;").nl
    }
    else if (!(x.isCompound && x.isOr))
    {
      if (x.base != null) w("  rdfs:subClassOf ").qname(x.base.qname).w(" ;").nl
      else  w("  rdfs:subClassOf rdfs:Resource ;").nl
    }

    // label and comment properties
    labelAndDoc(x)

    // Enum values are RDF string literals constrained by sh:in; they are not
    // vocabulary individuals of their own.
    if (x.isEnum)
    {
      w(".").nl
      return this
    }

    // Marker ownership includes optional and inherited markers. Only required
    // markers add a SHACL hasValue constraint.
    markers.each |s| { hasMarker(s) }
    if (hasShape)
    {
      w("  sh:targetClass ").qname(x.qname).w(" ;").nl
      props.each |s| { propShape(s) }
      markers.each |s| { if (!s.isMaybe) markerShape(s) }
    }

    w(".").nl

    // generate slot properties
    x.slotsOwn.each |s|
    {
      slot(s)
    }
    x.globalsOwn.each |g| { global(g) }

    if (x.isCompound && x.isOr)
    {
      x.bases.each |member|
      {
        qname(member.qname).w(" rdfs:subClassOf ").qname(x.qname).w(" .").nl
      }
    }

    return this
  }

  ** Emit only this library's contribution to a dependency-owned target. The
  ** dependency graph owns the target class and its original constraints;
  ** this graph adds a SHACL shape with contributor-owned properties.
  private Void mixinShape(Spec target, Spec[] contributions)
  {
    props   := Spec[,]
    markers := Spec[,]
    contributions.each |contribution|
    {
      contribution.slotsOwn.each |slot|
      {
        if (slot.isMarker) markers.add(slot)
        else props.add(slot)
      }
    }

    if (!props.isEmpty || markers.any |slot| { !slot.isMaybe })
    {
      qname(target.qname).nl
      w("  a sh:NodeShape ;").nl
      markers.each |slot| { hasMarker(slot) }
      w("  sh:targetClass ").qname(target.qname).w(" ;").nl
      props.each |slot| { propShape(slot) }
      markers.each |slot| { if (!slot.isMaybe) markerShape(slot) }
      w(".").nl
    }

    contributions.each |contribution|
    {
      contribution.slotsOwn.each |slot| { this.slot(slot) }
      contribution.globalsOwn.each |globalSlot| { global(globalSlot) }
    }
  }

  private Void hasMarker(Spec slot)
  {
    prop := isSys ? ":hasMarker" : "sys:hasMarker"
    w("  ").w(prop).w(" ").qname(slot.qname).w(" ;").nl
  }

  private Void markerShape(Spec slot)
  {
    prop := isSys ? ":hasMarker" : "sys:hasMarker"
    w("  sh:property [").nl
    w("    sh:path ").w(prop).w(" ;").nl
    w("    sh:hasValue ").qname(slot.qname).w(" ;").nl
    w("  ] ;").nl
  }

  private Void propShape(Spec slot)
  {
    type := slot.type
    if (type.isThis || ((type.isRef || type.isMultiRef) && slot.of(false)?.isThis == true))
      throw UnsupportedErr("RDF parent-relative This mapping not supported for ${slot.qname}")
    if (type.isGrid)
      throw UnsupportedErr("RDF Grid mapping not supported for ${slot.qname} of ${type.qname}")
    if (type.qname == "sys::Collection")
      throw UnsupportedErr("RDF Collection mapping not supported for ${slot.qname} of ${type.qname}")
    if (type.isFunc)
      throw UnsupportedErr("RDF Func mapping not supported for ${slot.qname} of ${type.qname}")
    if (type.isInterface)
      throw UnsupportedErr("RDF Interface mapping not supported for ${slot.qname} of ${type.qname}")
    if (type.isComp)
      throw UnsupportedErr("RDF runtime component mapping not supported for ${slot.qname} of ${type.qname}")

    if (slot.isQuery)
    {
      required := slot.slotsOwn.list.find |Spec member->Bool| { !member.isMaybe }
      if (required != null)
        throw UnsupportedErr("RDF query body mapping not supported for required member ${required.qname}")
    }

    // build constraints
    sh := Str:Obj[:]
    sh.ordered = true
    hasMinCount := !slot.isMaybe
    hasMaxCount := true

    // value type
    isQuantityValue := isQuantityValueSlot(slot)
    isLiteral := ((type.isScalar && !type.isRef) || type.qname == "sys::TimeZone") &&
                 !isQuantityValue && type.qname != "sys::Unit" &&
                 type.qname != "sys::UnitQuantity"
    datatype := isLiteral ? scalarDatatype(type) : null
    if (slot.isQuery)
    {
      of := slot.of(false)
      if (of != null) sh["class"] = qnameToUri(of.qname)
      hasMinCount = false
      hasMaxCount = false
    }
    else if (type.qname == "sys::Unit")
    {
      sh["class"] = "qudt:Unit"
    }
    else if (isQuantityValue)
    {
      // The scalar's datatype and range move to qudt:numericValue below.
    }
    else if (isLiteral)
    {
      sh["datatype"] = datatype
    }
    else if (type.isRef || type.isMultiRef)
    {
      of := slot.of(false)?.qname ?: "sys::Entity"
      sh["nodeKind"] = "sh:IRI"
      sh["class"] = qnameToUri(of)
      if (type.isMultiRef) hasMaxCount = false
    }
    else if (type.isEnum)
    {
      if (type.qname == "sys::UnitQuantity")
        throw UnsupportedErr("RDF UnitQuantity mapping not supported for ${slot.qname} of ${type.qname}")
      sh["datatype"] = "xsd:string"
    }
    else if (type.isChoice)
    {
      choice := ns.choice(slot)
      hasMinCount = !choice.isMaybe
      hasMaxCount = !choice.isMultiChoice
    }
    else if (type.isList)
    {
      // List item and size constraints are emitted below on the RDF
      // collection path. The outer slot remains one list value.
    }
    else if (type.isDict)
    {
      sh["node"] = qnameToUri(type.qname)
    }
    else if (type.qname == "sys::Obj")
    {
      // Obj deliberately constrains only cardinality.
    }
    else
    {
      throw UnsupportedErr("RDF slot type mapping not supported for ${slot.qname} of ${type.qname}")
    }

    // cardinality minCount/maxCount
    if (hasMinCount) sh["minCount"] = "1"
    if (hasMaxCount) sh["maxCount"] = "1"

    // write property shape
    w("  sh:property [").nl
    w("    sh:path ")
    if (slot.isQuery) queryPath(slot)
    else qname(slot.qname)
    w(" ;").nl
    sh.each |v, n| { w("    sh:").w(n).w(" ").w(v).w(" ;").nl }
    if (type.isEnum && type.qname != "sys::Unit" &&
        type.qname != "sys::UnitQuantity" && type.qname != "sys::TimeZone")
      enumConstraint(type)
    if (type.isChoice) choiceConstraint(slot)
    if (type.isList) listConstraint(slot)
    if (type.qname == "sys::Unit")
    {
      quantity := metaQuantity(slot)
      if (quantity != null) quantityKindConstraint(quantity, "    ")
    }
    if (isQuantityValue) quantityValueConstraint(slot)
    if (datatype != null) scalarConstraints(slot, datatype)
    w("  ] ;").nl
  }

  ** Write the computed SHACL property path for a query slot. Query metadata
  ** is resolved in the library that owns the declaration, which matters for
  ** slots contributed to another library's type by a mixin.
  private Void queryPath(Spec query)
  {
    viaVal := query.meta["via"]
    inverseVal := query.meta["inverse"]
    if (viaVal != null && inverseVal != null)
      throw UnsupportedErr("RDF query ${query.qname} cannot declare both via and inverse")

    if (viaVal != null)
    {
      via := viaVal as Str
        ?: throw UnsupportedErr("Invalid via metadata for ${query.qname}: ${viaVal.typeof}")
      writeViaPath(query, via, false)
      return
    }

    if (inverseVal != null)
    {
      inverse := inverseVal as Str
        ?: throw UnsupportedErr("Invalid inverse metadata for ${query.qname}: ${inverseVal.typeof}")
      validateQueryPath(query, inverse, false)
      inverseQname := resolveQueryName(query, inverse)
      inverseQuery := resolveSpec(inverseQname)
      if (inverseQuery != null && inverseQuery.isQuery)
      {
        inverseViaVal := inverseQuery.meta["via"]
        inverseVia := inverseViaVal as Str
        if (inverseViaVal != null && inverseVia == null)
          throw UnsupportedErr("Invalid via metadata for ${inverseQuery.qname}: ${inverseViaVal.typeof}")
        if (inverseVia == null)
          throw UnsupportedErr("Inverse query ${query.qname} must reference a via query: ${inverseQname}")
        writeViaPath(inverseQuery, inverseVia, true)
      }
      else
      {
        w("[ sh:inversePath ").qname(inverseQname).w(" ]")
      }
      return
    }

    // A plain query is still computed and has no cardinality, but its RDF
    // predicate is the ordinary declared slot property.
    qname(query.qname)
  }

  private Void writeViaPath(Spec query, Str source, Bool inverse)
  {
    validateQueryPath(query, source, true)

    quantifier := ""
    if (source.endsWith("+") || source.endsWith("*"))
    {
      quantifier = source[-1].toChar
      source = source[0..-2]
    }

    property := resolveQueryName(query, source)
    if (!quantifier.isEmpty)
      w(quantifier == "+" ? "[ sh:oneOrMorePath " : "[ sh:zeroOrMorePath ")
    if (inverse) w("[ sh:inversePath ")
    qname(property)
    if (inverse) w(" ]")
    if (!quantifier.isEmpty) w(" ]")
  }

  private Void validateQueryPath(Spec query, Str source, Bool allowQuantifier)
  {
    if (source.isEmpty)
      throw UnsupportedErr("Empty query path for ${query.qname}")

    path := source
    if (allowQuantifier && (path.endsWith("+") || path.endsWith("*")))
    {
      path = path[0..-2]
      if (path.isEmpty)
        throw UnsupportedErr("Empty query path for ${query.qname}")
    }

    if (path.contains("+") || path.contains("*") || !queryPathRef.matches(path))
      throw UnsupportedErr("Invalid query path for ${query.qname}: ${source}")
  }

  ** Resolve an unqualified path relative to the query declaration. A
  ** Spec.slot path is relative to the declaration's library; a fully
  ** qualified lib::Spec.slot path retains its explicit owner.
  private Str resolveQueryName(Spec query, Str name)
  {
    if (name.contains("::")) return name
    if (name.contains(".")) return "${query.lib.name}::${name}"
    parent := query.parent
      ?: throw UnsupportedErr("Query ${query.qname} has no declaring parent")
    return "${parent.qname}.${name}"
  }

  ** Namespace lookup does not include a temporary library until installed,
  ** so fall back to the currently exported library for its own query slots.
  private Spec? resolveSpec(Str qname)
  {
    found := ns.spec(qname, false)
    if (found != null) return found

    lib := curLib
    if (lib == null || !qname.startsWith("${lib.name}::")) return null
    local := qname[qname.index("::") + 2..-1]
    dot := local.index(".")
    if (dot == null) return lib.spec(local, false)
    parent := lib.spec(local[0..<dot], false)
    if (parent == null) return null
    return parent.slot(local[dot + 1..-1], false)
  }

  private Bool isQuantityValueSlot(Spec slot)
  {
    slot.type.qname == "sys::Number" &&
      (slot.meta["unit"] != null || slot.meta["quantity"] != null)
  }

  private Void quantityValueConstraint(Spec slot)
  {
    w("    sh:node [").nl
    w("      sh:class qudt:QuantityValue ;").nl
    w("      sh:property [").nl
    w("        sh:path qudt:numericValue ;").nl
    w("        sh:datatype xsd:decimal ;").nl

    minVal := quantityNumericMeta(slot, "minVal")
    if (minVal != null) w("        sh:minInclusive ").w(minVal).w(" ;").nl
    maxVal := quantityNumericMeta(slot, "maxVal")
    if (maxVal != null) w("        sh:maxInclusive ").w(maxVal).w(" ;").nl
    if (slot.meta.has("invariant"))
    {
      val := quantityNumericMeta(slot, "val")
      if (val == null)
        throw UnsupportedErr("Invariant quantity slot ${slot.qname} is missing val metadata")
      w("        sh:hasValue ").literal(val).w("^^xsd:decimal ;").nl
    }
    w("        sh:minCount 1 ;").nl
    w("        sh:maxCount 1 ;").nl
    w("      ] ;").nl

    w("      sh:property [").nl
    w("        sh:path qudt:unit ;").nl
    w("        sh:class qudt:Unit ;").nl
    unit := metaUnit(slot)
    if (unit != null)
      w("        sh:hasValue ").w(qudt.unit(unit)).w(" ;").nl
    quantity := metaQuantity(slot)
    if (quantity != null) quantityKindConstraint(quantity, "        ")
    w("        sh:minCount 1 ;").nl
    w("        sh:maxCount 1 ;").nl
    w("      ]").nl
    w("    ] ;").nl
  }

  private Void quantityKindConstraint(UnitQuantity quantity, Str indent)
  {
    targets := qudt.quantity(quantity)
    if (targets.size == 1)
    {
      w(indent).w("sh:node [ sh:property [ sh:path ( qudt:hasQuantityKind [ sh:zeroOrMorePath skos:broader ] ) ; sh:hasValue quantitykind:").w(targets.first).w(" ] ] ;").nl
      return
    }

    w(indent).w("sh:node [ sh:or (").nl
    targets.each |target|
    {
      w(indent).w("  [ sh:property [ sh:path ( qudt:hasQuantityKind [ sh:zeroOrMorePath skos:broader ] ) ; sh:hasValue quantitykind:").w(target).w(" ] ]").nl
    }
    w(indent).w(") ] ;").nl
  }

  private Unit? metaUnit(Spec slot)
  {
    val := slot.meta["unit"]
    if (val == null) return null
    unit := val as Unit
    if (unit != null) return unit
    if (val is Str) return Unit.fromStr(val)
    throw UnsupportedErr("Invalid unit metadata for ${slot.qname}: ${val.typeof}")
  }

  private UnitQuantity? metaQuantity(Spec slot)
  {
    val := slot.meta["quantity"]
    if (val == null) return null
    quantity := val as UnitQuantity
    if (quantity != null) return quantity
    if (val is Str) return UnitQuantity.fromStr(val)
    throw UnsupportedErr("Invalid quantity metadata for ${slot.qname}: ${val.typeof}")
  }

  private Void choiceConstraint(Spec slot)
  {
    // The RDF specification constrains a choice slot to the member IRIs
    // visible in the active namespace, rather than to marker values.
    members := choiceMembers(slot)
    if (members.isEmpty)
      throw UnsupportedErr("RDF choice ${slot.qname} has no members in the active namespace")
    w("    sh:in (")
    members.each |member, i|
    {
      if (i > 0) w(" ")
      qname(member.qname)
    }
    w(") ;").nl
  }

  private Spec[] choiceMembers(Spec slot)
  {
    // The declared slot type defines the selected branch. For an intermediate
    // Choice this includes the marker-bearing type itself and its descendants,
    // but excludes sibling branches under the root Choice.
    choiceType := slot.type

    // Namespace types cover installed dependency libraries. curLib is merged
    // explicitly because temporary or currently-exported libraries are not
    // necessarily installed in Namespace.eachType yet. Key by qname so a
    // library visible through both paths contributes each candidate once.
    candidates := Str:Spec[:]
    ns.eachType |candidate| { candidates[candidate.qname] = candidate }
    curLib?.types?.each |candidate| { candidates[candidate.qname] = candidate }

    members := Spec[,]
    candidates.each |candidate|
    {
      if (!candidate.isChoice) return
      if (!candidate.isa(choiceType)) return
      if (!candidate.slots.list.any |Spec memberSlot->Bool| { memberSlot.isMarker }) return
      members.add(candidate)
    }
    members.sort |a, b| { a.qname <=> b.qname }
    return members
  }

  private Void listConstraint(Spec slot)
  {
    of := slot.of(false)
    validateListItemType(slot, of)

    minSize := intMeta(slot, "minSize")
    if (slot.meta.has("nonEmpty") && (minSize == null || minSize < 1)) minSize = 1
    maxSize := intMeta(slot, "maxSize")
    if (of == null && minSize == null && maxSize == null) return

    // A Xeto list is one slot value represented by an RDF collection. The
    // outer property shape handles list presence/cardinality; this nested
    // shape applies item type and size constraints along rdf:rest*/rdf:first.
    w("    sh:node [").nl
    w("      sh:property [").nl
    w("        sh:path ( [ sh:zeroOrMorePath rdf:rest ] rdf:first ) ;").nl
    if (of != null)
    {
      if (of.isScalar)
        w("        sh:datatype ").w(scalarDatatype(of)).w(" ;").nl
      else if (of.isDict)
        w("        sh:class ").qname(of.qname).w(" ;").nl
    }
    if (minSize != null) w("        sh:minCount ").w(minSize).w(" ;").nl
    if (maxSize != null) w("        sh:maxCount ").w(maxSize).w(" ;").nl
    w("      ]").nl
    w("    ] ;").nl
  }

  private Void validateListItemType(Spec slot, Spec? of)
  {
    if (of == null) return

    // The current public mapping defines scalar and direct-dictionary items.
    // Deferred forms fail closed instead of being omitted or stringified.
    kind := "item type ${of.qname}"
    if (of.isChoice) kind = "choice item type ${of.qname}"
    else if (of.qname == "sys::Unit") kind = "unit item type ${of.qname}"
    else if (of.isEnum) kind = "enum item type ${of.qname}"
    else if (of.isRef || of.isMultiRef) kind = "reference item type ${of.qname}"
    else if (of.isList) kind = "nested-list item type ${of.qname}"
    else if (of.isScalar || of.isDict) return
    throw UnsupportedErr("RDF list mapping not supported for ${slot.qname}: ${kind}")
  }

  private Void enumConstraint(Spec type)
  {
    w("    sh:in (")
    type.enum.keys.each |key, i|
    {
      if (i > 0) w(" ")
      literal(key).w("^^xsd:string")
    }
    w(") ;").nl
  }

  private Void scalarConstraints(Spec slot, Str datatype)
  {
    meta := slot.meta

    minVal := numericMeta(slot, "minVal")
    if (minVal != null) w("    sh:minInclusive ").w(minVal).w(" ;").nl

    maxVal := numericMeta(slot, "maxVal")
    if (maxVal != null) w("    sh:maxInclusive ").w(maxVal).w(" ;").nl

    minSize := intMeta(slot, "minSize")
    if (minSize != null) w("    sh:minLength ").w(minSize).w(" ;").nl

    maxSize := intMeta(slot, "maxSize")
    if (maxSize != null) w("    sh:maxLength ").w(maxSize).w(" ;").nl

    scalarPatterns(slot, datatype).each |pattern|
    {
      w("    sh:pattern ").literal(pattern).w(" ;").nl
    }

    if (meta.has("nonEmpty"))
      w("    sh:pattern ").literal("\\S").w(" ;").nl

    if (meta.has("invariant"))
    {
      val := meta["val"]
      if (val == null)
        throw UnsupportedErr("Invariant scalar slot ${slot.qname} is missing val metadata")
      w("    sh:hasValue ")
      typedLiteral(val, slot.type, slot.qname)
      w(" ;").nl
    }
  }

  private Str scalarDatatype(Spec type)
  {
    switch (type.qname)
    {
      case "sys::Str":      return "xsd:string"
      case "sys::Number":   return "xsd:decimal"
      case "sys::Int":      return "xsd:integer"
      case "sys::Bool":     return "xsd:boolean"
      case "sys::Date":     return "xsd:date"
      case "sys::Time":     return "xsd:time"
      case "sys::DateTime": return "xsd:dateTime"
      case "sys::Uri":      return "xsd:anyURI"
      case "sys::TimeZone": return "xsd:string"
    }

    // User-defined Scalar subtypes have string lexical values unless this
    // profile assigns their qname a more specific datatype above.
    if (type.isScalar && type.lib.name != "sys") return "xsd:string"
    throw UnsupportedErr("RDF scalar datatype not supported: ${type.qname}")
  }

  ** Return every string pattern contributed by the custom scalar hierarchy,
  ** followed by any slot-level refinement. Each pattern is a separate SHACL
  ** constraint, so a value must satisfy the complete inherited contract.
  private Str[] scalarPatterns(Spec slot, Str datatype)
  {
    // Xeto's built-in numeric/date patterns describe source syntax and are
    // not SHACL regex constraints on RDF typed literals.
    if (datatype != "xsd:string") return Str[,]

    patterns := Str[,]
    added := Str:Bool[:]
    chain := Spec[,]
    seen := Str:Bool[:]
    Spec? cur := slot.type
    while (cur != null && cur.isScalar && cur.lib.name != "sys")
    {
      if (seen.containsKey(cur.qname))
        throw UnsupportedErr("Cyclic Xeto type inheritance while resolving ${slot.type.qname}: ${cur.qname}")
      seen[cur.qname] = true
      chain.add(cur)
      cur = cur.base
    }
    chain.reverse.each |type|
    {
      addScalarPattern(patterns, added, type.qname, type.meta["pattern"])
    }

    patternVal := slot.meta["pattern"]
    if (patternVal == null) return patterns
    pattern := patternVal as Str
      ?: throw UnsupportedErr("Invalid pattern metadata for ${slot.qname}: ${patternVal.typeof}")

    // Built-in scalar patterns describe Xeto's source encoding; they are not
    // additional value constraints. Keep a slot override or a custom scalar's
    // effective pattern.
    type := slot.type
    if (isBuiltInScalar(type.qname))
    {
      typePatternVal := type.meta["pattern"]
      typePattern := typePatternVal as Str
      if (typePatternVal != null && typePattern == null)
        throw UnsupportedErr("Invalid pattern metadata for ${type.qname}: ${typePatternVal.typeof}")
      if (pattern == typePattern) return patterns
    }
    if (!added.containsKey(pattern))
    {
      added[pattern] = true
      patterns.add(pattern)
    }
    return patterns
  }

  private Void addScalarPattern(Str[] patterns, Str:Bool added, Str owner, Obj? val)
  {
    if (val == null) return
    pattern := val as Str
      ?: throw UnsupportedErr("Invalid pattern metadata for ${owner}: ${val.typeof}")
    if (added.containsKey(pattern)) return
    added[pattern] = true
    patterns.add(pattern)
  }

  private Bool isBuiltInScalar(Str qname)
  {
    qname == "sys::Str"     || qname == "sys::Number" ||
    qname == "sys::Int"     || qname == "sys::Bool"   ||
    qname == "sys::Date"    || qname == "sys::Time"   ||
    qname == "sys::DateTime"|| qname == "sys::Uri"    ||
    qname == "sys::TimeZone"
  }

  private Str? numericMeta(Spec slot, Str name)
  {
    val := slot.meta[name]
    if (val == null) return null
    if (val is Int) return val.toStr
    if (val is Float)
    {
      float := (Float)val
      if (float.isNaN || float == Float.posInf || float == Float.negInf)
        throw UnsupportedErr("Invalid numeric metadata for ${slot.qname}.${name}: non-finite Float")
      return float.toStr
    }
    num := val as Number
    if (num == null)
      throw UnsupportedErr("Invalid numeric metadata for ${slot.qname}.${name}: ${val.typeof}")
    if (num.unit != null)
      throw UnsupportedErr("Invalid numeric metadata for ${slot.qname}.${name}: unit-bearing Number")
    if (num.isSpecial)
      throw UnsupportedErr("Invalid numeric metadata for ${slot.qname}.${name}: non-finite Number")
    return num.toStr
  }

  private Str? quantityNumericMeta(Spec slot, Str name)
  {
    val := slot.meta[name]
    if (val == null) return null
    if (val is Int) return val.toStr
    if (val is Float)
    {
      float := (Float)val
      if (float.isNaN || float == Float.posInf || float == Float.negInf)
        throw UnsupportedErr("Invalid numeric metadata for ${slot.qname}.${name}: non-finite Float")
      return float.toStr
    }
    num := val as Number
    if (num == null)
      throw UnsupportedErr("Invalid numeric metadata for ${slot.qname}.${name}: ${val.typeof}")
    if (num.isSpecial)
      throw UnsupportedErr("Invalid numeric metadata for ${slot.qname}.${name}: non-finite Number")
    return num.isInt ? num.toInt.toStr : num.toFloat.toStr
  }

  private Int? intMeta(Spec slot, Str name)
  {
    val := slot.meta[name]
    if (val == null) return null
    if (val is Int) return val
    num := val as Number
    if (num == null)
      throw UnsupportedErr("Invalid integer metadata for ${slot.qname}.${name}: ${val.typeof}")
    if (num.unit != null)
      throw UnsupportedErr("Invalid integer metadata for ${slot.qname}.${name}: unit-bearing Number")
    if (!num.isInt)
      throw UnsupportedErr("Invalid integer metadata for ${slot.qname}.${name}: non-integer Number")
    return num.toInt
  }

  ** Convert only runtime values with a defined scalar mapping. This avoids
  ** accepting an arbitrary object merely because its `toStr` happens to look
  ** like a legal lexical form for the requested RDF datatype.
  private This typedLiteral(Obj val, Spec type, Str context)
  {
    datatype := scalarDatatype(type)
    lexical := scalarLexical(val, type, context)
    return literal(lexical).w("^^").w(datatype)
  }

  private Str scalarLexical(Obj val, Spec type, Str context)
  {
    qname := type.qname
    wrapped := val as Scalar
    if (wrapped != null)
    {
      if (wrapped.qname != qname)
        throw UnsupportedErr("Expected ${qname} for ${context}, not ${wrapped.qname}")
      val = wrapped.val
    }

    if (qname == "sys::Str" || (type.isScalar && type.lib.name != "sys"))
      return val as Str ?: throw UnsupportedErr("Expected Str for ${context}, not ${val.typeof}")

    if (qname == "sys::Int")
    {
      if (val is Int) return val.toStr
      num := val as Number
      if (num == null || num.unit != null || num.isSpecial || !num.isInt)
        throw UnsupportedErr("Expected integer value for ${context}, not ${val.typeof}")
      return num.toInt.toStr
    }

    if (qname == "sys::Number")
    {
      if (val is Int) return val.toStr
      num := val as Number
      if (num == null || num.unit != null || num.isSpecial)
        throw UnsupportedErr("Expected finite unitless Number for ${context}, not ${val.typeof}")
      return num.isInt ? num.toInt.toStr : num.toFloat.toStr
    }

    if (qname == "sys::Bool")
    {
      if (val is Bool) return val.toStr
      str := val as Str
      if (str == "true" || str == "false") return str
      throw UnsupportedErr("Expected Bool for ${context}, not ${val.typeof}")
    }

    if (qname == "sys::Date")
    {
      if (val is Date) return val.toStr
      str := val as Str
      if (str != null && Date.fromStr(str, false) != null) return str
      throw UnsupportedErr("Expected Date for ${context}, not ${val.typeof}")
    }

    if (qname == "sys::Time")
    {
      if (val is Time) return val.toStr
      str := val as Str
      if (str != null && Time.fromStr(str, false) != null) return str
      throw UnsupportedErr("Expected Time for ${context}, not ${val.typeof}")
    }

    if (qname == "sys::DateTime")
    {
      if (val is DateTime) return val.toStr
      str := val as Str
      if (str != null && DateTime.fromStr(str, false) != null) return str
      throw UnsupportedErr("Expected DateTime for ${context}, not ${val.typeof}")
    }

    if (qname == "sys::Uri")
    {
      if (val is Uri) return val.toStr
      str := val as Str
      if (str != null && Uri.fromStr(str, false) != null) return str
      throw UnsupportedErr("Expected Uri for ${context}, not ${val.typeof}")
    }

    if (qname == "sys::TimeZone")
    {
      if (val is TimeZone) return val.toStr
      str := val as Str
      if (str != null && TimeZone.fromStr(str, false) != null) return str
      throw UnsupportedErr("Expected TimeZone for ${context}, not ${val.typeof}")
    }

    throw UnsupportedErr("RDF scalar value mapping not supported for ${context} of ${qname}")
  }

  private This global(Spec x)
  {
    return prop(x)
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
    if (x.base != null && !x.base.isType)
      w("  rdfs:subPropertyOf ").qname(x.base.qname).w(" ;").nl
    labelAndDoc(x)
    w(".").nl
    return this
  }

  ** Sealed is a schema validity rule rather than an RDF statement. Xeto's
  ** compiler normally prevents this state, but an exporter must still fail
  ** closed if handed a namespace assembled by another implementation.
  private Void validateSealedNamespace(Lib lib)
  {
    candidates := Str:Spec[:]
    ns.eachType |candidate| { candidates[candidate.qname] = candidate }
    lib.types.each |candidate| { candidates[candidate.qname] = candidate }
    candidates.each |candidate|
    {
      base := candidate.base
      if (base == null) return
      if (base.lib.name != candidate.lib.name && base.meta.has("sealed"))
        throw UnsupportedErr("External subtype ${candidate.qname} extends sealed spec ${base.qname}")
    }
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

    spec := instanceSpec(instance)
    this.id(id).nl
    w("  a ").w(isSys ? ":Entity" : "sys:Entity").w(", ").qname(spec.qname).w(" ;").nl
    instanceMembers(instance, spec, "  ")
    spec.slots.each |s| { if (s.isChoice) instanceChoice(instance, s) }
    w(".").nl
    return this
  }

  private Void instanceMembers(Dict instance, Spec spec, Str indent)
  {
    choiceMarkers := Str:Bool[:]
    spec.slots.each |slot|
    {
      if (!slot.isChoice) return
      instanceChoiceSelections(instance, slot).each |selection|
      {
        selection.slots.each |marker|
        {
          if (marker.isMarker) choiceMarkers[marker.name] = true
        }
      }
    }

    members := ns.reflect(instance, spec).members.dup
    members.sort |a, b| { instanceProperty(spec, a) <=> instanceProperty(spec, b) }
    members.each |member|
    {
      if (member.name == "id" || member.name == "spec" || member.isChoice) return
      if (choiceMarkers.containsKey(member.name)) return

      val := member.val
      slot := member.spec
      if (val == null && slot.isSlot && slot.metaOwn.has("val")) val = slot.metaOwn["val"]
      if (val == null) return

      property := instanceProperty(spec, member)
      // Parameterized list metadata such as `of` and size constraints lives
      // on the slot spec, not the shared sys::List type.
      type := slot.isSlot && slot.type.isList ? slot : (slot.isSlot ? slot.type : slot)
      instanceMember(property, type, val, indent)
    }
  }

  private Str instanceProperty(Spec parent, ReflectMember member)
  {
    spec := member.spec
    return spec.isSlot ? spec.qname : "${parent.qname}.${member.name}"
  }

  private Void instanceMember(Str property, Spec type, Obj val, Str indent)
  {
    if (val == Marker.val)
    {
      w(indent).w(isSys ? ":hasMarker" : "sys:hasMarker").w(" ").qname(property).w(" ;").nl
      return
    }

    if (type.isRef)
    {
      ref := val as Ref ?: throw UnsupportedErr("Expected Ref for ${property}, not ${val.typeof}")
      w(indent).qname(property).w(" ").id(ref).w(" ;").nl
      return
    }

    if (type.isMultiRef)
    {
      instanceMultiRef(property, val, indent)
      return
    }

    if (type.qname == "sys::TimeZone")
    {
      w(indent).qname(property).w(" ")
      typedLiteral(val, type, property)
      w(" ;").nl
      return
    }

    if (type.isEnum)
    {
      if (type.qname == "sys::Unit")
      {
        unit := val as Unit ?: throw UnsupportedErr("Expected Unit for ${property}, not ${val.typeof}")
        w(indent).qname(property).w(" ").w(qudt.unit(unit)).w(" ;").nl
        return
      }
      if (type.qname == "sys::UnitQuantity")
        throw UnsupportedErr("RDF UnitQuantity mapping not supported for ${property} of ${type.qname}")
      scalar := val as Scalar
        ?: throw UnsupportedErr("Expected ${type.qname} enum value for ${property}, not ${val.typeof}")
      if (scalar.qname != type.qname)
        throw UnsupportedErr("Expected ${type.qname} enum value for ${property}, not ${scalar.qname}")
      key := scalar.val
      if (type.enum.spec(key, false) == null)
        throw UnsupportedErr("Invalid ${type.qname} value: ${key}")
      w(indent).qname(property).w(" ").literal(key).w("^^xsd:string ;").nl
      return
    }

    if (type.isList)
    {
      instanceList(property, type, val, indent)
      return
    }

    if (type.isDict)
    {
      nested := val as Dict ?: throw UnsupportedErr("Expected Dict for ${property}, not ${val.typeof}")
      instanceNested(property, nested, indent)
      return
    }

    if (type.isScalar && !type.isRef)
    {
      num := val as Number
      if (num != null && num.unit != null)
      {
        instanceQuantityValue(property, num, indent)
        return
      }
      w(indent).qname(property).w(" ")
      typedLiteral(val, type, property)
      w(" ;").nl
      return
    }

    if (type.qname == "sys::Obj")
    {
      actual := ns.specOf(val, false)
      if (actual == null || actual.qname == "sys::Obj")
        throw UnsupportedErr("RDF Obj value type is ambiguous for ${property}: ${val.typeof}")
      instanceMember(property, actual, val, indent)
      return
    }

    throw UnsupportedErr("RDF instance value mapping not supported for ${property} of ${type.qname}")
  }

  private Void instanceQuantityValue(Str property, Number num, Str indent)
  {
    unit := num.unit ?: throw UnsupportedErr("Expected unit-bearing Number for ${property}")
    if (num.isSpecial)
      throw UnsupportedErr("RDF decimal quantity value must be finite for ${property}")
    value := num.isInt ? num.toInt.toStr : num.toFloat.toStr
    w(indent).qname(property).w(" [").nl
    w(indent).w("  a qudt:QuantityValue ;").nl
    w(indent).w("  qudt:numericValue ").literal(value).w("^^xsd:decimal ;").nl
    w(indent).w("  qudt:unit ").w(qudt.unit(unit)).nl
    w(indent).w("] ;").nl
  }

  private Void instanceMultiRef(Str property, Obj val, Str indent)
  {
    if (val is Ref)
    {
      instanceRefValue(property, val, indent)
      return
    }

    refs := val as List
    if (refs != null)
    {
      refs.each |item|
      {
        ref := item as Ref ?: throw UnsupportedErr("Expected Ref item for ${property}, not ${item.typeof}")
        instanceRefValue(property, ref, indent)
      }
      return
    }

    // Source-declared MultiRef blocks remain Dicts in Lib.instances; their
    // generated slots carry the same refs returned by instantiated Ref[].
    dict := val as Dict ?: throw UnsupportedErr("Expected Ref, Ref[], or MultiRef Dict for ${property}, not ${val.typeof}")
    dict.each |item, name|
    {
      if (name == "id" || name == "spec") return
      ref := item as Ref ?: throw UnsupportedErr("Expected Ref item for ${property}.${name}, not ${item.typeof}")
      instanceRefValue(property, ref, indent)
    }
  }

  private Void instanceRefValue(Str property, Ref ref, Str indent)
  {
    w(indent).qname(property).w(" ").id(ref).w(" ;").nl
  }

  private Void instanceNested(Str property, Dict nested, Str indent)
  {
    nestedId := nested["id"] as Ref
    if (nestedId != null)
    {
      w(indent).qname(property).w(" ").id(nestedId).w(" ;").nl
      return
    }

    nestedSpec := instanceSpec(nested)
    w(indent).qname(property).w(" [").nl
    w(indent).w("  a ").qname(nestedSpec.qname).w(" ;").nl
    instanceMembers(nested, nestedSpec, indent + "  ")
    w(indent).w("] ;").nl
  }

  private Void instanceList(Str property, Spec listType, Obj val, Str indent)
  {
    items := val as List ?: throw UnsupportedErr("Expected List for ${property}, not ${val.typeof}")
    of := listType.of(false)
    validateListItemType(listType, of)

    w(indent).qname(property).w(" (")
    if (!items.isEmpty) nl
    items.each |item|
    {
      w(indent).w("  ")
      instanceListItem(property, of, item, indent + "  ")
      nl
    }
    if (!items.isEmpty) w(indent)
    w(") ;").nl
  }

  private Void instanceListItem(Str property, Spec? declaredType, Obj item, Str indent)
  {
    type := declaredType ?: ns.specOf(item, false)
    if (type == null)
      throw UnsupportedErr("RDF list item type not known for ${property}: ${item.typeof}")
    validateListItemType(type, type)

    if (type.isScalar)
    {
      num := item as Number
      if (num != null && num.unit != null)
        throw UnsupportedErr("RDF quantity list item mapping not supported for ${property}")
      typedLiteral(item, type, property)
      return
    }

    if (type.isDict)
    {
      nested := item as Dict ?: throw UnsupportedErr("Expected Dict item for ${property}, not ${item.typeof}")
      nestedId := nested["id"] as Ref
      if (nestedId != null)
      {
        id(nestedId)
        return
      }

      nestedSpec := instanceSpec(nested)
      w("[").nl
      w(indent).w("  a ").qname(nestedSpec.qname).w(" ;").nl
      instanceMembers(nested, nestedSpec, indent + "  ")
      w(indent).w("]")
      return
    }

    throw UnsupportedErr("RDF list item mapping not supported for ${property}: ${type.qname}")
  }

  private Void instanceChoice(Dict instance, Spec slot)
  {
    selected := instanceChoiceSelections(instance, slot)
    selected.each |x|
    {
      w("  ").qname(slot.qname).w(" ").qname(x.qname).w(" ;").nl
    }
  }

  private Spec[] instanceChoiceSelections(Dict instance, Spec slot)
  {
    selected := choiceMembers(slot).findAll |Spec candidate->Bool|
    {
      markers := candidate.slots.list.findAll |Spec memberSlot->Bool| { memberSlot.isMarker }
      return markers.all |Spec marker->Bool| { instance.has(marker.name) }
    }
    return XetoUtil.excludeSupertypes(selected)
  }

  private Spec instanceSpec(Dict instance)
  {
    spec := ns.specOf(instance, false)
    if (spec != null) return spec

    specRef := instance["spec"] as Ref
    qname := specRef?.toStr
    lib := curLib
    if (qname != null && lib != null && qname.startsWith("${lib.name}::"))
      return lib.spec(qname[qname.index("::") + 2..-1])

    throw UnknownSpecErr(qname ?: instance.typeof.qname)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Lib? curLib
  private RdfQudtMappings? qudtRef

  private RdfQudtMappings qudt()
  {
    qudtRef ?: (qudtRef = RdfQudtMappings.load(ns))
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
    validateQName(qname, "RDF name")
    return w(qnameToUri(qname))
  }

  ** Output Xeto lib::name qualified name
  private This id(Ref id)
  {
    qname := id.toStr
    sep := qname.index("::")
    if (sep == null || sep == 0 || sep + 2 >= qname.size || qname.index("::", sep + 2) != null)
      throw UnsupportedErr("RDF instance id or reference is not library-qualified: ${qname}")

    libName := qname[0..<sep]
    local := qname[sep + 2..-1]
    lib := curLib?.name == libName ? curLib : ns.lib(libName, false)
    if (lib == null)
      throw UnsupportedErr("RDF instance id or reference uses unknown library ${libName}: ${qname}")

    // Keep ordinary Xeto qnames readable. Ref ids may also contain schemes
    // such as `op:name` and `filetype:json`; those are legal RDF fragments
    // but not legal prefixed names, so write their full versioned IRI.
    if (!local.contains(":") && !local.contains(" ") && !local.contains("\t") &&
        !local.contains("\r") && !local.contains("\n") && !local.contains("<") &&
        !local.contains(">") && !local.contains("\"") && !local.contains("\\"))
      return w(libName).w(":").w(local)

    encoded := Uri.encodeToken(local, Uri.sectionFrag)
    return w("<").w(libUri(lib)).w("#").w(encoded).w(">")
  }

  private Void validateQName(Str qname, Str kind)
  {
    sep := qname.index("::")
    invalid := sep == null || sep == 0 || sep + 2 >= qname.size ||
      qname.index("::", sep + 2) != null || qname[sep + 2..-1].contains(":") ||
      qname.contains(" ") || qname.contains("\t") || qname.contains("\r") ||
      qname.contains("\n") || qname.contains("<") || qname.contains(">") ||
      qname.contains("\"") || qname.contains("\\")
    if (invalid) throw UnsupportedErr("${kind} is not QName-compatible: ${qname}")
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
  private static const Regex queryPathRef := Regex<|(?:[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*::[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*)|>
}
