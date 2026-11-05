`timescale 1ns/1ps
`default_nettype none
module tb_led;
  reg clk=0, rst_n=0;
  always #18.518 clk=~clk;
  reg [3:0] buttons=4'b1111;
  wire uart_tx, buzzer_pin, led_up, led_down, servo_pin;
  wire [5:0] leds;
  wire [6:0] seg_data;
  wire [3:0] motor_pins;
  reg [31:0] sim_us=0, inject_addr=0, inject_data=0;
  integer phase_id=0;
  always @(posedge clk) if(rst_n) sim_us<=sim_us+1000;
  ibex_system_top dut
    (.clk(clk),.rst_n(rst_n),.buttons(buttons),.uart_rx(1'b1),.uart_tx(uart_tx),
     .leds(leds),.seg_data(seg_data),.motor_pins(motor_pins),
     .buzzer_pin(buzzer_pin),.led_up(led_up),.led_down(led_down),.servo_pin(servo_pin));
  always @(negedge clk) if (leds !== 6'b000000)
    $fatal(1,"[LED] Onboard LEDs must remain on: %b",leds);
  defparam dut.POR_CYCLES=4;
  task mmio_write(input [31:0] addr, input [31:0] value);
    begin
      inject_addr=addr; inject_data=value;
      @(negedge clk);
      force dut.data_req=1'b1; force dut.data_we=1'b1;
      force dut.data_addr=inject_addr; force dut.data_wdata=inject_data;
      @(negedge clk);
      release dut.data_req; release dut.data_we;
      release dut.data_addr; release dut.data_wdata;
      @(negedge clk);
    end
  endtask
  task mmio_read(input [31:0] addr, output [31:0] value);
    begin
      inject_addr=addr;
      @(negedge clk);
      force dut.data_req=1'b1; force dut.data_we=1'b0;
      force dut.data_addr=inject_addr;
      @(negedge clk);
      value=dut.data_rdata;
      release dut.data_req; release dut.data_we; release dut.data_addr;
      @(negedge clk);
    end
  endtask
  reg [31:0] read_value;
  initial begin #1000000; $fatal(1,"[LED] TIMEOUT"); end
  initial begin
    repeat(5) @(negedge clk); rst_n=1;
    force dut.timer_us=sim_us;
    repeat(3000) @(negedge clk);
    phase_id=1; $display("[LED 1] CPU ghi 0x50000000: LED Tang Nano active-low luon sang");
    mmio_write(32'h50000000,32'h0000000f);
    if(leds !== 6'b000000 || dut.led_reg[3:0] !== 4'b1111 || led_up !== 0 || led_down !== 0)
      $fatal(1,"[LED] Floor outputs wrong: %b",leds);
    $display("[LED] Six onboard LEDs stay on (active-low): %b",leds);
    phase_id=2; $display("[LED 2] Bit4/bit5 tai MMIO dieu khien LED huong len/xuong");
    mmio_write(32'h50000000,32'h00000010);
    if(led_up !== 1 || led_down !== 0 || leds !== 6'b000000)
      $fatal(1,"[LED] UP output failed");
    mmio_write(32'h50000000,32'h00000020);
    if(led_up !== 0 || led_down !== 1 || leds !== 6'b000000)
      $fatal(1,"[LED] DOWN output failed");
    phase_id=3; $display("[LED 3] 0x80000000 la servo: ghi muc tieu, doc vi tri/busy");
    mmio_write(32'h80000000,32'd2125);
    if(dut.u_servo.target_us !== 12'd2125) $fatal(1,"[LED] Servo MMIO 0x8 write failed");
    mmio_read(32'h80000000,read_value);
    if(read_value[16] !== 1'b1 || read_value[11:0] !== 12'd1000)
      $fatal(1,"[LED] Servo MMIO 0x8 read failed: %h",read_value);
    $display("[LED] SERVO read=0x%08h: current=%0d us, moving=%b",read_value,read_value[11:0],read_value[16]);
    mmio_write(32'hB0000000,32'd1500);
    if(dut.u_servo.target_us !== 12'd2125) $fatal(1,"[LED] Old 0xB address still writes servo");
    mmio_read(32'hB0000000,read_value);
    if(read_value !== 32'd0) $fatal(1,"[LED] Old 0xB address still readable: %h",read_value);
    $display("[LED] 0xB0000000 unmapped; status cua chi dua vao servo PASS");
    phase_id=4;
    rst_n=0; repeat(4) @(negedge clk);
    if(leds !== 6'b000000 || led_up !== 0 || led_down !== 0)
      $fatal(1,"[LED] Reset failed: leds=%b",leds);
    $display("PASS tb_led"); $finish;
  end
endmodule
`default_nettype wire
