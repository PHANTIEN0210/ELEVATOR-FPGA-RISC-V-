`timescale 1ns/1ps
`default_nettype none
module tb_buzzer;
  integer phase_id=0;
  reg clk=0, rst_n=0, data_req=0, data_we=0;
  always #18.518 clk=~clk; // production 27 MHz clock
  reg [31:0] data_wdata=0;
  wire buzzer_pin;
  buzzer_mmio #(.CLK_HZ(27000000),.TONE_HZ(2000)) dut
    (.clk(clk),.rst_n(rst_n),.data_req(data_req),.data_we(data_we),
     .data_wdata(data_wdata),.buzzer_pin(buzzer_pin));
  task set_buzzer(input on);
    begin
      @(negedge clk); data_req=1; data_we=1; data_wdata=on;
      @(negedge clk); data_req=0; data_we=0;
    end
  endtask
  time rise1, rise2;
  initial begin #10000000; $fatal(1,"[BUZZER] TIMEOUT"); end
  initial begin
    repeat(3) @(negedge clk); rst_n=1;
    if(buzzer_pin !== 0) $fatal(1,"[BUZZER] Not idle");
    phase_id=1; $display("[BUZZER 1] MMIO bit0=1: bat tone 2 kHz tai 27 MHz");
    set_buzzer(1);
    @(posedge buzzer_pin); rise1=$time;
    @(negedge buzzer_pin);
    if($time-rise1 < 249980 || $time-rise1 > 250020)
      $fatal(1,"[BUZZER] High width=%0d ns",$time-rise1);
    @(posedge buzzer_pin); rise2=$time;
    if(rise2-rise1 < 499960 || rise2-rise1 > 500040)
      $fatal(1,"[BUZZER] Period=%0d ns",rise2-rise1);
    $display("[BUZZER] Period=%0d ns, high=%0d ns",rise2-rise1,250000);
    phase_id=2; $display("[BUZZER 2] MMIO bit0=0: chan buzzer ve 0");
    set_buzzer(0); #1;
    if(buzzer_pin !== 0) $fatal(1,"[BUZZER] Disable failed");
    phase_id=3; $display("[BUZZER 3] Reset khi dang phat tone");
    set_buzzer(1); repeat(20) @(negedge clk);
    rst_n=0; #1;
    if(buzzer_pin !== 0) $fatal(1,"[BUZZER] Reset failed");
    $display("PASS tb_buzzer"); $finish;
  end
endmodule
`default_nettype wire
