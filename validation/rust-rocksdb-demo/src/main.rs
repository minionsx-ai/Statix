use std::fs;

use rocksdb::{Options, DB};

fn print_version_and_exit() {
    if std::env::args().any(|arg| arg == "--version" || arg == "-V") {
        println!("rust-rocksdb-demo {}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    print_version_and_exit();

    let path = std::env::temp_dir().join(format!("muslforge-rocksdb-{}", std::process::id()));
    let _ = fs::remove_dir_all(&path);

    let mut options = Options::default();
    options.create_if_missing(true);
    {
        let db = DB::open(&options, &path)?;
        db.put(b"runtime", b"passed")?;
        let value = db.get(b"runtime")?.expect("value must exist");
        println!("rocksdb={}", String::from_utf8(value)?);
    }

    DB::destroy(&options, &path)?;
    Ok(())
}
