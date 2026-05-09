use diesel::pg::PgConnection;
use diesel::Connection;

fn print_version_and_exit() {
    if std::env::args().any(|arg| arg == "--version" || arg == "-V") {
        println!("diesel-postgres {}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }
}

fn main() {
    print_version_and_exit();
    // Attempt connection to a non-existent server.
    // Validation point is static link success, not connectivity.
    // Any outcome — connected or connection refused — means libpq linked correctly.
    match PgConnection::establish("postgres://postgres:password@127.0.0.1/test") {
        Ok(_) => println!("diesel-postgres=runtime passed"),
        Err(_) => println!("diesel-postgres=runtime passed"),
    }
}
