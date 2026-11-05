# Hướng dẫn trình bày mô phỏng trong ModelSim / Questa

Project dùng FPGA Gowin Tang Nano 9K. ModelSim đi kèm Quartus có thể chạy Verilog độc lập; **Quartus không tổng hợp project Gowin**. Giải nén ZIP, mở ModelSim, tại Transcript chuyển tới thư mục gốc chứa `HTS.gprj`, `src`, `sim`, `RISC-V`:

```tcl
cd C:/duong-dan/HTS_N12_SIMPLE_S2
do sim/run_all.do
```

Chạy một bài để phóng to Wave:

```tcl
set tb tb_servo
do sim/run_one.do
```

Đổi `tb` thành `tb_button`, `tb_motor`, `tb_buzzer`, `tb_led`, `tb_servo`, `tb_led7seg`, `tb_uart`, `tb_power_on` hoặc `tb_ibex_system_top`. Mỗi bài in số giai đoạn trong Transcript và kết thúc bằng `PASS tb_...`; `$fatal`/`TIMEOUT` là lỗi. Khi chạy tất cả, Wave cuối cùng là bài tổng hợp. Chạy riêng bài muốn trình bày, dùng Zoom Full rồi phóng vùng tín hiệu cần giải thích.

## Cách đọc giao thức CPU ↔ MMIO

Trong Wave của `tb_ibex_system_top`, theo thứ tự nhóm `00` tới `08`:

1. CPU fetch firmware tại `0x00000080` sau reset. `instr_req` và `instr_rvalid` cho thấy yêu cầu lệnh và phản hồi.
2. CPU phát `data_req`, `data_addr`, `data_we` và `data_wdata`; `data_gnt` nhận yêu cầu. Chu kỳ sau, `data_rvalid` và `data_rdata` trả kết quả đọc. `data_we=1` là ghi, `0` là đọc.
3. Với nút, pin xuống 0 → hai FF đồng bộ tạo `btn_raw=1` → giữ đủ chống dội tạo `btn_stable=1` → CPU đọc `0x60000000`. Địa chỉ `0x60000004` cho thấy raw để chẩn đoán.
4. CPU ghi lệnh servo tới **`0x80000000`**. Khi đọc cùng địa chỉ, `[11:0]` là xung hiện tại (µs), bit `16` là đang quay. Không dùng `0xB0000000` và không có thanh ghi cửa riêng.

| MMIO | Dữ liệu chính | Chân / kết quả quan sát |
|---|---|---|
| `0x40000000` UART | ghi byte; đọc bit 0 `tx_busy` | `uart_tx`, khung 8N1 |
| `0x50000000` LED | bit 0–3 tầng, 4 lên, 5 xuống | `led_up`, `led_down`; 6 LED trên bo luôn sáng |
| `0x60000000`, `+4` BUTTON | bit 0–3 stable/raw | 4 nút J5, active low |
| `0x70000000` LED7SEG | mã tầng 0–4 | `seg_data[6:0] = gfedcba` |
| `0x80000000` SERVO | ghi µs; đọc current/busy | `servo_pin`, PWM cửa |
| `0x90000000` MOTOR | start, chiều, 16-bit số bước; đọc busy | `motor_pins[3:0]` |
| `0xA0000000` BUZZER | bit 0 bật/tắt | `buzzer_pin` 2 kHz |
| `0xC0000000` TIMER | bộ đếm µs | mốc giữ cửa 3 s trong firmware |

## 7 bài riêng: trình bày từ đầu vào tới đầu ra

| Bài | Giai đoạn và điểm cần phóng Wave | Điều kiện PASS |
|---|---|---|
| `tb_button` | reset → nhiễu ngắn → nhấn từng nút 1–4 → nhấn đồng thời → reset; so `buttons`, `sync1`, `btn_raw`, `btn_stable` | nhiễu bị lọc; 4 bit đúng; thả nút xóa stable |
| `tb_motor` | ghi `start/dir/steps` → đọc busy → 8 pha thuận → 8 pha nghịch → 0 bước → reset | đúng 8 bước mỗi chiều, busy và cuộn dây tắt khi xong |
| `tb_buzzer` | ghi bit 0=1 → đo sóng vuông → ghi 0 → reset | 2 kHz, chu kỳ 500 µs; tắt về 0 |
| `tb_led` | CPU ghi LED/hướng → quan sát LED tích hợp → ghi/đọc servo ở `0x8` → thử `0xB` cũ | 6 LED bo luôn sáng; hướng đúng; `0x8` hoạt động, `0xB` không ánh xạ |
| `tb_servo` | reset 1000 µs → ghi 2125 µs → busy/ramp/PWM → đóng 1000 µs → kẹp giới hạn → reset | khung 20 ms, xung 1000/2125 µs, ramp tối đa 10 µs/khung |
| `tb_led7seg` | mã 0 là `-`; 1–4; mã sai là `E` | đúng từng bit `gfedcba` |
| `tb_uart` | TX start, 8 data LSB-first, stop, busy → RX → đọc xóa valid → reset | hai byte TX, một byte RX đúng; divider 234 ở 27 MHz |
| `tb_power_on` | cấp nguồn khi S2 chưa nhấn → POR → CPU fetch `0x80` → timer thật → bốn nút → S2 reset → fetch lại | không cần xung reset nhân tạo, bốn bit raw/stable đúng |

Các module ngoại vi đơn lẻ không có cổng địa chỉ: top `ibex_system_top.v` giải mã địa chỉ. Vì vậy bài `tb_led` kiểm tra địa chỉ servo tại **top thật**, còn bài riêng tập trung giao thức điện/tín hiệu của ngoại vi. `tb_ibex_system_top` cho thấy toàn bộ giao dịch từ Ibex.

## Bài tổng hợp: kịch bản báo cáo 4 tầng

`tb_ibex_system_top` nạp chính bốn bank HEX bằng `$readmemh`. Theo dõi `phase_id` và các dòng `[DEMO 1]` tới `[DEMO 5]`:

1. Reset, CPU fetch `0x80`, tự kiểm tra LED, LED 7 đoạn, buzzer rồi in `READY` qua UART TX pin 41.
2. Nhấn nút tầng 4; trong lúc đi lên, thêm yêu cầu tầng 2 và 3. Mỗi nút phải có `Call registered`; tín hiệu raw/stable xem trực tiếp trên Wave.
3. Hệ thống phục vụ **2 → 3 → 4**. Mỗi chặng motor nhận 4096 bước, phát đúng 4096 pha, `busy` về 0. UART giữ dòng `[DBG] Motor busy...`. Tại mỗi điểm dừng: còi, servo mở, `Door Opened.`, giữ ≥3 s, đóng, `Door Closed.`.
4. Nhấn tầng 1; motor đổi chiều, đi **4 → 3 → 2 → 1**, phục vụ tầng 1. Tổng cộng 6 chặng motor và 4 chu kỳ cửa.
5. Reset phần cứng: motor/còi tắt, servo về mục tiêu đóng, CPU fetch lại `0x80` và in `READY` lần 2.

Bài tổng hợp tăng tốc **chỉ trong testbench**: timer firmware +50 µs/clock, UART 3 clock/bit, debounce 540 clock, motor 10 clock/bước, servo frame 3000 clock và 375 µs/bước. Dùng bài riêng để đo baud, PWM 50 Hz, 10 µs/khung và tần số còi thực. Không lấy thời gian xung vật lý từ Wave tổng hợp.

Nếu thay `elevator.c`, phải tạo lại ELF/BIN/HEX trước khi chạy bài tổng hợp. `$readmemh` cần chạy từ thư mục gốc. Wave chỉ xác nhận logic số; chân FPGA thật, dây CP2102, nguồn servo và góc cơ khí phải kiểm tra trên bo.
