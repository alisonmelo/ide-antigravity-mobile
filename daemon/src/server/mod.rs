pub mod ws;

use crate::agent::AgentEngine;
use axum::{
    extract::{ws::WebSocketUpgrade, State},
    response::IntoResponse,
    routing::get,
    Router,
};
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};

#[derive(Clone)]
pub struct AppState {
    pub token: String,
    pub agent: Arc<AgentEngine>,
}

pub fn create_router(state: AppState) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    Router::new()
        .route("/health", get(health_check))
        .route("/ws", get(ws_handler))
        .layer(cors)
        .with_state(state)
}

async fn health_check() -> impl IntoResponse {
    axum::Json(serde_json::json!({
        "status": "online",
        "service": "Antigravity Mobile Orbit Daemon",
        "version": "0.1.0"
    }))
}

async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let token = state.token.clone();
    let agent = state.agent.clone();
    ws.on_upgrade(move |socket| ws::handle_socket(socket, token, agent))
}

