use crate::agent::AgentEngine;
use axum::extract::ws::{Message, WebSocket};
use futures::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::{error, info};

#[derive(Debug, Deserialize)]
#[serde(tag = "type")]
pub enum ClientMessage {
    #[serde(rename = "auth")]
    Auth { token: String },
    #[serde(rename = "prompt")]
    Prompt { content: String, api_key: Option<String> },
    #[serde(rename = "list_files")]
    ListFiles { path: Option<String> },
    #[serde(rename = "read_file")]
    ReadFile { path: String },
    #[serde(rename = "save_file")]
    SaveFile { path: String, content: String },
    #[serde(rename = "run_command")]
    RunCommand { command: String },
}

#[derive(Debug, Serialize)]
#[serde(tag = "type")]
pub enum ServerMessage {
    #[serde(rename = "auth_ok")]
    AuthOk,
    #[serde(rename = "stream")]
    Stream { content: String },
    #[serde(rename = "files")]
    Files { path: String, entries: Vec<String> },
    #[serde(rename = "file_content")]
    FileContent { path: String, content: String },
    #[serde(rename = "command_output")]
    CommandOutput { output: String },
    #[serde(rename = "error")]
    Error { message: String },
}

pub async fn handle_socket(
    socket: WebSocket,
    expected_token: String,
    agent: Arc<AgentEngine>,
) {
    let (mut sender, mut receiver) = socket.split();
    let (tx, mut rx) = mpsc::unbounded_channel::<Message>();

    // Tarefa dedicada de envio (escrita assíncrona sem travas)
    let send_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if sender.send(msg).await.is_err() {
                break;
            }
        }
    });

    let mut authenticated = false;

    while let Some(Ok(msg)) = receiver.next().await {
        if let Message::Text(text) = msg {
            let parsed: Result<ClientMessage, _> = serde_json::from_str(&text);
            match parsed {
                Ok(ClientMessage::Auth { token }) => {
                    if token == expected_token {
                        authenticated = true;
                        let resp = serde_json::to_string(&ServerMessage::AuthOk).unwrap();
                        let _ = tx.send(Message::Text(resp));
                        info!("Mobile client autenticado com sucesso!");
                    } else {
                        let resp = serde_json::to_string(&ServerMessage::Error {
                            message: "Token inválido".into(),
                        })
                        .unwrap();
                        let _ = tx.send(Message::Text(resp));
                    }
                }
                Ok(other) => {
                    if !authenticated {
                        let resp = serde_json::to_string(&ServerMessage::Error {
                            message: "Não autenticado".into(),
                        })
                        .unwrap();
                        let _ = tx.send(Message::Text(resp));
                        continue;
                    }

                    match other {
                        ClientMessage::Prompt { content, api_key } => {
                            let current_agent = agent.clone_with_key(api_key);
                            let tx_stream = tx.clone();

                            let _ = current_agent
                                .process_user_prompt(&content, move |chunk| {
                                    let msg = serde_json::to_string(&ServerMessage::Stream {
                                        content: chunk,
                                    })
                                    .unwrap();
                                    let _ = tx_stream.send(Message::Text(msg));
                                })
                                .await;
                        }
                        ClientMessage::ListFiles { path } => {
                            let rel_path = path.unwrap_or_default();
                            let executor = agent.executor.lock().await;
                            match executor.list_directory(&rel_path) {
                                Ok(entries) => {
                                    let resp = serde_json::to_string(&ServerMessage::Files {
                                        path: rel_path,
                                        entries,
                                    })
                                    .unwrap();
                                    let _ = tx.send(Message::Text(resp));
                                }
                                Err(e) => {
                                    let resp = serde_json::to_string(&ServerMessage::Error {
                                        message: e.to_string(),
                                    })
                                    .unwrap();
                                    let _ = tx.send(Message::Text(resp));
                                }
                            }
                        }
                        ClientMessage::ReadFile { path } => {
                            let executor = agent.executor.lock().await;
                            match executor.read_file(&path) {
                                Ok(content) => {
                                    let resp = serde_json::to_string(&ServerMessage::FileContent {
                                        path,
                                        content,
                                    })
                                    .unwrap();
                                    let _ = tx.send(Message::Text(resp));
                                }
                                Err(e) => {
                                    let resp = serde_json::to_string(&ServerMessage::Error {
                                        message: e.to_string(),
                                    })
                                    .unwrap();
                                    let _ = tx.send(Message::Text(resp));
                                }
                            }
                        }
                        ClientMessage::SaveFile { path, content } => {
                            let executor = agent.executor.lock().await;
                            match executor.write_file(&path, &content) {
                                Ok(_) => {
                                    let resp = serde_json::to_string(&ServerMessage::Stream {
                                        content: format!("Arquivo {} salvo com sucesso!", path),
                                    })
                                    .unwrap();
                                    let _ = tx.send(Message::Text(resp));
                                }
                                Err(e) => {
                                    let resp = serde_json::to_string(&ServerMessage::Error {
                                        message: e.to_string(),
                                    })
                                    .unwrap();
                                    let _ = tx.send(Message::Text(resp));
                                }
                            }
                        }
                        ClientMessage::RunCommand { command } => {
                            let executor = agent.executor.lock().await;
                            match executor.execute_command(&command) {
                                Ok(output) => {
                                    let resp = serde_json::to_string(&ServerMessage::CommandOutput {
                                        output,
                                    })
                                    .unwrap();
                                    let _ = tx.send(Message::Text(resp));
                                }
                                Err(e) => {
                                    let resp = serde_json::to_string(&ServerMessage::Error {
                                        message: e.to_string(),
                                    })
                                    .unwrap();
                                    let _ = tx.send(Message::Text(resp));
                                }
                            }
                        }
                        _ => {}
                    }
                }
                Err(e) => {
                    error!("Erro ao deserializar mensagem: {}", e);
                }
            }
        }
    }

    send_task.abort();
}
