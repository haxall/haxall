//
// Copyright (c) 2023, Brian Frank
// All Rights Reserved
//
// History:
//  07 Aug 2023  Matthew Giannini Creation
//

/**
 * NameDict
 */
class NameDict extends sys.Obj
{
  constructor(table, spec, ...entries) { 
    super(); 
    this.#table = table ?? NameTable.makeEmpty();
    this.#spec = spec;
    this.#entries = sys.Map.make(sys.Int.type$, sys.Obj.type$);
    this.#entries.ordered(true);
    let i = 0;
    while (i < entries.length) {
      const code = table.add(entries[i]);
      const val  = entries[i+1];
      this.#entries.add(code, sys.ObjUtil.toImmutable(val));
      i += 2;
    }
  }

  static #empty;
  static empty() {
    if (!NameDict.#empty) NameDict.#empty = new NameDict(null, null);
    return NameDict.#empty;
  }

  #table;
  #spec;
  #entries;

  typeof() { return NameDict.type$; }

  spec() { return this.#spec ?? XetoEnv.cur().dictSpec(); }

  id() {
    const val = this.#get(this.#table.idCode())
    if (val != null) return sys.ObjUtil.as(val, haystack.Ref.type$);
    throw sys.UnresolvedErr.make("id");
  }

  isEmpty() { return this.#entries.isEmpty(); }

  size() { return this.#entries.size(); }

  fixedSize() { return this.size(); }

  has(name) { return this.get(name) != null; }

  missing(name) { return this.get(name) == null; }

  get(name, def=null) { 
    return this.#get(this.#table.toCode(name), def);
  }

  getByCode(code) { return this.#get(code); }

  #get(code, def=null) {
    return this.#entries.get(code) ?? def;
  }

  each(f) { this.#entries.each((v, n) => f(v, this.#table.toName(n))); }

  eachWhile(f) {
    return this.#entries.eachWhile((v, n) => { return f(v, this.#table.toName(n)); });
  }

  map(f) {
    const newEntries = [];
    for (const [key, value] of this.#entries) {
      const name = this.#table.toName(key);
      const newVal = f(value, name);
      newEntries.push(name, newVal);
    }
    return new NameDict(this.#table, this.#spec, ...newEntries);
  }

  trap(name, args=null) { 
    const val = this.get(name);
    if (val != null) return val;
    throw sys.UnresolvedErr.make(name);
  }

  nameAt(i) { return this.#entries.keys().get(i); }

  valAt(i) { return this.#entries.vals().get(i); }

  // if we do toStr() probably should be str name instead of int code for key
  // toStr() { return this.#entries.toStr(); }
}