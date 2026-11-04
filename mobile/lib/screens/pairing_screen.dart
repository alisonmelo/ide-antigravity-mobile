import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/websocket_service.dart';
import 'ide_shell.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _portController = TextEditingController(text: '3000');
  final _tokenController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
    WebSocketService().statusStream.listen((status) {
      if (!mounted) return;
      if (status == ConnectionStatus.connected) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => IdeShellScreen(geminiApiKey: _geminiKeyController.text)),
        );
      } else if (status == ConnectionStatus.error) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao conectar. Verifique o IP, porta e token do Daemon.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostController.text = prefs.getString('saved_host') ?? '127.0.0.1';
      _portController.text = prefs.getString('saved_port') ?? '3000';
      _tokenController.text = prefs.getString('saved_token') ?? '';
      _geminiKeyController.text = prefs.getString('saved_gemini_key') ?? '';
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_host', _hostController.text);
    await prefs.setString('saved_port', _portController.text);
    await prefs.setString('saved_token', _tokenController.text);
    await prefs.setString('saved_gemini_key', _geminiKeyController.text);
  }

  void _handleConnect() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 3000;
    final token = _tokenController.text.trim();

    if (host.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o Host e o Token de Segurança.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    _saveConfig();
    WebSocketService().connect(host: host, port: port, token: token);
  }

  void _parseQrPayload(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data.containsKey('host') && data.containsKey('token')) {
        setState(() {
          _hostController.text = data['host'].toString();
          _portController.text = (data['port'] ?? 3000).toString();
          _tokenController.text = data['token'].toString();
        });
        _handleConnect();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato de QR Code inválido')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.satellite_alt, color: Color(0xFF00D2FF)),
            SizedBox(width: 8),
            Text(
              'Antigravity Mobile Orbit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🛰️ Conectar ao PC ou VPS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Inicie o "agy-daemon" no seu computador para gerar o QR Code ou insira os dados de conexão manualmente abaixo.',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _hostController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Host / IP do Servidor', Icons.dns),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Porta', Icons.numbers),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Token de Segurança (UUID)', Icons.key),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _geminiKeyController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Chave Google Gemini API (Opcional/Grátis)', Icons.smart_toy),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D2FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'CONECTAR AO HOST',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Simulação de leitura de QR code ou diálogo para colar JSON
                _showPasteDialog();
              },
              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00D2FF)),
              label: const Text('LER QR CODE / COLAR JSON', style: TextStyle(color: Color(0xFF00D2FF))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00D2FF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasteDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Colar Dados do QR Code', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Cole o JSON gerado no terminal...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _parseQrPayload(textController.text.trim());
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8B949E)),
      prefixIcon: Icon(icon, color: const Color(0xFF00D2FF)),
      filled: true,
      fillColor: const Color(0xFF161B22),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

