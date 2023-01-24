#![no_main]
#![no_std]

use defmt::{write, Format};
use sam3x8e::pmc::ckgr_mor::MOSCRCF_A;
use turbo_run as _; // global logger + panicking-behavior + memory layout

struct Rcf(MOSCRCF_A);

impl Format for Rcf {
    fn format(&self, fmt: defmt::Formatter) {
        use MOSCRCF_A::*;
        match self {
            Rcf(_4_MHZ) => write!(fmt, "MOSCRCF_A::4_MHZ"),
            Rcf(_8_MHZ) => write!(fmt, "MOSCRCF_A::8_MHZ"),
            Rcf(_12_MHZ) => write!(fmt, "MOSCRCF_A::12_MHZ"),
        }
    }
}

#[rtic::app(
    device = sam3x8e,
    dispatchers = [ TC0 ]
    )]
mod app {
    use super::*;
    use systick_monotonic::*;

    #[shared]
    struct Shared {}

    #[local]
    struct Local {}

    #[monotonic(binds = SysTick, default = true)]
    type DwtMono = systick_monotonic::Systick<1_000>;

    #[init]
    fn init(cx: init::Context) -> (Shared, Local, init::Monotonics) {
        defmt::trace!("init");

        cx.device.WDT.mr.write(|w| w.wddis().set_bit());

        let mor = &cx.device.PMC.ckgr_mor;
        if mor.read().bits() != 0x08 {
            defmt::debug!("CKGR_MOR is not equal to its reset value");
            // SAFETY: we're resetting the processor
            unsafe { cx.device.RSTC.cr.write_with_zero(|w| {
                w.key().passwd();
                w.procrst().set_bit();
                w.perrst().set_bit()
            }); }
        } else {
            defmt::debug!("Everything seems in order");
        }

        let rcf = cx.device.PMC.ckgr_mor.read().moscrcf().variant().map(Rcf);
        defmt::debug!("{:?}", rcf);

        if mor.read().moscsel().bit_is_clear() {
            defmt::debug!("Running from RC");
        }

        let mono = Systick::new(cx.core.SYST, 4_000_000);

        timed_hello::spawn().unwrap();

        (Shared {}, Local {}, init::Monotonics(mono))
    }

    #[idle]
    fn idle(_: idle::Context) -> ! {
        defmt::trace!("idle");
        loop {
            continue;
        }
    }

    #[task]
    fn timed_hello(_cx: timed_hello::Context) {
        defmt::trace!("Hello, world! @ {:?}", monotonics::now().ticks());
        timed_hello::spawn_after(1.secs()).unwrap();
    }
}
