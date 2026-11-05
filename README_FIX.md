# Thang máy RISC-V trên Tang Nano 9K — bản S2 đơn giản

## Sửa lỗi bản này

- S2 có sẵn trên bo là reset active-low ở FPGA pin 3, miền 1,8 V. Bộ POR giữ reset thêm khoảng 10 ms sau khi cấp nguồn hoặc thả S2, rồi Ibex tự khởi động ở `0x80`. Không cần nhấn S2 một lần sau khi cắm nguồn.
- Chỉ dùng UART CP2102: FPGA TX pin 41, RX pin 42. Sau bài tự kiểm tra khoảng 600 ms, firmware in `ELEVATOR SYSTEM READY`. Dòng `[DBG] Motor busy...` vẫn được giữ khi motor chạy.
- Sáu LED trên bo vẫn sáng liên tục theo yêu cầu, kể cả khi CPU không chạy. Vì vậy **LED sáng không chứng minh firmware đã boot**. Dùng dòng `READY` hoặc LED 7 đoạn để xác nhận.
- `tb_power_on` kiểm tra cấp nguồn với S2 thả từ đầu, timer thực, bốn nút và nhấn S2 rồi khởi động lại.

## Kết nối và MMIO

| Chức năng | Địa chỉ / chân | Quy ước |
|---|---|---|
| Nút tầng 1–4 | FPGA pin 25, 26, 27, 28 = J5 vị trí 5–8 | Mỗi nút nối xuống GND, nhấn = mức 0; pull-up 3,3 V trong CST |
| S2 trên bo | FPGA pin 3 | Reset active-low, không nối nút ngoài vào pin này |
| Nút đã chống dội | `0x60000000` | bit 0–3 = tầng 1–4, nhấn = 1 |
| Nút sau đồng bộ | `0x60000004` | bit 0–3, trước chống dội |
| Servo cửa | `0x80000000`, chân 51 | Ghi bit 0–11: xung mục tiêu µs; đọc bit 0–11: xung hiện tại, bit 16: đang di chuyển |
| Motor bước | `0x90000000` | bit 0: start/busy, bit 1: chiều, bit 2–17: số bước |
| Buzzer | `0xA0000000` | Ghi bit 0: bật/tắt |
| UART CP2102 | TX pin 41, RX pin 42 | 115200 8N1, dùng chung GND, mức 3,3 V |

Các địa chỉ khác giữ nguyên: UART `0x40000000`, LED/hướng `0x50000000`, LED 7 đoạn `0x70000000`, timer µs `0xC0000000`. Sáu LED trên bo luôn sáng (active low); đèn hướng ngoài vẫn dùng pin 48/49. `0xB0000000` không còn ánh xạ servo. Không còn thanh ghi DOOR riêng.

## Quy trình cửa

Firmware chọn góc bằng độ: mặc định đóng 0° = 1000 µs, mở 90° = 2125 µs. RTL dịch 10 µs sau mỗi khung PWM 20 ms, nên hành trình danh định khoảng 2,26 s. UART báo `Door Opening...`, rồi chỉ báo `Door Opened.` khi giá trị xung hiện tại bằng mục tiêu và cờ đang quay tắt. Sau đó mới giữ 3 s, báo `Door Closing...`, ghi mục tiêu đóng và chỉ báo `Door Closed.` sau khi servo đạt 1000 µs. Quá 5 s mà chưa đạt mục tiêu, firmware báo `[FAULT]` và không chạy motor cho đến khi reset.

Trạng thái này được suy từ tín hiệu PWM, **không đo vị trí thật của cửa**. Nếu cần xác nhận cơ khí, phải gắn cảm biến cửa. Góc thực tế còn phụ thuộc hiệu chỉnh, nguồn, tải và GND chung. Chỉnh `SERVO_OPEN_ANGLE_DEG` và `SERVO_CAL_*` trong `RISC-V/elevator.c` theo cơ khí của bạn; khi thay C phải biên dịch lại firmware và tạo lại bitstream.

## Build và nạp

Trong thư mục `RISC-V`, chạy `make -B hex` với bộ `riscv-none-elf-gcc`, `objcopy`, Python. Lệnh này tạo ELF/BIN và bốn bank HEX tại `src/`; entry point là `0x80`. Mở `HTS.gprj` bằng Gowin, chạy Synthesize → Place & Route → Generate Bitstream rồi nạp bitstream **mới**. Gói source không chứa bitstream cũ. ModelSim đi kèm Quartus chỉ dùng để mô phỏng Verilog, không dùng Quartus để build chip Gowin.

Trong Gowin IDE, đặt `ibex_system_top` làm **Top Module** trước khi tổng hợp. Kiểm tra báo cáo pin cho `rst_n=3`, `buttons[0..3]=25..28`, `uart_tx=41`, `uart_rx=42`, `clk=52`; không nạp lại bitstream của gói cũ. FPGA pin 17 không được dùng trong bản này. Nếu Gowin báo lỗi nạp file HEX, mở project tại thư mục gốc có `src/firmware_bank0.hex` và chạy tổng hợp lại.

Có thể dùng `gw_sh.exe build_gowin.tcl` trong thư mục gốc để đặt top module tường minh và chạy toàn bộ flow. Lệnh Gowin này chưa được chạy tại môi trường hiện tại vì không có Gowin IDE.

## Kiểm tra trên bo sau khi nạp

1. Mở terminal CP2102 ở 115200 8N1. Bật nguồn: sau khoảng 600 ms phải thấy `ELEVATOR SYSTEM READY`. CP2102 RXD nối FPGA pin 41; TXD nối pin 42; GND chung.
2. Nhấn rồi thả S2: hệ thống tự kiểm tra lại và in `READY` lần nữa. Nếu đo S2, khi thả xấp xỉ 1,8 V, khi nhấn xấp xỉ 0 V; không cấp 3,3 V vào pin reset.
3. Mỗi nút tầng nối **một đầu** vào đúng J5 vị trí 5, 6, 7, 8; đầu kia về GND của bo. Khi thả: chân nút xấp xỉ 3,3 V; khi nhấn: gần 0 V. Giữ nút hơn 20 ms; terminal phải in `Call registered for Floor n`. Trên sơ đồ bo, GND có ở J6 vị trí 23; không lấy nhầm chân J5 kế bên làm GND.
4. Khi motor đang chạy, terminal vẫn có thể in `[DBG] Motor busy...`. Nếu không thấy `READY` sau khi nạp, kiểm tra clock 27 MHz, S2, chân 41 và bitstream mới trước.

Mô phỏng số không xác nhận được dây thật, nguồn motor/servo hay việc nạp bitstream. Kết luận phần cứng chỉ có sau bốn bước đo trên bo.

Xem `sim/README_MODELSIM.md` để chạy từng ngoại vi và toàn hệ thống trên Wave/Transcript.
