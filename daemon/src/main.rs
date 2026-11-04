mod agent;
mod server;

use agent::AgentEngine;
use anyhow::Result;
use qrcode::render::unicode;
use qrcode::QrCode;
use server::{create_router, AppState};
use std::env;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use tracing::info;
use uuid::Uuid;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .init();

    println!("============================================================");
    println!("  🛰️  Antigravity Mobile Orbit Daemon (by CESIC)");
    println!("============================================================");

    let workspace_root = env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    let api_key = env::var("GEMINI_API_KEY").ok();

    // 1. Gerar token de segurança da sessão
    let session_token = Uuid::new_v4().to_string();

    // 2. Identificar IP de rede local
    let local_ip = local_ip_address::local_ip()
        .map(|ip| ip.to_string())
        .unwrap_or_else(|_| "127.0.0.1".to_string());

    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(3000);

    // 3. Montar dados para o QR Code de pareamento
    let pairing_payload = serde_json::json!({
        "app": "antigravity-orbit",
        "host": local_ip,
        "port": port,
        "token": session_token
    });

    let pairing_string = serde_json::to_string(&pairing_payload)?;

    // 4. Renderizar QR Code no Terminal
    println!("\n📱 Aponte a câmera do aplicativo Antigravity Mobile para parear:\n");
    if let Ok(code) = QrCode::new(pairing_string.as_bytes()) {
        let image = code
            .render::<unicode::Dense1x2>()
            .dark_color(unicode::Dense1x2::Light)
            .light_color(unicode::Dense1x2::Dark)
            .build();
        println!("{}", image);
    }

    println!("\nConexão Manual:");
    println!("  Host: ws://{}:{}/ws", local_ip, port);
    println!("  Token: {}\n", session_token);
    println!("Workspace ativo: {}\n", workspace_root.display());

    // 5. Iniciar Servidor
    let agent = Arc::new(AgentEngine::new(workspace_root, api_key));
    let state = AppState {
        token: session_token,
        agent,
    };

    let router = create_router(state);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    info!("Servidor escutando em http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, router).await?;

    Ok(())
}

