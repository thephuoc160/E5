---
name: E5 Workspace
description: Bảng điều khiển Windows cục bộ, nền sáng và điểm nhấn xanh lá.
colors:
  green: "#176c4c"
  green-hover: "#105538"
  focus: "#25835a"
  paper: "#f4f6f3"
  white: "#fff"
  ink: "#1c302a"
  muted: "#5e7068"
  line: "#dce4de"
  soft: "#e8f2eb"
  amber: "#86500d"
  warning-surface: "#fff1db"
  red: "#b33437"
  error-surface: "#fceced"
typography:
  headline:
    fontFamily: "Segoe UI, Tahoma, sans-serif"
    fontSize: "32px"
    fontWeight: 650
    lineHeight: 1.25
    letterSpacing: "-0.9px"
  title:
    fontFamily: "Segoe UI, Tahoma, sans-serif"
    fontSize: "18px"
    fontWeight: 650
    lineHeight: 1.4
    letterSpacing: "-0.3px"
  body:
    fontFamily: "Segoe UI, Tahoma, sans-serif"
    fontSize: "15px"
    lineHeight: 1.55
  label:
    fontFamily: "Segoe UI, Tahoma, sans-serif"
    fontSize: "12px"
  console:
    fontFamily: "Consolas, monospace"
    fontSize: "12px"
    lineHeight: 1.8
rounded:
  badge: "6px"
  field: "7px"
  control: "8px"
  toast: "10px"
  surface: "14px"
  dialog: "16px"
spacing:
  compact: "8px"
  control: "10px"
  inline: "12px"
  content: "20px"
  section: "28px"
  main: "42px"
components:
  button-primary:
    backgroundColor: "{colors.green}"
    textColor: "{colors.white}"
    rounded: "{rounded.control}"
    padding: "10px 15px"
  button-primary-hover:
    backgroundColor: "{colors.green-hover}"
  button-secondary:
    backgroundColor: "{colors.white}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "10px 15px"
  button-secondary-hover:
    backgroundColor: "{colors.soft}"
  badge:
    backgroundColor: "{colors.soft}"
    textColor: "{colors.green}"
    rounded: "{rounded.badge}"
    padding: "5px 10px"
  badge-warning:
    backgroundColor: "{colors.warning-surface}"
    textColor: "{colors.amber}"
  badge-error:
    backgroundColor: "{colors.error-surface}"
    textColor: "{colors.red}"
  card:
    backgroundColor: "{colors.white}"
    rounded: "{rounded.surface}"
  log-filter:
    backgroundColor: "{colors.white}"
    textColor: "{colors.muted}"
    rounded: "{rounded.field}"
    padding: "7px"
  navigation-active:
    backgroundColor: "{colors.green}"
    textColor: "{colors.white}"
    rounded: "{rounded.control}"
    padding: "11px 13px"
  confirmation-dialog:
    textColor: "{colors.ink}"
    rounded: "{rounded.dialog}"
    padding: "28px"
---

# Design System: E5 Workspace

## Overview

**Creative North Star: "Bàn điều khiển cục bộ"**

Giao diện sáng, rõ ràng và tiết chế dành cho người vận hành trên Windows. Điểm nhấn xanh lá dẫn mắt đến thao tác chính và trạng thái sẵn sàng; nền trung tính giúp đọc thông tin tiếng Việt trong phiên làm việc dài.

Tài liệu ghi nhận thiết kế đã triển khai trong `dashboard/dashboard.template.html`. Các token ở đầu tệp là quy chuẩn; phần diễn giải hướng dẫn áp dụng. Tên gọi mô tả thiết kế hiện có, không bổ sung một hướng mỹ thuật mới.

**Key Characteristics:**

- Nền sáng, xanh lá làm điểm nhấn.
- Tiếng Việt rõ nghĩa, trạng thái có nhãn chữ.
- Bề mặt phẳng, đường phân cách nhẹ.
- Phông hệ thống hoạt động ngoại tuyến.

## Colors

Xanh lá trầm kết hợp nền giấy hơi ngả xanh; màu cảnh báo và lỗi dành cho ý nghĩa trạng thái.

### Primary

- **Xanh vận hành** (`green`): nút chính, điều hướng đang chọn, biểu tượng tác vụ và trạng thái thành công.
- **Xanh nhấn sâu** (`green-hover`): phản hồi rê chuột của nút chính.
- **Xanh tiêu điểm** (`focus`): viền chỉ báo bàn phím.

### Neutral

- **Giấy sáng** (`paper`): nền trang.
- **Trắng bề mặt** (`white`): vùng thông tin, danh sách và nút phụ.
- **Mực xanh đậm** (`ink`): nội dung chính và nền kết quả thực thi.
- **Xám xanh** (`muted`): mô tả, nhãn và thời gian.
- **Đường phân cách** (`line`): viền mảnh và các hàng.
- **Xanh dịu** (`soft`): nền trạng thái tích cực và phản hồi nút phụ.

### Status

- **Hổ phách** (`amber`, `warning-surface`): cảnh báo, chưa có dữ liệu và đang kết nối.
- **Đỏ lỗi** (`red`, `error-surface`): lỗi và mất kết nối.

**The Nhãn trạng thái Rule.** Luôn hiển thị ý nghĩa trạng thái bằng chữ; màu không thay thế nhãn.

## Typography

**Display Font / Body Font:** Segoe UI, dự phòng Tahoma và sans-serif.
**Label/Mono Font:** Segoe UI cho nhãn; Consolas, dự phòng monospace cho kết quả và nhật ký.

Phông hệ thống được chọn có chủ ý cho dashboard Windows cục bộ: hỗ trợ tiếng Việt, quen thuộc với môi trường vận hành và không phụ thuộc tải phông qua mạng.

### Hierarchy

- **Headline:** tiêu đề trang theo token `headline`; giảm còn (28px) khi chiều rộng không quá (1150px).
- **Title:** tiêu đề khu vực theo token `title`; tiêu đề trong khu vực tác vụ giảm còn (16px) trên màn hình nhỏ.
- **Body:** nội dung theo token `body`; giữ chữ thường tự nhiên và dấu tiếng Việt đầy đủ.
- **Label:** nhãn, trạng thái và mô tả phụ theo token `label`.
- **Metric:** số liệu (29px, weight 600), dùng chữ số có độ rộng đều; còn (25px) trên màn hình nhỏ.
- **Console:** theo token `console`; nhật ký dùng cùng họ chữ với line-height (1.7).

## Layout

Ở khung kiểm tra (1440px), thanh bên cố định theo chiều cuộn rộng (228px); nội dung có lề ngang (42px) và giới hạn rộng (1550px). Tổng quan chia cột (1.5fr / 1fr); khu vực tác vụ và lịch/kết quả chia (1.5fr / minmax(280px, 1fr)), cách nhau (28px). Ba số liệu nằm cùng hàng với đường chia.

Không quá (1150px): thanh bên còn (195px), lề nội dung (26px), khu vực tác vụ thành một cột; tổng quan vẫn hai cột (1.2fr / 1fr).

Không quá (700px), bao gồm khung kiểm tra (390px): thanh bên chuyển thành đầu trang, điều hướng ngang có thể cuộn; ẩn dòng phụ thương hiệu và breadcrumb. Nội dung có lề (18px); tiêu đề và nút chính xếp dọc, nút chính rộng toàn hàng; tổng quan xếp một cột. Ba số liệu vẫn cùng hàng với cỡ chữ nhỏ hơn; hàng tác vụ giữ nút chạy bên cạnh nhãn. Footer xếp dọc.

Từ (1600px), lề nội dung tăng thành (60px). Địa chỉ tài khoản và nhật ký dài phải ngắt dòng; chỉ danh sách nhật ký, kết quả và điều hướng nhỏ được cuộn nội bộ. Khoảng cách theo ngữ cảnh, lấy token spacing làm các mốc tái sử dụng.

## Elevation & Depth

Bề mặt thông thường phẳng; nền khác sắc và đường viền (1px) tạo phân cấp. Thanh bên có nền xanh xám, lịch có nền xanh dịu, kết quả có nền mực đậm. Bóng chỉ dành cho thông báo nổi và hộp thoại.

### Shadow Vocabulary

- **Thông báo nổi:** `0 8px 30px #1c302a26`.
- **Hộp thoại:** `0 20px 70px #0003`; lớp nền che `#102d2366`.

**The Bề mặt phẳng Rule.** Giữ vùng dữ liệu và danh sách không có bóng; chỉ lớp nổi cần tách khỏi nội dung dùng bóng.

## Shapes

Góc bo vừa phải, theo vai trò trong nhóm token rounded: chip nhỏ, nút và ô chọn gọn, vùng nội dung mềm hơn, hộp thoại bo lớn nhất. Viền mảnh giữ ranh giới rõ; danh sách dùng một khung chung và các đường phân hàng. Biểu tượng SVG nét mảnh (20px, stroke-width 1.7); trên điều hướng nhỏ còn (16px).

## Components

### Buttons

Nút rõ nghĩa, có nhãn động từ. Nút mặc định cao tối thiểu (44px), weight (600); nút chạy trong hàng cao tối thiểu (38px), chữ (12px), padding (7px 12px). Nút phụ nền trắng; hover nền xanh dịu và viền `#9db7a6`. Nút chính dùng xanh vận hành, hover xanh nhấn sâu. Tất cả điều khiển dùng focus-visible viền (3px), cách (4px). Khi bận hoặc chưa kết nối, nút tác vụ bị vô hiệu hóa với opacity (0.55) và con trỏ chờ.

### Chips

Chip trạng thái có nhãn chữ, nền dịu tương ứng thành công/cảnh báo/lỗi, chữ (12px, weight 600). Không dùng chip trạng thái làm điều khiển lọc.

### Cards / Containers

Vùng trắng có đường viền và góc theo token surface. Vùng ổ đĩa/tài khoản có padding (25px 27px), còn (20px) trên màn hình nhỏ. Danh sách tác vụ ghép các hàng trong một khung; lịch chạy dùng nền dịu riêng và padding (22px).

### Inputs / Fields

Ô chọn mức nhật ký là select gốc có nhãn truy cập, chữ (12px), cao tối thiểu (38px), viền mảnh và góc theo token field. Không có ô nhập văn bản trong giao diện hiện tại.

### Navigation

Điều hướng chữ và biểu tượng, mặc định màu `#50665b`; mục đang chọn nền xanh, chữ trắng và weight (600). Liên kết hover gạch chân. Trên màn hình nhỏ chuyển sang hàng ngang, nhãn không ngắt dòng và cuộn được.

### Confirmation Dialog

Dùng `dialog.showModal()` gốc, tiêu đề/mô tả liên kết bằng aria-labelledby và aria-describedby. Hộp thoại rộng tối đa `min(460px, 90vw)`; hai nút Hủy/Xác nhận chạy căn phải. Khi mở, đưa tiêu điểm vào Hủy. Hiển thị hệ quả của tác vụ trước khi gửi yêu cầu thay đổi dữ liệu hoặc lịch chạy.

### Execution Console and Feedback

Khối kết quả dùng nền mực, chữ sáng, nội dung monospace ngắt dòng; có thể nhận tiêu điểm để cuộn bàn phím. Nhật ký có bộ lọc, trạng thái trống và thời gian. Thông báo kết quả dùng role=status; tiến độ tác vụ có aria-live=polite. Có liên kết bỏ qua đến nội dung chính.

Tổng quan chỉ có hiệu ứng tăng độ sáng từ (0.96) lên (1) trong (0.45s), easing `cubic-bezier(0.16, 1, 0.3, 1)`, khi người dùng không yêu cầu giảm chuyển động. Không thêm chuyển động vào trạng thái xử lý.

## Do's and Don'ts

### Do:

- **Do** giữ nền sáng, điểm nhấn xanh lá và nội dung tiếng Việt.
- **Do** dùng dữ liệu thực; biểu thị đang tải, mất kết nối và chưa có dữ liệu rõ ràng.
- **Do** duy trì nhãn trạng thái, focus bàn phím và hộp thoại xác nhận có mô tả hệ quả.
- **Do** kiểm tra bố cục ở (1440px) và (390px) khi mở rộng giao diện.

### Don't:

- **Don't** thay số liệu chưa tải bằng dữ liệu thành công giả.
- **Don't** dùng riêng màu sắc để truyền đạt lỗi hoặc cảnh báo.
- **Don't** bỏ qua xác nhận trước tác vụ thay đổi dữ liệu hoặc lịch chạy.
- **Don't** thêm phông cần mạng cho dashboard vận hành ngoại tuyến.
