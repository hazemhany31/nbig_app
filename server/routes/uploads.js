const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const router = express.Router();

const upload = multer({ storage: multer.memoryStorage() });

// فرضاً عندك middleware للفحص auth وتعرف req.user.id
router.post('/', authMiddleware, upload.fields([{ name: 'clip' }, { name: 'pdf' }]), async (req, res) => {
  try {
    // تحقق إن المريض ده هو المستخدم الحالي أو له صلاحية
    const patientId = req.body.patientId;
    const doctorId = req.body.doctorId;
    if (req.user.role !== 'patient' || req.user.id !== patientId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // ملف الفيديو
    const clipFile = req.files['clip']?.[0];
    const pdfFile = req.files['pdf']?.[0];

    if (!clipFile) return res.status(400).json({ error: 'No clip' });

    // احفظ الملفات محلياً (انقل لـS3 في production)
    const uploadsDir = path.join(__dirname, '..', '..', 'uploads');
    if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

    const clipName = `clip_${Date.now()}.webm`;
    fs.writeFileSync(path.join(uploadsDir, clipName), clipFile.buffer);

    let pdfPath = null;
    if (pdfFile) {
      const pdfName = `pdf_${Date.now()}.pdf`;
      fs.writeFileSync(path.join(uploadsDir, pdfName), pdfFile.buffer);
      pdfPath = `/uploads/${pdfName}`;
    }

    // حط سجل في DB (مثال pseudo)
    const record = {
      patient_id: patientId,
      doctor_id: doctorId,
      type: 'clip',
      url: `/uploads/${clipName}`,
      pdf_url: pdfPath,
      duration: req.body.duration || null,
      created_at: new Date()
    };
    // مثال: await db('messages').insert(record);

    return res.json({ ok: true, record });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;