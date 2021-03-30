//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2019  Matthew Giannini  Creation
//

**
** An `OutStream` for writing RDF statements.
**
@Js abstract class RdfOutStream : OutStream
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Construct by wrapping the given output stream.
  new make(OutStream out) : super(out)
  {
    this.setNs("rdf",  "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
        .setNs("rdfs", "http://www.w3.org/2000/01/rdf-schema#")
        .setNs("xsd",  Xsd.ns)
  }

//////////////////////////////////////////////////////////////////////////
// Namespaces
//////////////////////////////////////////////////////////////////////////

  protected [Str:Str] nsMap := [:] { ordered = true }
  {
    private set
  }

  ** Associate a prefix with a namespace. If the prefix is already mapped to a different
  ** namespace, then throw `ArgErr`.
  **
  ** If an RDF export format doesn't support namesapce prefixes, this is a no-op. The
  ** behavior of the RDF out stream is undefined if you call this method of you have
  ** called `writeStmt`, so you should set all your namespace prefixes prior to writing
  ** statements.
  **
  ** Return this.
  **
  **   out.setNs("rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
  This setNs(Str prefix, Str namespace)
  {
    cur := nsMap[prefix]
    if (cur == null)
    {
      nsMap[prefix] = namespace
      onSetNs(prefix, namespace)
    }
    else if (cur != namespace)
      throw ArgErr("Cannot map ${prefix} to ${namespace}. Already mapped to: ${cur}")

    return this
  }

  ** sub-class hook when a new namespace prefix is set
  protected virtual This onSetNs(Str prefix, Str namespace) { return this }

//////////////////////////////////////////////////////////////////////////
// RdfOutStream
//////////////////////////////////////////////////////////////////////////

  ** There is no guarantee that any (or all) bytes are written to the output stream
  ** until this method is called. Therefore, when you are finished writing
  ** all RDF statements, you **must** call this method to allow the implementation
  ** a chance to finish any pending writes.
  **
  ** This method should only be invoked once when you are done writing all statements.
  ** The behavior is undefined if you invoke this method multiple times.
  **
  ** Closing this output stream will always call finish first.
  virtual This finish() { return this }

  override Bool close()
  {
    finish
    return super.close
  }

  ** Write the given RDF statement.
  **
  ** All writers should handle mapping the following Fantom types to well-defined
  ** RDF data types without requiring a type for 'typeOrLocale' parameter.
  **  - `Str` => 'xsd::string'
  **  - `Uri` => 'xsd::anyURI'
  **  - `Num` => 'xsd::integer' | 'xsd::decimal' | 'xsd::double'
  **  - `Bool` => 'xsd::boolean'
  **  - `Date` => 'xsd::date'
  **  - `Time` => 'xsd::time'
  **  - `DateTime` => 'xsd::dateTime'
  **  - `Buf` => 'xsd::hexBinary'
  **
  ** A non-null 'typeOrLocale' parameter is used as follows:
  **  - An `Iri` indicates the data type of the 'object' parameter. In this
  **  case the 'object' will **always** be encoded as a string.
  **  - A `Locale` indicates the language the 'object' is in. In this
  **  case the 'object' *should* be a string.
  **
  ** Not all export formats can make use of the information in 'typeOrLocale'
  ** parameter, but you should always provide it if available.
  **
  ** Return this.
  abstract This writeStmt(Iri subject, Iri predicate, Obj object, Obj? typeOrLocale := null)

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Write a Str with unicode characters escaped.
  protected This writeRdfStr(Str str)
  {
    writeChar('"')
    str.each |char|
    {
      if (char <= 0x7f)
      {
        switch (char)
        {
          case '\b': writeChar('\\').writeChar('b')
          case '\f': writeChar('\\').writeChar('f')
          case '\n': writeChar('\\').writeChar('n')
          case '\r': writeChar('\\').writeChar('r')
          case '\t': writeChar('\\').writeChar('t')
          case '\\': writeChar('\\').writeChar('\\')
          case '"':  writeChar('\\').writeChar('"')
          default: writeChar(char)
        }
      }
      else
      {
        writeChar('\\').writeChar('u').print(char.toHex(4))
      }
    }
    return writeChar('"')
  }

  protected This nl()
  {
    writeChar('\n')
  }

  protected This tab(Int num := 1, Int spaces := 4)
  {
    (num * spaces).times { writeChar(' ') }
    return this
  }
}

@NoDoc @Js mixin Xsd
{
  static const Str ns := "http://www.w3.org/2001/XMLSchema#"
  static const Iri string    := Iri("${ns}string")
  static const Iri float     := Iri("${ns}float")
  static const Iri double    := Iri("${ns}double")
  static const Iri boolean   := Iri("${ns}boolean")
  static const Iri anyURI    := Iri("${ns}anyURI")
  static const Iri hexBinary := Iri("${ns}hexBinary")
  static const Iri date      := Iri("${ns}date")
  static const Iri time      := Iri("${ns}time")
  static const Iri dateTime  := Iri("${ns}dateTime")

  static Str encode(Obj obj)
  {
    switch (obj.typeof)
    {
      case Buf#:      return (obj as Buf).toHex
      case Date#:     return obj.toStr
      case Time#:     return obj.toStr
      case DateTime#: return (obj as DateTime).toIso
      case Uri#:      return obj.toStr
      default:        return obj.toStr
    }
  }
}