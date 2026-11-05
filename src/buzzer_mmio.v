`default_nettype none

// ============================================================================
// buzzer_mmio.v
// Điều khiển passive buzzer @ 2kHz
// Tang Nano 9K @ 27 MHz
//
// MMIO: 0xA000_0000
//   CPU ghi bit[0] = 1 → bật buzzer (phát tone 2kHz)
//   CPU ghi bit[0] = 0 → tắt buzzer
// ============================================================================

module buzzer_mmio #(
    parameter CLK_HZ     = 27_000_000,
    parameter TONE_HZ    = 2000        // tần số tone, Hz
) (
    input  wire clk,
    input  wire rst_n,
    input  wire data_req,
    input  wire data_we,
    input  wire [31:0] data_wdata,
    output wire buzzer_pin
);

// Số cycle nửa chu kỳ = CLK / (TONE * 2)
localparam integer HALF_PERIOD = CLK_HZ / (TONE_HZ * 2) - 1;  // 6749

reg        enable;
reg [13:0] cnt;
reg        tone;

// ── MMIO write ───────────────────────────────────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        enable <= 1'b0;
    else if (data_req && data_we)
        enable <= data_wdata[0];
end

// ── Tạo sóng vuông tone_hz ───────────────────────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt  <= 14'd0;
        tone <= 1'b0;
    end else if (enable) begin
        if (cnt >= HALF_PERIOD[13:0]) begin
            cnt  <= 14'd0;
            tone <= ~tone;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end else begin
        cnt  <= 14'd0;
        tone <= 1'b0;
    end
end

assign buzzer_pin = enable ? tone : 1'b0;

endmodule

`default_nettype wire