`timescale 1ns/1ps
`default_nettype none

// Board-level smoke test: power is applied with S2 RELEASED. No artificial
// reset pulse or forced timer is used. Only the long debounce is shortened.
module tb_power_on;
  reg clk = 0;
  always #18.518 clk = ~clk;  // 27 MHz
  reg rst_n = 1;             // S2 released from the very first cycle
  reg [3:0] buttons = 4'b1111;
  wire uart_tx, buzzer_pin, led_up, led_down, servo_pin;
  wire [5:0] leds;
  wire [6:0] seg_data;
  wire [3:0] motor_pins;
  integer phase_id = 0;
  integer boot_fetches = 0;
  integer i;
  reg [31:0] timer_before;

  ibex_system_top dut
    (.clk(clk), .rst_n(rst_n), .buttons(buttons), .uart_rx(1'b1),
     .uart_tx(uart_tx), .leds(leds),
     .seg_data(seg_data), .motor_pins(motor_pins), .buzzer_pin(buzzer_pin),
     .led_up(led_up), .led_down(led_down), .servo_pin(servo_pin));

  defparam dut.POR_CYCLES = 8;
  defparam dut.u_button_debounce.CLK_HZ = 27000; // 20 ms -> 540 cycles in this test

  always @(posedge clk) begin
    if (dut.instr_req && dut.instr_addr == 32'h00000080) begin
      boot_fetches = boot_fetches + 1;
      $display("[POWER] Ibex fetch 0x80, count=%0d", boot_fetches);
    end
  end
  always @(negedge clk) begin
    if (leds !== 6'b000000)
      $fatal(1,"[LED] Onboard LEDs should stay on");
  end

  task press_floor(input integer floor_no);
    begin
      phase_id = floor_no;
      @(negedge clk); buttons[floor_no-1] = 1'b0;
      repeat (4) @(negedge clk);
      if (dut.btn_raw[floor_no-1] !== 1'b1 ||
          dut.btn_stable[floor_no-1] !== 1'b0)
        $fatal(1,"[BUTTON %0d] raw/stable timing wrong", floor_no);
      repeat (600) @(negedge clk);
      if (dut.btn_stable[floor_no-1] !== 1'b1 ||
          dut.btn_raw !== (4'b0001 << (floor_no-1)))
        $fatal(1,"[BUTTON %0d] stable press missing", floor_no);
      $display("[BUTTON %0d] physical low -> synchronized bit -> debounced bit PASS",floor_no);
      buttons[floor_no-1] = 1'b1;
      repeat (600) @(negedge clk);
      if (dut.btn_stable[floor_no-1] !== 1'b0 || dut.btn_raw !== 4'b0)
        $fatal(1,"[BUTTON %0d] release missing",floor_no);
    end
  endtask

  initial begin
    repeat (20000) @(posedge clk);
    $fatal(1,"[POWER] TIMEOUT phase=%0d, boot_fetches=%0d", phase_id, boot_fetches);
  end
  initial begin
    phase_id = 1;
    $display("[POWER 1] Supply on, S2 released: POR must start Ibex automatically");
    if (dut.rst_ni !== 1'b0)
      $fatal(1,"[POWER] Reset not asserted on configuration");
    repeat (8) @(negedge clk);
    if (dut.rst_ni !== 1'b0)
      $fatal(1,"[POWER] POR too short");
    repeat (4) @(negedge clk);
    if (dut.rst_ni !== 1'b1)
      $fatal(1,"[POWER] POR did not release");
    wait (boot_fetches >= 1);
    timer_before = dut.timer_us;
    repeat (80) @(negedge clk);
    if (dut.timer_us <= timer_before)
      $fatal(1,"[TIMER] 27 MHz microsecond counter did not advance");
    $display("[POWER] firmware fetched; hardware timer advances PASS");

    phase_id = 2;
    for (i=1; i<=4; i=i+1) press_floor(i);

    phase_id = 3;
    $display("[POWER 3] S2 pressed: reset peripherals, release and fetch again");
    @(negedge clk); rst_n = 0;
    repeat (3) @(negedge clk);
    if (dut.rst_ni !== 0 || dut.timer_us !== 0 ||
        dut.btn_stable !== 4'b0 || motor_pins !== 4'b0 ||
        buzzer_pin !== 0 || dut.u_servo.target_us !== 12'd1000)
      $fatal(1,"[RESET] S2 did not clear logic safely");
    rst_n = 1;
    repeat (12) @(negedge clk);
    if (dut.rst_ni !== 1) $fatal(1,"[RESET] S2 release failed");
    wait (boot_fetches >= 2);
    $display("PASS tb_power_on");
    $finish;
  end
endmodule
`default_nettype wire
