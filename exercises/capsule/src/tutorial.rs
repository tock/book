//! Sample capsule for Tock tutorial. It handles an alarm to
//! sample the humidity sensor

#![forbid(unsafe_code)]
#![no_std]
#![allow(dead_code, unused_imports, unused_variables)]

#[allow(unused_imports)]
#[macro_use(debug)]
extern crate kernel;

use kernel::hil::sensors::{HumidityDriver, HumidityClient};
use kernel::hil::time::{self, Alarm, Frequency};

pub struct Tutorial<'a, A: Alarm + 'a> {
    alarm: &'a A,
    humidity: &'a HumidityDriver,
}

impl<'a, A: Alarm> Tutorial<'a, A> {
    pub fn new(alarm: &'a A, humidity: &'a HumidityDriver) -> Tutorial<'a, A> {
        Tutorial {
            alarm: alarm,
            humidity: humidity,
        }
    }

    pub fn start(&self) {
    }
}

impl<'a, A: Alarm> time::Client for Tutorial<'a, A> {
    fn fired(&self) {}
}

impl<'a, A: Alarm> HumidityClient for Tutorial<'a, A> {
    fn callback(&self, humidity: usize) {}
}
