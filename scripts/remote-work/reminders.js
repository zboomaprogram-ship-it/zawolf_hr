'use strict';

/**
 * Durable reminders and bounded incident fanout (Feature 020).
 * Reference: specs/020-remote-work-attendance/plan.md & tasks.md (T12)
 */

const CAIRO_TZ = 'Africa/Cairo';

function cairoDateKey(date = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: CAIRO_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

function cairoMinutes(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: CAIRO_TZ,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const hour = Number(parts.find((p) => p.type === 'hour')?.value || 0);
  const minute = Number(parts.find((p) => p.type === 'minute')?.value || 0);
  return hour * 60 + minute;
}

function isQuietHours(minutes, config = {}) {
  if (config.enabled !== true) return false;
  const start = Number(config.startMinutes ?? 22 * 60); // 22:00
  const end = Number(config.endMinutes ?? 7 * 60); // 07:00
  if (start > end) {
    // Overnight quiet hours, e.g. 22:00 -> 07:00
    return minutes >= start || minutes < end;
  }
  return minutes >= start && minutes < end;
}

async function queueRemoteWorkReminders({
  db,
  admin,
  now = new Date(),
  pageSize = 100,
  maxDocuments = 1000,
}) {
  const dateKey = cairoDateKey(now);
  const nowMin = cairoMinutes(now);

  const result = {
    scanned: 0,
    queued: 0,
    skipped: 0,
    errors: [],
    dateKey,
  };

  try {
    // 1. Fetch companies with active remote work policy
    const companiesSnap = await db.collection('companies').limit(50).get();
    for (const compDoc of companiesSnap.docs) {
      if (result.scanned >= maxDocuments) break;

      const compData = compDoc.data() || {};
      const policy = compData.attendancePolicy?.remoteWorkPolicy;
      if (!policy || policy.enabled !== true) continue;

      const notifConfig = policy.notifications || {};
      if (notifConfig.enabled === false) continue;
      if (isQuietHours(nowMin, notifConfig.quietHours)) continue;

      const companyId = compDoc.id;

      // 2. Query today's approved schedules for this company
      const schedulesSnap = await db
        .collection('remoteWorkSchedules')
        .where('companyId', '==', companyId)
        .where('status', '==', 'approved')
        .limit(Math.min(pageSize, maxDocuments - result.scanned))
        .get();

      for (const schDoc of schedulesSnap.docs) {
        if (result.scanned >= maxDocuments) break;
        result.scanned++;

        const sch = schDoc.data() || {};
        const userId = sch.employeeId;
        if (!userId) continue;

        // Check if employee already checked in today
        const attRef = db.collection('attendance').doc(`${userId}_${dateKey}`);
        const attSnap = await attRef.get();
        if (attSnap.exists && attSnap.data()?.checkInTime) {
          result.skipped++;
          continue;
        }

        // Deduplicate reminder in notification items
        const notifId = `remote_remind_${userId}_${dateKey}_checkin`;
        const notifRef = db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .doc(notifId);

        const existing = await notifRef.get();
        if (existing.exists) {
          result.skipped++;
          continue;
        }

        // Queue reminder notification
        await notifRef.set({
          notificationId: notifId,
          type: 'remote_check_in_reminder',
          title: 'تذكير تسجيل الحضور عن بُعد',
          body: 'اليوم يوم عمل عن بعد مجدول. يرجى تسجيل حضورك عبر مفتاح المرور المعتمد.',
          data: {
            dateKey,
            companyId,
            scheduleId: schDoc.id,
          },
          isRead: false,
          pushSent: false,
          createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now.toISOString(),
        });

        result.queued++;
      }
    }
  } catch (error) {
    result.errors.push(String(error?.message || error));
  }

  return result;
}

async function queueRemoteIncidentCoverage({
  db,
  admin,
  now = new Date(),
  pageSize = 100,
  maxDocuments = 1000,
}) {
  const result = {
    scanned: 0,
    queued: 0,
    skipped: 0,
    errors: [],
  };

  try {
    // Scan active incidents that need population fanout
    const incidentsSnap = await db
      .collection('remoteWorkIncidents')
      .where('fanoutStatus', '==', 'pending')
      .limit(10)
      .get();

    for (const incDoc of incidentsSnap.docs) {
      if (result.scanned >= maxDocuments) break;

      const inc = incDoc.data() || {};
      const incidentId = incDoc.id;
      const companyId = inc.companyId || 'zawolf';
      const affectedDate = inc.date || cairoDateKey(now);

      // Find employees with approved schedules on this date
      const schedulesSnap = await db
        .collection('remoteWorkSchedules')
        .where('companyId', '==', companyId)
        .where('status', '==', 'approved')
        .limit(Math.min(pageSize, maxDocuments - result.scanned))
        .get();

      for (const schDoc of schedulesSnap.docs) {
        if (result.scanned >= maxDocuments) break;
        result.scanned++;

        const sch = schDoc.data() || {};
        const employeeId = sch.employeeId;
        if (!employeeId) continue;

        const covId = `${incidentId}_${employeeId}`;
        const covRef = db.collection('remoteWorkIncidentCoverage').doc(covId);
        const covSnap = await covRef.get();
        if (covSnap.exists) {
          result.skipped++;
          continue;
        }

        await covRef.set({
          coverageId: covId,
          incidentId,
          companyId,
          employeeId,
          date: affectedDate,
          status: 'covered',
          createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now.toISOString(),
        });

        // Place financial hold
        const holdId = `hold_${incidentId}_${employeeId}`;
        const holdRef = db.collection('remoteWorkFinancialHolds').doc(holdId);
        await holdRef.set({
          holdId,
          incidentId,
          companyId,
          employeeId,
          date: affectedDate,
          open: true,
          reason: 'it_incident_protection',
          createdAt: admin?.firestore?.FieldValue?.serverTimestamp() || now.toISOString(),
        });

        result.queued++;
      }

      // Mark incident fanout completed
      await incDoc.ref.set(
        {
          fanoutStatus: 'completed',
          fanoutCompletedAt: admin?.firestore?.FieldValue?.serverTimestamp() || now.toISOString(),
        },
        { merge: true }
      );
    }
  } catch (error) {
    result.errors.push(String(error?.message || error));
  }

  return result;
}

module.exports = {
  queueRemoteWorkReminders,
  queueRemoteIncidentCoverage,
  isQuietHours,
  cairoDateKey,
  cairoMinutes,
};
