pub mod tools;

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;
use tools::ToolExecutor;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentMessage {
    pub role: String,
    pub content: String,
    pub tool_calls: Option<Vec<tools::ToolCall>>,
}

#[derive(Clone)]
pub struct AgentEngine {
    pub executor: Arc<Mutex<ToolExecutor>>,
    pub api_key: Option<String>,
}

impl AgentEngine {
    pub fn new(workspace_root: PathBuf, api_key: Option<String>) -> Self {
        Self {
            executor: Arc::new(Mutex::new(ToolExecutor::new(workspace_root))),
            api_key,
        }
    }

    pub fn clone_with_key(&self, key: Option<String>) -> Self {
        Self {
            executor: self.executor.clone(),
            api_key: key.or_else(|| self.api_key.clone()),
        }
    }

    pub async fn process_user_prompt<F>(&self, prompt: &str, mut on_stream: F) -> Result<String>
    where
        F: FnMut(String) + Send + 'static,
    {
        // Se a chave não for fornecida, retorna instrução guiada
        let key = match &self.api_key {
            Some(k) if !k.is_empty() => k.clone(),
            _ => {
                let msg = "Por favor, configure sua chave do Google Gemini (gratuita no Google AI Studio) nas configurações do app para iniciar o agente de IA.".to_string();
                on_stream(msg.clone());
                return Ok(msg);
            }
        };

        // Chamar Gemini REST endpoint (v1beta gemini-2.0-flash ou 1.5-flash)
        let client = reqwest::Client::new();
        let url = format!(
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={}",
            key
        );

        let system_instruction = "Você é o Antigravity Mobile Orbit, assistente de programação da CESIC. Ajude o desenvolvedor com tarefas de código, refatoração e execução no PC/VPS.";

        let payload = serde_json::json!({
            "system_instruction": {
                "parts": [{ "text": system_instruction }]
            },
            "contents": [{
                "role": "user",
                "parts": [{ "text": prompt }]
            }]
        });

        on_stream("Pensando... Conectando à API do Gemini...".to_string());

        let res = client.post(&url).json(&payload).send().await?;
        if !res.status().is_success() {
            let err_text = res.text().await?;
            let err_msg = format!("Erro na API do Gemini: {}", err_text);
            on_stream(err_msg.clone());
            return Ok(err_msg);
        }

        let body: serde_json::Value = res.json().await?;
        let reply = body["candidates"][0]["content"]["parts"][0]["text"]
            .as_str()
            .unwrap_or("Sem resposta do modelo.")
            .to_string();

        on_stream(reply.clone());
        Ok(reply)
    }
}
