//! Printer motion controller for Run42's WebAssembly guest interface (ABI 2).
//!
//! It plays one move, a trapezoidal profile of 20 mm at up to 300 mm/s and 10,000 mm/s^2, starting 2 ms after boot. With
//! a zero-vibration input shaper (feature `shaper62` or `shaper69`) the commanded position is half the profile plus half
//! the profile delayed by half a period of the resonance the shaper is tuned to, which cancels that resonance's
//! vibration. The commanded position is quantised to microsteps (80 per mm of belt travel, 16 per full step) and
//! turned into the stepper's field angle (a quarter cycle per full step) with a constant phase current: by default it
//! is an open-loop stepper driver. With the feature `closed_loop` the stepper has an encoder: a PD position loop sets the
//! phase current and the field leads the rotor by a quarter cycle, in either direction. With the feature `servo` the
//! motor is a brushless servo: the same PD loop gives a torque current, and a PI current loop with decoupling turns the
//! d and q currents it measures into the stator voltages, limited to the supply. The controller samples every 50 us.
//! The CoreXY variants run the same closed-loop drive in each motor's belt coordinates for lines and a rounded corner.
//!
//! The guest also holds a test bench monitor, which is not part of the printer's firmware and which the controller never
//! reads: it is given the true carriage position and measures how well the move came out. After the commanded motion
//! has ended it keeps the last time the carriage was more than 20 um from its target (the settling time) and the
//! largest deviation (the residual vibration); during the move it keeps the largest distance from the commanded position
//! (the tracking error).
#![no_std]

const TICK_NS: i64 = 50_000; // 20 kHz
const PI: f64 = core::f64::consts::PI;

const START: f64 = 0.002; // s, when the move begins
const DISTANCE: f64 = 0.020; // m
const SPEED: f64 = 0.300; // m/s
const ACCELERATION: f64 = 10.0; // m/s^2 (10,000 mm/s^2)
const MICROSTEPS_PER_METRE: f64 = 80_000.0;
const FIELD_PER_MICROSTEP: f64 = PI / 32.0; // a quarter cycle per full step, 16 microsteps per full step
const CURRENT: f64 = 1.5; // A, peak phase current
const BAND: f64 = 20e-6; // m, the band the carriage has to settle into

#[cfg(feature = "shaper6150")]
const SHAPER_FREQUENCY: f64 = 61.50; // Hz, the servo axis
#[cfg(feature = "shaper6208")]
const SHAPER_FREQUENCY: f64 = 62.08; // Hz, the axis held by the open-loop stepper
#[cfg(feature = "shaper6350")]
const SHAPER_FREQUENCY: f64 = 63.50; // Hz, the axis under the closed-loop stepper
#[cfg(feature = "shaper6902")]
const SHAPER_FREQUENCY: f64 = 69.02; // Hz, the belt alone
#[cfg(not(any(feature = "shaper6150", feature = "shaper6208", feature = "shaper6350", feature = "shaper6902")))]
const SHAPER_FREQUENCY: f64 = 0.0; // no shaper

const PULLEY_RADIUS: f64 = 0.0063662; // m, 20 teeth of 2 mm

// The closed-loop stepper: current per metre of position error and per m/s of speed error, and the largest current.
const STEPPER_KP: f64 = 12_000.0; // A/m
const STEPPER_KD: f64 = 15.0; // A s/m
const STEPPER_CURRENT_MAX: f64 = 2.0; // A
const ROTOR_TEETH: f64 = 50.0;

// The servo: the same loop gives a q-axis current; the current loop is a PI with decoupling at 800 Hz.
const SERVO_KP: f64 = 53_000.0; // A/m
const SERVO_KD: f64 = 32.0; // A s/m
const SERVO_CURRENT_MAX: f64 = 6.0; // A
const SERVO_INDUCTANCE: f64 = 0.5e-3; // H
const SERVO_RESISTANCE: f64 = 0.5; // ohm
const SERVO_FLUX: f64 = 0.01; // Wb
const SERVO_POLE_PAIRS: f64 = 4.0;
const SERVO_CURRENT_LOOP: f64 = 5_000.0; // rad/s
const SERVO_VOLTAGE_MAX: f64 = 24.0 / 1.732_050_807_568_877_2; // V, the dc link over root 3

struct State {
    clock: i64,
    position: f64, // the true carriage position, for the monitor only
    position_y: f64,
    encoder: f64,  // the pulley-side belt position the motor's encoder gives, m
    encoder_before: f64,
    encoder_b: f64,
    encoder_b_before: f64,
    current_d: f64, // measured stator currents of the servo
    current_q: f64,
    integral_d: f64,
    integral_q: f64,
    voltage_d: f64,
    voltage_q: f64,
    field_angle: f64,
    current: f64,
    field_angle_b: f64,
    current_b: f64,
    last_outside: f64,
    residual: f64,
    tracking: f64,
}

const START_STATE: State = State {
    clock: 0,
    position: 0.0,
    position_y: 0.0,
    encoder: 0.0,
    encoder_before: 0.0,
    encoder_b: 0.0,
    encoder_b_before: 0.0,
    current_d: 0.0,
    current_q: 0.0,
    integral_d: 0.0,
    integral_q: 0.0,
    voltage_d: 0.0,
    voltage_q: 0.0,
    field_angle: 0.0,
    current: 0.0,
    field_angle_b: 0.0,
    current_b: 0.0,
    last_outside: 0.0,
    residual: 0.0,
    tracking: 0.0,
};
static mut STATE: State = START_STATE;

fn state() -> &'static mut State {
    #[allow(static_mut_refs)]
    unsafe {
        &mut STATE
    }
}

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

fn abs(x: f64) -> f64 {
    if x < 0.0 {
        -x
    } else {
        x
    }
}

/// Square root by Newton's method, for a non-negative argument.
fn sqrt(x: f64) -> f64 {
    if x <= 0.0 {
        return 0.0;
    }
    let mut y = if x > 1.0 { x } else { 1.0 };
    for _ in 0..40 {
        y = 0.5 * (y + x / y);
    }
    y
}

/// Limit `x` to the range from minus `limit` to `limit`.
fn clamp(x: f64, limit: f64) -> f64 {
    if x > limit {
        limit
    } else if x < -limit {
        -limit
    } else {
        x
    }
}

/// Round half away from zero.
fn round(x: f64) -> f64 {
    if x < 0.0 {
        -((-x + 0.5) as i64 as f64)
    } else {
        (x + 0.5) as i64 as f64
    }
}

/// Position along the trapezoidal profile `t` seconds after it starts.
fn profile(t: f64) -> f64 {
    let accel_time = SPEED / ACCELERATION;
    let accel_distance = 0.5 * ACCELERATION * accel_time * accel_time;
    let cruise_time = (DISTANCE - 2.0 * accel_distance) / SPEED;
    let total = 2.0 * accel_time + cruise_time;
    if t <= 0.0 {
        0.0
    } else if t < accel_time {
        0.5 * ACCELERATION * t * t
    } else if t < accel_time + cruise_time {
        accel_distance + SPEED * (t - accel_time)
    } else if t < total {
        let left = total - t;
        DISTANCE - 0.5 * ACCELERATION * left * left
    } else {
        DISTANCE
    }
}

/// How long the profile lasts.
fn move_time() -> f64 {
    let accel_time = SPEED / ACCELERATION;
    let accel_distance = 0.5 * ACCELERATION * accel_time * accel_time;
    2.0 * accel_time + (DISTANCE - 2.0 * accel_distance) / SPEED
}

/// The commanded position at time `t`: the profile, shaped by a zero-vibration shaper when there is one. The shaper's two
/// impulses are equal for an undamped resonance and are half a period apart.
fn commanded(t: f64) -> f64 {
    if SHAPER_FREQUENCY > 0.0 {
        0.5 * profile(t - START) + 0.5 * profile(t - START - 0.5 / SHAPER_FREQUENCY)
    } else {
        profile(t - START)
    }
}

/// When the commanded motion has ended.
fn done_time() -> f64 {
    let delay = if SHAPER_FREQUENCY > 0.0 { 0.5 / SHAPER_FREQUENCY } else { 0.0 };
    START + move_time() + delay
}

fn closed_stepper(command: f64, speed_command: f64, encoder: f64, speed: f64) -> (f64, f64) {
    let target = round(command * MICROSTEPS_PER_METRE) / MICROSTEPS_PER_METRE;
    let current = STEPPER_KP * (target - encoder) + STEPPER_KD * (speed_command - speed);
    let lead = if current >= 0.0 { PI / 2.0 } else { -PI / 2.0 };
    (
        ROTOR_TEETH * encoder / PULLEY_RADIUS + lead,
        clamp(abs(current), STEPPER_CURRENT_MAX),
    )
}

fn monitor(s: &mut State, t: f64, end: f64, tracking_error: f64, deviation: f64) {
    if t >= START && t <= end {
        s.tracking = s.tracking.max(tracking_error);
    }
    if t > end {
        if deviation > BAND {
            s.last_outside = t;
        }
        s.residual = s.residual.max(deviation);
    }
}

// The corner blends two 20 mm legs. Each end of the blend is 0.5 mm from the nominal corner.
// A quadratic Bézier has continuous velocity at the 75 mm/s entry and exit, with 7.95 m/s² inside the blend.
const BLEND: f64 = 0.0005;
const JUNCTION_SPEED: f64 = 0.075;
const BLEND_TIME: f64 = 2.0 * BLEND / JUNCTION_SPEED;
const LEG: f64 = DISTANCE - BLEND;
const RAMP_UP: f64 = SPEED / ACCELERATION;
const RAMP_DOWN: f64 = (SPEED - JUNCTION_SPEED) / ACCELERATION;
const RAMP_UP_DISTANCE: f64 = 0.5 * SPEED * RAMP_UP;
const RAMP_DOWN_DISTANCE: f64 = 0.5 * (SPEED + JUNCTION_SPEED) * RAMP_DOWN;
const CRUISE_TIME: f64 = (LEG - RAMP_UP_DISTANCE - RAMP_DOWN_DISTANCE) / SPEED;
const APPROACH_TIME: f64 = RAMP_UP + CRUISE_TIME + RAMP_DOWN;
const CORNER_TIME: f64 = 2.0 * APPROACH_TIME + BLEND_TIME;

fn approach(t: f64) -> f64 {
    if t <= 0.0 {
        0.0
    } else if t < RAMP_UP {
        0.5 * ACCELERATION * t * t
    } else if t < RAMP_UP + CRUISE_TIME {
        RAMP_UP_DISTANCE + SPEED * (t - RAMP_UP)
    } else if t < APPROACH_TIME {
        let time_left = APPROACH_TIME - t;
        LEG - JUNCTION_SPEED * time_left - 0.5 * ACCELERATION * time_left * time_left
    } else {
        LEG
    }
}

fn corexy_path(t: f64) -> (f64, f64) {
    if cfg!(feature = "corexy_corner") {
        if t <= APPROACH_TIME {
            return (approach(t), 0.0);
        }
        if t < APPROACH_TIME + BLEND_TIME {
            let u = (t - APPROACH_TIME) / BLEND_TIME;
            return (LEG + BLEND * (2.0 * u - u * u), BLEND * u * u);
        }
        return (DISTANCE, DISTANCE - approach(CORNER_TIME - t));
    }

    let distance = profile(t);
    if cfg!(feature = "corexy_x") {
        (distance, 0.0)
    } else if cfg!(feature = "corexy_y") {
        (0.0, distance)
    } else if cfg!(feature = "corexy_opposite") {
        (0.8 * distance, -0.6 * distance)
    } else {
        (0.8 * distance, 0.6 * distance)
    }
}

fn corexy_command(t: f64) -> (f64, f64) {
    let (x, y) = corexy_path(t - START);
    if SHAPER_FREQUENCY > 0.0 {
        let (delayed_x, delayed_y) = corexy_path(t - START - 0.5 / SHAPER_FREQUENCY);
        (0.5 * (x + delayed_x), 0.5 * (y + delayed_y))
    } else {
        (x, y)
    }
}

fn motion_end() -> f64 {
    if cfg!(feature = "corexy_corner") {
        done_time() + (CORNER_TIME - move_time())
    } else {
        done_time()
    }
}

fn corexy_tick(s: &mut State, t: f64, dt: f64) {
    let (x, y) = corexy_command(t);
    let (next_x, next_y) = corexy_command(t + dt);
    let vx = (next_x - x) / dt;
    let vy = (next_y - y) / dt;
    (s.field_angle, s.current) = closed_stepper(
        x + y, vx + vy, s.encoder, (s.encoder - s.encoder_before) / dt,
    );
    (s.field_angle_b, s.current_b) = closed_stepper(
        x - y, vx - vy, s.encoder_b, (s.encoder_b - s.encoder_b_before) / dt,
    );
    s.encoder_before = s.encoder;
    s.encoder_b_before = s.encoder_b;

    let distance_to = |target_x: f64, target_y: f64| {
        let dx = s.position - target_x;
        let dy = s.position_y - target_y;
        sqrt(dx * dx + dy * dy)
    };
    let (final_x, final_y) = corexy_path(motion_end());
    monitor(s, t, motion_end(), distance_to(x, y), distance_to(final_x, final_y));
}

#[no_mangle]
pub extern "C" fn api() -> i32 {
    2
}
#[no_mangle]
pub extern "C" fn initialize() -> i32 {
    *state() = START_STATE;
    0
}
#[no_mangle]
pub extern "C" fn clock() -> i64 {
    state().clock
}
#[no_mangle]
pub extern "C" fn deadline() -> i64 {
    state().clock + TICK_NS
}
/// Readings: 0 the true carriage position in m, for the test bench monitor only; 1 the encoder, the belt position at the
/// pulley in m; 2 and 3 the d and q currents of the servo in A. On CoreXY, 4 is carriage Y and 5 is belt B's encoder.
#[no_mangle]
pub extern "C" fn provide(index: i32, value: f64) -> i32 {
    match index {
        0 => state().position = value,
        1 => state().encoder = value,
        2 => state().current_d = value,
        3 => state().current_q = value,
        4 if cfg!(feature = "corexy") => state().position_y = value,
        5 if cfg!(feature = "corexy") => state().encoder_b = value,
        _ => return 1,
    }
    0
}
#[no_mangle]
pub extern "C" fn advance(target: i64) -> i32 {
    let s = state();
    if target < s.clock || (target - s.clock) % TICK_NS != 0 {
        return 1;
    }
    while s.clock < target {
        s.clock += TICK_NS;
        let t = (s.clock as f64) * 1e-9;
        let dt = (TICK_NS as f64) * 1e-9;
        if cfg!(feature = "corexy") {
            corexy_tick(s, t, dt);
            continue;
        }
        let command = commanded(t);
        let target = round(command * MICROSTEPS_PER_METRE) / MICROSTEPS_PER_METRE; // the microstep the driver is told
        let speed = (s.encoder - s.encoder_before) / dt;
        s.encoder_before = s.encoder;
        // The speed the profile asks for now, from the commanded position a tick ahead.
        let speed_command = (commanded(t + dt) - command) / dt;
        if cfg!(feature = "servo") {
            let torque_current = clamp(SERVO_KP * (target - s.encoder) + SERVO_KD * (speed_command - speed), SERVO_CURRENT_MAX);
            let electrical_speed = SERVO_POLE_PAIRS * speed / PULLEY_RADIUS;
            let error_d = -s.current_d;
            let error_q = torque_current - s.current_q;
            let kp = SERVO_INDUCTANCE * SERVO_CURRENT_LOOP;
            let ki = SERVO_RESISTANCE * SERVO_CURRENT_LOOP;
            let vd = kp * error_d + s.integral_d - electrical_speed * SERVO_INDUCTANCE * s.current_q;
            let vq = kp * error_q + s.integral_q + electrical_speed * (SERVO_INDUCTANCE * s.current_d + SERVO_FLUX);
            let magnitude = sqrt(vd * vd + vq * vq);
            if magnitude > SERVO_VOLTAGE_MAX {
                // Saturated: limit the voltage vector and hold the integrators.
                s.voltage_d = vd * SERVO_VOLTAGE_MAX / magnitude;
                s.voltage_q = vq * SERVO_VOLTAGE_MAX / magnitude;
            } else {
                s.voltage_d = vd;
                s.voltage_q = vq;
                s.integral_d += ki * error_d * dt;
                s.integral_q += ki * error_q * dt;
            }
        } else if cfg!(feature = "closed_loop") {
            (s.field_angle, s.current) = closed_stepper(command, speed_command, s.encoder, speed);
        } else {
            s.field_angle = round(command * MICROSTEPS_PER_METRE) * FIELD_PER_MICROSTEP;
            s.current = CURRENT;
        }
        monitor(s, t, done_time(), abs(s.position - command), abs(s.position - DISTANCE));
    }
    0
}
#[no_mangle]
pub extern "C" fn receive(_: i32) -> i32 {
    1
}
/// 0 field angle (rad); 1 phase current (A); 2 settling time (s); 3 residual vibration (m); 4 tracking error (m);
/// 5 and 6 the d and q stator voltages of the servo (V); 7 and 8 the CoreXY B field angle and phase current.
/// 9 and 10 are the planned CoreXY endpoint in metres.
#[no_mangle]
pub extern "C" fn sample(index: i32) -> f64 {
    let s = state();
    match index {
        0 => s.field_angle,
        1 => s.current,
        2 => {
            if s.last_outside > motion_end() {
                s.last_outside - motion_end()
            } else {
                0.0
            }
        }
        3 => s.residual,
        4 => s.tracking,
        5 => s.voltage_d,
        6 => s.voltage_q,
        7 if cfg!(feature = "corexy") => s.field_angle_b,
        8 if cfg!(feature = "corexy") => s.current_b,
        9 if cfg!(feature = "corexy") => corexy_path(motion_end()).0,
        10 if cfg!(feature = "corexy") => corexy_path(motion_end()).1,
        _ => f64::NAN,
    }
}
