# 🛗 Hệ Thống Thang Máy 4 Tầng SoC RISC-V Trên FPGA Tang Nano 9K

[![FPGA](https://img.shields.io/badge/FPGA-Gowin_GW1NR--9C-blue.svg)](http://www.gowinsemi.com.cn/)
[![Core](https://img.shields.io/badge/CPU-Ibex_RV32IM-red.svg)](https://github.com/lowRISC/ibex)
[![Toolchain](https://img.shields.io/badge/Toolchain-riscv--none--elf--gcc-orange.svg)](https://gnu-mcu-eclipse.github.io/)
[![EDA](https://img.shields.io/badge/EDA-Gowin_V1.9.9-green.svg)](http://www.gowinsemi.com.cn/)
[![Simulation](https://img.shields.io/badge/Sim-ModelSim_Questa-blueviolet.svg)](https://www.intel.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Dự án thiết kế hệ thống nhúng SoC (System-on-Chip) điều khiển thang máy 4 tầng theo mô hình **Đồng thiết kế Phần cứng - Phần mềm (Hardware/Software Co-design)**. Dự án tích hợp lõi vi xử lý **RISC-V Ibex (RV32IM)** trên chip FPGA **Gowin GW1NR-9C (Sipeed Tang Nano 9K)**, kết hợp cùng firmware C thực hiện thuật toán điều phối thang máy thông minh **SCAN/LOOK**.

---

## 📌 Tính Năng Nổi Bật

- **Lõi Vi Xử Lý RISC-V**: Sử dụng core **Ibex 32-bit (RV32IM)** mã nguồn mở từ lowRISC/OpenTitan, nạp và chạy firmware trực tiếp từ BRAM nội tại địa chỉ `0x00000080`.
- **Ngoại Vi Thiết Kế Riêng Bằng Verilog (MMIO)**:
  - **Khối Stepper MMIO**: Tự động phát chuỗi xung 8 pha nửa bước (half-step) tần số 1000 Hz lái động cơ bước 28BYJ-48, chống rung và triệt tiêu nhiệt khi dừng.
  - **Khối Servo MMIO (PWM 50 Hz)**: Điều khiển đóng/mở cửa với cơ chế **Soft-Ramping** (chỉ dịch 10 µs mỗi chu kỳ 20 ms), giúp cửa chuyển động êm ái trong ~2.26s.
  - **Khối Button Debounce**: Đồng bộ 2 tầng Flip-Flop và bộ đếm lọc nhiễu cơ khí 20 ms cho 4 nút bấm.
  - **Khối Passive Buzzer**: Tự động tổng hợp sóng vuông tần số 2 kHz cho còi báo tầng.
  - **Khối LED 7 Đoạn & Hướng**: Hiển thị số tầng hiện tại và chiều di chuyển (Lên / Xuống).
  - **UART Controller**: Giao tiếp chẩn đoán và truyền dữ liệu thời gian thực lên máy tính với baudrate 115200 8N1.
- **Thuật Toán Lập Lịch SCAN/LOOK**: Tối ưu hóa hành trình, ưu tiên đón khách theo chiều đang di chuyển, lướt qua các tầng không có yêu cầu mà không dừng ngắt quãng.
- **Cơ Chế Bảo Vệ An Toàn**: Tự động ngắt động cơ và kích hoạt trạng thái khóa lỗi (`ST_FAULT`) nếu hành trình đóng/mở cửa vượt quá thời gian timeout (5 giây).

---

## 🏗 Kiến Trúc Hệ Thống

```
                     ┌──────────────────────────────────────────────┐
                     │            FPGA GOWIN GW1NR-9C               │
                     │                                              │
                     │  ┌─────────────────┐    ┌─────────────────┐  │
                     │  │ RISC-V Ibex Core│    │ 16KB SRAM/BRAM  │  │
                     │  │   (RV32IM CPU)  │◄──►│ (Firmware/Data) │  │
                     │  └────────┬────────┘    └─────────────────┘  │
                     │           │ System Data Bus                  │
                     │           ▼                                  │
                     │  ┌────────────────────────────────────────┐  │
                     │  │     Address Decoder & MMIO Bridge      │  │
                     │  └───┬──────┬──────┬──────┬──────┬──────┬──┘  │
                     └──────┼──────┼──────┼──────┼──────┼──────┼──────┘
                            │      │      │      │      │      │
      ┌─────────────────────┘      │      │      │      │      └──────────────────┐
      ▼                            ▼      ▼      ▼      ▼                         ▼
┌──────────────┐              ┌────────┐┌──────┐┌────┐┌───────┐             ┌──────────┐
│ ULN2003      │              │ Servo  ││Buzzer││7SEG││4 Nút  │             │  CP2102  │
│ 28BYJ-48     │              │ SG90   ││ 2kHz ││    ││Tầng   │             │  UART    │
│(Động cơ tời) │              │ (Cửa)  ││(Còi) ││    ││1 -> 4 │             │ Terminal │
└──────────────┘              └────────┘└──────┘└────┘└───────┘             └──────────┘
```

---

## 🗺 Bản Đồ Bộ Nhớ MMIO (Memory Map)

| Địa chỉ MMIO | Tên thiết bị | Quyền | Chức năng chi tiết |
|:---:|:---:|:---:|---|
| `0x00000000 - 0x00003FFF` | **RAM/ROM** | R/W | 16 KB bộ nhớ nhúng BRAM (chứa Firmware và Stack) |
| `0x40000000` | **UART** | R/W | Ghi: byte TX \| Đọc: bit 0 cờ `tx_busy` |
| `0x50000000` | **LEDs** | W | Bit [3:0]: tầng 1–4, Bit 4: LED LÊN, Bit 5: LED XUỐNG |
| `0x60000000` | **BUTTON** | R | Bit [3:0]: trạng thái 4 nút gọi tầng (đã chống dội) |
| `0x60000004` | **BUTTON_RAW** | R | Bit [3:0]: trạng thái nút thô (chẩn đoán) |
| `0x70000000` | **7-SEGMENT** | W | Bit [2:0]: hiển thị tầng (`0` = `-`, `1..4` = tầng) |
| `0x80000000` | **SERVO** | R/W | Ghi [11:0]: xung mục tiêu µs \| Đọc [11:0]: xung hiện tại, Bit 16: `busy` |
| `0x90000000` | **STEPPER** | R/W | Bit 0: start/busy, Bit 1: chiều, Bit [17:2]: số bước |
| `0xA0000000` | **BUZZER** | W | Bit 0: bật/tắt còi 2 kHz |
| `0xC0000000` | **TIMER** | R | Bộ đếm thời gian thực tự do (độ phân giải 1 µs, 32-bit) |

---

## 🔌 Sơ Đồ Đấu Nối Phần Cứng (Pinout)

> [!WARNING]
> **Quy tắc cấp nguồn an toàn:**
> - Bo **Tang Nano 9K** nhận nguồn thông qua cổng USB Type-C cắm vào máy tính.
> - Động cơ bước (ULN2003) và Servo bắt buộc cấp nguồn từ **củ sạc ngoài 5V (tối thiểu 2A)**.
> - **BẮT BUỘC nối chung GND** giữa nguồn ngoài 5V và chân GND của FPGA.
> - **TUYỆT ĐỐI KHÔNG** nối dây 5V nguồn ngoài vào chân 3.3V của Tang Nano 9K.

| Linh kiện | Chân linh kiện | Chân FPGA | Chuẩn I/O | Ghi chú |
|---|---|:---:|:---:|---|
| Clock 27 MHz | Thạch anh trên bo | **52** | LVCMOS33 | — |
| Nút Reset S2 | Nút S2 trên bo | **3** | LVCMOS18 | Active Low + POR 10 ms |
| Nút tầng 1 | Push button → GND | **25** | LVCMOS33 | Pull-Up nội |
| Nút tầng 2 | Push button → GND | **26** | LVCMOS33 | Pull-Up nội |
| Nút tầng 3 | Push button → GND | **27** | LVCMOS33 | Pull-Up nội |
| Nút tầng 4 | Push button → GND | **28** | LVCMOS33 | Pull-Up nội |
| Stepper (ULN2003) | IN1, IN2, IN3, IN4 | **29, 30, 33, 34** | LVCMOS33 | Drive = 8 mA |
| Servo SG90 | Dây cam (PWM) | **51** | LVCMOS33 | PWM 50 Hz |
| Buzzer | Chân dương | **70** | LVCMOS33 | Passive buzzer |
| 7-Seg a..g | Các thanh LED | **72, 73, 74, 75, 76, 77, 71** | LVCMOS33 | Common Cathode |
| LED Hướng LÊN | LED đơn ngoài | **48** | LVCMOS33 | Qua trở 220Ω |
| LED Hướng XUỐNG | LED đơn ngoài | **49** | LVCMOS33 | Qua trở 220Ω |
| UART TX | CP2102 RXD | **41** | LVCMOS33 | 115200 8N1 |
| UART RX | CP2102 TXD | **42** | LVCMOS33 | 115200 8N1 |

---

## 🗂 Cấu Trúc Thư Mục

```
.
├── HTS.gprj                     # Project Gowin EDA
├── README.md
├── RISC-V/
│   ├── elevator.c               # Logic điều khiển thang máy (máy trạng thái + SCAN/LOOK)
│   ├── crt0.S                   # Startup Assembly (entry point)
│   ├── link.ld                  # Linker script (16 KB bộ nhớ, entry 0x80)
│   ├── make_hex.py              # Chuyển đổi firmware.bin → 4 bank hex cho BRAM
│   ├── Makefile                 # Biên dịch firmware
│   ├── firmware.elf             # ELF đã build (pre-built)
│   └── firmware.bin             # Binary đã build (pre-built)
├── src/
│   ├── ibex_system_top.v        # Top-level module kết nối CPU + MMIO
│   ├── ibex_*.v                 # Lõi CPU RISC-V Ibex (RV32IM)
│   ├── button_mmio.v            # Chống dội nút bấm
│   ├── stepper_mmio.v           # Điều khiển động cơ bước (8 pha)
│   ├── servo_mmio.v             # PWM 50 Hz cửa thang (soft-ramp)
│   ├── buzzer_mmio.v            # Còi 2 kHz
│   ├── led_7_seg_mmio.v         # Hiển thị tầng
│   ├── uart_mmio.v              # UART 115200
│   ├── hts_pin..cst             # Pin constraints Gowin
│   ├── timing.sdc               # Timing constraints 27 MHz
│   └── firmware_bank*.hex       # 4 bank hex nhúng vào BRAM (pre-built)
└── sim/
    ├── tb_ibex_system_top.v     # Testbench toàn hệ thống
    ├── tb_button.v              # Test chống dội nút
    ├── tb_motor.v               # Test động cơ bước
    ├── tb_servo.v               # Test servo cửa
    ├── tb_buzzer.v              # Test còi
    ├── tb_led.v                 # Test LED + hướng
    ├── tb_led7seg.v             # Test LED 7 đoạn
    ├── tb_uart.v                # Test UART
    ├── tb_power_on.v            # Test Power-on Reset
    ├── run_all.do               # Chạy tất cả testbench (ModelSim)
    ├── run_one.do               # Chạy 1 testbench chọn trước
    └── README_MODELSIM.md       # Hướng dẫn chạy mô phỏng
```

---

## 🚀 Hướng Dẫn Biên Dịch & Nạp Mạch

### Yêu Cầu Phần Mềm

| Phần mềm | Mục đích |
|---|---|
| [Gowin EDA ≥ V1.9.8](http://www.gowinsemi.com.cn/) | Tổng hợp và tạo bitstream FPGA |
| [riscv-none-elf-gcc](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack) | Biên dịch firmware C |
| Python ≥ 3.8 | Chạy script `make_hex.py` |
| ModelSim / QuestaSim | Mô phỏng kiểm tra (tùy chọn) |

### Bước 1: Biên Dịch Firmware (Chỉ cần nếu sửa `elevator.c`)

```bash
cd RISC-V
make hex
# Kết quả: 4 file src/firmware_bank*.hex sẽ được cập nhật
```

### Bước 2: Tổng Hợp & Tạo Bitstream

1. Mở **Gowin EDA**, mở file `HTS.gprj`.
2. Chuột phải vào `ibex_system_top` → **Set as Top Module**.
3. Nhấn lần lượt: **Synthesize** → **Place & Route** → **Generate Bitstream**.

### Bước 3: Nạp Lên Bo Mạch

```
1. Cắm cáp USB Type-C vào Tang Nano 9K và máy tính.
2. Mở Gowin Programmer → chọn thiết bị GW1NR-9C.
3. Trỏ tới file bitstream → Click Program/Download.
```

### Bước 4: Mở Terminal UART

Mở **Putty / Tera Term / Mobaxterm**, chọn cổng COM của CP2102, thông số **115200 - 8 - N - 1**. Kết quả mong đợi:

```
=================================
 ELEVATOR SYSTEM READY (FLOOR 1)
=================================
[SYS] Call registered for Floor 4
[SYS] Moving UP from Floor 1...
[SYS] Passing Floor 2...
[SYS] Passing Floor 3...
[SYS] Arrived at Floor 4!
[SYS] Door Opening...
[SYS] Door Opened.
[SYS] Door Closing...
[SYS] Door Closed.
```

---

## 🧪 Mô Phỏng Kiểm Tra (ModelSim)

> **Lưu ý**: Thư mục dự án không được chứa ký tự đặc biệt hoặc có dấu trong đường dẫn vì ModelSim (win32) không hỗ trợ.

```tcl
# Mở ModelSim, tại cửa sổ Transcript chuyển tới thư mục dự án:
cd C:/path/to/HTS_N12_11_5

# Chạy tất cả 8 bài kiểm tra + bài tổng hợp:
do sim/run_all.do

# Chạy 1 bài kiểm tra cụ thể (thay tên tb tương ứng):
set tb tb_servo
do sim/run_one.do
```

**Các bài testbench có sẵn:**

| Testbench | Kiểm tra |
|---|---|
| `tb_button` | Chống dội 4 nút bấm, lọc nhiễu |
| `tb_motor` | Chuỗi 8 pha động cơ bước, busy flag |
| `tb_servo` | Soft-ramp PWM 50 Hz, kẹp giới hạn |
| `tb_buzzer` | Sóng vuông 2 kHz, bật/tắt |
| `tb_led` | LED tầng + hướng + địa chỉ MMIO |
| `tb_led7seg` | Mã LED 7 đoạn tầng 0–4 |
| `tb_uart` | TX/RX khung 8N1, baudrate 115200 |
| `tb_power_on` | Power-on Reset, POR timer, fetch CPU |
| `tb_ibex_system_top` | **Toàn bộ hệ thống** (kịch bản 4 tầng đầy đủ) |

---

## ⚠️ Lưu Ý Quan Trọng

- **Firmware đã được pre-build** sẵn trong `src/firmware_bank*.hex`. Chỉ cần chạy lại `make hex` nếu bạn thay đổi file `elevator.c`.
- Chỉnh góc servo theo cơ khí thực tế bằng cách thay đổi `SERVO_OPEN_ANGLE_DEG` trong `elevator.c` (mặc định 90°), sau đó build lại firmware và tạo lại bitstream.
- **Không dùng Quartus để tổng hợp dự án này** — Quartus không hỗ trợ định dạng project Gowin. Dùng **Gowin EDA**.
- ModelSim đi kèm Quartus chỉ dùng để **mô phỏng Verilog**, không tổng hợp chip Gowin.

---

## 👨‍💻 Tác Giả

- **Đồ án môn học**: Thiết Kế Hệ Thống Số (Digital System Design)
- **Nền tảng**: FPGA Sipeed Tang Nano 9K · Gowin GW1NR-9C · RISC-V Ibex RV32IM
- **GitHub**: [@PHANTIEN0210](https://github.com/PHANTIEN0210)
