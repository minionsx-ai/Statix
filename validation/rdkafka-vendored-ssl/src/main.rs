fn print_version_and_exit() {
    if std::env::args().any(|arg| arg == "--version" || arg == "-V") {
        println!("rdkafka-vendored-ssl {}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }
}

fn main() {
    print_version_and_exit();
    let (_, version) = rdkafka::util::get_rdkafka_version();
    println!("librdkafka={version}");
}
