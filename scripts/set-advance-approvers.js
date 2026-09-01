const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({
  projectId: "zawolf-hr-system-60317",
  credential: applicationDefault()
});

const db = getFirestore();

async function run() {
  const snap = await db.collection('users').get();
  console.log(`Found ${snap.docs.length} users:`);
  for (const doc of snap.docs) {
    const u = doc.data();
    console.log(`- ${doc.id} | ${u.displayName} | ${u.email} | role: ${u.role} | pos: ${u.position} | dept: ${u.department} | active: ${u.isActive}`);
  }
}

run().catch(console.error);
