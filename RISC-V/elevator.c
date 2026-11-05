#include <stdint.h>

// ============================================================================
// Địa chỉ thanh ghi MMIO (theo ibex_system_top.v)
// ============================================================================
#define REG32(a)    (*(volatile uint32_t *)(a))

#define UART_REG     REG32(0x40000000u) // Ghi: TX byte | Đọc bit0: tx_busy
#define LED_REG      REG32(0x50000000u) // Bit[3:0]: tầng 1-4, Bit4: LED LÊN, Bit5: LED XUỐNG
#define BTN_REG      REG32(0x60000000u) // Bit[0..3]: nút tầng 1-4
#define SEG_REG      REG32(0x70000000u) // Bit[2:0]: LED 7 đoạn
#define SERVO_REG    REG32(0x80000000u) // Ghi: xung mục tiêu µs; đọc: xung hiện tại [11:0], bit16: đang quay
#define STEPPER_REG  REG32(0x90000000u) // Bit0: busy/start, Bit1: dir, Bit[17:2]: số bước
#define BUZZER_REG   REG32(0xA0000000u) // Bit0: 1 = bật còi
#define TIMER_REG    REG32(0xC0000000u) // Đọc: bộ đếm µs tự chạy

// ============================================================================
// Tham số hệ thống
// ============================================================================
#define MIN_FLOOR        1u
#define MAX_FLOOR        4u

// Đổi số vòng/tầng tại đây: 100 = 1,00 vòng; 150 = 1,50 vòng.
// 4096 bước/vòng là hệ số hiệu chỉnh hiện tại của motor và hộp số.
#define MOTOR_STEPS_PER_REV       4096u
#define MOTOR_TURNS_PER_FLOOR_X100 100u
#define MOTOR_MAX_STEPS          65535u  // thanh ghi stepper chứa 16 bit số bước

#if MOTOR_STEPS_PER_REV == 0 || MOTOR_TURNS_PER_FLOOR_X100 == 0
#error "Motor steps/rev and turns/floor must be greater than zero"
#endif

// Góc servo tính từ vị trí cửa đóng. Hiệu chỉnh từ quan sát 120° tại 2500 µs.
// Để chỉnh hành trình cửa, chỉ đổi SERVO_OPEN_ANGLE_DEG (ví dụ 80, 90, 100).
#define SERVO_CLOSED_ANGLE_DEG  0u
#define SERVO_OPEN_ANGLE_DEG   90u
#define SERVO_CAL_MAX_DEG     120u
#define SERVO_CAL_0_DEG_US   1000u
#define SERVO_CAL_MAX_US     2500u
#define SERVO_MOVING_BIT (1u << 16)
#define SERVO_CURRENT_MASK 0x0fffu
#define DOOR_MOVE_TIMEOUT_MS 5000u

#define BEEP_TOTAL_MS    300u    // tít (100) - nghỉ (100) - tít (100)
#define DOOR_HOLD_MS     3000u   // cửa mở giữ 3 giây
#define STEP_START_MS    50u     // chờ tối đa cờ busy của motor bật lên
#define DBG_PERIOD_MS    1000u

// ============================================================================
// Trạng thái thang máy
// ============================================================================
typedef enum {
    ST_IDLE = 0,
    ST_MOVING,
    ST_BEEP,
    ST_DOOR_OPEN,
    ST_DOOR_CLOSING,
    ST_FAULT
} state_t;

static uint8_t  requests[MAX_FLOOR + 1];
static uint8_t  btn_prev[MAX_FLOOR];
static state_t  state;
static uint8_t  current_floor;
static uint8_t  direction_up;      // hướng ưu tiên khi IDLE
static uint8_t  move_up;           // hướng của chuyến đang chạy
static uint32_t t_state;           // mốc thời gian của trạng thái (µs)
static uint32_t t_dbg;
static uint8_t  step_seen_busy;
static uint8_t  buzzer_level;
static uint8_t  door_reported;

// ============================================================================
// Thời gian (dùng timer phần cứng 1 µs, không phụ thuộc tốc độ CPU)
// ============================================================================
static inline uint32_t micros(void) {
    return TIMER_REG;
}

static inline uint32_t elapsed_ms(uint32_t since_us) {
    return (micros() - since_us) / 1000u;
}

// Chỉ các hệ số hiệu chỉnh ở trên dùng micro giây; mọi lệnh cửa dùng độ.
static uint32_t servo_angle_to_us(uint16_t angle_deg) {
    if (angle_deg > SERVO_CAL_MAX_DEG) angle_deg = SERVO_CAL_MAX_DEG;
    return SERVO_CAL_0_DEG_US +
           ((uint32_t)angle_deg * (SERVO_CAL_MAX_US - SERVO_CAL_0_DEG_US) +
            SERVO_CAL_MAX_DEG / 2u) / SERVO_CAL_MAX_DEG;
}

static void servo_set_angle_deg(uint16_t angle_deg) {
    SERVO_REG = servo_angle_to_us(angle_deg);
}

// Khẳng định trạng thái từ PWM đã đạt mục tiêu; không phải cảm biến vị trí cơ khí.
static uint8_t servo_reached_angle_deg(uint16_t angle_deg) {
    uint32_t status = SERVO_REG;
    return ((status & SERVO_MOVING_BIT) == 0u) &&
           ((status & SERVO_CURRENT_MASK) == servo_angle_to_us(angle_deg));
}

// Tính bằng phần trăm vòng để dùng số nguyên, không cần FPU/libm.
static uint16_t motor_steps_for_turns_x100(uint32_t turns_x100) {
    const uint32_t max_turns_x100 = (MOTOR_MAX_STEPS * 100u) / MOTOR_STEPS_PER_REV;
    if (turns_x100 > max_turns_x100) return (uint16_t)MOTOR_MAX_STEPS;
    uint32_t steps = (turns_x100 * MOTOR_STEPS_PER_REV + 50u) / 100u;
    if (steps > MOTOR_MAX_STEPS) steps = MOTOR_MAX_STEPS;
    return (uint16_t)steps;
}

static void motor_start_turns_x100(uint32_t turns_x100, uint8_t up) {
    uint32_t steps = motor_steps_for_turns_x100(turns_x100);
    if (steps != 0u)
        STEPPER_REG = (steps << 2) | (up ? 0x3u : 0x1u);
}

// ============================================================================
// UART (chờ cờ busy thật; có timeout để không bao giờ treo)
// ============================================================================
static void uart_putchar(char c) {
    uint32_t t = micros();
    while ((UART_REG & 1u) && ((micros() - t) < 3000u)) { }
    UART_REG = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *str) {
    while (*str) {
        uart_putchar(*str++);
    }
}

static void uart_put_floor(uint8_t f) {
    uart_putchar((char)('0' + f));
}

// ============================================================================
// Hiển thị: LED tầng + LED hướng + LED 7 đoạn
// ============================================================================
static void update_display(uint8_t floor, uint8_t is_up, uint8_t is_down) {
    uint32_t led_val = (1u << (floor - 1u));
    if (is_up)   led_val |= (1u << 4);
    if (is_down) led_val |= (1u << 5);
    LED_REG = led_val;
    SEG_REG = floor;
}

// ============================================================================
// Còi: chỉ ghi khi đổi mức
// ============================================================================
static void buzzer_set(uint8_t on) {
    if (buzzer_level != on) {
        buzzer_level = on;
        BUZZER_REG = on;
    }
}

// ============================================================================
// Nút bấm: bắt sườn lên, gọi trong MỌI vòng lặp (không còn delay chặn)
// ============================================================================
static void poll_buttons(void) {
    uint32_t buttons = BTN_REG;
    for (uint8_t i = 0; i < MAX_FLOOR; i++) {
        uint8_t btn = (buttons & (1u << i)) ? 1u : 0u;
        if (btn && !btn_prev[i]) {
            uint8_t floor = (uint8_t)(i + 1u);
            requests[floor] = 1;
            uart_puts("[SYS] Call registered for Floor ");
            uart_put_floor(floor);
            uart_puts("\r\n");
        }
        btn_prev[i] = btn;
    }
}

// Delay có quét nút (chỉ dùng lúc khởi động)
static void delay_ms_poll(uint32_t ms) {
    uint32_t t = micros();
    while (elapsed_ms(t) < ms) {
        poll_buttons();
    }
}

// ============================================================================
// Truy vấn yêu cầu
// ============================================================================
static uint8_t has_request_above(uint8_t floor) {
    for (uint8_t f = (uint8_t)(floor + 1u); f <= MAX_FLOOR; f++) {
        if (requests[f]) return 1;
    }
    return 0;
}

static uint8_t has_request_below(uint8_t floor) {
    uint8_t f = floor;
    while (f > MIN_FLOOR) {
        f--;
        if (requests[f]) return 1;
    }
    return 0;
}

// ============================================================================
// Motor: ra lệnh quay đúng 1 tầng (không chặn)
// ============================================================================
static void start_step(void) {
    motor_start_turns_x100(MOTOR_TURNS_PER_FLOOR_X100, move_up);
    step_seen_busy = 0;
    t_state = micros();
}

// ============================================================================
// Còi -> Cửa mở (servo) -> Giữ 3s -> Cửa đóng (servo ngược)
// ============================================================================
static void beep_start(void) {
    state   = ST_BEEP;
    t_state = micros();
    buzzer_set(1);
}

static void door_open_start(void) {
    uart_puts("[SYS] Door Opening...\r\n");
    servo_set_angle_deg(SERVO_OPEN_ANGLE_DEG);
    door_reported = 0;
    t_state       = micros();          // mốc bắt đầu quay; 3 giây giữ tính sau khi quay xong
    state         = ST_DOOR_OPEN;
}

static void door_close_start(void) {
    uart_puts("[SYS] Door Closing...\r\n");
    servo_set_angle_deg(SERVO_CLOSED_ANGLE_DEG);
    t_state   = micros();
    state     = ST_DOOR_CLOSING;
}

// ============================================================================
// Xử lý khi vừa tới 1 tầng mới
// ============================================================================
static void on_floor_reached(void) {
    if (move_up) current_floor++;
    else         current_floor--;

    update_display(current_floor, move_up, !move_up);

    uint8_t need_stop = 0;
    if (requests[current_floor])                                   need_stop = 1; // có người gọi tầng này
    else if (move_up  && !has_request_above(current_floor))        need_stop = 1; // hết yêu cầu phía trên
    else if (!move_up && !has_request_below(current_floor))        need_stop = 1; // hết yêu cầu phía dưới
    if (move_up  && current_floor >= MAX_FLOOR)                    need_stop = 1; // chặn tràn tầng
    if (!move_up && current_floor <= MIN_FLOOR)                    need_stop = 1;

    if (need_stop) {
        update_display(current_floor, 0, 0);   // tắt đèn hướng
        requests[current_floor] = 0;

        uart_puts("[SYS] Arrived at Floor ");
        uart_put_floor(current_floor);
        uart_puts("!\r\n");

        beep_start();
    } else {
        uart_puts("[SYS] Passing Floor ");
        uart_put_floor(current_floor);
        uart_puts("...\r\n");
        start_step();                          // đi tiếp mượt, không dừng
    }
}

// ============================================================================
// Chương trình chính
// ============================================================================
int main(void) {
    // Khởi tạo tường minh (không phụ thuộc .bss được xóa hay chưa)
    for (uint8_t i = 0; i <= MAX_FLOOR; i++) requests[i] = 0;
    for (uint8_t i = 0; i < MAX_FLOOR; i++) btn_prev[i] = 0;
    state          = ST_IDLE;
    current_floor  = 1;
    direction_up   = 1;
    move_up        = 1;
    buzzer_level   = 0;
    door_reported  = 0;
    step_seen_busy = 0;

    // Power-on self-test: dash, floor LED pulse, floor 1, then ready beep.
    servo_set_angle_deg(SERVO_CLOSED_ANGLE_DEG);
    SEG_REG    = 0;
    LED_REG    = 1u << (current_floor - 1u);
    delay_ms_poll(200);
    LED_REG    = 0;
    delay_ms_poll(100);
    SEG_REG    = current_floor;
    delay_ms_poll(200);
    buzzer_set(1);
    delay_ms_poll(100);
    buzzer_set(0);
    update_display(current_floor, 0, 0);

    uart_puts("\r\n=================================\r\n");
    uart_puts(" ELEVATOR SYSTEM READY (FLOOR 1)\r\n");
    uart_puts("=================================\r\n");

    while (1) {
        poll_buttons();

        switch (state) {

        // --------------------------------------------------------------
        case ST_IDLE:
            // Có yêu cầu ngay tại tầng đang đỗ
            if (requests[current_floor]) {
                requests[current_floor] = 0;
                uart_puts("[SYS] Serving Floor ");
                uart_put_floor(current_floor);
                uart_puts("!\r\n");
                update_display(current_floor, 0, 0);
                beep_start();
                break;
            }

            // Chọn hướng theo thuật toán SCAN/LOOK
            {
                uint8_t go = 0;
                if (direction_up) {
                    if (has_request_above(current_floor))      { go = 1; }
                    else if (has_request_below(current_floor)) { direction_up = 0; go = 1; }
                } else {
                    if (has_request_below(current_floor))      { go = 1; }
                    else if (has_request_above(current_floor)) { direction_up = 1; go = 1; }
                }

                if (go) {
                    move_up = direction_up;
                    update_display(current_floor, move_up, !move_up);
                    uart_puts(move_up ? "[SYS] Moving UP from Floor "
                                      : "[SYS] Moving DOWN from Floor ");
                    uart_put_floor(current_floor);
                    uart_puts("...\r\n");

                    start_step();
                    t_dbg = micros();
                    state = ST_MOVING;
                }
            }
            break;

        // --------------------------------------------------------------
        case ST_MOVING: {
            uint32_t busy = STEPPER_REG & 0x01u;

            if (busy) {
                step_seen_busy = 1;
                if (elapsed_ms(t_dbg) >= DBG_PERIOD_MS) {
                    uart_puts("[DBG] Motor busy...\r\n");
                    t_dbg = micros();
                }
            } else if (step_seen_busy || elapsed_ms(t_state) >= STEP_START_MS) {
                // Motor đã quay xong 1 tầng
                on_floor_reached();
            }
            break;
        }

        // --------------------------------------------------------------
        case ST_BEEP: {
            uint32_t e = elapsed_ms(t_state);
            buzzer_set((e < 100u) || (e >= 200u && e < 300u));
            if (e >= BEEP_TOTAL_MS) {
                buzzer_set(0);
                door_open_start();
            }
            break;
        }

        // --------------------------------------------------------------
        case ST_DOOR_OPEN:
            // Báo UART khi servo đã quay xong (cửa mở hẳn)
            if (!door_reported && servo_reached_angle_deg(SERVO_OPEN_ANGLE_DEG)
                               && elapsed_ms(t_state) >= 50u) {
                uart_puts("[SYS] Door Opened.\r\n");
                door_reported = 1;
                t_state = micros();      // chỉ bắt đầu giữ cửa sau khi mở xong
            }

            // Có người bấm đúng tầng đang mở cửa -> gia hạn thêm 3 giây
            if (door_reported && requests[current_floor]) {
                requests[current_floor] = 0;
                t_state = micros();
                uart_puts("[SYS] Door hold extended.\r\n");
            }

            if (door_reported && elapsed_ms(t_state) >= DOOR_HOLD_MS) {
                door_close_start();
            }
            if (!door_reported && elapsed_ms(t_state) >= DOOR_MOVE_TIMEOUT_MS) {
                uart_puts("[FAULT] Door open timeout; servo target not reached.\r\n");
                state = ST_FAULT;
            }
            break;

        // --------------------------------------------------------------
        case ST_DOOR_CLOSING: {
            uint32_t e = elapsed_ms(t_state);
            if (e >= 50u && servo_reached_angle_deg(SERVO_CLOSED_ANGLE_DEG)) {
                uart_puts("[SYS] Door Closed.\r\n");
                state = ST_IDLE;
            } else if (e >= DOOR_MOVE_TIMEOUT_MS) {
                uart_puts("[FAULT] Door close timeout; servo target not reached.\r\n");
                state = ST_FAULT;
            }
            break;
        }

        case ST_FAULT:
            // Cửa chưa xác nhận đóng: không nhận lệnh chạy motor cho tới reset.
            break;

        default:
            state = ST_IDLE;
            break;
        }
    }

    return 0;
}
