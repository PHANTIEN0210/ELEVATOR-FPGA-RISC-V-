`timescale 1ns/1ps
`default_nettype none
// CPU Ibex chay firmware HEX that. Wave theo doi request/grant/response MMIO;
// Transcript dien giai chan -> CPU -> MMIO -> ngoai vi -> UART cho 4 tang.
module tb_ibex_system_top;
  reg clk=0, rst_n=0, uart_rx=1;
  always #18.518 clk=~clk; // clock logic 27 MHz
  reg [3:0] buttons=4'b1111; // J5 vi tri 5..8, nhan = 0
  wire uart_tx, buzzer_pin, led_up, led_down, servo_pin;
  wire [5:0] leds;
  wire [6:0] seg_data;
  wire [3:0] motor_pins;
  reg [31:0] sim_us=0;
  integer phase_id=0;
  always @(posedge clk or negedge rst_n)
    if(!rst_n) sim_us<=0;
    else sim_us<=sim_us+50; // chi timer firmware duoc tang toc

  ibex_system_top dut
    (.clk(clk),.rst_n(rst_n),.buttons(buttons),.uart_rx(uart_rx),.uart_tx(uart_tx),
     .leds(leds),.seg_data(seg_data),.motor_pins(motor_pins),
     .buzzer_pin(buzzer_pin),.led_up(led_up),.led_down(led_down),.servo_pin(servo_pin));

  // Chi tang toc bai tong hop. Bai rieng kiem tra timing thuc.
  defparam dut.POR_CYCLES=4;
  defparam dut.u_button_debounce.CLK_HZ=27000; // 540 clock debounce
  defparam dut.uart_inst.DEFAULT_DIV=1;        // UART 3 clock/bit
  defparam dut.u_buzzer.CLK_HZ=27000;
  defparam dut.u_servo.CLK_HZ=1000000;
  defparam dut.u_servo.FRAME_US=3000;
  defparam dut.u_servo.STEP_US=375;            // 3 frame cho 0 -> 90 do
  defparam dut.u_stepper.STEP_HZ=2700000;      // 10 clock/buoc

  integer boot_fetches=0, ready_count=0, button_reads=0, servo_reads=0;
  integer led_writes=0, seg_writes=0, buzzer_on=0, buzzer_off=0;
  integer buzzer_edges=0, servo_open_writes=0, servo_close_writes=0;
  integer stepper_writes=0, completed_legs=0, leg_phase_changes=0;
  integer opening_count=0, opened_count=0, closing_count=0, closed_count=0;
  integer arrival_count=0, arrival_order[0:3], registered_count[1:4];
  integer i;
  reg [3:0] last_motor_pins=0;
  reg last_motor_busy=0;
  reg [31:0] opened_us=0;

  always @(posedge buzzer_pin) if(rst_n) buzzer_edges=buzzer_edges+1;
  always @(posedge clk) if(rst_n) begin
    if(dut.instr_req && dut.instr_addr==32'h80) begin
      boot_fetches=boot_fetches+1;
      $display("[%0d us][CPU] Fetch firmware tai 0x00000080",sim_us);
    end
    if(dut.data_req) begin
      if(dut.data_gnt !== 1'b1) $fatal(1,"[MMIO] Grant missing");
      if(dut.data_addr[31:28]==4'hB)
        $fatal(1,"[MMIO] Firmware con truy cap dia chi SERVO cu 0xB...");
      if(!dut.data_we && dut.button_sel) button_reads=button_reads+1;
      if(!dut.data_we && dut.servo_sel) servo_reads=servo_reads+1;
      if(dut.data_we && dut.led_sel) begin
        led_writes=led_writes+1;
        $display("[%0d us][LED] MMIO 0x5 data=%02h -> tang/huong",sim_us,dut.data_wdata[5:0]);
      end
      if(dut.data_we && dut.seg_sel) begin
        seg_writes=seg_writes+1;
        $display("[%0d us][LED7SEG] MMIO 0x7 tang=%0d -> gfedcba=%07b",
                 sim_us,dut.data_wdata[2:0],seg_data);
      end
      if(dut.data_we && dut.buzzer_sel) begin
        if(dut.data_wdata[0]) buzzer_on=buzzer_on+1;
        else buzzer_off=buzzer_off+1;
        $display("[%0d us][BUZZER] MMIO 0xA bit0=%b",sim_us,dut.data_wdata[0]);
      end
      if(dut.data_we && dut.servo_sel) begin
        $display("[%0d us][SERVO] MMIO 0x80000000 target=%0d us",
                 sim_us,dut.data_wdata[11:0]);
        if(dut.data_wdata[11:0]==12'd2125) servo_open_writes=servo_open_writes+1;
        else if(dut.data_wdata[11:0]==12'd1000) servo_close_writes=servo_close_writes+1;
        else $fatal(1,"[SERVO] Unexpected target=%0d",dut.data_wdata[11:0]);
      end
      if(dut.data_we && dut.stepper_sel) begin
        stepper_writes=stepper_writes+1;
        leg_phase_changes=0;
        $display("[%0d us][MOTOR] MMIO 0x9 start=%b dir=%b steps=%0d",
                 sim_us,dut.data_wdata[0],dut.data_wdata[1],dut.data_wdata[17:2]);
        if(dut.data_wdata[0] !== 1'b1 || dut.data_wdata[17:2] !== 16'd4096 ||
           dut.data_wdata[1] !== (stepper_writes<=3))
          $fatal(1,"[MOTOR] Expected 3 legs UP then 3 legs DOWN, 4096 steps each");
      end
    end
  end
  always @(negedge clk) begin
    if(!rst_n) begin
      last_motor_pins=0; last_motor_busy=0;
    end else begin
      if(motor_pins !== last_motor_pins) begin
        leg_phase_changes=leg_phase_changes+1;
        last_motor_pins=motor_pins;
        if(leg_phase_changes==1 || leg_phase_changes==2048 || leg_phase_changes==4096)
          $display("[%0d us][MOTOR] Pha=%b; buoc %0d/4096",
                   sim_us,motor_pins,leg_phase_changes);
      end
      if(last_motor_busy && !dut.u_stepper.busy) begin
        if(leg_phase_changes !== 4096)
          $fatal(1,"[MOTOR] Leg %0d co %0d pha, can 4096",stepper_writes,leg_phase_changes);
        completed_legs=completed_legs+1;
        $display("[%0d us][MOTOR] Hoan tat leg %0d, busy=0",sim_us,completed_legs);
      end
      last_motor_busy=dut.u_stepper.busy;
    end
  end

  task record_arrival(input integer floor_no);
    begin
      if(arrival_count>=4) $fatal(1,"[SYSTEM] Unexpected extra stop at floor %0d",floor_no);
      arrival_order[arrival_count]=floor_no;
      arrival_count=arrival_count+1;
      if(dut.seg_floor_reg !== floor_no || motor_pins !== 4'b0000)
        $fatal(1,"[SYSTEM] Floor %0d display/motor failed",floor_no);
      $display("[%0d us][SYSTEM] Den tang %0d: LED7SEG=%07b, motor dung",
               sim_us,floor_no,seg_data);
    end
  endtask

  // Giai ma CHAN TX, khong suy ra UART tu lenh ghi MMIO.
  string uart_line="";
  reg [7:0] rx_char;
  integer bit_index;
  initial forever begin
    @(negedge uart_tx);
    if(rst_n) begin
      repeat(1) @(negedge clk);
      if(uart_tx !== 1'b0) $fatal(1,"[UART] Start bit must be 0");
      for(bit_index=0;bit_index<8;bit_index=bit_index+1) begin
        repeat(3) @(negedge clk);
        rx_char[bit_index]=uart_tx;
      end
      repeat(3) @(negedge clk);
      if(uart_tx !== 1'b1) $fatal(1,"[UART] Stop bit must be 1");
      if(rx_char==8'h0d) begin end
      else if(rx_char==8'h0a) begin
        if(uart_line!="") $display("[%0d us][UART] %s",sim_us,uart_line);
        if(uart_line==" ELEVATOR SYSTEM READY (FLOOR 1)") ready_count=ready_count+1;
        if(uart_line=="[SYS] Call registered for Floor 1") registered_count[1]=registered_count[1]+1;
        if(uart_line=="[SYS] Call registered for Floor 2") registered_count[2]=registered_count[2]+1;
        if(uart_line=="[SYS] Call registered for Floor 3") registered_count[3]=registered_count[3]+1;
        if(uart_line=="[SYS] Call registered for Floor 4") registered_count[4]=registered_count[4]+1;
        if(uart_line=="[SYS] Arrived at Floor 1!") record_arrival(1);
        if(uart_line=="[SYS] Arrived at Floor 2!") record_arrival(2);
        if(uart_line=="[SYS] Arrived at Floor 3!") record_arrival(3);
        if(uart_line=="[SYS] Arrived at Floor 4!") record_arrival(4);
        if(uart_line=="[SYS] Door Opening...") opening_count=opening_count+1;
        if(uart_line=="[SYS] Door Opened.") begin
          if(opening_count != opened_count+1 || dut.u_servo.cur_us !== 12'd2125 ||
             dut.u_servo.target_us !== 12'd2125)
            $fatal(1,"[SERVO] OPEN phai sau khi PWM dat 2125 us");
          opened_count=opened_count+1; opened_us=sim_us;
          $display("[%0d us][DOOR] OPEN xac nhan tu servo, bat dau giu 3 s",sim_us);
        end
        if(uart_line=="[SYS] Door Closing...") begin
          if(opened_count != closing_count+1 || sim_us-opened_us < 32'd3000000)
            $fatal(1,"[DOOR] CLOSE truoc khi OPEN du 3 s: %0d us",sim_us-opened_us);
          closing_count=closing_count+1;
          $display("[%0d us][DOOR] CLOSE sau %0d us giu cua",sim_us,sim_us-opened_us);
        end
        if(uart_line=="[SYS] Door Closed.") begin
          if(closing_count != closed_count+1 || dut.u_servo.cur_us !== 12'd1000 ||
             dut.u_servo.target_us !== 12'd1000)
            $fatal(1,"[SERVO] CLOSED phai sau khi PWM dat 1000 us");
          closed_count=closed_count+1;
        end
        if(uart_line=="[FAULT] Door open timeout; servo target not reached." ||
           uart_line=="[FAULT] Door close timeout; servo target not reached.")
          $fatal(1,"[SYSTEM] Firmware reported servo fault: %s",uart_line);
        uart_line="";
      end else uart_line={uart_line,rx_char};
    end
  end

  task press_floor(input integer floor_no);
    integer before_count;
    begin
      before_count=registered_count[floor_no];
      @(negedge clk); buttons[floor_no-1]=0;
      $display("[%0d us][BUTTON] Nhan nut tang %0d: FPGA pin %0d ve 0",
               sim_us,floor_no,24+floor_no);
      while(registered_count[floor_no]==before_count) @(negedge clk);
      if(dut.btn_raw[floor_no-1] !== 1'b1 || dut.btn_stable[floor_no-1] !== 1'b1)
        $fatal(1,"[BUTTON] Floor %0d raw/stable mismatch",floor_no);
      @(negedge clk); buttons[floor_no-1]=1;
      wait(dut.btn_stable[floor_no-1]===1'b0);
      $display("[%0d us][BUTTON] Tang %0d: raw -> debounce -> MMIO -> request PASS",sim_us,floor_no);
    end
  endtask

  initial begin repeat(2000000) @(posedge clk); $fatal(1,"[SYSTEM] TIMEOUT phase=%0d arrivals=%0d doors=%0d legs=%0d",phase_id,arrival_count,closed_count,completed_legs); end
  initial begin
    for(i=1;i<=4;i=i+1) registered_count[i]=0;
    phase_id=1; $display("[DEMO 1] Reset -> Ibex fetch 0x80 -> self-test -> READY tang 1");
    repeat(10) @(negedge clk); rst_n=1;
    force dut.timer_us=sim_us;
    wait(ready_count>=1);
    if(boot_fetches<1 || button_reads<10 || led_writes<3 || seg_writes<2 ||
       buzzer_on<1 || buzzer_off<1 || buzzer_edges<1 || leds !== 6'b000000 ||
       seg_data !== 7'b0000110)
      $fatal(1,"[SYSTEM] Boot/self-test failed");

    phase_id=2; $display("[DEMO 2] Goi tang 4; khi dang di len, xep them tang 2 va 3");
    press_floor(4);
    wait(dut.u_stepper.busy===1'b1);
    press_floor(2);
    press_floor(3);
    phase_id=3; $display("[DEMO 3] SCAN/LOOK phuc vu 2 -> 3 -> 4; moi tang co beep/servo/hold");
    wait(closed_count>=3);
    if(arrival_count!==3 || arrival_order[0]!==2 || arrival_order[1]!==3 ||
       arrival_order[2]!==4 || completed_legs!==3)
      $fatal(1,"[SYSTEM] UP service order/steps failed");

    phase_id=4; $display("[DEMO 4] Goi tang 1; motor dao chieu va di 4 -> 3 -> 2 -> 1");
    press_floor(1);
    wait(closed_count>=4);
    if(arrival_count!==4 || arrival_order[3]!==1 || completed_legs!==6 ||
       stepper_writes!==6 || opening_count!==4 || opened_count!==4 ||
       closing_count!==4 || servo_open_writes!==4 || servo_close_writes<5 ||
       servo_reads<8 || buzzer_on<5 || buzzer_off<5 || leds !== 6'b000000)
      $fatal(1,"[SYSTEM] 4-floor service/peripheral coverage failed");
    for(i=1;i<=4;i=i+1)
      if(registered_count[i]!==1)
        $fatal(1,"[BUTTON] Floor %0d was not registered exactly once",i);
    $display("[DEMO] 4 nut, 6 chang motor, 4 lan mo/dong, UART va MMIO PASS");

    phase_id=5; $display("[DEMO 5] Reset phan cung -> outputs an toan -> CPU boot lai 0x80");
    @(negedge clk); rst_n=0; repeat(5) @(negedge clk);
    if(leds !== 6'b000000 || motor_pins !== 4'b0000 || buzzer_pin !== 0 ||
       dut.u_servo.target_us !== 12'd1000)
      $fatal(1,"[SYSTEM] Hardware reset failed");
    uart_line="";
    rst_n=1;
    wait(ready_count>=2);
    if(boot_fetches<2) $fatal(1,"[SYSTEM] CPU did not fetch 0x80 after reset");
    $display("PASS tb_ibex_system_top"); $finish;
  end
endmodule
`default_nettype wire
