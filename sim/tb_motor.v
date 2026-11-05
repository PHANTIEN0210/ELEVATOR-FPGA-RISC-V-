`timescale 1ns/1ps
`default_nettype none
module tb_motor;
  reg clk=0, rst_n=0, data_req=0, data_we=0;
  always #500 clk=~clk;
  reg [31:0] data_wdata=0;
  wire [31:0] data_rdata;
  wire [3:0] motor_pins;
  stepper_mmio #(.CLK_HZ(1000),.STEP_HZ(100)) dut
    (.clk(clk),.rst_n(rst_n),.data_req(data_req),.data_we(data_we),
     .data_wdata(data_wdata),.data_rdata(data_rdata),.motor_pins(motor_pins));
  task write_cmd(input [15:0] steps, input dir);
    begin
      @(negedge clk); data_req=1; data_we=1;
      data_wdata=({16'd0,steps}<<2)|{30'd0,dir,1'b1};
      @(negedge clk); data_req=0; data_we=0;
    end
  endtask
  task read_busy(input expected);
    begin
      @(negedge clk); data_req=1; data_we=0;
      @(negedge clk); data_req=0;
      if(data_rdata[0] !== expected)
        $fatal(1,"[MOTOR] busy read=%b expected=%b",data_rdata[0],expected);
    end
  endtask
  integer changes=0;
  integer direction_check=0;
  reg [3:0] last_pins=0;
  integer phase_id=0;
  always @(negedge clk) if(rst_n && motor_pins !== last_pins) begin
    if(motor_pins != 0 && changes<7) begin
      if(direction_check==1) begin
        case(changes)
          0: if(motor_pins !== 4'b1100) $fatal(1,"[MOTOR] FWD phase 0");
          1: if(motor_pins !== 4'b0100) $fatal(1,"[MOTOR] FWD phase 1");
          2: if(motor_pins !== 4'b0110) $fatal(1,"[MOTOR] FWD phase 2");
          3: if(motor_pins !== 4'b0010) $fatal(1,"[MOTOR] FWD phase 3");
          4: if(motor_pins !== 4'b0011) $fatal(1,"[MOTOR] FWD phase 4");
          5: if(motor_pins !== 4'b0001) $fatal(1,"[MOTOR] FWD phase 5");
          6: if(motor_pins !== 4'b1001) $fatal(1,"[MOTOR] FWD phase 6");
        endcase
      end else if(direction_check==2) begin
        case(changes)
          0: if(motor_pins !== 4'b1001) $fatal(1,"[MOTOR] REV phase 0");
          1: if(motor_pins !== 4'b0001) $fatal(1,"[MOTOR] REV phase 1");
          2: if(motor_pins !== 4'b0011) $fatal(1,"[MOTOR] REV phase 2");
          3: if(motor_pins !== 4'b0010) $fatal(1,"[MOTOR] REV phase 3");
          4: if(motor_pins !== 4'b0110) $fatal(1,"[MOTOR] REV phase 4");
          5: if(motor_pins !== 4'b0100) $fatal(1,"[MOTOR] REV phase 5");
          6: if(motor_pins !== 4'b1100) $fatal(1,"[MOTOR] REV phase 6");
        endcase
      end
    end
    if(motor_pins != 0) $display("[MOTOR] phase=%b remaining=%0d",motor_pins,dut.steps_remain);
    changes=changes+1; last_pins=motor_pins;
  end
  initial begin #300000; $fatal(1,"[MOTOR] TIMEOUT"); end
  initial begin
    phase_id=1; $display("[MOTOR 1] Reset: busy=0, 4 cuon day tat");
    repeat(3) @(negedge clk); rst_n=1;
    phase_id=2; $display("[MOTOR 2] MMIO: bit0=start bit1=UP bit[17:2]=8; 10 clock/buoc");
    direction_check=1;
    write_cmd(8,1);
    read_busy(1);
    $display("[MOTOR] CPU doc busy=1 trong khi pha cuon day dang doi");
    repeat(85) @(negedge clk);
    if(dut.busy !== 0 || dut.steps_remain !== 0 || motor_pins !== 0 || changes !== 8)
      $fatal(1,"[MOTOR] Forward failed busy=%b remain=%0d pins=%b changes=%0d",
        dut.busy,dut.steps_remain,motor_pins,changes);
    read_busy(0);
    phase_id=3; $display("[MOTOR 3] MMIO: dir=DOWN, 8 buoc theo thu tu pha nguoc");
    changes=0; direction_check=2; write_cmd(8,0); read_busy(1);
    repeat(85) @(negedge clk);
    if(dut.busy !== 0 || motor_pins !== 0 || changes !== 8)
      $fatal(1,"[MOTOR] Reverse failed");
    phase_id=4; $display("[MOTOR 4] Lenh 0 buoc: busy=0, motor khong chay");
    write_cmd(0,1); repeat(3) @(negedge clk);
    if(dut.busy !== 0 || motor_pins !== 0) $fatal(1,"[MOTOR] Zero-step failed");
    phase_id=5; $display("[MOTOR 5] Reset giua hanh trinh cat busy va tat 4 pha");
    direction_check=0; write_cmd(20,1); repeat(15) @(negedge clk);
    rst_n=0; #1;
    if(dut.busy !== 0 || motor_pins !== 0) $fatal(1,"[MOTOR] Reset failed");
    $display("[MOTOR] Reset during movement PASS");
    $display("PASS tb_motor"); $finish;
  end
endmodule
`default_nettype wire
