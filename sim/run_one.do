# Start ModelSim/Questa in the project root, then:
#   set tb tb_button
#   do sim/run_one.do
# Valid tb values: tb_ibex_system_top, tb_button, tb_motor,
# tb_buzzer, tb_led, tb_servo, tb_led7seg, tb_uart, tb_power_on.
if {![info exists tb]} {error "Set tb first, e.g. set tb tb_button"}
if {![file exists src/firmware_bank0.hex]} {
    error "Run from the project root containing src/firmware_bank0.hex"
}
if {![file isdirectory work]} {vlib work}
set unit_src ""
switch -- $tb {
    tb_button  {set unit_src src/button_mmio.v}
    tb_motor   {set unit_src src/stepper_mmio.v}
    tb_buzzer  {set unit_src src/buzzer_mmio.v}
    tb_servo   {set unit_src src/servo_mmio.v}
    tb_led7seg {set unit_src src/led_7_seg_mmio.v}
    tb_uart    {set unit_src src/uart_mmio.v}
    tb_led - tb_power_on - tb_ibex_system_top {set unit_src [glob src/*.v]}
    default {error "Unknown testbench: $tb"}
}
puts "\n========== COMPILE $tb =========="
eval vlog -sv -work work $unit_src sim/$tb.v
catch {quit -sim}
vsim -onfinish stop -voptargs=+acc work.$tb
catch {view transcript}
catch {view wave}
if {$tb eq "tb_ibex_system_top"} {
    add wave -divider "00 CLOCK / DEMO / CPU"
    add wave /$tb/clk /$tb/rst_n /$tb/phase_id /$tb/sim_us
    add wave /$tb/dut/instr_req /$tb/dut/instr_addr /$tb/dut/instr_rvalid
    add wave -divider "01 IBEX MMIO: request -> grant -> response"
    add wave /$tb/dut/data_req /$tb/dut/data_gnt /$tb/dut/data_we
    add wave /$tb/dut/data_addr /$tb/dut/data_wdata /$tb/dut/data_rvalid /$tb/dut/data_rdata
    add wave -divider "02 BUTTON: pin -> sync/raw -> debounce -> CPU"
    add wave /$tb/buttons /$tb/dut/btn_raw /$tb/dut/btn_stable /$tb/dut/btn_rdata_r
    add wave -divider "03 MOTOR: command -> busy -> phase"
    add wave /$tb/motor_pins /$tb/dut/u_stepper/busy /$tb/dut/u_stepper/steps_remain /$tb/dut/u_stepper/phase
    add wave -divider "04 BUZZER: enable -> tone"
    add wave /$tb/dut/u_buzzer/enable /$tb/buzzer_pin
    add wave -divider "05 LED: floor/direction"
    add wave /$tb/dut/led_reg /$tb/leds /$tb/led_up /$tb/led_down
    add wave -divider "06 SERVO = DOOR: target -> current -> PWM"
    add wave /$tb/dut/servo_rdata /$tb/dut/u_servo/target_us /$tb/dut/u_servo/cur_us /$tb/dut/u_servo/frame_cnt /$tb/servo_pin
    add wave -divider "07 LED7SEG: floor code -> gfedcba"
    add wave /$tb/dut/seg_floor_reg /$tb/seg_data
    add wave -divider "08 UART: 8N1 serial pin"
    add wave /$tb/uart_rx /$tb/uart_tx /$tb/dut/uart_tx_busy
} elseif {$tb eq "tb_power_on"} {
    add wave -divider "S2 / POWER ON RESET"
    add wave /$tb/clk /$tb/rst_n /$tb/dut/por_count /$tb/dut/rst_ni
    add wave -divider "CPU BOOT / REAL TIMER"
    add wave /$tb/dut/instr_req /$tb/dut/instr_addr /$tb/dut/timer_us
    add wave -divider "FOUR BUTTONS: pin -> raw -> stable"
    add wave /$tb/buttons /$tb/dut/btn_raw /$tb/dut/btn_stable
    add wave -divider "BOARD OUTPUTS"
    add wave /$tb/uart_tx /$tb/leds /$tb/motor_pins /$tb/buzzer_pin
} elseif {$tb eq "tb_led"} {
    add wave -divider "DEMO PHASE / CPU MMIO"
    add wave /$tb/clk /$tb/rst_n /$tb/phase_id
    add wave /$tb/dut/data_req /$tb/dut/data_we /$tb/dut/data_addr /$tb/dut/data_wdata /$tb/dut/data_rvalid /$tb/dut/data_rdata
    add wave -divider "LED / DIRECTION"
    add wave /$tb/dut/led_reg /$tb/leds /$tb/led_up /$tb/led_down
    add wave -divider "SERVO ADDRESS 0x80000000"
    add wave /$tb/dut/servo_sel /$tb/dut/u_servo/target_us /$tb/dut/u_servo/cur_us /$tb/dut/servo_rdata
} else {
    add wave -divider "DEMO PHASE / INPUT / OUTPUT"
    add wave -r /$tb/*
    add wave -divider "DUT internal state"
    add wave -r /$tb/dut/*
}
puts "========== RUN $tb =========="
run -all
puts "========== END $tb =========="
