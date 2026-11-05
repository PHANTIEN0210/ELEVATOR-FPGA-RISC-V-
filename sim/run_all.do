# Run from the project root in the ModelSim Transcript:
#   do sim/run_all.do
set testbenches {tb_button tb_motor tb_buzzer tb_led tb_servo tb_led7seg tb_uart tb_power_on tb_ibex_system_top}
set completed 0
foreach tb $testbenches {
    puts "\n=================================================="
    puts "TEST [expr {$completed+1}]/[llength $testbenches]: $tb"
    puts "=================================================="
    if {[catch {do sim/run_one.do} result]} {
        puts "FAIL $tb: $result"
        error "Stopped on $tb"
    }
    incr completed
}
puts "\nALL $completed TESTBENCHES COMPLETED. Transcript must show PASS tb_... for each test."
