# Secure Messaging App

# التقرير التقني الشامل: بنية الاتصال وتدفق البيانات في تطبيق الدردشة والمكالمات الآمن
الطالبان :

محمد سالم عبد الحفيظ 232098


عبد العزيز عادل صولة 232112


الفصل السادس
**التاريخ:** 29 ديسمبر 2025

---

## 1. مقدمة
يقدم هذا التقرير شرحاً تفصيلياً للبنية التحتية والعمليات التقنية التي تدير رحلة البيانات والاتصال داخل تطبيقك. يعتمد التطبيق على نموذج **التشفير من طرف إلى طرف (E2EE)** لضمان خصوصية المستخدمين، مع استخدام تقنيات **WebRTC** للاتصال المباشر و **SignalR** لإدارة الإشارات.

---

## 2. المكونات الرئيسية وأدوارها

| المكون | الدور الوظيفي | الأهمية الأمنية |
| :--- | :--- | :--- |
| **Crypto Service** | إدارة الهوية (مفتاح عام/خاص) وتشفير رسائل الإشارة. | يضمن أن خادم الإشارة لا يمكنه قراءة محتوى الاتصال. |
| **SignalR Service** | خادم الإشارة (Signaling). نقل رسائل الإعداد بين الأطراف. | يعمل كوسيط لنقل البيانات المشفرة فقط. |
| **WebRTC Service** | إنشاء وإدارة الاتصال المباشر (P2P) لنقل الوسائط. | يضمن مباشرة الاتصال وتشفير دفق الصوت/الفيديو (SRTP). |

---

## 3. مخطط تدفق البيانات (Data Flow Diagram)

يوضح المخطط التالي كيفية ترابط المكونات وانتقال البيانات بين جهاز المتصل، خادم الإشارة، وجهاز المستجيب. نلاحظ أن دفق الوسائط (الصوت/الفيديو) يتم مباشرة بين الأجهزة دون المرور بالخادم.

![مخطط تدفق البيانات](https://private-us-east-1.manuscdn.com/sessionFile/TZumPBLW9eOSF8BRjwwmtO/sandbox/hytIQETZHKQtRwflGa96R2-images_1767007056360_na1fn_L2hvbWUvdWJ1bnR1L2RhdGFfZmxvd19kaWFncmFt.png?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9wcml2YXRlLXVzLWVhc3QtMS5tYW51c2Nkbi5jb20vc2Vzc2lvbkZpbGUvVFp1bVBCTFc5ZU9TRjhCUmp3d210Ty9zYW5kYm94L2h5dElRRVRaSEtRdFJ3ZmxHYTk2UjItaW1hZ2VzXzE3NjcwMDcwNTYzNjBfbmExZm5fTDJodmJXVXZkV0oxYm5SMUwyUmhkR0ZmWm14dmQxOWthV0ZuY21GdC5wbmciLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE3OTg3NjE2MDB9fX1dfQ__&Key-Pair-Id=K2HSFNDJXOU9YS&Signature=u8yhA037NOHTlj8qp6QqhSQJ7ECXB~8Uxv-oKSb3F~6XI8M8Lk-mhvWLFpAFWfBCAOF~934v4SQkbesSZfZCJ9IJG1h~qePZvrQvTAsl8n~QTOW4I-V6fiV5wI6fxcGrLnGPQpk8H6xbk7zibNH9m~n4bKaSwvbKIjNsA7oX0hYlDupuh0dc9bzSX~QgXLDhGdl6MK23HorSx80btW5Dk96ousCZ4h0PTz5VKtmyNMLYMU2SoLfkENeAzxDd695vZg3DfsFL1Nzvm0exdI3s9GI~v0R87zQyPJBBwH8ZhuSCveczgQ4uTzYTx1qC9oJgfiB5yyHa2zT6FzhJLZ9gbg__)

---

## 4. رحلة المكالمة بالتفصيل (Step-by-Step Journey)

### المرحلة الأولى: التهيئة وتأسيس الهوية
عند تشغيل التطبيق، يتم إنشاء زوج مفاتيح (عام وخاص). يتم تخزين المفتاح الخاص بأمان على الجهاز، بينما يتم إرسال المفتاح العام إلى خادم SignalR لتعريف المستخدم.

### المرحلة الثانية: تبادل الإشارة المشفرة (Signaling)
عندما يبدأ "أحمد" مكالمة مع "فاطمة":
1.  يتم إنشاء **مفتاح سري مشترك** باستخدام (مفتاح أحمد الخاص + مفتاح فاطمة العام).
2.  يتم تشفير وصف الجلسة (SDP Offer) بهذا المفتاح.
3.  يتم إرسال العرض المشفر عبر SignalR.
4.  تقوم فاطمة بفك التشفير، إنشاء رد (Answer)، تشفيره، وإرساله مرة أخرى.

### المرحلة الثالثة: تبادل مرشحي ICE
يتبادل الطرفان عناوين IP والمنافذ المحتملة (ICE Candidates) بشكل مشفر عبر SignalR لإيجاد أفضل مسار للاتصال المباشر.

### المرحلة الرابعة: الاتصال المباشر (P2P)
بمجرد اكتمال التبادل، يبدأ WebRTC في نقل دفق الصوت والفيديو المشفر (SRTP) مباشرة بين الجهازين.

---

## 5. مخطط تسلسل المكالمة (Call Sequence Diagram)

يوضح هذا المخطط الترتيب الزمني الدقيق للرسائل والعمليات التي تحدث لإنشاء مكالمة ناجحة.

![مخطط تسلسل المكالمة](https://private-us-east-1.manuscdn.com/sessionFile/TZumPBLW9eOSF8BRjwwmtO/sandbox/hytIQETZHKQtRwflGa96R2-images_1767007056361_na1fn_L2hvbWUvdWJ1bnR1L2NhbGxfc2VxdWVuY2VfZGlhZ3JhbQ.png?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9wcml2YXRlLXVzLWVhc3QtMS5tYW51c2Nkbi5jb20vc2Vzc2lvbkZpbGUvVFp1bVBCTFc5ZU9TRjhCUmp3d210Ty9zYW5kYm94L2h5dElRRVRaSEtRdFJ3ZmxHYTk2UjItaW1hZ2VzXzE3NjcwMDcwNTYzNjFfbmExZm5fTDJodmJXVXZkV0oxYm5SMUwyTmhiR3hmYzJWeGRXVnVZMlZmWkdsaFozSmhiUS5wbmciLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE3OTg3NjE2MDB9fX1dfQ__&Key-Pair-Id=K2HSFNDJXOU9YS&Signature=JtCfRPoKZoHhUPFB0K5186WvkD4vC4cM3wvNh4DU7ktG2aqODrAYw9o~869VUjOGgCAEIzEhv1nAU4LuArBZzpc-mMl4u1uxaiRt~oqYDVM9DBeLqGAZdRa5nWhXSqhkrMk0s5-nroR7fTiEuxvt-iSOKonSOsGE9FixVbIUwhNXF31rdOfPD-lcCLQfcmeb5ZrhXL5~GdTss4UXgp-92tkh7KklTEYD3qBQO-8HvAFn-UqSw9dTZPJlV-u9KHuEiiGDtaLAo74daJKD8S3AOol8SCph2YHVqFqzxBNOi2Wux7ycCjPJJHzKPCV6UBoKYXFsLVV-dqGVCRlfm7AXgg__)

---

## 6. الخلاصة الأمنية
يضمن هذا التصميم أن:
*   **الخادم (SignalR)** لا يرى سوى بيانات مشفرة لا يمكنه فك رموزها.
*   **دفق الوسائط** لا يمر عبر الخادم، مما يقلل من زمن التأخير ويزيد من الخصوصية.
*   **الهوية الرقمية** محمية باستخدام تشفير المفتاح العام، مما يمنع هجمات انتحال الشخصية.



⚠️ This project is for academic and educational purposes only.
