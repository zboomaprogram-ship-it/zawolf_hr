'use strict';

function data(snapshot) { return snapshot.exists ? { id: snapshot.id, ...snapshot.data() } : null; }

function createOrganizationFirestoreStore(db) {
  return {
    transact(work) {
      return db.runTransaction(async (transaction) => work({
        async getReceipt(id) { return data(await transaction.get(db.collection('companyOsOperationReceipts').doc(id))); },
        async putReceipt(id, value) { transaction.create(db.collection('companyOsOperationReceipts').doc(id), value); },
        async putAudit(id, value) { transaction.create(db.collection('companyOsAuditEvents').doc(id), value); },
        async getTree(id) { return data(await transaction.get(db.collection('companyOsOrganizationTrees').doc(id))); },
        async listTrees() {
          const snapshot = await transaction.get(db.collection('companyOsOrganizationTrees').orderBy('order', 'asc').limit(100));
          return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        },
        async putTree(id, value) { transaction.set(db.collection('companyOsOrganizationTrees').doc(id), value, { merge: true }); },
        async getUnit(id) { return data(await transaction.get(db.collection('companyOsOrganizationUnits').doc(id))); },
        async listUnits() {
          const snapshot = await transaction.get(db.collection('companyOsOrganizationUnits').limit(500));
          return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        },
        async listUnitsForTree(treeId) {
          const snapshot = await transaction.get(db.collection('companyOsOrganizationUnits').where('treeId', '==', treeId).limit(500));
          return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        },
        async putUnit(id, value) { transaction.set(db.collection('companyOsOrganizationUnits').doc(id), value, { merge: true }); },
        async getMembership(id) { return data(await transaction.get(db.collection('companyOsOrganizationMemberships').doc(id))); },
        async listMembershipsForEmployee(employeeUid) {
          const snapshot = await transaction.get(db.collection('companyOsOrganizationMemberships').where('employeeUid', '==', employeeUid).limit(100));
          return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        },
        async listMembershipsForTree(treeId) {
          const snapshot = await transaction.get(db.collection('companyOsOrganizationMemberships').where('treeId', '==', treeId).limit(500));
          return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        },
        async putMembership(id, value) { transaction.set(db.collection('companyOsOrganizationMemberships').doc(id), value, { merge: true }); },
        async getUser(id) { return data(await transaction.get(db.collection('users').doc(id))); },
        async putUser(id, value) { transaction.set(db.collection('users').doc(id), value, { merge: true }); },
        async listUsersByDepartment(id) {
          const snapshot = await transaction.get(db.collection('users').where('departmentUnitId', '==', id).limit(2));
          return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        },
        async listDepartmentMembers(id) {
          const snapshot = await transaction.get(db.collection('users').where('departmentUnitId', '==', id).limit(100));
          return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        },
        async putRouting(employeeUid, value) {
          transaction.set(db.collection('companyOsOrganizationRouting').doc(employeeUid), value, { merge: true });
        },
        async currentManager(unitId) {
          const snapshot = await transaction.get(db.collection('companyOsOrganizationManagerHistory').where('unitId', '==', unitId).where('active', '==', true).limit(1));
          return snapshot.empty ? null : { id: snapshot.docs[0].id, ...snapshot.docs[0].data() };
        },
        async putManager(id, value) {
          transaction.set(db.collection('companyOsOrganizationManagerHistory').doc(id), { ...value, active: !value.endedAt }, { merge: true });
        },
      }));
    },
  };
}

module.exports = { createOrganizationFirestoreStore };
