`timescale 1ns/1ps
`default_nettype none
module tb_led7seg;
  integer phase_id=0;
  reg [2:0] current_floor=3'bxxx;
  wire [6:0] seg_data;
  led_7_seg_mmio dut(.current_floor(current_floor),.seg_data(seg_data));
  task check(input [2:0] floor, input [6:0] expected);
    begin
      current_floor=floor; #1;
      $display("[LED7SEG] floor=%0d gfedcba=%07b",floor,seg_data);
      if(seg_data !== expected) $fatal(1,"[LED7SEG] floor %0d expected %07b",floor,expected);
    end
  endtask
  initial begin
    phase_id=1; $display("[LED7SEG 1] Ma 0 hien dau gach khi khoi dong; common-cathode, gfedcba");
    check(0,7'b1000000); check(1,7'b0000110);
    phase_id=2; $display("[LED7SEG 2] CPU ghi ma tang 1..4 -> tung doan a..g");
    check(2,7'b1011011); check(3,7'b1001111);
    check(4,7'b1100110); check(5,7'b1111001);
    phase_id=3; $display("[LED7SEG 3] Ma khong hop le 5..7 hien E");
    check(6,7'b1111001); check(7,7'b1111001);
    $display("PASS tb_led7seg"); $finish;
  end
endmodule
`default_nettype wire
