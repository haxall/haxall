//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jan 2019  Matthew Giannini  Creation
//


**
** Writes RDF in [Turtle]`https://www.w3.org/TR/turtle/` format
**
@Js class TurtleOutStream : RdfOutStream
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(OutStream out) : super(out)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Iri xsdNs := Iri("http://www.w3.org/2001/XMLSchema#")
  private static const Iri rdfType := Iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")

//////////////////////////////////////////////////////////////////////////
// State
//////////////////////////////////////////////////////////////////////////

  ** The subject from the previous statement
  private Iri? prevSubj := null

  ** The predicate from the previous statement
  private Iri? prevPred := null

  override This finish()
  {
    if (prevSubj != null) writeChars(" .").nl
    this.prevSubj = null
    this.prevPred = null
    return flush
  }

//////////////////////////////////////////////////////////////////////////
// RdfOutStream
//////////////////////////////////////////////////////////////////////////

  protected override This onSetNs(Str prefix, Str namespace)
  {
    finish
      .writeChars("@prefix ${prefix}: <${namespace}> .").nl
  }

  override This writeStmt(Iri subject, Iri predicate, Obj object, Obj? typeOrLocale := null)
  {
    // always work with normalized IRIs
    subject   = subject.fullIri(nsMap)
    predicate = predicate.fullIri(nsMap)
    if (object is Iri) object = (object as Iri).fullIri(nsMap)

    newSubj := this.prevSubj != subject
    newPred := true
    if (newSubj)
    {
      // finish previous statement and write new unterminated statement
      finish.nl
        .writePreOrIri(subject).writeChar(' ')
        .writePredIri(predicate).writeChar(' ')
    }
    else
    {
      // Not a new subject
      // 1) If new predicate, terminate prev predicate, indent and write predicate
      // 2) If not a new predicate, terminate prev object and indent
      newPred = this.prevPred != predicate
      if (newPred)
        writeChars(" ;").nl.tab.writePredIri(predicate).writeChar(' ')
      else
        writeChar(',').nl.tab(2)
    }

    // Always write the object
    writeObject(object, typeOrLocale)

    // update state
    this.prevSubj = subject
    this.prevPred = predicate

    return this
  }

  private This writePredIri(Iri normIri)
  {
    rdfType == normIri ? writeChar('a') : writePreOrIri(normIri)
  }

  ** Writes the prefixed turtle notation for the given normalized IRI
  ** if we have a matching namespace prefix. Otherwise, it writes the full IRI.
  ** All IRIs and blank nodes should be written using this method.
  internal This writePreOrIri(Iri normIri)
  {
    preOrIri := normIri.prefixIri(nsMap)
    if (normIri.isBlankNode)
      writeChars(validateBlankNode(normIri).toStr)
    else if (preOrIri == normIri)
      writeChar('<').writeChars(preOrIri.toStr).writeChar('>')
    else
      writeChars(preOrIri.toStr)
    return this
  }

  internal This writeObject(Obj object, Obj? typeOrLocale)
  {
    switch (object.typeof)
    {
      case Iri#:  return writePreOrIri(object)
      case Str#:  writeStr(object, typeOrLocale as Locale)
      case Bool#:
      case Int#:
      case Float#:
      case Decimal#:
        // fall-through: can use Fantom Str encoding for literal
        return writeChars(object.toStr)
      case Buf#:      return writeXsd(object, Xsd.hexBinary)
      case Date#:     return writeXsd(object, Xsd.date)
      case Time#:     return writeXsd(object, Xsd.time)
      case DateTime#: return writeXsd(object, Xsd.dateTime)
      case Uri#:      return writeXsd(object, Xsd.anyURI)
      default:
        writeStr(object.toStr)
    }

    // only get this far if object was a Str or custom data-type

    // custom data-type
    if (typeOrLocale is Iri)
    {
      type := (typeOrLocale as Iri).fullIri(nsMap)
      writeChars("^^").writePreOrIri(type)
    }

    return this
  }

  internal This writeStr(Str str, Locale? locale := null)
  {
    writeRdfStr(str)
    if (locale != null) writeChars(locale.toStr)
    return this
  }

  internal This writeXsd(Obj object, Iri type)
  {
    writeChar('"').writeChars(Xsd.encode(object)).writeChar('"').writeType(type)
  }

  internal This writeType(Iri typeIri)
  {
    writeChars("^^").writePreOrIri(typeIri)
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Return true if the given string is a legal label name for a blank node.
  **
  ** The characters in the label are built upon PN_CHARS_BASE, liberalized as follows
  **   - The characters '_' and digits may appear anywhere in a blank node label.
  **   - The character '.' may appear anywhere except the first or last character.
  **   - The characters '-', U+00B7, U+0300 to U+036F and U+203F to U+2040 are permitted
  **     anywhere except the first character.
  **
  ** pre>
  ** PN_CHARS_BASE ::= [A-Z] | [a-z] | [#x00C0-#x00D6] | [#x00D8-#x00F6]
  ** | [#x00F8-#x02FF] | [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D]
  ** | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF]
  ** | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
  ** <pre
  **
  ** See `https://www.w3.org/TR/turtle/#BNodes`
  static Bool isLabelName(Str name)
  {
    if (name.isEmpty) return false
    c1 := name[0]
    cn := name[-1]
    if (c1 == '.' || cn == '.') return false
    if (c1 == '.' || c1 == 0xB7 || (0x300 <= c1 && c1 <= 0x036F) || (0x203F <= c1 && c1 <= 0x2040) )return false
     // TODO: this is a simplification of PN_CHARS_BASE to just ASCII for now
    return name.all |ch|
    {
      ch.isAlphaNum || ch == '_' || ch == '.' || ch == '-'
    }

    return true
  }

  ** Validate the blank node and return it if it is valid; otherwise raise `ArgErr`.
  static Iri validateBlankNode(Iri iri)
  {
    if (!iri.isBlankNode)       throw ArgErr("Not a blank node: $iri")
    if (!isLabelName(iri.name)) throw ArgErr("Invalid label name for blank node: $iri")
    return iri
  }

}