use anyhow::Result;
use rusqlite::{params, Connection};

fn print_version_and_exit() {
    if std::env::args().any(|arg| arg == "--version" || arg == "-V") {
        println!("rusqlite-bundled {}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }
}

fn main() -> Result<()> {
    print_version_and_exit();

    let connection = Connection::open_in_memory()?;
    connection.execute(
        "CREATE TABLE checks (id INTEGER PRIMARY KEY, value TEXT NOT NULL)",
        [],
    )?;
    connection.execute("INSERT INTO checks (value) VALUES (?1)", params!["ok"])?;

    let value: String =
        connection.query_row("SELECT value FROM checks WHERE id = 1", [], |row| {
            row.get(0)
        })?;
    println!("sqlite={value}");
    Ok(())
}
