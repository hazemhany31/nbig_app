/**
 * Utility script to sync existing users with role 'doctor' to the 'doctors' collection.
 * 
 * Usage:
 * 1. Download your service account key from Firebase Console (Project Settings > Service Accounts).
 * 2. Save it as 'service-account.json' in this folder.
 * 3. Run: node scripts/sync_existing_doctors.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("../service-account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function syncExistingDoctors() {
  console.log("🔍 Fetching users with role 'doctor'...");
  
  try {
    const usersSnapshot = await db.collection("users")
      .where("role", "==", "doctor")
      .get();

    if (usersSnapshot.empty) {
      console.log("ℹ️ No doctors found in 'users' collection.");
      return;
    }

    console.log(`✅ Found ${usersSnapshot.size} doctors. Checking profile status...`);

    const batch = db.batch();
    let syncCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      const doctorRef = db.collection("doctors").doc(userId);
      const doctorDoc = await doctorRef.get();

      if (!doctorDoc.exists) {
        console.log(`➕ Creating profile for: ${userData.name || userId}`);
        batch.set(doctorRef, {
          userId: userId,
          name: userData.name || 'دكتور جديد',
          nameAr: userData.name || 'دكتور جديد',
          email: userData.email || '',
          phoneNumber: userData.phoneNumber || '',
          photoUrl: userData.photoUrl || '',
          image: userData.photoUrl || '',
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
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        syncCount++;
      } else {
        console.log(`✔ Profile already exists for: ${userData.name || userId}`);
      }
    }

    if (syncCount > 0) {
      await batch.commit();
      console.log(`🚀 Successfully synced ${syncCount} new doctor profiles!`);
    } else {
      console.log("✨ All doctors are already synced.");
    }

  } catch (error) {
    console.error("❌ Error syncing doctors:", error);
  } finally {
    process.exit();
  }
}

syncExistingDoctors();
