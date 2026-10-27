'use strict';

const clone = (value) => structuredClone(value);

function mergeFirestoreMaps(previous, value) {
  const result = { ...previous };
  for (const [key, nested] of Object.entries(value)) {
    if (nested && Object.getPrototypeOf(nested) === Object.prototype && Object.keys(nested).length) {
      result[key] = mergeFirestoreMaps(result[key] || {}, nested);
    } else result[key] = clone(nested);
  }
  return result;
}

function assertEmulatorEnvironment(env = process.env) {
  const host = String(env.FIRESTORE_EMULATOR_HOST || '');
  const projectId = String(env.GCLOUD_PROJECT || env.FIREBASE_PROJECT_ID || '');
  let parsedHost;
  try { parsedHost = new URL(`http://${host}`); } catch (_) { parsedHost = null; }
  const loopback = ['127.0.0.1', 'localhost', '::1'].includes(parsedHost?.hostname);
  if (!loopback || !parsedHost.port || Number(parsedHost.port) < 1 || Number(parsedHost.port) > 65535) {
    throw new Error('Remote attendance emulator requires a localhost FIRESTORE_EMULATOR_HOST.');
  }
  if (!/^(?:demo|test)-[a-z0-9-]+$/.test(projectId)) {
    throw new Error('Remote attendance emulator requires an explicit demo-* or test-* project ID.');
  }
  return { host, projectId };
}

function createMemoryBackend(fixtures = {}) {
  const documents = new Map(Object.entries(fixtures).map(([path, value]) => [path, clone(value)]));
  let transactionTail = Promise.resolve();
  const reads = [];
  const writes = [];

  const ref = (path) => ({ path });
  const db = {
    collection(name) {
      return {
        doc(id) { return ref(`${name}/${id}`); },
        where(field, operator, value) {
          const filters = [[field, operator, value]];
          const query = {
            where(nextField, nextOperator, nextValue) {
              filters.push([nextField, nextOperator, nextValue]);
              return query;
            },
            limit() { return query; },
            async get() {
              const prefix = `${name}/`;
              const docs = [...documents.entries()]
                .filter(([path, data]) => path.startsWith(prefix) && filters.every(([key, op, expected]) => {
                  if (op !== '==') throw new Error(`Unsupported memory query operator: ${op}`);
                  return data?.[key] === expected;
                }))
                .map(([path, data]) => ({ id: path.slice(prefix.length), exists: true, data: () => clone(data) }));
              reads.push({ collection: name, filters, count: docs.length });
              return { docs, empty: docs.length === 0, size: docs.length };
            },
          };
          return query;
        },
      };
    },
    async runTransaction(callback) {
      let unlock;
      const previous = transactionTail;
      transactionTail = new Promise((resolve) => { unlock = resolve; });
      await previous;
      const staged = [];
      const transaction = {
        async get(reference) {
          reads.push({ document: reference.path });
          const value = documents.get(reference.path);
          return { exists: value !== undefined, data: () => value === undefined ? undefined : clone(value) };
        },
        set(reference, value, options = {}) {
          if (options.mergeFields) {
            if (options.mergeFields.some((field) => typeof field !== 'string' || field.includes('.') || !Object.hasOwn(value, field))) {
              throw new Error('Memory backend supports only explicit root-field merge masks.');
            }
            const masked = Object.fromEntries(options.mergeFields.map((field) => [field, value[field]]));
            staged.push({ type: 'merge_fields', path: reference.path, value: clone(masked) });
          } else {
            staged.push({ type: options.merge ? 'merge' : 'set', path: reference.path, value: clone(value) });
          }
        },
        create(reference, value) {
          if (documents.has(reference.path)) throw new Error('already-exists');
          staged.push({ type: 'create', path: reference.path, value: clone(value) });
        },
        delete(reference) { staged.push({ type: 'delete', path: reference.path }); },
      };
      try {
        const result = await callback(transaction);
        if (staged.some((write) => write.type === 'create' && documents.has(write.path))) {
          throw new Error('already-exists');
        }
        for (const write of staged) {
          if (write.type === 'delete') documents.delete(write.path);
          else if (write.type === 'merge') documents.set(write.path, mergeFirestoreMaps(documents.get(write.path) || {}, write.value));
          else if (write.type === 'merge_fields') documents.set(write.path, { ...(documents.get(write.path) || {}), ...write.value });
          else documents.set(write.path, write.value);
          writes.push(write);
        }
        return result;
      } finally {
        unlock();
      }
    },
  };
  return {
    db,
    documents,
    reads,
    writes,
    seed(collection, id, data) { documents.set(`${collection}/${id}`, clone(data)); },
    read(collection, id) {
      const value = documents.get(`${collection}/${id}`);
      return value === undefined ? null : clone(value);
    },
    count(collection) { return [...documents.keys()].filter((path) => path.startsWith(`${collection}/`)).length; },
  };
}

async function createRemoteHarness({ now = '2026-11-02T06:45:00.000Z', pilot = {}, fixtures = {}, backend = 'memory' } = {}) {
  if (!['memory', 'emulator'].includes(backend)) throw new Error('Unsupported remote attendance fixture backend.');
  let memory;
  let db;
  let app;
  if (backend === 'memory') {
    memory = createMemoryBackend(fixtures);
    db = memory.db;
  } else {
    const { projectId } = assertEmulatorEnvironment();
    const admin = require('firebase-admin');
    app = admin.initializeApp({ projectId }, `remote-work-test-${Date.now()}`);
    db = require('firebase-admin/firestore').getFirestore(app);
    if (Object.keys(fixtures).length) throw new Error('Seed emulator fixtures explicitly through seed() after opening the harness.');
  }
  let clock = new Date(now);
  const handlers = new Map();
  const command = (kind, payload = {}, options = {}) => ({
    commandId: options.commandId || `rw_${Math.random().toString(36).slice(2, 14)}`,
    kind,
    actorId: options.actorId || pilot.actorId || 'employee_test',
    companyId: options.companyId || pilot.companyId || 'zawolf',
    payload: clone(payload),
    ...options,
  });
  return {
    db,
    actor: clone(pilot.actor || { uid: pilot.actorId || 'employee_test', companyId: pilot.companyId || 'zawolf', active: true }),
    command,
    registerCommand(kind, handler) { handlers.set(kind, handler); },
    async execute(value) {
      const handler = handlers.get(value.kind);
      if (!handler) throw new Error(`No remote attendance command handler registered for ${value.kind}.`);
      return handler({ db, actor: this.actor, command: value, now: new Date(clock) });
    },
    async seed(collection, id, data) {
      if (memory) return memory.seed(collection, id, data);
      await db.collection(collection).doc(id).set(data);
    },
    async read(collection, id) {
      if (memory) return memory.read(collection, id);
      const snapshot = await db.collection(collection).doc(id).get();
      return snapshot.exists ? snapshot.data() : null;
    },
    async count(collection) {
      if (memory) return memory.count(collection);
      const snapshot = await db.collection(collection).get();
      return snapshot.size;
    },
    advanceTo(isoInstant) {
      const next = new Date(isoInstant);
      if (Number.isNaN(next.getTime())) throw new Error('Fixture clock requires a valid instant.');
      clock = next;
      return new Date(clock);
    },
    async runWorker(name, input = {}) {
      const handler = handlers.get(`worker:${name}`);
      if (!handler) throw new Error(`No remote attendance worker registered for ${name}.`);
      return handler({ db, now: new Date(clock), ...input });
    },
    get reads() { return memory?.reads || []; },
    async close() { if (app) await app.delete(); },
  };
}

module.exports = { assertEmulatorEnvironment, createMemoryBackend, createRemoteHarness };
