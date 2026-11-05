`timescale 1ns/1ps
`default_nettype none
module tb_servo;
  reg clk=0, rst_n=0, data_req=0, data_we=0;
  always #500 clk=~clk; // 1 MHz: one clock is one microsecond
  reg [31:0] data_wdata=0;
  wire [31:0] data_rdata;
  wire servo_pin;
  reg [11:0] previous_us=1000;
  integer ramp_changes=0;
  integer phase_id=0;
  always @(negedge clk) begin
    if (!rst_n) previous_us=1000;
    else if (dut.cur_us != previous_us) begin
      if ((dut.cur_us > previous_us && dut.cur_us-previous_us > 10) ||
          (dut.cur_us < previous_us && previous_us-dut.cur_us > 10))
        $fatal(1,"[SERVO] Ramp exceeded 10 us per frame");
      previous_us=dut.cur_us;
      ramp_changes=ramp_changes+1;
    end
  end
  servo_mmio #(.CLK_HZ(1000000),.STEP_US(10)) dut
    (.clk(clk),.rst_n(rst_n),.data_req(data_req),.data_we(data_we),
     .data_wdata(data_wdata),.data_rdata(data_rdata),.servo_pin(servo_pin));
  task write_us(input [31:0] us);
    begin
      @(negedge clk); data_req=1; data_we=1; data_wdata=us;
      @(negedge clk); data_req=0; data_we=0;
      $display("[SERVO] MMIO target=%0d us, clamped=%0d us",us,dut.target_us);
    end
  endtask
  task read_status(input [11:0] expected_us, input expected_moving);
    begin
      @(negedge clk); data_req=1; data_we=0;
      @(negedge clk); data_req=0;
      if(data_rdata[11:0] !== expected_us || data_rdata[16] !== expected_moving)
        $fatal(1,"[SERVO] Status=%h expected cur=%0d moving=%b",
          data_rdata,expected_us,expected_moving);
    end
  endtask
  task check_pwm(input integer expected_us);
    time rise_t, fall_t, next_rise_t;
    begin
      @(posedge servo_pin); rise_t=$time;
      @(negedge servo_pin); fall_t=$time;
      @(posedge servo_pin); next_rise_t=$time;
      $display("[SERVO] PWM high=%0d ns frame=%0d ns",fall_t-rise_t,next_rise_t-rise_t);
      if(fall_t-rise_t != expected_us*1000 || next_rise_t-rise_t != 20000000)
        $fatal(1,"[SERVO] PWM expected high=%0d us, frame=20000 us",expected_us);
    end
  endtask
  initial begin #5500000000; $fatal(1,"[SERVO] TIMEOUT"); end
  initial begin
    phase_id=1; $display("[SERVO 1] Reset: PWM 1000 us = cua dong");
    repeat(3) @(negedge clk); rst_n=1;
    if(dut.cur_us !== 1000 || dut.target_us !== 1000)
      $fatal(1,"[SERVO] Reset position failed");
    phase_id=2; $display("[SERVO 2] Firmware ghi 2125 us tai 0x80000000; doc bit16 busy");
    $display("[SERVO] 0 deg=1000 us, 90 deg=2125 us; 10 us/frame");
    write_us(2125);
    read_status(1000,1);
    phase_id=3; $display("[SERVO 3] Moi khung 20 ms dich toi da 10 us; PWM 50 Hz");
    repeat(114*20000) @(negedge clk);
    if(dut.cur_us !== 2125) $fatal(1,"[SERVO] Open reached %0d",dut.cur_us);
    read_status(2125,0);
    check_pwm(2125);
    $display("[SERVO] OPEN complete");
    phase_id=4; $display("[SERVO 4] Ghi 1000 us -> dong; chi CLOSED sau busy=0, current=1000");
    write_us(1000);
    repeat(114*20000) @(negedge clk);
    if(dut.cur_us !== 1000) $fatal(1,"[SERVO] Close reached %0d",dut.cur_us);
    read_status(1000,0);
    check_pwm(1000);
    if (ramp_changes != 226) $fatal(1,"[SERVO] Wrong number of ramp steps: %0d",ramp_changes);
    $display("[SERVO] CLOSED complete");
    phase_id=5; $display("[SERVO 5] Gioi han lenh, sau do reset");
    write_us(100); if(dut.target_us !== 500) $fatal(1,"[SERVO] Minimum clamp failed");
    write_us(3000); if(dut.target_us !== 2500) $fatal(1,"[SERVO] Maximum clamp failed");
    rst_n=0; #1;
    if(dut.cur_us !== 1000 || servo_pin !== 0) $fatal(1,"[SERVO] Reset failed");
    $display("PASS tb_servo"); $finish;
  end
endmodule
`default_nettype wire
