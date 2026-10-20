# Backlog: chức năng chưa làm

So sánh với app Fits (fits-app.com, ảnh trên Google Play). Cập nhật 20/10/2026.

Độ khó ước lượng: **Thấp** (vài giờ), **Vừa** (1–2 ngày), **Cao** (cần dịch vụ ngoài
hoặc backend, nhiều ngày).

Lưu ý chung: chỉ học ý tưởng của Fits. Không lấy logo, sticker, hình minh họa hay
ảnh của họ.

## 1. Chức năng Fits có mà ALL_FITS chưa có

| # | Chức năng | Mô tả | Độ khó | Bắt đầu từ đâu |
|---|---|---|---|---|
| 1 | AI tự nhận diện loại, màu, mùa | Chụp ảnh món đồ thì form tự điền loại, màu, mùa | Vừa | Gửi ảnh qua `AiStylistService` (`lib/data/remote/ai_stylist_service.dart`), điền sẵn `ClothingFormScreen` |
| 2 | Tag tùy chỉnh | Người dùng tự đặt tag và lọc theo tag | Thấp–Vừa | Thêm `tags` vào `ClothingItem` (cả JSON), thêm vào bộ lọc `wardrobe_filter_sheet.dart` |
| 3 | Thêm đồ từ link web | Dán link sản phẩm, app lấy ảnh, tên, giá | Cao | Đọc thẻ `og:image` / `og:title` của trang. Cần lưu ý bản quyền ảnh |
| 4 | Nhiều ảnh cho một món | Ngoài ảnh chính có thêm ảnh phụ | Vừa | `ClothingItem.imagePath` hiện chỉ có một ảnh, cần đổi thành danh sách |
| 5 | Collections | Tab thứ ba của Fits: gom đồ hoặc outfit thành nhóm | Vừa | Model mới, thêm tab vào `lib/navigation/closet_screen.dart` |
| 6 | Danh sách đồ đi du lịch | Chọn khoảng ngày, app gộp các món cần mang | Vừa | Dựa trên dữ liệu của Planner (`PlannerController`) |
| 7 | AI Stylist dạng chat | Fits dùng khung chat (bong bóng đen/xám). Màn của mình đang là form kèm danh sách gợi ý | Vừa | Giữ `AiStylistService`, viết lại giao diện `stylist_screen.dart` |
| 8 | Sticker, kiểu tóc, đổi nền trên canvas | Thanh dưới canvas có Wardrobe / Stickers / Background | Vừa | `outfit_canvas.dart`, `outfit_builder_screen.dart`. Cần sticker tự vẽ hoặc có giấy phép |
| 9 | Thử đồ bằng AI | Tạo ảnh người mặc outfit | Cao | Cần dịch vụ tạo ảnh bên ngoài, có chi phí |
| 10 | Mạng xã hội | Hồ sơ công khai/riêng tư, bạn bè xem tủ đồ, tạo outfit giúp nhau, feed "Discover new ideas" | Cao | Cần backend cho nhiều người dùng (Supabase đã có trong `pubspec.yaml`) |

## 2. Màn Swipe outfit: đã bổ sung (20/10/2026)

Màn: `lib/features/outfits/screens/swipe_outfit_screen.dart`.

- Hình người phía sau quần áo: vẽ bằng `CustomPainter` (`_MannequinPainter`), không dùng asset.
- Chip loại con: thêm `ClothingSubcategory` (`lib/data/models/clothing_subcategory.dart`),
  chọn trong form thêm/sửa đồ (mục Type), lọc từng hàng trong màn Swipe.
- Hàng áo khoác, váy liền, phụ kiện: nút ≡ (Rows) trên app bar để bật/tắt từng hàng.
- Ảnh chưa tách nền: thay 2 ảnh mẫu (hoodie, áo dài tay) bằng ảnh tách được và thêm cutout.
  Ảnh của người dùng chưa tách nền được hiện thành thẻ bo góc.

Còn lại: hàng không khớp chính xác với ma-nơ-canh khi bật thêm hàng; người mặc đồ mẫu cũ
cần Settings → Remove sample data → Load sample wardrobe để thấy ảnh và loại con mới.

## 3. Hạn chế đã biết sau lần đổi giao diện giống Fits

- **Mất bộ lọc khi đổi tab**: chuyển giữa Clothes / Outfits / Planner trong Profile làm
  mất ô tìm kiếm và bộ lọc của Clothes (`TabBarView` hủy trang không hiển thị).
  Sửa bằng `AutomaticKeepAliveClientMixin`. Độ khó: Thấp.
- **Mất dòng đếm** ở đầu các tab: số outfit, số outfit đã lên lịch trong tháng.
- **Ô quần áo không hiện tên** (giống Fits). Nếu người dùng cần, có thể hiện tên khi
  nhấn giữ.
- **README đã cũ**: vẫn ghi Log out nằm ở Profile (giờ ở nút ≡ → Account) và ghi
  "không cần backend", trong khi commit `681ea7e` đã thêm Supabase. Cần kiểm tra lại
  dữ liệu đang lưu ở đâu rồi cập nhật README.
- **Chưa chạy dart format** cho 5 file: `home_sections.dart`, `outfit_layout.dart`,
  `outfit_builder_screen.dart`, `outfit_canvas.dart`, `test/features/outfit_canvas_test.dart`.
- **Chưa thử trên điện thoại thật**: giao diện mới mới được kiểm tra bằng test và ảnh
  render trong test.
