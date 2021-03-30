//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jan 2019  Matthew Giannini  Creation
//

**
** Writes RDF in [JSON-LD]`https://w3c.github.io/json-ld-syntax/` format
**
@Js class JsonLdOutStream : RdfOutStream
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(OutStream out) : super(out)
  {
    this.writeChar('{').nl
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private [Str:Obj][] graph := [Str:Obj][,]

//////////////////////////////////////////////////////////////////////////
// State
//////////////////////////////////////////////////////////////////////////

  ** Have we already written the context
  private Bool wroteContext := false

  ** Writes the context object if it has not been written yet
  private This finishContext()
  {
    if (wroteContext) return this

    // write the context
    writeChars(JsonLD.context.toCode).writeChar(':').writeMap(nsMap)
    writeChar(',').nl

    // start the graph
    writeChars(JsonLD.graph.toCode).writeChars(":[")

    // mark that we've done this
    wroteContext = true
    return this
  }

  ** The current subject
  private [Str:Obj] curSubj := [:] { ordered = true }
  private Bool firstSubj := true

  private This finishSubj()
  {
    if (!curSubj.isEmpty)
    {
      if (!firstSubj) writeChar(',').nl; else firstSubj = false
      writeMap(curSubj)
      this.curSubj = newMap
    }
    return this
  }

  override This finish()
  {
    finishContext.finishSubj.writeChars("]}").flush
  }

//////////////////////////////////////////////////////////////////////////
// RdfOutStream
//////////////////////////////////////////////////////////////////////////

  override protected This onSetNs(Str prefix, Str namespace)
  {
    if (wroteContext) throw Err("Cannot set namespace: statements have already been written")
    return this
  }

  override This writeStmt(Iri subject, Iri predicate, Obj object, Obj? typeOrLocale := null)
  {
    finishContext

    subject = subject.prefixIri(nsMap)
    predicate = predicate.prefixIri(nsMap)
    if (object is Iri) object = (object as Iri).prefixIri(nsMap)

    subjId  := subject.toStr
    newSubj := curSubj[JsonLD.id] != subjId
    if (newSubj)
    {
      finishSubj
      curSubj[JsonLD.id] = subjId
    }

    predKey := predicate.toStr
    predVal := curSubj[predKey]

    obj := encObj(object, typeOrLocale)

    if (predVal == null)
      curSubj[predKey] = obj
    else if (predVal is List)
      (predVal as List).add(obj)
    else
      curSubj[predKey] = Obj[predVal, obj]

    return this
  }

  private This writeSubj(Iri subj)
  {
    curSubj[JsonLD.id] = subj.toStr
    return this
  }

  private This writeVal(Obj val)
  {
    if (val is Map)  return writeMap(val)
    if (val is List) return writeList(val)
    return writeScalar(val)
  }

  private This writeMap([Str:Obj] m)
  {
    if (m.isEmpty) return writeChars("{}")

    writeChar('{')
    first := true
    m.each |val, key|
    {
      if (!first) writeChar(','); else first = false
      writeChars(key.toCode).writeChar(':').writeVal(val)
    }
    return writeChar('}')
  }

  private This writeList(List arr)
  {
    writeChar('[')
    arr.each |val,i|
    {
      if (i > 0) writeChar(',')
      writeVal(val)
    }
    return writeChar(']')
  }

  private This writeScalar(Obj val)
  {
    switch (val.typeof)
    {
      case Bool#:
      case Int#:
      case Float#:
      case Decimal#:
        // fall-through: can use Str encoding
        return writeChars(val.toStr)
      default:
        return writeRdfStr(val.toStr)
    }
  }

  private Obj encObj(Obj object, Obj? typeOrLocale)
  {
    switch (object.typeof)
    {
      case Iri#: return newMap.set(JsonLD.id, object.toStr)
      case Bool#:
      case Int#:
      case Float#:
      case Decimal#:
        // fall-through: can use Fantom type as encoding
        return object
      case Buf#:      return typedVal(object, Xsd.hexBinary)
      case Date#:     return typedVal(object, Xsd.date)
      case Time#:     return typedVal(object, Xsd.time)
      case DateTime#: return typedVal(object, Xsd.dateTime)
      case Uri#:      return typedVal(object, Xsd.anyURI)
    }

    // encode as a Str
    locale := typeOrLocale as Locale
    if (locale != null)
    {
      return newMap.set(JsonLD.value, object.toStr)
                   .set(JsonLD.lang, locale.toStr)
    }
    else if (typeOrLocale is Iri)
    {
      return typedVal(object, typeOrLocale)
    }
    else
    {
      return object.toStr
    }
  }

  private Map typedVal(Obj val, Iri type)
  {
    newMap.set(JsonLD.value, Xsd.encode(val))
          .set(JsonLD.type, type.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private [Str:Obj] newMap() { [Str:Obj][:] { ordered = true } }
}

@Js internal abstract class JsonLD
{
  static const Str context := "@context"
  static const Str graph   := "@graph"
  static const Str id      := "@id"
  static const Str lang    := "@language"
  static const Str type    := "@type"
  static const Str value   := "@value"
}