`timescale 1ns/1ps
`default_nettype none
module tb_uart;
  integer phase_id=0;
  reg clk=0, resetn=0, ser_rx=1, reg_dat_we=0, reg_dat_re=0;
  always #18.518 clk=~clk; // 27 MHz
  reg [31:0] reg_dat_di=0;
  wire ser_tx, reg_tx_busy, reg_dat_wait;
  wire [31:0] reg_dat_do, reg_div_do;
  uart_mmio #(.DEFAULT_DIV(234)) dut
    (.clk(clk),.resetn(resetn),.ser_tx(ser_tx),.ser_rx(ser_rx),
     .reg_div_we(4'b0),.reg_div_di(32'b0),.reg_div_do(reg_div_do),
     .reg_dat_we(reg_dat_we),.reg_dat_re(reg_dat_re),
     .reg_dat_di(reg_dat_di),.reg_dat_do(reg_dat_do),
     .reg_dat_wait(reg_dat_wait),.reg_tx_busy(reg_tx_busy));
  task tx_check(input [7:0] value);
    reg [7:0] observed;
    integer i;
    begin
      wait(!reg_tx_busy); @(negedge clk);
      reg_dat_di=value; reg_dat_we=1;
      @(negedge clk); reg_dat_we=0;
      if(ser_tx !== 0 || reg_tx_busy !== 1) $fatal(1,"[UART] TX start/busy failed");
      repeat(118) @(negedge clk);
      if(ser_tx !== 0) $fatal(1,"[UART] Start bit too short");
      for(i=0;i<8;i=i+1) begin
        repeat(236) @(negedge clk); observed[i]=ser_tx;
      end
      repeat(236) @(negedge clk);
      if(ser_tx !== 1 || observed !== value)
        $fatal(1,"[UART] TX sent %h expected %h stop=%b",observed,value,ser_tx);
      $display("[UART] TX 0x%02h (%c): start=0, 8 data LSB-first, stop=1, busy PASS",value,value);
    end
  endtask
  task rx_send(input [7:0] value);
    integer i;
    begin
      @(negedge clk); ser_rx=0; repeat(236) @(negedge clk);
      for(i=0;i<8;i=i+1) begin
        ser_rx=value[i]; repeat(236) @(negedge clk);
      end
      ser_rx=1; repeat(250) @(negedge clk);
      if(reg_dat_do[7:0] !== value)
        $fatal(1,"[UART] RX got %h expected %h",reg_dat_do,value);
      $display("[UART] RX 0x%02h (%c) PASS",reg_dat_do[7:0],value);
      reg_dat_re=1; @(negedge clk); reg_dat_re=0;
      #1; if(reg_dat_do !== 32'hffffffff) $fatal(1,"[UART] RX clear failed: %h",reg_dat_do);
    end
  endtask
  initial begin #1000000; $fatal(1,"[UART] TIMEOUT"); end
  initial begin
    repeat(3) @(negedge clk); resetn=1;
    if(reg_div_do !== 234) $fatal(1,"[UART] Divider reset failed");
    phase_id=1; $display("[UART 1] Divider=234 o 27 MHz; xap xi 115200 baud, 8N1");
    phase_id=2; $display("[UART 2] CPU ghi byte; TX phat start/data/stop, busy=1");
    tx_check(8'h41); tx_check(8'h55);
    phase_id=3; $display("[UART 3] RX nhan 8 bit LSB-first; doc thanh ghi xoa valid");
    rx_send(8'h5a);
    phase_id=4; $display("[UART 4] Reset dua TX vao idle sau dummy frame");
    resetn=0; @(negedge clk);
    if(reg_tx_busy !== 1) $fatal(1,"[UART] Reset dummy state missing");
    $display("PASS tb_uart"); $finish;
  end
endmodule
`default_nettype wire
