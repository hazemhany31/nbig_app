const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
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

/**
 * Triggers when a user document is created or updated.
 * Syncs users with role 'doctor' to the 'doctors' collection.
 */
exports.syncDoctorProfile = onDocumentWritten("users/{userId}", async (event) => {
  const userId = event.params.userId;
  const newData = event.data.after.data();
  const oldData = event.data.before.data();

  // If the document was deleted, we optionally could mark doctor as inactive
  if (!newData) {
    logger.info(`User ${userId} deleted. Skipping sync.`);
    return;
  }

  // Check if role is 'doctor'
  if (newData.role !== 'doctor') {
    // If it was a doctor and role changed, we might want to handle that, 
    // but for now we just focus on ensuring doctors exist.
    return;
  }

  const doctorRef = admin.firestore().collection('doctors').doc(userId);
  
  try {
    const doctorDoc = await doctorRef.get();
    
    const doctorData = {
      userId: userId,
      name: newData.name || 'دكتور جديد',
      nameAr: newData.name || 'دكتور جديد',
      email: newData.email || '',
      phoneNumber: newData.phoneNumber || '',
      photoUrl: newData.photoUrl || '',
      image: newData.photoUrl || '',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!doctorDoc.exists) {
      // Create new doctor profile with defaults
      logger.info(`Creating new doctor profile for ${userId}`);
      await doctorRef.set({
        ...doctorData,
        specialty: 'General',
        specialtyAr: 'عام',
        rating: "4.8",
        reviews: 0,
        patients: "0",
        experience: "1",
        about: "لا توجد تفاصيل حالياً.",
        aboutAr: "لا توجد تفاصيل حالياً.",
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Update existing profile (basic info only to avoid overwriting specialty/bio)
      logger.info(`Updating doctor profile for ${userId}`);
      await doctorRef.update({
        name: doctorData.name,
        nameAr: doctorData.nameAr,
        email: doctorData.email,
        phoneNumber: doctorData.phoneNumber,
        photoUrl: doctorData.photoUrl,
        image: doctorData.image,
        updatedAt: doctorData.updatedAt,
      });
    }
  } catch (error) {
    logger.error(`Error syncing doctor profile for ${userId}:`, error);
  }
});
