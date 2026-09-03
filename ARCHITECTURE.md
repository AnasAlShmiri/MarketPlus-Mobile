# MarketPlus.Mobile Architecture

## هدف النسخة

تطبيق Flutter عربي RTL للكاشير والمدير، متصل مباشرة بـ `MarketPlus.API` ويغطي متطلبات W8:

- Architecture
- Screens
- Navigation
- API Integration

مع شرط تشغيل أساسي: **الباركود الموجود في الكتالوج المحلي لا ينتظر الشبكة بعد اكتشافه بالكاميرا**.

---

## الطبقات

```text
UI / Screens
    ↓
AppSession + ProductCatalog
    ↓
Repositories
    ↓
ApiClient (Dio + PersistCookieJar)
    ↓
ASP.NET Core MarketPlus.API
    ↓
Application Services / EF Core / SQL Server
```

### `core/`
- Design System والألوان والمسافات.
- `ApiClient` وtimeouts ومعالجة الأخطاء.
- Identity Cookie محفوظة في `PersistCookieJar`، ولا يتم تخزين كلمة المرور.

### `data/`
- Models.
- Repositories.
- `ProductSource` abstraction لاختبار الكاش بدون شبكة.

### `state/`
- `AppSession`: المستخدم، الصلاحيات، السلة وحالة الدخول.
- `ProductCatalog`: فهرس المنتجات المحلي والمزامنة.

### `screens/`
- Login
- Home
- Sale / Scanner
- Cart / Checkout
- Products
- Debts
- Invoice
- Settings

---

## Fast Barcode Path

عند تسجيل الدخول:

1. التطبيق يجلب `GET /api/products` مرة واحدة.
2. يبني في الذاكرة:

```dart
Map<String, Product> byBarcode
```

3. يحفظ نسخة JSON محلية عبر `SharedPreferences`.
4. عند إعادة فتح التطبيق يتم Hydrate للكاش قبل بدء الاستخدام.

عند المسح:

```text
Camera decodes barcode
        ↓
Normalize barcode
        ↓
Map lookup O(1)
        ↓
Add to cart
        ↓
Haptic + visual feedback
```

إذا لم يوجد الباركود محليًا فقط:

```text
GET /api/products/barcode/{barcode}
        ↓
Cache product
        ↓
Add to cart
```

### Performance Budget

الهدف المقاس في Debug داخل `SaleScreen`:

```text
[SCAN] barcode=... source=memory scan-to-cart=XXms
```

- Memory cache lookup + cart mutation: target `< 100ms`.
- Total camera-to-visible-product: target `< 1000ms` على جهاز Android متوسط وفي إضاءة جيدة.
- API fallback ليس جزءًا من ضمان المسار السريع لأنه يعتمد على Wi-Fi والخادم.

لا يتم الادعاء بتحقيق الرقم النهائي قبل قياسه على هاتف فعلي.

---

## Session & Security

- Backend الحالي يستخدم ASP.NET Core Identity Cookie.
- Flutter يستخدم `Dio + dio_cookie_manager + PersistCookieJar`.
- الجلسة تستعاد عبر `GET /api/auth/me`.
- كلمة المرور لا تحفظ محليًا.
- 401/403 تتحول إلى رسائل واضحة للمستخدم.
- الإنتاج يجب أن يستخدم HTTPS.

---

## Role-Aware UX

### Admin
- Dashboard stats.
- Products.
- Debts.
- Settle debt.
- Sale.

### Cashier
- Sale.
- Products lookup.
- Debts read-only.
- لا يتم استدعاء `GET /api/dashboard/stats` لأنه Admin-only.

---

## Inventory Consistency

بعد نجاح `POST /api/invoices`:

1. الخادم هو المصدر النهائي للحقيقة.
2. Flutter يطبق نفس الخصم على `ProductCatalog` المحلي فورًا.
3. يمنع التطبيق زيادة كمية السلة فوق `stockQuantity` المحلي.
4. أي تعارض حقيقي متعدد الأجهزة يجب أن يرفضه الـBackend أثناء إنشاء الفاتورة.

---

## Navigation

`go_router`:

```text
/login
/home
/sale
/products
/debts
/settings
/cart
/invoice/:id
```

الشاشات اليومية داخل `AppShell` وتستخدم Bottom Navigation ثابتة.

---

## API Contract Used

```text
POST /api/auth/login
GET  /api/auth/me
POST /api/auth/logout

GET  /api/products
GET  /api/products/barcode/{barcode}

POST /api/invoices
GET  /api/invoices/{id}
GET  /api/invoices/debts
PUT  /api/invoices/{id}/settle   (Admin)

GET  /api/dashboard/stats        (Admin)
POST /api/whatsapp/link
```

---

## Quality Gates قبل التسليم

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --profile --dart-define=API_BASE_URL=http://<PC-IP>:5000
```

### Device QA

- 30 عملية مسح لباركود موجود في الكاش.
- 5 عمليات لنفس المنتج مع تحريك المنتج خارج/داخل الإطار.
- مسح منتج نافد.
- API متوقف مع وجود كاش.
- API متوقف بدون كاش.
- Cashier login.
- Admin login.
- بيع نقدي.
- بيع آجل برقم يمني.
- فتح فاتورة وWhatsApp.
- إغلاق التطبيق وإعادة فتحه للتحقق من استعادة الجلسة والكاش.
