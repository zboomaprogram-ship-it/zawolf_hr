const admin = require('firebase-admin');
const { installFirestoreCompatibility } = require('./firebase-service-account');
installFirestoreCompatibility(admin);

// 1. Initialize Firebase Admin
let serviceAccount;
try {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} catch (e) {
  console.error('Error parsing FIREBASE_SERVICE_ACCOUNT secret. Please ensure it is set correctly in GitHub Secrets.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.cert(serviceAccount)
});

const db = admin.firestore();

async function runMonthlyTasks() {
  console.log('Starting monthly tasks...');
  
  // Get current month string in Egypt time (GMT+3)
  const dateOptions = { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' };
  const dateParts = new Intl.DateTimeFormat('en-CA', dateOptions).formatToParts(new Date());
  const day = dateParts.find(p => p.type === 'day').value;
  const isManualRun = process.env.GITHUB_EVENT_NAME === 'workflow_dispatch';
  if (!isManualRun && day !== '01') {
    console.log(`Cairo date is day ${day}; monthly reset only runs on day 01. Exiting.`);
    return;
  }

  const options = { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit' };
  const formatter = new Intl.DateTimeFormat('en-CA', options); // en-CA gives YYYY-MM
  const parts = formatter.formatToParts(new Date());
  const year = parts.find(p => p.type === 'year').value;
  const month = parts.find(p => p.type === 'month').value;
  const currentMonth = `${year}-${month}`;
  
  console.log(`Processing monthly reset for: ${currentMonth}`);

  // Fetch all active employees
  const usersSnap = await db.collection('users').where('isActive', '==', true).get();
  console.log(`Found ${usersSnap.size} active users.`);

  let resetCount = 0;
  let batch = db.batch();
  let batchOps = 0;
  const BATCH_LIMIT = 450;

  async function commitIfNeeded() {
    if (batchOps >= BATCH_LIMIT) {
      await batch.commit();
      console.log(`Committed batch of ${batchOps} operations.`);
      batch = db.batch();
      batchOps = 0;
    }
  }

  for (const userDoc of usersSnap.docs) {
    const user = userDoc.data();
    
    // Check if permissionBalance exists and needs reset
    if (user.permissionBalance && user.permissionBalance.lastResetMonth !== currentMonth) {
      batch.update(userDoc.ref, {
        'permissionBalance.usedThisMonth': 0,
        'permissionBalance.usedHoursThisMonth': 0.0,
        'permissionBalance.lastResetMonth': currentMonth,
        'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });
      resetCount++;
      batchOps++;
      await commitIfNeeded();
    } else if (!user.permissionBalance) {
      batch.update(userDoc.ref, {
        'permissionBalance.usedThisMonth': 0,
        'permissionBalance.usedHoursThisMonth': 0.0,
        'permissionBalance.lastResetMonth': currentMonth,
        'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });
      resetCount++;
      batchOps++;
      await commitIfNeeded();
    }
  }

  if (batchOps > 0) {
    await batch.commit();
    console.log(`Successfully committed! Reset permission quotas for ${resetCount} employees.`);
  } else {
    console.log('No action required. All employees already have their permission quotas reset for this month.');
  }
}

runMonthlyTasks()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Error running monthly tasks:', error);
    process.exit(1);
  });
