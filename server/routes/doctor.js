const express = require('express');
const router = express.Router();

// تأكد عندك authMiddleware و function isDoctorAssignedToPatient
router.get('/patient/:patientId/clips', authMiddleware, async (req, res) => {
  try {
    const doctorId = req.user.id;
    const patientId = req.params.patientId;

    // تحقّق إن الطبيب مربوط بالمريض
    const allowed = await isDoctorAssignedToPatient(doctorId, patientId);
    if (!allowed) return res.status(403).json({ ok: false, error: 'Forbidden' });

    // جلب من DB - عدّل حسب ORM/SQL عندك
    // مثال باستخدام knex:
    // const rows = await db('messages').where({ patient_id: patientId, doctor_id: doctorId }).orderBy('created_at', 'desc');
    const rows = []; // ...replace with real query...

    return res.json({ ok: true, data: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ ok: false, error: 'Server error' });
  }
});

module.exports = router;