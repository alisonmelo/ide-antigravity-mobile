import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class IdeShellScreen extends StatefulWidget {
  final String geminiApiKey;
  const IdeShellScreen({super.key, required this.geminiApiKey});

  @override
  State<IdeShellScreen> createState() => _IdeShellScreenState();
}

class _IdeShellScreenState extends State<IdeShellScreen> {
  int _currentTabIndex = 0;
  final ws = WebSocketService();

  // Agent Chat State
  final _promptController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isAgentStreaming = false;

  // Editor State
  String _currentFilePath = '';
  final _codeController = TextEditingController();
  List<String> _fileList = [];

  // Terminal State
  final _terminalInputController = TextEditingController();
  final List<String> _terminalLogs = ['🛰️ Conectado ao Antigravity Orbit Daemon. Pronto para executar comandos.'];

  @override
  void initState() {
    super.initState();
    _setupWebSocketListeners();
    ws.listFiles();
  }

  void _setupWebSocketListeners() {
    ws.messagesStream.listen((msg) {
      if (!mounted) return;
      final type = msg['type'];

      if (type == 'stream') {
        final content = msg['content'] as String? ?? '';
        setState(() {
          _isAgentStreaming = false;
          _messages.add({'role': 'assistant', 'content': content});
        });
      } else if (type == 'files') {
        final entries = (msg['entries'] as List<dynamic>?)?.cast<String>() ?? [];
        setState(() {
          _fileList = entries;
        });
      } else if (type == 'file_content') {
        final path = msg['path'] as String? ?? '';
        final content = msg['content'] as String? ?? '';
        setState(() {
          _currentFilePath = path;
          _codeController.text = content;
          _currentTabIndex = 1; // Mudar para a aba do editor
        });
      } else if (type == 'command_output') {
        final output = msg['output'] as String? ?? '';
        setState(() {
          _terminalLogs.add(output);
        });
      } else if (type == 'error') {
        final err = msg['message'] as String? ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $err'), backgroundColor: Colors.redAccent),
        );
      }
    });
  }

  void _sendAgentPrompt() {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isAgentStreaming = true;
      _promptController.clear();
    });

    ws.sendPrompt(text, apiKey: widget.geminiApiKey);
  }

  void _runTerminalCommand() {
    final cmd = _terminalInputController.text.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _terminalLogs.add('> $cmd');
      _terminalInputController.clear();
    });

    ws.runCommand(cmd);
  }

  void _saveCurrentFile() {
    if (_currentFilePath.isEmpty) return;
    ws.saveFile(_currentFilePath, _codeController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Arquivo $_currentFilePath salvo no host!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.satellite_alt, color: Color(0xFF00D2FF), size: 20),
            const SizedBox(width: 8),
            Text(
              _tabTitle(_currentTabIndex),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => ws.listFiles(),
            tooltip: 'Recarregar arquivos',
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: () {
              ws.disconnect();
              Navigator.of(context).pushReplacementNamed('/');
            },
            tooltip: 'Desconectar',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildAgentTab(),
          _buildEditorTab(),
          _buildGitTab(),
          _buildTerminalTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        backgroundColor: const Color(0xFF161B22),
        selectedItemColor: const Color(0xFF00D2FF),
        unselectedItemColor: const Color(0xFF8B949E),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'Agente'),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Editor'),
          BottomNavigationBarItem(icon: Icon(Icons.merge_type), label: 'Git'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'Terminal'),
        ],
      ),
    );
  }

  String _tabTitle(int index) {
    switch (index) {
      case 0:
        return 'Agente de IA (Gemini)';
      case 1:
        return _currentFilePath.isEmpty ? 'Editor de Código' : _currentFilePath;
      case 2:
        return 'Controle Git (GitHub)';
      case 3:
        return 'Terminal Remoto PTY';
      default:
        return 'Antigravity Orbit';
    }
  }

  // 1. ABA DO AGENTE
  Widget _buildAgentTab() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF00D2FF), size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Antigravity Agent Pronto',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Peça para criar telas, corrigir erros ou refatorar.',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Listar arquivos'),
                            backgroundColor: const Color(0xFF161B22),
                            labelStyle: const TextStyle(color: Color(0xFF00D2FF)),
                            onPressed: () {
                              _promptController.text = 'Liste os principais arquivos deste projeto e me dê um resumo.';
                            },
                          ),
                          ActionChip(
                            label: const Text('Criar README'),
                            backgroundColor: const Color(0xFF161B22),
                            labelStyle: const TextStyle(color: Color(0xFF00D2FF)),
                            onPressed: () {
                              _promptController.text = 'Crie uma documentação inicial para as principais funções do projeto.';
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF1F6FEB) : const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: isUser ? null : Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: Text(
                          msg['content'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isAgentStreaming)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D2FF))),
                SizedBox(width: 12),
                Text('Agente pensando e executando...', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            border: Border(top: BorderSide(color: Color(0xFF30363D))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promptController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'O que o agente deve programar hoje?',
                    hintStyle: TextStyle(color: Color(0xFF8B949E)),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendAgentPrompt(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF00D2FF)),
                onPressed: _sendAgentPrompt,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. ABA DO EDITOR DE CÓDIGO
  Widget _buildEditorTab() {
    return Column(
      children: [
        // Seletor de Arquivos
        Container(
          height: 48,
          color: const Color(0xFF161B22),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: _fileList.length,
            itemBuilder: (context, index) {
              final file = _fileList[index];
              final isSelected = file == _currentFilePath;
              return Container(
                margin: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(file, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF00D2FF),
                  backgroundColor: const Color(0xFF21262D),
                  onSelected: (selected) {
                    if (selected && !file.endsWith('/')) {
                      ws.readFile(file);
                    }
                  },
                ),
              );
            },
          ),
        ),
        // Área de Edição
        Expanded(
          child: TextField(
            controller: _codeController,
            maxLines: null,
            expands: true,
            style: const TextStyle(
              color: Color(0xFFE6EDF3),
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
              fillColor: Color(0xFF0D1117),
              filled: true,
            ),
          ),
        ),
        // Barra de atalhos rápidos touch para código
        Container(
          height: 42,
          color: const Color(0xFF161B22),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _keyShortcut('{'),
              _keyShortcut('}'),
              _keyShortcut('('),
              _keyShortcut(')'),
              _keyShortcut(';'),
              _keyShortcut('Tab', insertText: '  '),
              _keyShortcut('//'),
              _keyShortcut('=>'),
              _keyShortcut('='),
              _keyShortcut('"'),
              IconButton(
                icon: const Icon(Icons.save, color: Color(0xFF00D2FF), size: 20),
                onPressed: _saveCurrentFile,
                tooltip: 'Salvar Arquivo',
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _keyShortcut(String label, {String? insertText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: const BorderSide(color: Color(0xFF30363D)),
          backgroundColor: const Color(0xFF21262D),
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          final toInsert = insertText ?? label;
          final currentText = _codeController.text;
          final selection = _codeController.selection;
          final newText = currentText.replaceRange(selection.start, selection.end, toInsert);
          _codeController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start + toInsert.length),
          );
        },
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // 3. ABA DO GIT
  Widget _buildGitTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const Row(
              children: [
                Icon(Icons.call_split, color: Color(0xFF00D2FF)),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branch Atual', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                    Text('main', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ws.runCommand('git status');
              setState(() => _currentTabIndex = 3);
            },
            icon: const Icon(Icons.sync),
            label: const Text('VERIFICAR STATUS DO GIT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF21262D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              ws.runCommand('git pull');
              setState(() => _currentTabIndex = 3);
            },
            icon: const Icon(Icons.cloud_download),
            label: const Text('PULL DO GITHUB'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF21262D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  // 4. ABA DO TERMINAL
  Widget _buildTerminalTab() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF0D1117),
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              itemCount: _terminalLogs.length,
              itemBuilder: (context, index) {
                return Text(
                  _terminalLogs[index],
                  style: const TextStyle(
                    color: Color(0xFF58A6FF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
        Container(
          color: const Color(0xFF161B22),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('\$ ', style: TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.bold)),
              Expanded(
                child: TextField(
                  controller: _terminalInputController,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText: 'Digite um comando (ex: git status, cargo check)...',
                    hintStyle: TextStyle(color: Color(0xFF8B949E)),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _runTerminalCommand(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Color(0xFF00D2FF)),
                onPressed: _runTerminalCommand,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

