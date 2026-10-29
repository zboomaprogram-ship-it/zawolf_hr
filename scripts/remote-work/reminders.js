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
          // Employee has checked in. Evaluate checkpoints deadline & escalations.
          const checkpoints = Array.isArray(policy.schedule?.checkpoints) ? policy.schedule.checkpoints : [];
          let cpEscalated = false;

          if (checkpoints.length > 0) {
            const sessionId = attSnap.data()?.remoteSessionId || `${userId}_${dateKey}`;
            const sessionDoc = await db.collection('remoteWorkSessions').doc(`${companyId}_${sessionId}`).get();
            const sessionData = sessionDoc.exists ? (sessionDoc.data() || {}) : {};
            const updates = Array.isArray(sessionData.updates) ? sessionData.updates : [];

            for (let i = 0; i < checkpoints.length; i++) {
              const cp = checkpoints[i];
              const parts = String(cp.dueTime || '').split(':').map(Number);
              if (parts.length < 2 || isNaN(parts[0]) || isNaN(parts[1])) continue;
              const dueMin = parts[0] * 60 + parts[1];
              const graceMin = Number(cp.graceMinutes ?? 15);
              const deadlineMin = dueMin + graceMin;

              if (nowMin > deadlineMin) {
                const isSubmitted = updates.some((u) => u.checkpointId === cp.id || u.slotIndex === i + 1);
                if (!isSubmitted) {
                  const escalationId = `missed_cp_${userId}_${dateKey}_${cp.id}`;
                  const escalationRef = db.collection('remoteWorkEscalations').doc(escalationId);
                  const existing = await escalationRef.get();
                  if (!existing.exists) {
                    const userDoc = await db.collection('users').doc(userId).get();
                    const userData = userDoc.exists ? (userDoc.data() || {}) : {};
                    const employeeName = userData.displayName || userData.name || userData.employeeName || 'الموظف';
                    const managerId = userData.directManagerId || userData.managerId || userData.supervisorId || null;
                    const cpLabel = cp.label || `نقطة المتابعة ${i + 1} (${cp.dueTime})`;

                    await escalationRef.set({
                      escalationId,
                      companyId,
                      userId,
                      employeeName,
                      dateKey,
                      checkpointId: cp.id,
                      checkpointLabel: cpLabel,
                      dueTime: cp.dueTime,
                      graceMinutes: graceMin,
                      managerId,
                      createdAt: admin?.firestore?.FieldValue?.serverTimestamp ? admin.firestore.FieldValue.serverTimestamp() : now.toISOString(),
                    });

                    // 1. Notify Manager
                    if (managerId) {
                      const mgrNotifId = `mgr_${escalationId}`;
                      await db.collection('notifications').doc(managerId).collection('items').doc(mgrNotifId).set({
                        notificationId: mgrNotifId,
                        type: 'remote_missed_checkpoint',
                        title: 'تنبيه: نقطة متابعة فائتة لموظف عن بُعد',
                        body: `تجاوز الموظف ${employeeName} فترة السماح المحددة لنقطة المتابعة (${cpLabel}) دون تسجيل متابعة.`,
                        data: {
                          userId,
                          employeeName,
                          checkpointId: cp.id,
                          dateKey,
                          companyId,
                        },
                        isRead: false,
                        pushSent: false,
                        createdAt: admin?.firestore?.FieldValue?.serverTimestamp ? admin.firestore.FieldValue.serverTimestamp() : now.toISOString(),
                      });
                      if (admin?.firestore?.FieldValue?.increment) {
                        await db.collection('users').doc(managerId).set({
                          unreadNotifications: admin.firestore.FieldValue.increment(1),
                        }, { merge: true }).catch(() => {});
                      }
                    }

                    // 2. Notify HR
                    const hrRoles = new Set(['super_admin', 'admin', 'hr', 'hr_admin', 'hr_manager', 'owner']);
                    const usersSnap = await db.collection('users').limit(50).get();
                    const hrDocs = usersSnap.docs.filter((d) => hrRoles.has(String(d.data()?.role || '').toLowerCase()));
                    for (const hrDoc of hrDocs) {
                      if (hrDoc.id === managerId) continue;
                      const hrNotifId = `hr_${escalationId}_${hrDoc.id}`;
                      await db.collection('notifications').doc(hrDoc.id).collection('items').doc(hrNotifId).set({
                        notificationId: hrNotifId,
                        type: 'remote_missed_checkpoint',
                        title: 'مخالفة دوام عن بُعد: نقطة متابعة فائتة',
                        body: `تخلف الموظف ${employeeName} عن تقديم نقطة المتابعة (${cpLabel}) بعد انتهاء فترة السماح.`,
                        data: {
                          userId,
                          employeeName,
                          checkpointId: cp.id,
                          dateKey,
                          companyId,
                        },
                        isRead: false,
                        pushSent: false,
                        createdAt: admin?.firestore?.FieldValue?.serverTimestamp ? admin.firestore.FieldValue.serverTimestamp() : now.toISOString(),
                      });
                      if (admin?.firestore?.FieldValue?.increment) {
                        await db.collection('users').doc(hrDoc.id).set({
                          unreadNotifications: admin.firestore.FieldValue.increment(1),
                        }, { merge: true }).catch(() => {});
                      }
                    }

                    result.queued++;
                    cpEscalated = true;
                  }
                }
              }
            }
          }

          if (!cpEscalated) {
            result.skipped++;
          }
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
