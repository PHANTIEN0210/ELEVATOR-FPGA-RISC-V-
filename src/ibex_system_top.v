`default_nettype none

// ============================================================================
// ibex_system_top.v
// Tang Nano 9K + ibex RISC-V + UART + LED + BUTTON + STEPPER + BUZZER + SERVO
//
// Memory map:
//   0x0000_0000  RAM/ROM 16KB
//   0x4000_0000  UART     (ghi: TX byte | đọc bit0: tx_busy)
//   0x5000_0000  LED      (bit[3:0] tầng, bit4 LÊN, bit5 XUỐNG)
//   0x6000_0000  BUTTON   (bit[3:0], active-high sau debounce)
//   0x6000_0004  BUTTON RAW (bit[3:0], sau đồng bộ, trước debounce)
//   0x7000_0000  7-SEG    (bit[2:0] tầng)
//   0x8000_0000  SERVO cửa (ghi: xung mục tiêu µs; đọc: xung hiện tại, bit16 busy)
//   0x9000_0000  STEPPER
//   0xA000_0000  BUZZER
//   0xC000_0000  TIMER    (đọc: bộ đếm µs tự chạy, 32 bit)
// ============================================================================

module ibex_system_top #(
    // 10 ms at 27 MHz. The power-on value makes startup independent of S2.
    parameter integer POR_CYCLES = 270_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] buttons,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [5:0] leds,
    output wire [6:0] seg_data,
    output wire [3:0] motor_pins,
    output wire       buzzer_pin,
    output wire       led_up,      // đèn hướng LÊN  (LED ngoài)
    output wire       led_down,    // đèn hướng XUỐNG (LED ngoài)
    output wire       servo_pin    // servo cửa (chân 51)
);

// =========================================================================
// 1. Clock / Reset
// =========================================================================
wire clk_i  = clk;
// S2 (FPGA pin 3) is active low. Holding every block in reset for a few
// milliseconds after configuration also covers power-up with S2 untouched.
// Gowin implements the declared zero initial values in configuration bits.
reg [18:0] por_count = 19'd0;
reg [1:0] rst_sync = 2'b00;

always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n)
        por_count <= 19'd0;
    else if (por_count < POR_CYCLES)
        por_count <= por_count + 1'b1;
end

always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n)
        rst_sync <= 2'b00;
    else
        rst_sync <= {rst_sync[0], (por_count == POR_CYCLES)};
end

wire rst_ni = rst_n && rst_sync[1];

// =========================================================================
// 2. ibex instruction bus
// =========================================================================
wire        instr_req;
wire        instr_gnt;
wire        instr_rvalid;
wire [31:0] instr_addr;
wire [31:0] instr_rdata;
wire        instr_err;
wire [6:0]  instr_rdata_intg = 7'b0;

// =========================================================================
// 3. ibex data bus
// =========================================================================
wire        data_req;
wire        data_gnt;
wire        data_rvalid;
wire        data_we;
wire [3:0]  data_be;
wire [31:0] data_addr;
wire [31:0] data_wdata;
wire [31:0] data_rdata;
wire        data_err;
wire [6:0]  data_rdata_intg = 7'b0;

wire [3:0]  lockstep_cmp_en;
wire        data_req_shadow, data_we_shadow, instr_req_shadow;
wire [3:0]  data_be_shadow;
wire [31:0] data_addr_shadow, data_wdata_shadow, instr_addr_shadow;
wire [6:0]  data_wdata_intg_shadow;
wire [1:0]  ram_cfg_rsp_icache_tag, ram_cfg_rsp_icache_data;

// =========================================================================
// 4. ibex_top
// =========================================================================
ibex_top #(
    .PMPEnable        (0),
    .PMPGranularity   (0),
    .PMPNumRegions    (4),
    .MHPMCounterNum   (0),
    .MHPMCounterWidth (40),
    .RV32E            (0),
    .RV32M            (2),
    .RV32B            (0),
    .RegFile          (0),
    .BranchTargetALU  (0),
    .WritebackStage   (0),
    .ICache           (0),
    .ICacheECC        (0),
    .BranchPredictor  (0),
    .DbgTriggerEn     (0),
    .DbgHwBreakNum    (1),
    .SecureIbex       (0),
    .DmHaltAddr       (32'h1A110800),
    .DmExceptionAddr  (32'h1A110808)
) u_ibex_top (
    .clk_i                      (clk_i),
    .rst_ni                     (rst_ni),
    .test_en_i                  (1'b0),
    .ram_cfg_icache_tag_i       (12'b0),
    .ram_cfg_rsp_icache_tag_o   (ram_cfg_rsp_icache_tag),
    .ram_cfg_icache_data_i      (12'b0),
    .ram_cfg_rsp_icache_data_o  (ram_cfg_rsp_icache_data),
    .hart_id_i                  (32'b0),
    // Ibex fetches its first instruction at boot_addr_i + 0x80.
    // link.ld and make_hex.py place _start at physical address 0x80.
    .boot_addr_i                (32'h00000000),
    .instr_req_o                (instr_req),
    .instr_gnt_i                (instr_gnt),
    .instr_rvalid_i             (instr_rvalid),
    .instr_addr_o               (instr_addr),
    .instr_rdata_i              (instr_rdata),
    .instr_rdata_intg_i         (instr_rdata_intg),
    .instr_err_i                (instr_err),
    .data_req_o                 (data_req),
    .data_gnt_i                 (data_gnt),
    .data_rvalid_i              (data_rvalid),
    .data_we_o                  (data_we),
    .data_be_o                  (data_be),
    .data_addr_o                (data_addr),
    .data_wdata_o               (data_wdata),
    .data_wdata_intg_o          (),
    .data_rdata_i               (data_rdata),
    .data_rdata_intg_i          (data_rdata_intg),
    .data_err_i                 (data_err),
    .irq_software_i             (1'b0),
    .irq_timer_i                (1'b0),
    .irq_external_i             (1'b0),
    .irq_fast_i                 (15'b0),
    .irq_nm_i                   (1'b0),
    .scramble_key_valid_i       (1'b0),
    .scramble_key_i             (128'b0),
    .scramble_nonce_i           (64'b0),
    .scramble_req_o             (),
    .debug_req_i                (1'b0),
    .crash_dump_o               (),
    .double_fault_seen_o        (),
    .fetch_enable_i             (4'b0101),
    .alert_minor_o              (),
    .alert_major_internal_o     (),
    .alert_major_bus_o          (),
    .core_sleep_o               (),
    .scan_rst_ni                (1'b1),
    .lockstep_cmp_en_o          (lockstep_cmp_en),
    .data_req_shadow_o          (data_req_shadow),
    .data_we_shadow_o           (data_we_shadow),
    .data_be_shadow_o           (data_be_shadow),
    .data_addr_shadow_o         (data_addr_shadow),
    .data_wdata_shadow_o        (data_wdata_shadow),
    .data_wdata_intg_shadow_o   (data_wdata_intg_shadow),
    .instr_req_shadow_o         (instr_req_shadow),
    .instr_addr_shadow_o        (instr_addr_shadow)
);

// =========================================================================
// 5. Memory map decode
// =========================================================================
// RAM vật lý đúng 16KB (14 bit thấp) -> dmem_sel chỉ khớp 0x0000_0000-0x0000_3FFF
wire dmem_sel    = (data_addr[31:14] == 18'h00000);
wire uart_sel    = (data_addr[31:28] == 4'h4);
wire led_sel     = (data_addr[31:28] == 4'h5);
wire button_sel  = (data_addr[31:28] == 4'h6);
wire seg_sel     = (data_addr[31:28] == 4'h7);
wire servo_sel   = (data_addr[31:28] == 4'h8);
wire stepper_sel = (data_addr[31:28] == 4'h9);
wire buzzer_sel  = (data_addr[31:28] == 4'hA);
wire timer_sel   = (data_addr[31:28] == 4'hC);

wire [11:0] ibus_word_addr = instr_addr[13:2];
wire [11:0] dbus_word_addr = data_addr[13:2];

// [FIX] Bus trả dữ liệu đọc TRỄ 1 chu kỳ (data_rvalid = data_req đã trễ).
// Vì vậy phải CHỐT thiết bị được chọn tại chu kỳ yêu cầu rồi mới dùng để
// chọn nguồn dữ liệu ở chu kỳ phản hồi. Nếu dùng thẳng data_addr (tổ hợp),
// địa chỉ có thể đã đổi sang lệnh kế tiếp -> đọc nhầm thanh ghi.
reg       dmem_sel_r;
reg [3:0] dev_sel_r;

always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        dmem_sel_r <= 1'b0;
        dev_sel_r  <= 4'h0;
    end else if (data_req) begin
        dmem_sel_r <= dmem_sel;
        dev_sel_r  <= data_addr[31:28];
    end
end

// =========================================================================
// 6. Instruction ROM 16KB
// =========================================================================
reg [7:0] imem0 [0:4095] /* synthesis syn_romstyle = "block_rom" */;
reg [7:0] imem1 [0:4095] /* synthesis syn_romstyle = "block_rom" */;
reg [7:0] imem2 [0:4095] /* synthesis syn_romstyle = "block_rom" */;
reg [7:0] imem3 [0:4095] /* synthesis syn_romstyle = "block_rom" */;

// =========================================================================
// 7. Data RAM 16KB
// =========================================================================
reg [7:0] dmem0 [0:4095] /* synthesis syn_ramstyle = "block_ram" */;
reg [7:0] dmem1 [0:4095] /* synthesis syn_ramstyle = "block_ram" */;
reg [7:0] dmem2 [0:4095] /* synthesis syn_ramstyle = "block_ram" */;
reg [7:0] dmem3 [0:4095] /* synthesis syn_ramstyle = "block_ram" */;

initial begin
    $readmemh("src/firmware_bank0.hex", imem0);
    $readmemh("src/firmware_bank1.hex", imem1);
    $readmemh("src/firmware_bank2.hex", imem2);
    $readmemh("src/firmware_bank3.hex", imem3);

    $readmemh("src/firmware_bank0.hex", dmem0);
    $readmemh("src/firmware_bank1.hex", dmem1);
    $readmemh("src/firmware_bank2.hex", dmem2);
    $readmemh("src/firmware_bank3.hex", dmem3);
end

// =========================================================================
// 8. Instruction bus
// =========================================================================
assign instr_gnt = instr_req;
assign instr_err = 1'b0;

reg        instr_rvalid_r;
reg [31:0] instr_rdata_r;

always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        instr_rvalid_r <= 1'b0;
        instr_rdata_r  <= 32'b0;
    end else begin
        instr_rvalid_r <= instr_req;
        if (instr_req)
            instr_rdata_r <= {imem3[ibus_word_addr], imem2[ibus_word_addr],
                              imem1[ibus_word_addr], imem0[ibus_word_addr]};
    end
end

assign instr_rvalid = instr_rvalid_r;
assign instr_rdata  = instr_rdata_r;

// =========================================================================
// 9. Data bus — RAM
// =========================================================================
assign data_gnt = data_req;
assign data_err = 1'b0;

reg        data_rvalid_r;
reg [31:0] data_rdata_ram;

always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        data_rvalid_r  <= 1'b0;
        data_rdata_ram <= 32'b0;
    end else begin
        data_rvalid_r <= data_req;
        if (data_req && dmem_sel) begin
            data_rdata_ram <= {dmem3[dbus_word_addr], dmem2[dbus_word_addr],
                               dmem1[dbus_word_addr], dmem0[dbus_word_addr]};
            if (data_we) begin
                if (data_be[0]) dmem0[dbus_word_addr] <= data_wdata[7:0];
                if (data_be[1]) dmem1[dbus_word_addr] <= data_wdata[15:8];
                if (data_be[2]) dmem2[dbus_word_addr] <= data_wdata[23:16];
                if (data_be[3]) dmem3[dbus_word_addr] <= data_wdata[31:24];
            end
        end
    end
end

assign data_rvalid = data_rvalid_r;

// =========================================================================
// 10. LED MMIO  0x5000_0000
// =========================================================================
reg [5:0] led_reg;

always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        led_reg <= 6'b0;
    else if (led_sel && data_req && data_we)
        led_reg <= data_wdata[5:0];
end

// Tang Nano 9K onboard LEDs are active-low: all six stay on.
assign leds = 6'b000000;

assign led_up   = led_reg[4];
assign led_down = led_reg[5];

// =========================================================================
// 11. BUTTON MMIO 0x6000_0000
// =========================================================================
wire [3:0] btn_stable;
wire [3:0] btn_raw;

button_mmio #(
    .CLK_HZ      (27_000_000),
    .DEBOUNCE_MS (20)
) u_button_debounce (
    .clk        (clk_i),
    .rst_n      (rst_ni),
    .buttons    (buttons),
    .btn_stable (btn_stable),
    .btn_raw    (btn_raw)
);

reg [31:0] btn_rdata_r;

always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        btn_rdata_r <= 32'd0;
    else if (data_req && !data_we && button_sel)
        btn_rdata_r <= data_addr[2] ? {28'd0, btn_raw}
                                    : {28'd0, btn_stable};
end

// =========================================================================
// 12. 7-SEG MMIO  0x7000_0000
// =========================================================================
reg [2:0] seg_floor_reg;

always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        seg_floor_reg <= 3'd0;
    else if (seg_sel && data_we && data_req)
        seg_floor_reg <= data_wdata[2:0];
end

led_7_seg_mmio u_seg (
    .current_floor(seg_floor_reg),
    .seg_data(seg_data)
);

// =========================================================================
// 13. UART MMIO  0x4000_0000
//   ghi  @+0 : gửi byte
//   đọc  @+0 : bit0 = tx_busy (1 = đang gửi, KHÔNG được ghi thêm)
//   đọc  @+4 : byte nhận (0xFFFFFFFF nếu chưa có)
// =========================================================================
wire [31:0] uart_dat_do;
wire        uart_dat_wait;
wire        uart_tx_busy;

wire uart_tx_sel = uart_sel && data_we  && data_req && (data_addr[3:2] == 2'b00);
wire uart_rx_sel = uart_sel && !data_we && data_req && (data_addr[3:2] == 2'b01);
wire uart_st_sel = uart_sel && !data_we && data_req && (data_addr[3:2] == 2'b00);

uart_mmio #(
    .DEFAULT_DIV(16'd234)
) uart_inst (
    .clk         (clk_i),
    .resetn      (rst_ni),
    .ser_tx      (uart_tx),
    .ser_rx      (uart_rx),
    .reg_div_we  (4'b0000),
    .reg_div_di  (32'b0),
    .reg_div_do  (),
    .reg_dat_we  (uart_tx_sel),
    .reg_dat_re  (uart_rx_sel),
    .reg_dat_di  (data_wdata),
    .reg_dat_do  (uart_dat_do),
    .reg_dat_wait(uart_dat_wait),
    .reg_tx_busy (uart_tx_busy)
);

wire [31:0] uart_status = {31'b0, uart_tx_busy};

reg [31:0] uart_rdata_r;
always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        uart_rdata_r <= 32'b0;
    else if (uart_rx_sel)
        uart_rdata_r <= uart_dat_do;
    else if (uart_st_sel)
        uart_rdata_r <= uart_status;
end

// =========================================================================
// 14. STEPPER MMIO  0x9000_0000
// =========================================================================
wire [31:0] stepper_rdata;

stepper_mmio #(
    .CLK_HZ  (27_000_000),
    .STEP_HZ (400)
) u_stepper (
    .clk        (clk_i),
    .rst_n      (rst_ni),
    .data_req   (data_req && stepper_sel),
    .data_we    (data_we),
    .data_wdata (data_wdata),
    .data_rdata (stepper_rdata),
    .motor_pins (motor_pins)
);

// =========================================================================
// 15. BUZZER MMIO  0xA000_0000
// =========================================================================
buzzer_mmio #(
    .CLK_HZ  (27_000_000),
    .TONE_HZ (2000)
) u_buzzer (
    .clk        (clk_i),
    .rst_n      (rst_ni),
    .data_req   (data_req && buzzer_sel),
    .data_we    (data_we),
    .data_wdata (data_wdata),
    .buzzer_pin (buzzer_pin)
);

// =========================================================================
// 16. SERVO MMIO  0x8000_0000: cửa dùng chính vị trí servo
// =========================================================================
wire [31:0] servo_rdata;

servo_mmio #(
    .CLK_HZ     (27_000_000),
    .DEFAULT_US (1000),      // vị trí cửa đóng đã hiệu chỉnh
    .STEP_US    (10)         // 1125 us / 10 us per 20 ms: about 2.26 s
) u_servo (
    .clk        (clk_i),
    .rst_n      (rst_ni),
    .data_req   (data_req && servo_sel),
    .data_we    (data_we),
    .data_wdata (data_wdata),
    .data_rdata (servo_rdata),
    .servo_pin  (servo_pin)
);

// =========================================================================
// 17. TIMER MMIO  0xC000_0000  (bộ đếm µs tự chạy, chỉ đọc)
// =========================================================================
localparam integer TIMER_US_DIV = 27_000_000 / 1_000_000 - 1;   // 26

reg [7:0]  timer_div;
reg [31:0] timer_us;
reg [31:0] timer_rdata_r;

always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        timer_div <= 8'd0;
        timer_us  <= 32'd0;
    end else if (timer_div == TIMER_US_DIV[7:0]) begin
        timer_div <= 8'd0;
        timer_us  <= timer_us + 1'b1;
    end else begin
        timer_div <= timer_div + 1'b1;
    end
end

always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        timer_rdata_r <= 32'd0;
    else if (data_req && timer_sel && !data_we)
        timer_rdata_r <= timer_us;
end

// =========================================================================
// 18. Read data mux  (chọn theo thiết bị đã CHỐT ở chu kỳ yêu cầu)
// =========================================================================
assign data_rdata = dmem_sel_r            ? data_rdata_ram :
                    (dev_sel_r == 4'h4)   ? uart_rdata_r   :
                    (dev_sel_r == 4'h6)   ? btn_rdata_r    :
                     (dev_sel_r == 4'h8)   ? servo_rdata    :
                    (dev_sel_r == 4'h9)   ? stepper_rdata  :
                    (dev_sel_r == 4'hC)   ? timer_rdata_r  :
                                            32'd0;

endmodule

`default_nettype wire
