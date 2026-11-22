//! Motion controller for one axis of the printer: firmware for Run42's WebAssembly guest interface (ABI 2).
//!
//! It plays one move, a trapezoidal profile of 20 mm at up to 300 mm/s and 10,000 mm/s^2, starting 2 ms after boot. With
//! a zero-vibration input shaper (feature `shaper62` or `shaper69`) the commanded position is half the profile plus half
//! the profile delayed by half a period of the resonance the shaper is tuned to, which cancels that resonance's
//! vibration. The commanded position is quantised to microsteps (80 per mm of belt travel, 16 per full step) and
//! turned into the stepper's field angle (a quarter cycle per full step) with a constant phase current: it is an
//! open-loop stepper driver. Every 50 us the coordinator hands the guest nothing the controller uses.
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

#[cfg(feature = "shaper62")]
const SHAPER_FREQUENCY: f64 = 62.08; // Hz
#[cfg(feature = "shaper69")]
const SHAPER_FREQUENCY: f64 = 69.02; // Hz
#[cfg(not(any(feature = "shaper62", feature = "shaper69")))]
const SHAPER_FREQUENCY: f64 = 0.0; // no shaper

struct State {
    clock: i64,
    position: f64, // the true carriage position, for the monitor only
    field_angle: f64,
    current: f64,
    last_outside: f64,
    residual: f64,
    tracking: f64,
}

const START_STATE: State = State {
    clock: 0,
    position: 0.0,
    field_angle: 0.0,
    current: 0.0,
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
/// Readings: 0 the true carriage position in m, for the test bench monitor only.
#[no_mangle]
pub extern "C" fn provide(index: i32, value: f64) -> i32 {
    match index {
        0 => state().position = value,
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
        let command = commanded(t);
        s.field_angle = round(command * MICROSTEPS_PER_METRE) * FIELD_PER_MICROSTEP;
        s.current = CURRENT;
        // Test bench monitor.
        if t >= START && t <= done_time() {
            let error = abs(s.position - command);
            if error > s.tracking {
                s.tracking = error;
            }
        }
        if t > done_time() {
            let deviation = abs(s.position - DISTANCE);
            if deviation > BAND {
                s.last_outside = t;
            }
            if deviation > s.residual {
                s.residual = deviation;
            }
        }
    }
    0
}
#[no_mangle]
pub extern "C" fn receive(_: i32) -> i32 {
    1
}
/// 0 field angle (rad); 1 phase current (A); 2 settling time (s); 3 residual vibration (m); 4 tracking error (m).
#[no_mangle]
pub extern "C" fn sample(index: i32) -> f64 {
    let s = state();
    match index {
        0 => s.field_angle,
        1 => s.current,
        2 => {
            if s.last_outside > done_time() {
                s.last_outside - done_time()
            } else {
                0.0
            }
        }
        3 => s.residual,
        4 => s.tracking,
        _ => f64::NAN,
    }
}
