`timescale 1ns/1ps
`default_nettype none
// Giai doan: chan active-low -> 2 FF dong bo -> raw -> debounce -> stable/MMIO.
module tb_button;
  reg clk=0, rst_n=0;
  always #500 clk=~clk;
  reg [3:0] buttons=4'b1111;
  wire [3:0] btn_stable, btn_raw;
  integer phase_id=0, floor_idx;
  button_mmio #(.CLK_HZ(1000),.DEBOUNCE_MS(3)) dut
    (.clk(clk),.rst_n(rst_n),.buttons(buttons),.btn_stable(btn_stable),.btn_raw(btn_raw));
  initial begin #120000; $fatal(1,"[BUTTON] TIMEOUT"); end
  initial begin
    phase_id=1; $display("[BUTTON 1] Reset: 4 chan tha = 1111, raw/stable = 0000");
    repeat(3) @(negedge clk); rst_n=1;
    if(btn_raw !== 0 || btn_stable !== 0) $fatal(1,"[BUTTON] Reset failed");
    phase_id=2; $display("[BUTTON 2] Xung doi < 3 chu ky phai bi loc");
    buttons[0]=0; @(negedge clk); buttons[0]=1;
    repeat(5) @(negedge clk);
    if(btn_stable !== 0) $fatal(1,"[BUTTON] Bounce was accepted");
    phase_id=3; $display("[BUTTON 3] Nhan tung tang 1..4: raw co truoc stable");
    for(floor_idx=0;floor_idx<4;floor_idx=floor_idx+1) begin
      buttons[floor_idx]=0;
      repeat(3) @(negedge clk);
      if(btn_raw[floor_idx] !== 1 || btn_stable[floor_idx] !== 0)
        $fatal(1,"[BUTTON] Floor %0d synchronizer/debounce order",floor_idx+1);
      repeat(5) @(negedge clk);
      if(btn_stable !== (4'b0001 << floor_idx))
        $fatal(1,"[BUTTON] Floor %0d stable=%b",floor_idx+1,btn_stable);
      $display("[BUTTON] Tang %0d: pin=0 raw=%b stable=%b -> MMIO bit %0d = 1",
               floor_idx+1,btn_raw,btn_stable,floor_idx);
      repeat(4) @(negedge clk);
      if(btn_stable !== (4'b0001 << floor_idx)) $fatal(1,"[BUTTON] Held press changed");
      buttons[floor_idx]=1;
      repeat(8) @(negedge clk);
      if(btn_stable !== 0) $fatal(1,"[BUTTON] Floor %0d release",floor_idx+1);
    end
    phase_id=4; $display("[BUTTON 4] Nhan dong thoi 4 tang va reset khi dang nhan");
    buttons=4'b0000; repeat(8) @(negedge clk);
    if(btn_raw !== 4'b1111 || btn_stable !== 4'b1111)
      $fatal(1,"[BUTTON] Simultaneous press failed raw=%b stable=%b",btn_raw,btn_stable);
    rst_n=0; #1;
    if(btn_raw !== 0 || btn_stable !== 0) $fatal(1,"[BUTTON] Async reset failed");
    $display("PASS tb_button"); $finish;
  end
endmodule
`default_nettype wire
