`default_nettype none

module stepper_mmio #(
    parameter CLK_HZ  = 27_000_000,
    parameter STEP_HZ = 1000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        data_req,
    input  wire        data_we,
    input  wire [31:0] data_wdata,
    output reg  [31:0] data_rdata,
    output reg  [3:0]  motor_pins
);

localparam integer STEP_PERIOD = CLK_HZ / STEP_HZ;

reg busy;
reg dir;
reg [15:0] steps_remain;
reg [25:0] clk_cnt;
reg [2:0] phase;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy         <= 1'b0;
        dir          <= 1'b0;
        steps_remain <= 16'd0;
        clk_cnt      <= 26'd0;
        phase        <= 3'd0;
        motor_pins   <= 4'b0000;
    end else begin

        /* Nhận lệnh mới */
        if (data_req && data_we && data_wdata[0] && !busy) begin
            dir          <= data_wdata[1];
            steps_remain <= data_wdata[17:2];
            clk_cnt      <= 26'd0;
            busy         <= (data_wdata[17:2] != 0);
        end

        /* Motor đang chạy */
        if (busy) begin
            if (clk_cnt >= STEP_PERIOD - 1) begin
                clk_cnt <= 26'd0;

                /* Chiều thuận */
                if (dir) begin
                    if (phase == 3'd7)
                        phase <= 3'd0;
                    else
                        phase <= phase + 1'b1;
                end
                /* Chiều ngược */
                else begin
                    if (phase == 3'd0)
                        phase <= 3'd7;
                    else
                        phase <= phase - 1'b1;
                end

                /* Xuất pha mới */
                if (dir) begin
                    case (phase)
                        3'd0: motor_pins <= 4'b1100;
                        3'd1: motor_pins <= 4'b0100;
                        3'd2: motor_pins <= 4'b0110;
                        3'd3: motor_pins <= 4'b0010;
                        3'd4: motor_pins <= 4'b0011;
                        3'd5: motor_pins <= 4'b0001;
                        3'd6: motor_pins <= 4'b1001;
                        3'd7: motor_pins <= 4'b1000;
                    endcase
                end else begin
                    case (phase)
                        3'd0: motor_pins <= 4'b1001;
                        3'd1: motor_pins <= 4'b1000;
                        3'd2: motor_pins <= 4'b1100;
                        3'd3: motor_pins <= 4'b0100;
                        3'd4: motor_pins <= 4'b0110;
                        3'd5: motor_pins <= 4'b0010;
                        3'd6: motor_pins <= 4'b0011;
                        3'd7: motor_pins <= 4'b0001;
                    endcase
                end

                /* Đếm bước */
                if (steps_remain > 16'd0)
                    steps_remain <= steps_remain - 1'b1;

                /* Hết bước */
                if (steps_remain == 16'd1) begin
                    busy       <= 1'b0;
                    motor_pins <= 4'b0000;
                end
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end
    end
end

/* Đọc trạng thái busy */
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_rdata <= 32'd0;
    else if (data_req && !data_we)
        data_rdata <= {31'd0, busy};
end

endmodule

`default_nettype wire