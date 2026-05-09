use ed25519_dalek::{Signer, SigningKey, Verifier};
use secp256k1::{ecdsa::Signature, Message, PublicKey, Secp256k1, SecretKey};
use sha2::{Digest, Sha256};

fn print_version_and_exit() {
    if std::env::args().any(|arg| arg == "--version" || arg == "-V") {
        println!("crypto-signing {}", env!("CARGO_PKG_VERSION"));
        std::process::exit(0);
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    print_version_and_exit();

    let message = b"muslforge-validation";
    let digest = Sha256::digest(message);

    let ed25519_key = SigningKey::from_bytes(&[7_u8; 32]);
    let ed25519_signature = ed25519_key.sign(message);
    ed25519_key
        .verifying_key()
        .verify(message, &ed25519_signature)?;

    let secp = Secp256k1::new();
    let secret = SecretKey::from_slice(&[11_u8; 32])?;
    let public_key = PublicKey::from_secret_key(&secp, &secret);
    let secp_message = Message::from_digest_slice(digest.as_slice())?;
    let signature: Signature = secp.sign_ecdsa(&secp_message, &secret);
    secp.verify_ecdsa(&secp_message, &signature, &public_key)?;

    println!(
        "sha256={} blake3={} bs58={}",
        hex::encode(digest),
        blake3::hash(message).to_hex(),
        bs58::encode(message).into_string()
    );
    Ok(())
}
