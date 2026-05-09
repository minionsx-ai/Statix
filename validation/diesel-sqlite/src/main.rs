use diesel::connection::SimpleConnection;
use diesel::prelude::*;
use diesel::sqlite::SqliteConnection;

fn print_version_and_exit() {
    if std::env::args().any(|arg| arg == "--version" || arg == "-V") {
        println!("diesel-sqlite {}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    print_version_and_exit();

    let mut connection = SqliteConnection::establish(":memory:")?;
    connection.batch_execute(
        "CREATE TABLE checks (id INTEGER PRIMARY KEY, value TEXT NOT NULL);
         INSERT INTO checks (value) VALUES ('runtime passed');",
    )?;

    println!("diesel-sqlite=runtime passed");
    Ok(())
}
