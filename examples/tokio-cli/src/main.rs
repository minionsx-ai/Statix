use std::time::Duration;

use anyhow::Result;
use clap::Parser;
use serde::Serialize;

#[derive(Parser)]
#[command(version, about = "MuslForge Tokio CLI validation target")]
struct Cli {
    #[arg(long, default_value_t = 3)]
    count: usize,
}

#[derive(Serialize)]
struct Item {
    index: usize,
    label: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    tokio::time::sleep(Duration::from_millis(1)).await;

    let items: Vec<_> = (0..cli.count)
        .map(|index| Item {
            index,
            label: format!("item-{index}"),
        })
        .collect();

    println!("{}", serde_json::to_string(&items)?);
    Ok(())
}
