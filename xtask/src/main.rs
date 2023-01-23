use jaylink::JayLink;

fn main() {
    if let Err(e) = try_main() {
        eprintln!("{e}");
        std::process::exit(-1);
    }
}

fn try_main() -> anyhow::Result<()> {
    let task = std::env::args().nth(1);
    match task.as_deref() {
        Some("power-on") => power(Power::On)?,
        Some("power-off") => power(Power::Off)?,
        _ => print_help(),
    }
    Ok(())
}

fn print_help() {
    eprintln!(
        "Tasks:

power-on        Turn on JLink 5V supply
power-off       Turn off JLink 5V supply")
}

#[derive(Debug, Clone, Copy)]
enum Power {
    On, Off
}


fn power(p: Power) -> anyhow::Result<()> {
    let mut jlink = JayLink::open_by_serial(None)?;
    Ok(jlink.set_kickstart_power(match p {
        Power::On => true,
        Power::Off => false,
    })?)
}
