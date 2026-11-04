use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCall {
    pub name: String,
    pub arguments: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolResult {
    pub success: bool,
    pub output: String,
}

pub struct ToolExecutor {
    workspace_root: PathBuf,
}

impl ToolExecutor {
    pub fn new(workspace_root: PathBuf) -> Self {
        Self { workspace_root }
    }

    fn resolve_path(&self, rel_path: &str) -> PathBuf {
        self.workspace_root.join(rel_path.trim_start_matches('/'))
    }

    pub fn list_directory(&self, rel_path: &str) -> Result<Vec<String>> {
        let full_path = self.resolve_path(rel_path);
        let mut entries = Vec::new();
        if full_path.exists() && full_path.is_dir() {
            for entry in fs::read_dir(full_path)? {
                let entry = entry?;
                let file_name = entry.file_name().to_string_lossy().to_string();
                let is_dir = entry.file_type()?.is_dir();
                entries.push(if is_dir { format!("{}/", file_name) } else { file_name });
            }
        }
        Ok(entries)
    }

    pub fn read_file(&self, rel_path: &str) -> Result<String> {
        let full_path = self.resolve_path(rel_path);
        let content = fs::read_to_string(full_path)?;
        Ok(content)
    }

    pub fn write_file(&self, rel_path: &str, content: &str) -> Result<()> {
        let full_path = self.resolve_path(rel_path);
        if let Some(parent) = full_path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(full_path, content)?;
        Ok(())
    }

    pub fn execute_command(&self, command_line: &str) -> Result<String> {
        #[cfg(target_os = "windows")]
        let mut cmd = {
            let mut c = Command::new("cmd");
            c.args(["/C", command_line]);
            c
        };

        #[cfg(not(target_os = "windows"))]
        let mut cmd = {
            let mut c = Command::new("sh");
            c.args(["-c", command_line]);
            c
        };

        cmd.current_dir(&self.workspace_root);
        let output = cmd.output()?;
        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        if output.status.success() {
            Ok(stdout)
        } else {
            Ok(format!("Status: {}\nStdout: {}\nStderr: {}", output.status, stdout, stderr))
        }
    }
}

