//
// Copyright (c) 2023, Brian Frank
// All Rights Reserved
//
// History:
//  07 Aug 2023  Matthew Giannini Creation
//

/**
 * NameTable
 */
class NameTable extends sys.Obj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  constructor(empty=false) {
    super();
    this.#byCode = [];
    this.#map = new js.Map();
    if (!empty) {
      this.#emptyCode = this.#put("");
      this.#idCode    = this.#put("id");
    }
  }

  static #maxSize = 1_000_000;

  #byCode;
  #map;
  #emptyCode;
  #idCode;
  #isSparse = false;

  static make() { return new NameTable(); }
  static makeEmpty() { return new NameTable(true); }

//////////////////////////////////////////////////////////////////////////
// Fantom API
//////////////////////////////////////////////////////////////////////////

  typeof() { return NameTable.type$; }

  toStr() { return "NameTable"; }

  isSparse() { return this.#isSparse; }

  size() { return this.#map.size; }

  maxCode() { return this.#map.size; }

  toCode(name) { return this.#code(name); }

  toName(code) { return this.#name(code); }

  add(name) { return this.#put(name); }

  set(code, name) {
    // if already set, then ignore (we don't actually check name though)
    if (this.#byCode[code]) return;

    // add to lookup table
    this.#doPut(code, name);
  }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  emptyCode() { return this.#emptyCode; }
  idCode() { return this.#idCode; }

  #name(code) {
    const name = this.#byCode[code];
    if (!name) throw sys.Err.make(`Invalid name code: ${code}`);
    return name;
  }

  #code(name) {
    return this.#map.get(name) ?? 0;
  }

  #put(name) {
    const code = this.#code(name);
    if (code > 0) return code;

    // add to lookup table
    return this.#doPut(-1, name);
  }

  #doPut(code, name) {
    // allocate code unless this is a set
    if (code < 0) {
      if (this.#isSparse) throw sys.Err.make("Cannot call add once set has been called");
      code = this.size() + 1;
    } else {
      this.#isSparse = true;
    }

    if (this.size() > NameTable.#maxSize) throw Err.make(`Max names exceeded: ${NameTable.#maxSize}`);

    this.#byCode[code] = name;
    this.#map.set(name, code);

    return code;
  }

  dump(out) {
    out.printLine(`=== NameTable [${this.size()}] ===`);
    for (let i = 0; i <=this.size(); ++i) {
      out.printLine(`${i.toString().padStart(6)}: ${this.#byCode[i]}`)
    }
    out.printLine();
  }

//////////////////////////////////////////////////////////////////////////
// NameDict Factories
//////////////////////////////////////////////////////////////////////////

  dict1(n0, v0, spec=null) {
    return new NameDict(this, spec, n0, v0);
  }

  dict2(n0, v0, n1, v1, spec=null) {
    return new NameDict(this, spec, n0, v0, n1, v1);
  }

  dict3(n0, v0, n1, v1, n2, v2, spec=null) {
    return new NameDict(this, spec, n0, v0, n1, v1, n2, v2);
  }

  dict4(n0, v0, n1, v1, n2, v2, n3, v3, spec=null) {
    return new NameDict(this, spec, n0, v0, n1, v1, n2, v2, n3, v3);
  }

  dict5(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, spec=null) {
    return new NameDict(this, spec, n0, v0, n1, v1, n2, v2, n3, v3, n4, v4);
  }

  dict6(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5, spec=null) {
    return new NameDict(this, spec, n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5);
  }

  dict7(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5, n6, v6, spec=null) {
    return new NameDict(this, spec, n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5, n6, v6);
  }

  dict8(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5, n6, v6, n7, v7, spec=null) {
    return new NameDict(this, spec, n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5, n6, v6, n7, v7);
  }

  dictMap(map, spec=null) {
    if (map.isEmpty()) return NameDict.empty();

    const entries = [];
    map.each((v, k) => { entries.push(k, v); });
    return new NameDict(this, spec, ...entries);
  }

  dictDict(dict, spec=null) {
    if (dict.isEmpty()) return NameDict.empty();
    const entries = [];
    dict.each((v, k) => { entries.push(k, v); });
    return new NameDict(this, spec, ...entries);
  }

  readDict(size, r, spec) {
    if (size == 0) return NameDict.empty();
    const entries = [];
    for (let i=0; i < size; ++i) {
      entries.push(this.#name(r.readName()), r.readVal());
    }
    return new NameDict(this, spec, ...entries);
  }

}