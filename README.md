# Secure Messaging App

# التقرير التقني الشامل: بنية الاتصال وتدفق البيانات في تطبيق الدردشة والمكالمات الآمن

**الطالبان:**
محمد سالم عبد الحفيظ (232098)
عبد العزيز عادل صولة (232112)

**الفصل:** السادس

**التاريخ:** 29 ديسمبر 2025

---

## 1. نظرة عامة على البنية المعمارية (Architecture Overview)

يعتمد التطبيق على بنية هجينة تجمع بين ثلاث تقنيات أساسية لضمان الأمان والاتصال في الوقت الفعلي:

1.  **WebRTC (Web Real-Time Communication):** وهو المسؤول عن إنشاء اتصال مباشر (Peer-to-Peer - P2P) بين المستخدمين لنقل دفق الصوت والفيديو المشفر.
2.  **SignalR (Signaling Server):** يعمل كوسيط إشارة (Signaling) لنقل رسائل الإعداد الأولية اللازمة لـ WebRTC.
3.  **End-to-End Encryption (E2EE):** يتم تطبيقه على رسائل الإشارة لضمان أن خادم SignalR لا يمكنه قراءة محتوى الاتصال.

### جدول الأدوار الرئيسية للمكونات

| المكون | الدور الوظيفي | الموقع | البيانات التي يتعامل معها |
| :--- | :--- | :--- | :--- |
| **المستخدم (المتصل/المستجيب)** | نقطة النهاية، مصدر ومستقبل البيانات. | العميل (Flutter App) | المفاتيح الخاصة، دفق الوسائط (الصوت/الفيديو). |
| **Crypto Service** | إدارة الهوية (مفتاح عام/خاص) وتشفير/فك تشفير رسائل الإشارة. | العميل (Flutter App) | المفاتيح العامة والخاصة، المفتاح السري المشترك. |
| **SignalR Service** | نقل رسائل الإشارة (Offer, Answer, ICE Candidates) بين الأطراف. | الخادم | رسائل الإشارة المشفرة فقط. |
| **WebRTC Service** | إنشاء وإدارة اتصال P2P، وجمع مرشحي ICE. | العميل (Flutter App) | وصف الجلسة (SDP)، مرشحو ICE، دفق الوسائط. |

---

## 2. المرحلة الأولى: الإعداد والتهيئة (Initialization and Identity)

تحدث هذه المرحلة عند تشغيل التطبيق، وهي حاسمة لتأسيس هوية المستخدم وقناة الاتصال بالخادم.

### 2.1. تأسيس الهوية الرقمية (CryptoService)

1.  **التحقق من المفتاح الخاص:** `CryptoService` يتحقق من وجود مفتاح خاص مخزن بأمان (`FlutterSecureStorage`).
2.  **إنشاء زوج المفاتيح:** إذا لم يوجد، يتم إنشاء زوج جديد من المفاتيح (عام وخاص) باستخدام خوارزمية تشفير قوية.
3.  **التخزين الآمن:** يتم تخزين المفتاح الخاص محلياً بشكل آمن، بينما يتم تخزين المفتاح العام في مكان يسهل الوصول إليه.

### 2.2. تأسيس قناة الإشارة (SignalR Service)

1.  **بدء الاتصال:** `SignalRService.startConnection()` تبدأ اتصال WebSocket مع خادم الإشارة.
2.  **تسجيل المستمعين:** يتم إعداد وظائف رد الاتصال (Callbacks) للتعامل مع الرسائل الواردة من الخادم.
3.  **تسجيل العميل:** بعد نجاح الاتصال، يرسل التطبيق **المفتاح العام** الخاص به إلى خادم SignalR. يقوم الخادم بربط هذا المفتاح العام بمعرف اتصال WebSocket الحالي، مما يمكنه من توجيه الرسائل إلى المستخدم الصحيح.

**النتيجة:** أصبح التطبيق الآن جاهزاً بالكامل، ولديه هوية رقمية فريدة وقناة اتصال حية وموثوقة مع الخادم.

---

## 3. المرحلة الثانية: رحلة المكالمة - تبادل الإشارة المشفرة (The Encrypted Signaling Dance)

هذه هي المرحلة التي يتم فيها التفاوض بين الطرفين (المتصل والمستجيب) لإنشاء اتصال P2P.

### 3.1. المتصل - إنشاء العرض (Offer)

1.  **بدء المكالمة:** عندما يبدأ المتصل مكالمة، يتم استدعاء `webRTCService.startCall(fatimaPublicKey)`.
2.  **إنشاء الاتصال:** يتم إنشاء كائن `RTCPeerConnection` محلي.
3.  **إنشاء العرض (SDP Offer):** يتم إنشاء وصف الجلسة (SDP) الذي يحدد قدرات جهاز المتصل.
4.  **توليد المفتاح السري المشترك:**
    *   `CryptoService` يستخدم **المفتاح الخاص للمتصل** و**المفتاح العام للمستجيب** لتوليد مفتاح سري مشترك (Shared Secret) باستخدام خوارزمية تبادل المفاتيح (ECDH).
    *   هذا المفتاح هو أساس أمان المكالمة.
5.  **تشفير العرض:** يتم تشفير SDP Offer بالكامل باستخدام المفتاح السري المشترك.
6.  **الإرسال عبر SignalR:** يتم إرسال العرض المشفر إلى المستجيب عبر `SignalRService`، مع تحديد نوع الرسالة كـ `Offer`.

### 3.2. المستجيب - استقبال العرض والرد (Answer)

1.  **استقبال العرض:** `SignalRService` على جهاز المستجيب يستقبل الرسالة المشفرة.
2.  **فك التشفير:**
    *   يستخدم المستجيب **مفتاحه الخاص** و**المفتاح العام للمتصل** لتوليد نفس المفتاح السري المشترك.
    *   يتم استخدام هذا المفتاح لفك تشفير SDP Offer.
3.  **إعداد الاتصال:** يتم إنشاء كائن `RTCPeerConnection` محلي.
4.  **تعيين الوصف البعيد:** يتم تعيين SDP Offer الذي تم فك تشفيره كوصف بعيد (`setRemoteDescription`).
5.  **إنشاء الرد (SDP Answer):** يتم إنشاء SDP Answer بناءً على قدرات المستجيب.
6.  **تشفير الرد:** يتم تشفير SDP Answer باستخدام نفس المفتاح السري المشترك.
7.  **الإرسال عبر SignalR:** يتم إرسال الرد المشفر إلى المتصل عبر `SignalRService`، مع تحديد نوع الرسالة كـ `Answer`.

### 3.3. تبادل مرشحي ICE (ICE Candidates Exchange)

تحدث هذه العملية بالتوازي مع تبادل Offer/Answer:

1.  **الجمع:** بمجرد تعيين الوصف المحلي (`setLocalDescription`) على كلا الطرفين، يبدأ WebRTC في جمع مرشحي ICE (عناوين IP والمنافذ المحتملة للاتصال).
2.  **الإرسال المشفر:** كل مرشح ICE يتم العثور عليه يتم تشفيره (باستخدام المفتاح السري المشترك) وإرساله فوراً إلى الطرف الآخر عبر SignalR.
3.  **الاستقبال والإضافة:** الطرف المستقبل يفك تشفير المرشح ويضيفه إلى `RTCPeerConnection` الخاص به (`addIceCandidate`).

---

## 4. المرحلة الثالثة: الاتصال المباشر ونقل الوسائط (P2P Media Transfer)

### 4.1. إنشاء الاتصال المباشر (NAT Traversal)

1.  **بروتوكول ICE:** يستخدم WebRTC بروتوكول ICE (Interactive Connectivity Establishment) لمحاولة إنشاء اتصال P2P باستخدام مرشحي ICE المتبادلين.
2.  **خوادم STUN/TURN:** يعتمد التطبيق على خوادم STUN و TURN لضمان نجاح الاتصال عبر جميع أنواع الشبكات وجدران الحماية.
3.  **الاتصال الناجح:** بمجرد نجاح ICE في إيجاد مسار اتصال، يتم إنشاء قناة بيانات مباشرة بين الطرفين.

### 4.2. تأمين دفق الوسائط (SRTP)

1.  **اشتقاق مفتاح SRTP:** يتم استخدام المفتاح السري المشترك الذي تم توليده في المرحلة الثانية (عبر ECDH) لاشتقاق مفاتيح التشفير والمصادقة لبروتوكول **SRTP (Secure Real-time Transport Protocol)**.
2.  **النقل المشفر:** يتم نقل دفق الصوت والفيديو بين الطرفين عبر قناة SRTP المشفرة بالكامل.
3.  **الأمان:** دفق الوسائط لا يمر عبر خادم SignalR على الإطلاق، ويتم تشفيره باستخدام مفاتيح لا يعرفها سوى الطرفان المتصلان، مما يحقق **التشفير الكامل من طرف إلى طرف (E2EE)**.

---

## 5. مخطط تدفق البيانات (Data Flow Diagram)

يوضح المخطط التالي كيفية ترابط المكونات وانتقال البيانات بين جهاز المتصل، خادم الإشارة، وجهاز المستجيب. نلاحظ أن دفق الوسائط (الصوت/الفيديو) يتم مباشرة بين الأجهزة دون المرور بالخادم.

![مخطط تدفق البيانات](https://private-us-east-1.manuscdn.com/sessionFile/TZumPBLW9eOSF8BRjwwmtO/sandbox/xHVeZ1ka5aYsUAhwvyU8p2-images_1767272787385_na1fn_L2hvbWUvdWJ1bnR1L2RhdGFfZmxvd19kaWFncmFt.png?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9wcml2YXRlLXVzLWVhc3QtMS5tYW51c2Nkbi5jb20vc2Vzc2lvbkZpbGUvVFp1bVBCTFc5ZU9TRjhCUmp3d210Ty9zYW5kYm94L3hIVmVaMWthNWFZc1VBaHd2eVU4cDItaW1hZ2VzXzE3NjcyNzI3ODczODVfbmExZm5fTDJodmJXVXZkV0oxYm5SMUwyUmhkR0ZmWm14dmQxOWthV0ZuY21GdC5wbmciLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE3OTg3NjE2MDB9fX1dfQ__&Key-Pair-Id=K2HSFNDJXOU9YS&Signature=kiSuF3-E9qJFh9E~iShQZ4paHtWq3xK7QSKcA5durRm~YtDmsebcNuJcjD7MA3GfnUJh5tBtJtIzbbHmJJXVAOOAYiAoX1PAk6wXVjnp4UhjSvscBEI2u1e-5P1eWFSk5qPZvqS435l9CKR4d7dDDX4xaXah-fbtGcsarrLzaZbkk2mvk06IMwxVSqyEQxoSZUFqYrS6ncG1BcWodXl5jqfYUdrLt45ddXTN2m3MX9y5oKFbz54YLpJvU9XyH5jbbCpb0~6HTn56dsHtyjrHHev82wC9qJYWm4Lns1RuLRuZaMUOvkWSY3VcmY8c7F0A3JXqDcgX5UD-5OkNEqw7mw__)

---

## 6. مخطط تسلسل المكالمة (Call Sequence Diagram)

يوضح هذا المخطط الترتيب الزمني الدقيق للرسائل والعمليات التي تحدث لإنشاء مكالمة ناجحة.

![مخطط تسلسل المكالمة](https://private-us-east-1.manuscdn.com/sessionFile/TZumPBLW9eOSF8BRjwwmtO/sandbox/xHVeZ1ka5aYsUAhwvyU8p2-images_1767272787385_na1fn_L2hvbWUvdWJ1bnR1L2NhbGxfc2VxdWVuY2VfZGlhZ3JhbQ.png?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9wcml2YXRlLXVzLWVhc3QtMS5tYW51c2Nkbi5jb20vc2Vzc2lvbkZpbGUvVFp1bVBCTFc5ZU9TRjhCUmp3d210Ty9zYW5kYm94L3hIVmVaMWthNWFZc1VBaHd2eVU4cDItaW1hZ2VzXzE3NjcyNzI3ODczODVfbmExZm5fTDJodmJXVXZkV0oxYm5SMUwyTmhiR3hmYzJWeGRXVnVZMlZmWkdsaFozSmhiUS5wbmciLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE3OTg3NjE2MDB9fX1dfQ__&Key-Pair-Id=K2HSFNDJXOU9YS&Signature=gQlAzOqQ0bk9XiTmRHRX1AsaPGaQnUvVSIy~bAGyPki5aSfRr8uoH5JC0vxcPVUcj0ZUbrWrcC~rMqrXPOWhS1Op8B65T8fd6oVIQf1vxucgMYiuP0oVlzxGfFEMh9vTVSj44FCdv6-n58jbO1dLIJIvyfBeB5zk-mkN~X6TYBeS-oQJEf9AxXgCLGGfP2S0sjI2OFlzxGiJGwcBq4trX8dhivt4lIQCnmDjXTpYVc03XdCWquOaE6G750Cu05hWfw17jmUUHI5vh9ASM1wCrlQJkwrROTdiOMO3S77KTFBb8QGpM1qFMXQO8QQQtMLBCbG2HGq548VlmpMgHfB4aQ__)

---

## 7. الخلاصة الأمنية

يضمن هذا التصميم ما يلي:
*   **الخادم (SignalR)** لا يرى سوى بيانات مشفرة لا يمكنه فك رموزها.
*   **دفق الوسائط** لا يمر عبر الخادم، مما يقلل من زمن التأخير ويزيد من الخصوصية.
*   **الهوية الرقمية** محمية باستخدام تشفير المفتاح العام، مما يمنع هجمات انتحال الشخصية.

---
