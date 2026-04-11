const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");

admin.initializeApp();

// Runs every 5 minutes to sweep old unconfirmed appointments
exports.autoCancelUnconfirmed = onSchedule("every 5 minutes", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const appointmentsRef = admin.firestore().collection('appointments');
  
  try {
    const snapshot = await appointmentsRef
      .where('status', '==', 'pending')
      .where('expiresAt', '<=', now)
      .get();

    if (snapshot.empty) {
      logger.info('No expired pending appointments found.');
      return;
    }

    const batch = admin.firestore().batch();
    
    snapshot.forEach(doc => {
      // 1. Change status to cancelled
      batch.update(doc.ref, { 
        status: 'cancelled',
        cancelReason: 'auto_cancelled_timeout',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // 2. Add a notification for the patient
      const notifRef = admin.firestore().collection('notifications').doc();
      batch.set(notifRef, {
        recipientId: doc.data().patientId,
        title: 'إلغاء الموعد ❌',
        body: 'تم إلغاء موعدك تلقائياً لعدم تأكيده خلال مهلة الـ 60 دقيقة.',
        appointmentId: doc.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: 'cancelled_appointment',
        status: 'unread'
      });
    });

    await batch.commit();
    logger.info(`Successfully cancelled ${snapshot.size} expired appointments.`);
  } catch (error) {
    logger.error('Error auto-cancelling appointments:', error);
  }
});

// Runs every 5 minutes to send reminders for items exactly 30 mins old
exports.sendConfirmationReminder = onSchedule("every 5 minutes", async (event) => {
  // We want to remind them when it's exactly 30 minutes since 'createdAt'
  const thirtyMinsAgo = new Date(Date.now() - 30 * 60 * 1000);
  const thirtyFiveMinsAgo = new Date(Date.now() - 35 * 60 * 1000); 

  const appointmentsRef = admin.firestore().collection('appointments');
  
  try {
    const snapshot = await appointmentsRef
      .where('status', '==', 'pending')
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(thirtyMinsAgo))
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(thirtyFiveMinsAgo))
      .get();

    if (snapshot.empty) {
      return;
    }

    const batch = admin.firestore().batch();
    
    snapshot.forEach(doc => {
      // Only send if we haven't reminded
      if (doc.data().reminderSent) return;

      const notifRef = admin.firestore().collection('notifications').doc();
      batch.set(notifRef, {
        recipientId: doc.data().patientId,
        title: 'تذكير لتأكيد الحجز ⏳',
        body: 'باقي أقل من نصف ساعة لتأكيد الحجز قبل الإلغاء التلقائي. يرجى تأكيد الموعد من قائمة مواعيدك.',
        appointmentId: doc.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: 'reminder',
        status: 'unread'
      });

      // mark doc so we don't remind again
      batch.update(doc.ref, { reminderSent: true });
    });

    if (batch._mutations.length > 0) {
      await batch.commit();
      logger.info(`Successfully sent reminders for ${batch._mutations.length / 2} appointments.`);
    }
  } catch (error) {
    logger.error('Error sending confirmation reminders:', error);
  }
});
