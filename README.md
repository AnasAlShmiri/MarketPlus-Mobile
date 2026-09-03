# MarketPlus.Mobile — Flutter W8 High-Fidelity

تطبيق الموبايل الرسمي لمشروع **ماركت بلس**، مبني كنسخة POS حقيقية مرتبطة بـ `MarketPlus.API` وليس Demo ببيانات وهمية.

يغطي متطلبات الدكتور الأربعة مباشرة:

1. **Architecture** — فصل `core`, `data`, `state`, `screens` مع Repository Pattern وProduct Source abstraction.
2. **Screens** — Login, Home, Sale/Scanner, Cart/Checkout, Products, Debts, Invoice, Settings.
3. **Navigation** — `go_router` + Bottom Navigation عربية RTL.
4. **API Integration** — اتصال مباشر مع ASP.NET Core API باستخدام Dio وASP.NET Identity Cookie.

راجع أيضًا: [`ARCHITECTURE.md`](ARCHITECTURE.md)

---

## Fast Barcode Architecture

التطبيق لا يرسل HTTP request عند كل مسح إذا المنتج موجود في الكتالوج المحلي.

بعد تسجيل الدخول:

```text
GET /api/products
      ↓
ProductCatalog
      ↓
Map<String, Product> indexed by barcode
      ↓
Persistent local cache
```

عند المسح:

```text
Camera decode → O(1) local barcode lookup → add to cart → haptic/visual feedback
```

فقط إذا لم يوجد الباركود محليًا يتم استخدام:

```text
GET /api/products/barcode/{barcode}
```

في وضع Debug يظهر قياس حقيقي:

```text
[SCAN] barcode=... source=memory scan-to-cart=XXms
```

### Performance Target

- `scan-to-cart` بعد فك الكاميرا للباركود: **أقل من 100ms** عند Cache Hit.
- Camera-to-visible-product: **هدف أقل من ثانية** على هاتف Android متوسط وإضاءة جيدة.
- الرقم النهائي يجب قياسه على جهاز حقيقي؛ لا يتم اعتباره ناجحًا قبل Device QA.

---

## التشغيل لأول مرة

```powershell
cd MarketPlus.Mobile
.\tool\bootstrap.ps1
```

السكربت يقوم بـ:

- إنشاء ملفات Android/iOS.
- تجهيز Camera permission.
- السماح بـ HTTP المحلي في Android Debug فقط.
- `flutter pub get`.
- `flutter analyze`.

ثم شغل الـ API في نافذة منفصلة:

```powershell
cd ..
dotnet run --project .\MarketPlus.API\MarketPlus.API.csproj --urls http://0.0.0.0:5000
```

### Android Emulator

```powershell
cd MarketPlus.Mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

### هاتف Android حقيقي

استخدم IPv4 للكمبيوتر داخل نفس شبكة Wi-Fi، مثال:

```powershell
ipconfig
```

ثم:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000
```

> للإنتاج استخدم HTTPS. السماح بـ cleartext HTTP موجود في Android Debug فقط لتطوير الشبكة المحلية.

---

## Quality Gates

قبل اعتبار النسخة جاهزة للتسليم:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --profile --dart-define=API_BASE_URL=http://<PC-IP>:5000
```

ثم اختبر 30 عملية Barcode Scan فعلية وسجل زمن `[SCAN]`.

---

## API المستخدمة

- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/auth/logout`
- `GET /api/products`
- `GET /api/products/barcode/{barcode}`
- `POST /api/invoices`
- `GET /api/invoices/{id}`
- `GET /api/invoices/debts`
- `PUT /api/invoices/{id}/settle` — Admin only
- `GET /api/dashboard/stats` — Admin only
- `POST /api/whatsapp/link`

---

## Authentication

الـBackend يستخدم **ASP.NET Core Identity Cookie** وليس JWT.

Flutter يستخدم:

```text
Dio
+ dio_cookie_manager
+ PersistCookieJar
```

الجلسة تحفظ في مساحة التطبيق وتستعاد عبر `/api/auth/me`، ولا يتم تخزين كلمة المرور.

---

## Offline-friendly Product Lookup

المنتجات تحفظ محليًا كنسخة Cache.

إذا توقف API بعد أن تمت المزامنة سابقًا:

- البحث في المنتجات يستمر.
- مسح الباركود الموجود في الكاش يستمر بالظهور فورًا.
- إنشاء الفاتورة نفسها يحتاج عودة الاتصال لأن الخادم هو المصدر النهائي للحفظ والمخزون.

---

## Role-aware UI

### Cashier

- البيع والمسح.
- المنتجات.
- عرض الديون.
- السلة والفاتورة وWhatsApp.

### Admin

- كل ما سبق.
- Dashboard statistics.
- تسجيل سداد الدين.

التطبيق لا يستدعي `/api/dashboard/stats` للكاشير لأن الـBackend يمنعه بصلاحية Admin.


deepseek-v4-pro