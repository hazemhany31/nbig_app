# حل مشكلة reCAPTCHA على iOS

## المشكلة:
- خطأ "Unable to load external reCAPTCHA dependencies!"
- reCAPTCHA يفتح في المتصفح بدلاً من إرسال SMS مباشرة

## الحلول:

### الحل 1: إعداد APNs (الأفضل للإنتاج)

1. **في Firebase Console:**
   - اذهب إلى Project Settings → Cloud Messaging
   - حمّل APNs Authentication Key من Apple Developer
   - أو حمّل APNs Certificate

2. **في Apple Developer:**
   - أنشئ APNs Key أو Certificate
   - حمّله في Firebase Console

3. **بعد الإعداد:**
   - SMS سيتم إرساله مباشرة بدون reCAPTCHA
   - لن يفتح المتصفح

### الحل 2: استخدام أرقام اختبار (للاختبار فقط)

1. **في Firebase Console:**
   - اذهب إلى Authentication → Sign-in method → Phone
   - أضف أرقام هاتف للاختبار في "Phone numbers for testing"
   - مثال: `+201234567890` مع كود: `123456`

2. **استخدم هذه الأرقام في التطبيق:**
   - SMS سيتم إرساله مباشرة
   - استخدم الكود المحدد في Firebase Console

### الحل 3: إعداد reCAPTCHA بشكل صحيح

1. **تأكد من Info.plist:**
   - يجب أن يحتوي على `REVERSED_CLIENT_ID` في `CFBundleURLSchemes`
   - موجود بالفعل في الكود ✅

2. **في Firebase Console:**
   - تأكد من تفعيل Phone Authentication
   - تأكد من إعداد reCAPTCHA بشكل صحيح

## ملاحظات مهمة:

- **iOS Simulator:** لا يستقبل SMS حقيقية، استخدم جهاز حقيقي
- **أرقام الاختبار:** تعمل فقط في Development mode
- **APNs:** مطلوب للإنتاج (Production)

## الخطوات السريعة:

1. افتح Firebase Console
2. Authentication → Sign-in method → Phone
3. أضف رقم اختبار: `+201234567890` مع كود: `123456`
4. استخدم هذا الرقم في التطبيق للاختبار

