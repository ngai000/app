# Nhật Ký Của Tôi 📔

Ứng dụng nhật ký cá nhân — viết nhật ký, ghi chú điều quan trọng, đánh giá tâm trạng mỗi ngày, và tìm lại kỷ niệm cũ theo tâm trạng. Toàn bộ dữ liệu lưu **ngay trên máy bạn** (không gửi lên internet, không cần tài khoản).

## Tính năng
- **📔 Nhật ký**: viết nhiều trang nhật ký, mỗi trang có tiêu đề, nội dung, ngày và tâm trạng (5 mức, từ 😢 đến 😄). Sửa/xoá bất cứ lúc nào.
- **🌤️ Hôm nay**: đánh giá nhanh tâm trạng trong ngày + ghi chú ngắn, có dải lịch sử 14 ngày và bộ đếm "🔥 ngày liên tiếp".
- **📌 Ghi chú**: ghi lại điều quan trọng, có thể đánh dấu ⭐ để ưu tiên.
- **🔍 Tìm kiếm**: tìm theo từ khoá và lọc theo tâm trạng để xem lại đúng những ngày vui/buồn.

## Cách dùng ngay trên điện thoại Android (không cần cài gì)
1. Giải nén file zip này.
2. Chép cả thư mục vào điện thoại (qua cáp USB, Google Drive, Zalo gửi file cho chính mình...).
3. Dùng **trình quản lý file** trên điện thoại, mở file `index.html` bằng **Chrome**.
4. App chạy đầy đủ tính năng ngay trong Chrome. Nhấn menu (⋮) → **"Thêm vào Màn hình chính"** để có icon riêng, mở lên như một app thật (toàn màn hình, có icon quyển sổ tay).

> Lưu ý: vì đây là app "web" chạy độc lập trên máy (không có server), dữ liệu được lưu trong bộ nhớ trình duyệt của điện thoại. Nếu bạn xoá dữ liệu Chrome hoặc dùng trình duyệt khác, nhật ký cũ sẽ không hiện ra ở đó — nên tránh xoá cache/dữ liệu Chrome nếu muốn giữ nhật ký lâu dài.

## Về file .apk
Mình **chưa thể build ra file .apk thật** ở bước này, vì môi trường hiện tại không có Android SDK/Gradle và không có kết nối mạng để tải các công cụ build Android. Thay vào đó mình đã đóng gói app dưới dạng **Progressive Web App (PWA)** — dùng ngay như hướng dẫn ở trên, trải nghiệm gần như 1 app thật (icon riêng, chạy toàn màn hình, hoạt động offline).

Nếu bạn vẫn muốn có file `.apk` cài đặt thật, có 2 cách đơn giản, bạn tự làm trong vài phút:

**Cách 1 – Dùng PWABuilder (miễn phí, không cần biết lập trình)**
1. Upload thư mục này lên một nơi có thể truy cập qua link công khai, ví dụ GitHub Pages, Netlify Drop (netlify.com/drop), hoặc Vercel — chỉ cần kéo-thả thư mục vào là có link.
2. Vào https://www.pwabuilder.com, dán link vừa có.
3. Chọn "Package for Android" → tải file `.apk` (hoặc `.aab`) về.

**Cách 2 – Dùng Android Studio (nếu bạn có máy tính)**
1. Tạo project Android mới với 1 `WebView` full màn hình.
2. Copy toàn bộ thư mục `nhatky-app` vào `assets/`.
3. Cho `WebView` load `file:///android_asset/index.html`.
4. Build → Generate Signed APK.

Nếu muốn, lần sau bạn cứ nhắn mình phần "host thử link công khai" hoặc muốn mình chỉnh sửa thêm tính năng — mình chỉnh trực tiếp trong file `index.html` giúp bạn.

## Cấu trúc file
```
nhatky-app/
├── index.html      ← toàn bộ app (giao diện + logic)
├── manifest.json   ← cấu hình PWA (icon, tên app...)
├── sw.js           ← service worker giúp app chạy offline
├── icons/          ← icon app
└── README.md       ← file này
```
