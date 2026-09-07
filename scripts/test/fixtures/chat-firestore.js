'use strict';
// Serializes transactions to model Firestore retry outcome, rolls back rejected
// writes, and rejects reads after writes (an easy production-only failure).
function firestore(seed = {}) {
  let data = new Map(Object.entries(seed)), queue = Promise.resolve();
  const reads = [];
  const snap = (ref, store = data) => ({ id: ref.id, ref, exists: store.has(ref.path), data: () => structuredClone(store.get(ref.path)) });
  function document(path) {
    return { path, id: path.split('/').at(-1), get: async () => { reads.push(path); return snap(document(path)); }, collection: name => query(`${path}/${name}`), set: async (value, options) => data.set(path, options?.merge ? { ...data.get(path), ...structuredClone(value) } : structuredClone(value)), create: async value => { if (data.has(path)) throw Error('exists'); data.set(path, structuredClone(value)); }, update: async value => data.set(path, { ...data.get(path), ...structuredClone(value) }) };
  }
  function query(path, filters = [], orders = [], cap = Infinity, after = []) {
    return {
      doc: id => document(`${path}/${id}`), where: (key, op, value) => query(path, [...filters, [key,op,value]], orders, cap, after), orderBy: (key, direction = 'asc') => query(path, filters, [...orders,[key,direction]], cap, after), limit: n => query(path, filters, orders, n, after), startAfter: (...values) => query(path, filters, orders, cap, values),
      count: () => ({ get: async () => { const result = await query(path, filters, orders, cap, after).get(); return { data: () => ({ count: result.size }) }; } }),
      get: async () => {
        if (!Number.isFinite(cap)) throw Error('unbounded query'); reads.push({ path, limit: cap });
        const value = (row,key) => key === '__name__' ? row.id : row.data()[key];
        let rows = [...data.keys()].filter(key => key.startsWith(`${path}/`) && key.split('/').length === path.split('/').length + 1).map(key => snap(document(key)));
        rows = rows.filter(row => filters.every(([key,op,v]) => { const actual = value(row,key); return op === '==' ? (actual instanceof Date && v instanceof Date ? +actual === +v : actual === v) : op === '!=' ? actual !== v : op === 'in' ? v.includes(actual) : op === 'array-contains' ? actual?.includes(v) : op === '>' ? actual > v : false; }));
        const compare = (a,b) => a < b ? -1 : a > b ? 1 : 0;
        rows.sort((a,b) => { for (const [key,dir] of orders) { const diff = compare(value(a,key), value(b,key)); if (diff) return diff * (dir === 'desc' ? -1 : 1); } return 0; });
        if (after.length) rows = rows.filter(row => { for(let i=0;i<after.length;i++) { const diff=compare(value(row,orders[i][0]),after[i])*(orders[i][1]==='desc'?-1:1); if(diff) return diff>0; } return false; });
        rows = rows.slice(0,cap); return { docs: rows, size: rows.length, empty: !rows.length };
      },
    };
  }
  return {
    collection: query, getAll: async (...refs) => Promise.all(refs.map(ref => ref.get())), reads,
    dump: () => Object.fromEntries(data),
    runTransaction: fn => {
      const task = queue.then(async () => {
        const copy = new Map([...data].map(([key,value]) => [key,structuredClone(value)])); let written = false;
        const write = (ref,value,merge) => { written = true; copy.set(ref.path, merge ? { ...copy.get(ref.path), ...structuredClone(value) } : structuredClone(value)); };
        const result = await fn({ get: async ref => { if (written) throw Error('read after write'); reads.push(ref.path); return snap(ref,copy); }, set: (ref,value,options) => write(ref,value,options?.merge), create: (ref,value) => { if(copy.has(ref.path)) throw Error('exists'); write(ref,value); }, update: (ref,value) => write(ref,value,true) });
        data = copy; return result;
      }); queue = task.catch(() => {}); return task;
    },
  };
}
module.exports = { firestore };
