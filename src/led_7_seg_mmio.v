module led_7_seg_mmio (
    input  wire [2:0] current_floor,
    output reg  [6:0] seg_data
);
    // Common Cathode: 1 = ON, 0 = OFF
    // Bit order: seg_data[6:0] = gfedcba
    always @(*) begin
        case (current_floor)
            3'd0: seg_data = 7'b1000000; // "-"
            3'd1: seg_data = 7'b0000110; // 1
            3'd2: seg_data = 7'b1011011; // 2
            3'd3: seg_data = 7'b1001111; // 3
            3'd4: seg_data = 7'b1100110; // 4
            default: seg_data = 7'b1111001; // E (error)
        endcase
    end
endmodule