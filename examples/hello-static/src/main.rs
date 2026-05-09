use clap::Parser;

#[derive(Parser)]
#[command(version, about = "MuslForge static hello validation target")]
struct Cli {
    #[arg(long, default_value = "musl")]
    name: String,
}

fn main() {
    let cli = Cli::parse();
    println!("hello {}", cli.name);
}
