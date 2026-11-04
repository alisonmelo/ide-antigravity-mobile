/**
 * Antigravity Mobile Orbit - Dev / Mock Daemon (Node.js)
 * Permite testar o protocolo WebSocket e o pareamento imediatamente no seu PC!
 */

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const PORT = process.env.PORT || 3000;
const SESSION_TOKEN = crypto.randomUUID();

// Identificar IP local básico
const os = require('os');
const networkInterfaces = os.networkInterfaces();
let localIp = '127.0.0.1';
for (const iface of Object.values(networkInterfaces)) {
    for (const config of iface) {
        if (config.family === 'IPv4' && !config.internal) {
            localIp = config.address;
            break;
        }
    }
}

const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
            status: 'online',
            service: 'Antigravity Mobile Orbit (Dev Mode)',
            version: '0.1.0'
        }));
    }
    res.writeHead(404);
    res.end();
});

// Implementação simples de WebSocket RFC 6455
server.on('upgrade', (req, socket, head) => {
    if (req.url !== '/ws') {
        socket.destroy();
        return;
    }

    const key = req.headers['sec-websocket-key'];
    const acceptKey = crypto
        .createHash('sha1')
        .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
        .digest('base64');

    const responseHeaders = [
        'HTTP/1.1 101 Switching Protocols',
        'Upgrade: websocket',
        'Connection: Upgrade',
        `Sec-WebSocket-Accept: ${acceptKey}`
    ];

    socket.write(responseHeaders.join('\r\n') + '\r\n\r\n');

    let authenticated = false;

    socket.on('data', (buffer) => {
        // Decodificação básica de frames WebSocket
        const length = buffer[1] & 127;
        let maskStart = 2;
        if (length === 126) maskStart = 4;
        else if (length === 127) maskStart = 10;

        const masks = buffer.slice(maskStart, maskStart + 4);
        const dataStart = maskStart + 4;
        const payload = buffer.slice(dataStart);
        const unmasked = Buffer.alloc(payload.length);
        for (let i = 0; i < payload.length; i++) {
            unmasked[i] = payload[i] ^ masks[i % 4];
        }

        try {
            const msg = JSON.parse(unmasked.toString('utf8'));
            handleClientMessage(socket, msg);
        } catch (e) {
            // Ignorar frames de controle
        }
    });

    function sendWs(data) {
        const json = JSON.stringify(data);
        const payload = Buffer.from(json);
        const length = payload.length;
        let header;
        if (length < 126) {
            header = Buffer.from([0x81, length]);
        } else if (length <= 65535) {
            header = Buffer.alloc(4);
            header[0] = 0x81;
            header[1] = 126;
            header.writeUInt16BE(length, 2);
        }
        socket.write(Buffer.concat([header, payload]));
    }

    function handleClientMessage(socket, msg) {
        if (msg.type === 'auth') {
            if (msg.token === SESSION_TOKEN) {
                authenticated = true;
                console.log('✅ Cliente Mobile conectado e autenticado!');
                sendWs({ type: 'auth_ok' });
            } else {
                sendWs({ type: 'error', message: 'Token de segurança incorreto' });
            }
            return;
        }

        if (!authenticated) {
            return sendWs({ type: 'error', message: 'Não autenticado' });
        }

        if (msg.type === 'list_files') {
            const root = path.resolve('.');
            fs.readdir(root, (err, files) => {
                if (err) return sendWs({ type: 'error', message: err.message });
                sendWs({ type: 'files', path: '', entries: files });
            });
        } else if (msg.type === 'read_file') {
            fs.readFile(msg.path, 'utf8', (err, data) => {
                if (err) return sendWs({ type: 'error', message: err.message });
                sendWs({ type: 'file_content', path: msg.path, content: data });
            });
        } else if (msg.type === 'run_command') {
            exec(msg.command, (error, stdout, stderr) => {
                sendWs({ type: 'command_output', output: stdout || stderr || 'Comando executado sem retorno.' });
            });
        } else if (msg.type === 'prompt') {
            sendWs({
                type: 'stream',
                content: `🛰️ [Antigravity Daemon Dev] Recebi sua instrução: "${msg.content}". O orquestrador em Rust conectará diretamente à API do Gemini.`
            });
        }
    }
});

server.listen(PORT, () => {
    console.log('============================================================');
    console.log('  🛰️  Antigravity Mobile Orbit - Host Daemon (Dev)');
    console.log('============================================================');
    console.log(`\nServidor ativo em: http://${localIp}:${PORT}`);
    console.log(`WebSocket URL:     ws://${localIp}:${PORT}/ws`);
    console.log(`Token da Sessão:   ${SESSION_TOKEN}`);
    console.log('\nJSON para colar no App Mobile:');
    console.log(JSON.stringify({
        app: 'antigravity-orbit',
        host: localIp,
        port: PORT,
        token: SESSION_TOKEN
    }, null, 2));
    console.log('\nPronto para receber conexões do Flutter!');
});

