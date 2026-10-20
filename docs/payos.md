# Thanh toán Premium qua payOS

Premium có giá 2.000đ cho 30 ngày, trả bằng chuyển khoản hoặc VietQR qua payOS.
Hết 30 ngày thì Premium tự tắt, không tự trừ tiền lại. Trả thêm lần nữa sẽ cộng tiếp
30 ngày.

## Cách hoạt động

1. App gọi Edge Function `payos/create`. Function tạo đơn trong bảng `payments`, xin
   link thanh toán từ payOS rồi trả link về app.
2. App mở link đó trong trình duyệt. Từ trang này người dùng có thể mở thẳng app ngân hàng.
3. App hiện hộp thoại "Waiting for payment". Cứ 3 giây, và mỗi lần người dùng quay lại
   app, nó gọi `payos/status` để hỏi payOS trạng thái đơn.
4. Khi đơn chuyển sang PAID, server gọi hàm SQL `mark_payment_paid` để cộng 30 ngày
   vào bảng `subscriptions`. Webhook của payOS cũng gọi hàm này. Hàm chỉ tính lần gọi
   đầu tiên, nên không cộng ngày hai lần.
5. App đọc lại gói từ bảng `subscriptions`.

Khoá payOS chỉ nằm trên server. Chỉ Edge Function được ghi vào `payments` và
`subscriptions`, nên người dùng không tự bật Premium được.

Khi chạy không có Supabase (chưa điền `SUPABASE_URL`, hoặc trong test), app vẫn dùng
nút Premium demo như trước, không thu tiền.

## Cài đặt (làm một lần)

1. **Lấy khoá payOS.** Vào https://my.payos.vn, tạo kênh thanh toán gắn với tài khoản
   ngân hàng nhận tiền, rồi chép **Client ID**, **API Key** và **Checksum Key**.
2. **Tạo bảng.** Mở Supabase Dashboard → SQL Editor, dán toàn bộ `supabase/schema.sql`
   rồi bấm Run. File này chạy lại nhiều lần vẫn an toàn.
3. **Deploy function.** Chạy ở thư mục gốc của project:

   ```sh
   npx supabase login
   npx supabase secrets set --project-ref xglqmbspaczcizmbycvm \
     PAYOS_CLIENT_ID=... PAYOS_API_KEY=... PAYOS_CHECKSUM_KEY=...
   npx supabase functions deploy payos --no-verify-jwt --project-ref xglqmbspaczcizmbycvm
   ```

   Phải có `--no-verify-jwt`, vì payOS gọi webhook mà không kèm token Supabase. Hai
   đường `create` và `status` vẫn tự kiểm tra token của người dùng.
4. **Đăng ký webhook.** Trong my.payos.vn → kênh thanh toán → Webhook, nhập
   `https://xglqmbspaczcizmbycvm.supabase.co/functions/v1/payos/webhook` rồi lưu.
   payOS sẽ gửi một lệnh thử, function trả về 200 là được.
5. **Thử.** Mở app → Premium → Upgrade, rồi chuyển khoản 2.000đ thật.

## Đổi giá hoặc số ngày

Đặt secret `PREMIUM_PRICE_VND` và `PREMIUM_DAYS` cho function (mặc định 2000 và 30),
rồi sửa `AppConfig.premiumPriceVnd` và `AppConfig.premiumDays` cho khớp. App chỉ dùng
hai giá trị này để hiển thị, còn số tiền thực thu do server quyết định.

## Gỡ lỗi

- **App báo "Payment service is unavailable".** Xem log ở Dashboard → Edge Functions →
  payos → Logs. Thường là thiếu secret, hoặc payOS trả mã lỗi (sai khoá, sai chữ ký).
- **Đã trả tiền nhưng app chưa lên Premium** (thường do đã đóng hộp thoại chờ). Thoát
  hẳn app rồi mở lại: gói được đọc lại từ bảng `subscriptions` mỗi lần mở app. Nếu vẫn
  chưa có, xem bảng `payments` để biết đơn đó còn PENDING hay đã PAID.
- **Kiểm tra chữ ký** (sau khi sửa `signature.ts`): chạy
  `node supabase/functions/payos/signature_test.ts`.
