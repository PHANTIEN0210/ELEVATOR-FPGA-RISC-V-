`default_nettype none

// ============================================================================
// button_mmio.v
// Debounce nút bấm active-low cho Tang Nano 9K @ 27 MHz
//
// Ports:
//   clk        — 27 MHz
//   rst_n      — reset active-low
//   buttons    — nút vật lý (active-low)
//   btn_stable — bit đã debounce, active-high, đọc bởi CPU
// ============================================================================

module button_mmio #(
    parameter CLK_HZ      = 27_000_000,
    parameter DEBOUNCE_MS = 20
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] buttons,      // active-low: nút tầng 1..4
    output reg  [3:0] btn_stable,   // active-high sau chống dội
    output wire [3:0] btn_raw       // active-high sau đồng bộ, trước chống dội
);

// Số cycle cần giữ ổn định = CLK_HZ * DEBOUNCE_MS / 1000 - 1
localparam integer DEBOUNCE_CNT = CLK_HZ / 1000 * DEBOUNCE_MS - 1;

// ── 2-stage synchronizer ─────────────────────────────────────────────────
reg [3:0] sync0, sync1;
assign btn_raw = sync1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sync0 <= 4'h0;
        sync1 <= 4'h0;
    end else begin
        sync0 <= ~buttons;   // đảo: active-low → active-high
        sync1 <= sync0;
    end
end

// ── Debounce từng bit bằng generate ─────────────────────────────────────
genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : gen_deb
        reg [19:0] cnt;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                cnt             <= 20'd0;
                btn_stable[i]   <= 1'b0;
            end else if (sync1[i] == btn_stable[i]) begin
                // Tín hiệu ổn định → reset counter
                cnt <= 20'd0;
            end else if (cnt == DEBOUNCE_CNT[19:0]) begin
                // Đã giữ ổn định đủ thời gian → cập nhật output
                btn_stable[i] <= sync1[i];
                cnt           <= 20'd0;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endgenerate

endmodule

`default_nettype wire
