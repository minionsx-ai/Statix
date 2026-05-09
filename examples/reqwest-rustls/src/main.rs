use anyhow::Result;
use clap::Parser;

#[derive(Parser)]
#[command(version, about = "MuslForge reqwest/rustls validation target")]
struct Cli {
    #[arg(long, default_value = "https://example.com")]
    url: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    let response = reqwest::get(&cli.url).await?;
    println!("{} {}", response.status(), cli.url);
    Ok(())
}
