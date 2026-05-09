fn print_version_and_exit() {
    if std::env::args().any(|arg| arg == "--version" || arg == "-V") {
        println!("openssl-sys-demo {}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }
}

fn main() {
    print_version_and_exit();
    println!("{}", openssl::version::version());
}
