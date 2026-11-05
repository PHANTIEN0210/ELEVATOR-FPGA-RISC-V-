`default_nettype none

// ============================================================================
// servo_mmio.v
// Điều khiển servo RC (PWM 50 Hz) cho Tang Nano 9K @ 27 MHz
//
// MMIO: 0x8000_0000 (cửa dùng chính vị trí servo, không có thanh ghi DOOR riêng)
//   GHI : bit[11:0] = độ rộng xung mục tiêu (micro giây), tự kẹp trong
//         [MIN_US .. MAX_US]. Góc thực tế phụ thuộc loại servo và cơ khí cửa.
//   ĐỌC : bit[11:0] = độ rộng xung hiện tại (µs)
//         bit[16]   = 1 nếu servo còn đang quay tới vị trí mục tiêu
//
// Servo không nhảy tức thời: mỗi khung 20 ms, độ rộng xung nhích STEP_US µs
// về phía mục tiêu -> quay mượt, ít giật. STEP_US = 10 => 1125 µs mất ~2,26 giây.
// ============================================================================

module servo_mmio #(
    parameter CLK_HZ     = 27_000_000,
    parameter FRAME_US   = 20000,   // chu kỳ PWM: 20 ms = 50 Hz
    parameter MIN_US     = 500,
    parameter MAX_US     = 2500,
    parameter DEFAULT_US = 1000,    // vị trí khi vừa cấp nguồn (cửa đóng)
    parameter STEP_US    = 10       // µs nhích mỗi khung
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        data_req,
    input  wire        data_we,
    input  wire [31:0] data_wdata,
    output reg  [31:0] data_rdata,
    output reg         servo_pin
);

localparam integer US_DIV = CLK_HZ / 1_000_000 - 1;   // 26 với 27 MHz

localparam [11:0] MIN_C = MIN_US;
localparam [11:0] MAX_C = MAX_US;
localparam [11:0] DEF_C = DEFAULT_US;
localparam [11:0] STEP_C = STEP_US;

reg [7:0]  div_cnt;
reg [14:0] frame_cnt;      // đếm µs trong khung 0..FRAME_US-1
reg [11:0] target_us;
reg [11:0] cur_us;

wire tick_us   = (div_cnt == US_DIV[7:0]);
wire frame_end = tick_us && (frame_cnt == FRAME_US - 1);

// ── Bộ đếm thời gian ─────────────────────────────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt   <= 8'd0;
        frame_cnt <= 15'd0;
    end else begin
        if (tick_us) begin
            div_cnt <= 8'd0;
            if (frame_cnt == FRAME_US - 1)
                frame_cnt <= 15'd0;
            else
                frame_cnt <= frame_cnt + 1'b1;
        end else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end
end

// ── Ghi mục tiêu từ CPU (kẹp giới hạn an toàn) ──────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        target_us <= DEF_C;
    else if (data_req && data_we) begin
        if (data_wdata[11:0] < MIN_C)
            target_us <= MIN_C;
        else if (data_wdata[11:0] > MAX_C)
            target_us <= MAX_C;
        else
            target_us <= data_wdata[11:0];
    end
end

// ── Nhích dần về mục tiêu mỗi cuối khung ────────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cur_us <= DEF_C;
    else if (frame_end) begin
        if (cur_us < target_us) begin
            if ((target_us - cur_us) <= STEP_C)
                cur_us <= target_us;
            else
                cur_us <= cur_us + STEP_C;
        end else if (cur_us > target_us) begin
            if ((cur_us - target_us) <= STEP_C)
                cur_us <= target_us;
            else
                cur_us <= cur_us - STEP_C;
        end
    end
end

// ── Xuất xung PWM (đăng ký để chống glitch) ─────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        servo_pin <= 1'b0;
    else
        servo_pin <= (frame_cnt < {3'b000, cur_us});
end

// ── Đọc trạng thái ──────────────────────────────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_rdata <= 32'd0;
    else if (data_req && !data_we)
        data_rdata <= {15'd0, (cur_us != target_us), 4'd0, cur_us};
end

endmodule

`default_nettype wire
