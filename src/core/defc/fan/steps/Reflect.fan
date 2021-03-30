//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2019  Brian Frank  Creation
//

using haystack

**
** Reflect parses defs from Fantom types and slots using reflection
**
internal class Reflect : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    eachLib |lib|
    {
      try
        reflectLib(lib)
      catch (Err e)
        err("Cannot reflect lib: $lib.name", lib.loc, e)
    }
  }

  private Void reflectLib(CLib lib)
  {
    lib.input.scanReflects(compiler).each |ri|
    {
      reflectInput(lib, ri)
    }
  }

  private Void reflectInput(CLib lib, ReflectInput ri)
  {
    // force complete reflection to avoid race conditions
    try ri.type->finish; catch (Err e) e.trace

    // reflect slots
    reflectType(lib, ri)
    reflectFields(lib, ri)
    reflectMethods(lib, ri)
  }

//////////////////////////////////////////////////////////////////////////
// Type
//////////////////////////////////////////////////////////////////////////

  private Void reflectType(CLib lib, ReflectInput ri)
  {
    facetType := ri.typeFacet
    if (facetType == null) return

    type := ri.type
    facet := type.facet(facetType, false) as Define
    if (facet == null) return null

     loc     := CLoc(type.qname)
     symbol  := ri.toSymbol(null)
     csymbol := parseSymbol("def", symbol, loc)

     // map to meta
     acc := Str:Obj[:]
     acc["def"] = symbol
     dict := typeToMeta(acc, symbol, ri, facet)

     // create cdef
     def := addDef(loc, lib, csymbol, dict)

     // callback to input
     if (def != null) ri.onDef(null, def)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Void reflectFields(CLib lib, ReflectInput ri)
  {
    facetType := ri.fieldFacet
    if (facetType == null) return
    ri.type.fields.each |field|
    {
      if (field.parent !== ri.type) return
      facet := field.facet(facetType, false)
      if (facet != null) reflectField(lib, ri, field, (Define)facet)
    }
  }

  private Void reflectField(CLib lib, ReflectInput ri, Field field, Define facet)
  {
    loc     := CLoc(field.qname)
    symbol  := ri.toSymbol(field)
    csymbol := parseSymbol("def", symbol, loc)
    type    := typeToDef(field.type)

    // map to meta
    acc := Str:Obj[:]
    acc["def"] = symbol
    acc["is"]  = type
    dict := slotToMeta(acc, symbol, ri, field, facet)

    // create cdef
    def := addDef(loc, lib, csymbol, dict)

    // callback to input
    if (def != null) ri.onDef(field, def)
  }

//////////////////////////////////////////////////////////////////////////
// Methods
//////////////////////////////////////////////////////////////////////////

  private Void reflectMethods(CLib lib, ReflectInput ri)
  {
    facetType := ri.methodFacet
    if (facetType == null) return
    ri.type.methods.each |method|
    {
      if (method.parent !== ri.type) return
      facet := method.facet(facetType, false)
      if (facet != null) reflectMethod(lib, ri, method, (Define)facet)
    }
  }

  private Void reflectMethod(CLib lib, ReflectInput ri, Method method, Define facet)
  {
    loc     := CLoc(method.qname)
    symbol  := ri.toSymbol(method)
    csymbol := parseSymbol("def", symbol, loc)

    // map to meta
    acc := Str:Obj[:]
    acc["def"] = symbol
    dict := slotToMeta(acc, symbol, ri, method, facet)

    // create cdef
    def := addDef(loc, lib, csymbol, dict)

    // callback to input
    if (def != null) ri.onDef(method, def)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Dict typeToMeta(Str:Obj acc, Symbol symbol, ReflectInput ri, Define facet)
  {
    type := ri.type
    if (type.hasFacet(Deprecated#)) acc["deprecated"] = Marker.val
    if (type.hasFacet(NoDoc#)) acc["nodoc"] = Marker.val
    if (type.doc != null) acc["doc"] = type.doc
    facetToMeta(acc, facet)
    ri.addMeta(symbol, acc)
    return Etc.makeDict(acc)
  }

  private Dict slotToMeta(Str:Obj acc, Symbol symbol, ReflectInput ri, Slot slot, Define facet)
  {
    if (slot.hasFacet(Deprecated#)) acc["deprecated"] = Marker.val
    if (slot.hasFacet(NoDoc#)) acc["nodoc"] = Marker.val
    if (slot.doc != null) acc["doc"] = slot.doc
    facetToMeta(acc, facet)
    ri.addMeta(symbol, acc)
    return Etc.makeDict(acc)
  }

  private Void facetToMeta(Str:Obj acc, Define facet)
  {
    facet.decode |n, v|
    {
      if (acc[n] == null) acc[n] = v
    }
  }

  private Symbol typeToDef(Type type)
  {
    if (type === Int#) return intSymbol
    if (type == Duration#) return durationSymbol
    return Kind.fromType(type).defSymbol
  }

  private const Symbol intSymbol := Symbol("int")
  private const Symbol durationSymbol := Symbol("duration")

}

