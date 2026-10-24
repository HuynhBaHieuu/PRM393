# Cách hoạt động của 10 chức năng sắp làm

Tài liệu này mô tả 10 chức năng ALL_FITS dự định làm thêm, học theo ý tưởng của app Fits. Các chức năng này chưa có trong app. Mỗi phần kể lại người dùng sẽ làm gì, app làm gì ở phía sau, và bản miễn phí khác bản Premium thế nào.

Các giới hạn miễn phí ghi ở đây là đề xuất, nhóm có thể đổi.


## 1. AI tự nhận diện món đồ

Khi bạn thêm một món đồ bằng ảnh, AI nhìn ảnh và tự điền giúp loại đồ, loại con, màu, mùa, và gợi ý tên, hãng. Bạn không phải chọn từng mục bằng tay nữa.

Cách dùng:
1. Bấm nút + ở giữa thanh dưới, chọn "Add clothes".
2. Chụp ảnh hoặc chọn ảnh có sẵn.
3. Dưới ảnh hiện dòng "Đang nhận diện…". Sau vài giây, các ô trong form được điền sẵn. Ô nào do AI điền có một dấu nhỏ bên cạnh.
4. Kiểm tra lại, sửa nếu AI đoán sai. Nếu không vừa ý, bấm "Hoàn tác" để trả các ô về như trước.
5. Bấm "Save" như bình thường.

App làm gì phía sau: app thu nhỏ ảnh rồi gửi lên dịch vụ AI, nhận lại câu trả lời và điền vào form. AI chỉ điền những ô bạn còn để trống, không ghi đè thứ bạn đã gõ. Nếu bạn đổi sang ảnh khác, app nhận diện lại từ đầu.

Về quyền riêng tư: chức năng này gửi ảnh của bạn lên máy chủ AI. Lần đầu dùng, app hỏi bạn có đồng ý không. Bạn có thể tắt chức năng này trong Settings bất cứ lúc nào.

Miễn phí và Premium: bản miễn phí được nhận diện 5 lần mỗi tháng, Premium không giới hạn.

Khi có lỗi: nếu mất mạng, AI trả lời quá lâu, hoặc ảnh không có món đồ nào, app báo "Không nhận diện được, hãy điền tay" và bạn vẫn điền form bình thường.


## 2. Tag tùy chỉnh (Huy)

Bạn tự đặt nhãn cho quần áo theo cách của mình, ví dụ "đồ đi học", "vintage", "cần giặt", rồi lọc tủ đồ theo các nhãn đó.

Cách dùng:
1. Khi thêm hoặc sửa một món đồ, tìm mục "Tags".
2. Gõ tên tag rồi bấm Enter. Tag hiện thành một ô nhỏ, bấm dấu × để bỏ.
3. Khi gõ, app gợi ý những tag bạn đã từng dùng.
4. Trong tab Clothes, mở bộ lọc và chọn một hoặc nhiều tag. Chỉ những món có đủ các tag đã chọn mới hiện ra.
5. Ô tìm kiếm cũng tìm được theo tag.
6. Muốn đổi tên hoặc xóa một tag cho mọi món cùng lúc, vào Account, Settings, "Manage tags".

App làm gì phía sau: app bỏ khoảng trắng thừa và dấu # ở đầu, và coi "Vintage" với "vintage" là một tag. Khi đổi tên một tag thành tên đã có, hai tag được gộp làm một.

Miễn phí và Premium: bản miễn phí được 5 tag khác nhau, Premium không giới hạn. Nếu hết Premium, các tag đã có vẫn dùng bình thường, chỉ không tạo thêm được.


## 3. Thêm đồ từ link web (NLGbao)

Bạn thấy một món đồ trên trang bán hàng, dán link vào app, app tự lấy ảnh, tên, hãng và giá để tạo món đồ.

Cách dùng:
1. Bấm nút +, chọn "Add clothes", rồi chọn "Từ link web".
2. Dán link sản phẩm, bấm "Lấy thông tin".
3. Đợi một chút (tối đa khoảng 15 giây, có nút Hủy).
4. Nếu trang có nhiều ảnh, chọn một ảnh làm ảnh chính.
5. Form thêm đồ hiện ra với ảnh, tên, hãng, giá đã điền sẵn. Nếu có chức năng AI nhận diện ở mục 1, loại đồ và màu cũng được điền luôn.
6. Kiểm tra lại rồi bấm "Save".

App làm gì phía sau: app mở trang web, đọc phần thông tin sản phẩm mà các shop thường để sẵn cho Google và mạng xã hội, rồi tải ảnh về. Món đồ lưu kèm link gốc, nên sau này bạn có thể mở lại trang sản phẩm từ màn chi tiết. Nếu giá ghi bằng đơn vị tiền khác, app giữ nguyên con số và ghi đơn vị gốc vào phần ghi chú, không tự đổi tỷ giá.

Về bản quyền: ảnh sản phẩm thuộc về shop. Ảnh lấy từ web chỉ dùng trong tủ đồ của riêng bạn, không được đăng công khai.

Miễn phí và Premium: dùng miễn phí. Món thêm từ link vẫn tính vào giới hạn số món của bản miễn phí, như thêm đồ bình thường.

Khi có lỗi: một số trang không đọc được, ví dụ trang bắt đăng nhập hoặc trang chặn ứng dụng. Khi đó app báo "Không đọc được trang này" và cho bạn chọn ảnh bằng tay, vẫn giữ link đã dán.


## 4. Nhiều ảnh cho một món (quân)

Ngoài ảnh chính, mỗi món đồ có thể có thêm ảnh phụ, ví dụ mặt sau, chi tiết đường may, nhãn mác.

Cách dùng:
1. Khi thêm hoặc sửa món đồ, phía trên form có một hàng ảnh: ảnh chính, các ảnh phụ, và nút +.
2. Bấm + để chụp hoặc chọn thêm ảnh.
3. Nhấn giữ một ảnh phụ để chọn "Đặt làm ảnh chính" hoặc "Xóa".
4. Ở màn chi tiết món đồ, vuốt ngang để xem lần lượt các ảnh. Bấm vào ảnh để xem toàn màn hình và phóng to.

App làm gì phía sau: ảnh phụ chỉ để xem. Lưới tủ đồ, màn ghép outfit và màn vuốt outfit vẫn dùng ảnh chính đã tách nền. Khi bạn đổi ảnh chính, app tách nền lại cho ảnh mới. Khi xóa món đồ, mọi ảnh của món đó đều bị xóa theo.

Miễn phí và Premium: bản miễn phí chỉ có ảnh chính. Premium được thêm tối đa 4 ảnh phụ mỗi món. Hết Premium thì vẫn xem được ảnh phụ cũ, chỉ không thêm ảnh mới.


## 5. Collections (bảo)

Collection là một nhóm do bạn tự đặt, gom cả quần áo lẫn outfit, ví dụ "Đi biển", "Đồ đi làm", "Muốn mua".

Cách dùng:
1. Vào Profile, chọn tab "Collections" (nằm giữa Outfits và Planner).
2. Bấm "New collection", đặt tên.
3. Mở collection, bấm "Add" để chọn nhiều món đồ hoặc outfit cùng lúc.
4. Cũng có thể thêm từ chỗ khác: ở màn chi tiết của một món đồ hoặc outfit, chọn "Add to collection" rồi tích vào một hoặc nhiều collection.
5. Trong menu của collection, bạn đổi tên, chọn ảnh bìa, hoặc xóa collection.

App làm gì phía sau: mỗi collection hiện thành một ô có ảnh bìa ghép từ 4 món, kèm số món và số outfit. Xóa collection không xóa quần áo hay outfit bên trong. Khi bạn xóa hẳn một món đồ hay outfit, nó tự biến mất khỏi mọi collection. Món đã lưu trữ vẫn nằm trong collection nhưng hiện mờ.

Miễn phí và Premium: bản miễn phí được 3 collection, Premium không giới hạn.


## 6. Danh sách đồ mang đi du lịch (nlgbao)

Bạn lên outfit cho từng ngày của chuyến đi, app gom tất cả thành danh sách đồ cần xếp vào vali.

Cách dùng:
1. Vào Planner, bấm "Plan a trip".
2. Đặt tên chuyến đi, chọn ngày đi và ngày về, nhập thành phố nếu muốn xem thời tiết.
3. Màn tiếp theo có mỗi ngày một dòng, kèm dự báo thời tiết. Bấm vào từng ngày để chọn outfit có sẵn, tạo outfit mới, hoặc dùng màn vuốt outfit. Bạn cũng có thể nhờ AI Stylist gợi ý outfit cho cả chuyến.
4. Mở "Packing list". App liệt kê mọi món cần mang, chia theo loại (áo, quần, giày…). Món nào mặc nhiều ngày thì ghi "mặc 3 ngày".
5. Tích vào món đã xếp vào vali. Thanh tiến độ cho biết đã xếp bao nhiêu món.
6. Thêm các thứ không phải quần áo, như đồ ngủ hay sạc điện thoại, bằng cách gõ chữ.
7. Bấm "Sao chép danh sách" để dán vào ghi chú hoặc gửi cho bạn bè.

App làm gì phía sau: các outfit của chuyến đi cũng được đưa vào lịch như lên lịch bình thường, nên màn Home và Planner hiện đúng outfit của ngày đó. Trên lịch, những ngày thuộc chuyến đi có một dải màu và tên chuyến. Dự báo thời tiết chỉ có cho khoảng 16 ngày tới; ngày xa hơn ghi "chưa có dự báo".

Miễn phí và Premium: bản miễn phí có 1 chuyến đi chưa kết thúc tại một thời điểm, Premium không giới hạn. Phần nhờ AI gợi ý tính vào lượt AI của mục 7.

Lưu ý: một chuyến đi dài tối đa 30 ngày. Nếu một ngày trong chuyến đã có outfit lên lịch từ trước, app hỏi bạn muốn giữ hay thay. Khi xóa chuyến đi, app hỏi có xóa luôn các outfit đã lên lịch cho chuyến đó không.


## 7. AI Stylist dạng chat

Thay vì điền form như hiện tại, bạn trò chuyện với một stylist ảo. Bạn hỏi "Tối nay đi hẹn hò mặc gì?", stylist trả lời và gửi kèm outfit ghép từ chính tủ đồ của bạn.

Cách dùng:
1. Bấm nút +, chọn "AI Stylist".
2. Màn chat hiện lời chào và vài gợi ý nhanh như "Đi làm", "Hẹn hò", "Trời mưa", "Cuối tuần". Bấm một gợi ý, hoặc tự gõ câu hỏi.
3. Tin nhắn của bạn nằm bên phải, nền đen. Câu trả lời của stylist nằm bên trái, nền xám, có thể kèm 1 đến 3 outfit.
4. Mỗi outfit có nút "Save outfit" để lưu ngay, và "Edit" để chỉnh trước khi lưu.
5. Bạn có thể hỏi tiếp, ví dụ "đổi giày khác" hay "ấm hơn chút", stylist sẽ sửa outfit vừa gợi ý.

App làm gì phía sau: mỗi lần bạn gửi tin, app gửi kèm danh sách quần áo (chỉ thông tin chữ, không gửi ảnh) và thời tiết hôm nay nếu bạn đã chọn thành phố. Stylist chỉ được dùng đồ có trong tủ của bạn. Nếu nó nhắc tới món không có thật, app tự bỏ món đó đi. App chỉ nhớ 10 lượt nói chuyện gần nhất. Trong bản đầu, đóng màn chat là mất cuộc trò chuyện.

Stylist sẽ có tên và hình đại diện riêng do nhóm thiết kế, không dùng lại nhân vật của Fits.

Miễn phí và Premium: hiện AI Stylist chỉ dành cho Premium. Đề xuất cho bản miễn phí dùng thử 3 tin nhắn mỗi ngày, Premium không giới hạn.

Khi có lỗi: nếu gửi không được, tin nhắn hiện thông báo lỗi và nút "Thử lại". Nếu tủ đồ còn quá ít, stylist nhắc bạn thêm đồ và có nút "Add clothes".


## 8. Sticker, kiểu tóc và đổi nền khi ghép outfit (huy)

Khi ghép outfit trên bảng, bạn có thể thêm sticker trang trí, gắn kiểu tóc, và đổi màu nền cho outfit đẹp hơn.

Cách dùng:
1. Mở màn tạo hoặc sửa outfit.
2. Thanh dưới có ba nút: "Wardrobe" để thêm quần áo như hiện tại, "Stickers" để thêm sticker và kiểu tóc, "Background" để đổi màu nền.
3. Bấm một sticker, nó hiện giữa bảng. Kéo để di chuyển, dùng hai ngón tay để phóng to và xoay, giống như với quần áo.
4. Nhấn giữ sticker để đưa lên trên, đưa xuống dưới, hoặc xóa.
5. Chọn một màu nền: trắng, kem, hồng nhạt, xanh nhạt, đen…

App làm gì phía sau: outfit lưu lại vị trí sticker và màu nền, nên ở mọi nơi hiện outfit (Home, Planner, danh sách outfit, màn chi tiết) đều thấy giống hệt. Sticker không được tính vào số món của outfit.

Về nguồn sticker: không dùng sticker của Fits. Nhóm tự vẽ, hoặc dùng bộ biểu tượng miễn phí có giấy phép cho phép và ghi nguồn trong màn giấy phép của app.

Miễn phí và Premium: bản miễn phí có khoảng 10 sticker, 3 kiểu tóc và mọi màu nền. Premium mở toàn bộ. Hết Premium thì sticker đã đặt vẫn còn, chỉ không thêm được sticker Premium mới.


## 9. Thử đồ bằng AI

App tạo một bức ảnh người mặc outfit bạn đã ghép, để bạn hình dung khi mặc lên trông thế nào. Cách làm học theo màn "AI Try On" của Fits.

Cách dùng:
1. Mở một outfit và bấm "Try on", hoặc bấm ô "AI Try On" ở Home. Từ Home, bước đầu là màn "Select clothes to try on": lọc theo Tops, Bottoms, Shoes, Outerwear, Full Body, Accessories, chọn tối đa 5 món, món đã chọn hiện ở khay dưới (bấm × để bỏ), rồi bấm "Next".
2. Lần đầu, màn "Try on profile" giải thích cách hoạt động. Bạn thêm ảnh selfie, ảnh toàn thân (không bắt buộc) và chọn dáng người (Nam/Nữ, S/M/L, chân ngắn/dài). Bấm "Continue" nghĩa là đồng ý gửi ảnh cho dịch vụ AI. Nếu không muốn gửi ảnh, bấm "Use an AI model instead" để dùng người mẫu AI theo dáng người đã chọn.
3. Màn thử đồ hiện các món đã chọn bị làm mờ, nút "Generate image" và số lượt còn lại. Hàng nút bên dưới cho đổi: Background (Studio, Brick wall, NYC Subway, Tokyo Night, Skatepark, Café, Paris, Old town, Beach), Clothes, Fast/Quality (Quality chậm gấp đôi nhưng đẹp hơn), Prompt (ghi thêm yêu cầu, ví dụ "Oversized fit") và người mặc (bạn hoặc người mẫu AI).
4. Đợi khoảng 20 đến 60 giây. Bạn có thể rời màn hình, khi xong app báo "Your AI try-on is ready" kèm nút "View".
5. Xem ảnh kết quả, có nhãn "AI-generated image". Giữ tay lên ảnh để xem lại các món đồ. Bấm "Try again" để tạo lại, "Save" để lưu vào thư viện ảnh, "Share" để chia sẻ, hoặc "Delete". Đổi bất kỳ lựa chọn nào thì quay về nút "Generate image".
6. Các ảnh đã tạo được giữ trong mục "Try-on" của outfit đó. Bấm vào một ảnh để mở lại.
7. Ảnh selfie, ảnh toàn thân và dáng người xem, thay hoặc xóa trong Account, Settings, "Try on profile" (hoặc bấm ảnh đại diện ở màn chọn đồ). Ở đây có thêm ô "Additional prompt" để tả ngoại hình (tối đa 300 ký tự, ví dụ "đeo kính, tóc ngắn"), được gửi kèm mỗi lần tạo ảnh. Nút "Try on" trong AI Stylist cũng dùng chung chức năng này.

App làm gì phía sau: app gửi ảnh của bạn (hoặc dáng người khi dùng người mẫu AI), ảnh các món đồ, bối cảnh và yêu cầu thêm trong một lần. App thử Muse Image của Meta trước (`muse-image-1.0`, endpoint `/v1/images/edits`, khoảng $0.01 một ảnh, dùng chung `MUSE_API_KEY` với AI Stylist). Nếu Muse chưa có billing hoặc hết lượt thì chuyển sang Gemini: Fast dùng `gemini-2.5-flash-image`, Quality dùng `gemini-3-pro-image-preview`. Muse không có bản chậm hơn, nên Fast/Quality chỉ đổi model của Gemini. Các model đổi được bằng `MUSE_IMAGE_MODEL`, `AI_IMAGE_MODEL` và `AI_IMAGE_MODEL_QUALITY` trong `assets/env.json`. Nếu cả hai đều không dùng được, app chuyển tiếp sang Cloudflare Workers AI (`@cf/black-forest-labs/flux-2-klein-4b`, đặt `CLOUDFLARE_ACCOUNT_ID` và `CLOUDFLARE_API_TOKEN`). Dịch vụ này miễn phí 10.000 neuron mỗi ngày, khoảng 100 ảnh, và mất chừng 6 đến 15 giây một ảnh. Cloudflare chỉ nhận 4 ảnh nhỏ hơn 512px, nên app tự thu nhỏ ảnh và bỏ bớt ảnh toàn thân rồi tới các món thừa. Chất lượng kém hơn Muse/Gemini, chữ và logo trên áo hay bị méo. Bộ lọc an toàn của Cloudflare hay chặn ảnh làm từ ảnh chân dung người thật (lỗi 3030 "output has been flagged"), nên app tự thử lại tối đa 4 lần. Nếu vẫn bị chặn thì nên dùng người mẫu AI; chế độ này hầu như không bị chặn. Cả ba dịch vụ đều mặc được nhiều món cùng lúc, nên không cần mặc từng món.

Hiện tại app gọi AI thẳng từ điện thoại và đếm lượt trên máy, giống AI Stylist. Trước khi bán lượt thật, nên chuyển việc gọi AI và đếm lượt sang một Supabase Edge Function.

Về quyền riêng tư: ảnh selfie và ảnh toàn thân chỉ bạn xem được, không nằm trong hồ sơ công khai, và xóa được bất cứ lúc nào. Ảnh chỉ được gửi đi khi bạn bấm tạo ảnh. Ảnh được gửi cho Meta hoặc Google; trước khi phát hành, nhóm cần kiểm tra lại điều khoản dữ liệu của gói API đang dùng.

Lưu ý: ảnh do AI tạo có thể lệch màu hoặc sai dáng so với đồ thật, nên app ghi rõ "AI-generated image".

Miễn phí và Premium: mỗi ảnh tốn tiền dịch vụ. Bản miễn phí được thử 1 lần, Premium được 20 ảnh mỗi tháng (đổi trong `AppConfig.freeTryOns` và `AppConfig.premiumTryOnsPerMonth`). Hết lượt thì app mời lên Premium. Tạo ảnh thất bại hoặc bấm "Cancel" thì không bị trừ lượt.


## 10. Mạng xã hội: hồ sơ, theo dõi, khám phá

Bạn có hồ sơ riêng, theo dõi (Follow) người khác như trên Fits, phối đồ giúp nhau, và xem outfit của người khác để lấy ý tưởng. Chức năng này lớn nên làm theo 4 bước, bước nào xong cũng dùng được ngay. Giao diện và chữ trong app theo đúng Fits (đã soi app Fits thật trên máy ảo).

Bước 1, hồ sơ:
1. Ở tab Profile, bấm "Create profile" (hoặc Account, "My profile"). Đặt username (không trùng với ai, app báo "Username is available" ngay khi gõ), tên, ảnh đại diện, bio.
2. Bật "Private account" nếu chỉ muốn người theo dõi đã được bạn duyệt xem tủ đồ. Tắt thì ai cũng xem được.
3. Bấm "Share profile" để gửi username cho bạn bè.
4. Bấm biểu tượng kính lúp trên Home, tìm username để mở hồ sơ người khác: tab Clothes và Outfits của họ. Giá tiền, ghi chú và số lần mặc luôn được ẩn.

Bước 2, theo dõi:
1. Ở hồ sơ người khác, bấm "Follow". Tài khoản công khai thì thành "Following" ngay; tài khoản riêng tư thì thành "Requested" chờ duyệt.
2. Người kia thấy yêu cầu ở chuông thông báo trên Home (có số báo màu đỏ), chọn "Accept" hoặc bấm × để từ chối.
3. Bấm số Followers / Following trên tab Profile (hoặc Account, "Followers & following") để xem người theo dõi, người bạn theo dõi, và yêu cầu đã gửi/đã nhận. Từ đây bạn bỏ theo dõi hoặc xóa người theo dõi.
4. Nút "…" trên hồ sơ người khác có "Copy username", "Report" và "Block".

Bước 3, phối đồ giúp nhau ("Styled together"):
1. Nếu người kia bật "Let others style me" và bạn xem được tủ đồ của họ, hồ sơ có nút "Style <username>".
2. Chọn đồ từ chính tủ đồ của người đó, bấm "Next", xếp đồ trên khung, viết lời nhắn rồi bấm gửi.
3. Người nhận thấy outfit ở chuông thông báo và trong Account, "Styled together" (tab For you / By you), chọn "Save to my outfits" hoặc "Dismiss".

Bước 4, khám phá:
1. Trong màn chi tiết outfit, bật "Public" để chia sẻ outfit lên Discover.
2. Trên Home có mục "Discover": lưới outfit công khai mới nhất, kèm ảnh đại diện người đăng. "See all" mở trang Discover với bộ lọc Latest / Following / Saved.
3. Bấm vào để xem chi tiết, bấm biểu tượng bookmark để lưu làm ý tưởng (xem lại ở bộ lọc Saved).
4. Gặp nội dung không phù hợp thì bấm "…", chọn "Report" hoặc "Block".

Về quyền riêng tư và an toàn:
1. Chuyển sang "Private account" thì outfit đã đăng rời khỏi Latest; chỉ người theo dõi đã duyệt thấy chúng ở Following. Chuyển lại công khai thì các yêu cầu đang chờ được duyệt luôn.
2. Chặn một người thì hai bên hết theo dõi nhau, họ biến khỏi Discover và tìm kiếm, không gửi outfit cho bạn được nữa, và outfit họ đã gửi mà bạn chưa trả lời bị xóa. Họ không nhận được thông báo. Bỏ chặn ở Account, "Blocked users".
3. Món đồ lấy từ link web (mục 3) không được đăng công khai, vì ảnh thuộc bản quyền của shop. Mục 3 chưa làm; khi làm thì loại các món đó trong hàm public_item ở supabase/schema.sql.
4. Xóa tài khoản thì xóa luôn hồ sơ, lượt theo dõi và các outfit đã chia sẻ (khóa ngoại on delete cascade).
5. Username chỉ gồm chữ thường không dấu, số, dấu gạch dưới và dấu chấm, dài 3 đến 20 ký tự (kiểm tra cả trong app lẫn trong database).

Ghi chú cho nhóm: phần phân quyền nằm hết trong supabase/schema.sql (đoạn "Social"). Các bảng gốc chỉ chủ nhân đọc được; người khác chỉ thấy dữ liệu qua các hàm profile_summary, profile_closet, discover_feed…, và các hàm này chỉ chép những trường được liệt kê sẵn (không bao giờ có giá, ghi chú, số lần mặc). Ai sửa đoạn này cần một người khác kiểm tra lại, vì sai một chỗ là lộ tủ đồ của mọi người. Nhớ chạy lại schema.sql trong SQL Editor sau khi kéo code mới. Nếu app chạy ở chế độ chỉ lưu trên máy, không có tài khoản trực tuyến, thì toàn bộ mục mạng xã hội được ẩn đi.

Miễn phí và Premium: cho dùng miễn phí, vì càng nhiều người tham gia thì chức năng này càng có ích.
