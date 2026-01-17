# VR Training AI Server

**Version:** 3.2.0  
**Date:** January 15, 2026  
**Status:** Production Ready

---

## 📋 Overview

AI-powered manual assistant for VR training with Meta Quest 3. Completely offline after initial setup.

### Key Features

- ✅ **100% Offline** after setup
- ✅ **Voice Queries** via Quest 3 microphone  
- ✅ **Natural Language** Q&A from PDF manuals
- ✅ **Page Citations** in responses
- ✅ **GUI Launcher** with progress tracking
- ✅ **Auto-Installer** for Windows

### Architecture

```
Quest 3 (Client) ←→ WiFi ←→ Windows PC (Server)
                                ↓
                    Python + Flask + Ollama + ChromaDB
```

---

## 🚀 Quick Start

### Requirements

- Windows 10/11
- 8GB RAM (16GB recommended)
- 5GB free disk space
- Administrator privileges
- Internet (initial setup only)

### Installation (5 minutes)

1. **Run the installer:**
   - Right-click `installer.iss` → Compile with Inno Setup
   - OR: Run the compiled installer `.exe`

2. **Wait for:**
   - Python 3.11+ installation
   - Ollama + llama3.2:3b model (~2GB)
   - Python dependencies
   - Firewall configuration

3. **Launch:**
   - Desktop shortcut: "TRAINING AI SERVER"
   - Or: `C:\Program Files\TRAINING AI SERVER\start_server.bat`

---

## 📁 Installation Structure

```
C:\Program Files\TRAINING AI SERVER\
├── server\
│   ├── offline_server.py      # Main Flask server (v3.0)
│   ├── launcher.py             # GUI launcher (v5.0 with logo)
│   ├── logo.png                # Application logo (60x60)
│   ├── requirements.txt        # Python dependencies
│   └── chroma_db\             # Vector DB (auto-created in AppData)
├── installer\
│   ├── smart_installer.bat    # Automated installer
│   ├── installer_lib.bat      # Installation functions
│   └── uninstaller_cleanup.bat
├── start_server.bat            # Server launcher with auto-Ollama
├── logs\                       # Installation/error logs
└── manuals\                    # Place PDFs here
```

**User Data Location:**
```
C:\Users\[User]\AppData\Local\TRAINING AI SERVER\
└── chroma_db\                  # Database with write permissions
```

---

## 🎨 GUI Launcher Features

### v5.0 Features:
- ✅ **Professional Logo** (VR headset + AI design)
- ✅ **Visual Progress Bar** for indexing
- ✅ **Real-time Log** viewer
- ✅ **Server Controls** (Start/Stop/Test)
- ✅ **Manual Selection** with browse dialog
- ✅ **Status Display** (IP, model, chunks)

### Using the Launcher:

1. **Start Server:** Click "▶ Start Server"
2. **Index Manual:** Browse PDF → "📊 Index Manual"
3. **Monitor Progress:** Visual bar shows 0-100%
4. **View Logs:** Real-time server output
5. **Test Connection:** "Test Connection" button
6. **Stop Server:** "⏹ Stop Server"

---

## 📚 Indexing Manuals

### Requirements:
- PDF format with selectable text
- Recommended: < 500 pages, < 50MB
- First indexing: 10-15 minutes (downloads model)
- Subsequent: 5-10 minutes

### Progress Phases:
1. **5-10%** - Loading PDF
2. **10-50%** - Processing pages
3. **50-55%** - Creating chunks
4. **55-75%** - Downloading ONNX model (first time only)
5. **75-95%** - Generating embeddings
6. **100%** - Complete!

### Via API:
```cmd
curl -X POST http://localhost:5000/index ^
  -H "Content-Type: application/json" ^
  -d "{\"pdf_path\": \"C:/path/to/manual.pdf\"}"
```

---

## 🌐 Network Setup

### Find Your IP:
The launcher shows it automatically in "Server IP" field.

Or check manually:
```cmd
ipconfig | findstr IPv4
```

### Configure Firewall:
Done automatically during installation. Port 5000 TCP is opened.

### Verify from Quest 3:
Connect Quest 3 to same WiFi, then test:
```
http://[YOUR_IP]:5000/health
```

---

## 🧪 Testing

### Health Check:
```cmd
curl http://localhost:5000/health
```

Expected response:
```json
{
  "status": "healthy",
  "whisper_loaded": true,
  "ollama_model": "llama3.2:3b",
  "indexed_chunks": 969,
  "server_ip": "192.168.1.69"
}
```

### Query Test:
```cmd
curl -X POST http://localhost:5000/query ^
  -H "Content-Type: application/json" ^
  -d "{\"query\": \"How do I reset the device?\"}"
```

---

## 📊 API Endpoints

### GET /health
Returns server status and configuration.

### GET /test
Simple "server is running" message.

### POST /index
Index a PDF manual.
```json
{
  "pdf_path": "C:/path/to/manual.pdf"
}
```

### POST /query
Text query against indexed manual.
```json
{
  "query": "How do I perform maintenance?"
}
```

### POST /query_audio
Voice query (WAV file).
- Multipart form with `audio` field

---

## 🔧 Troubleshooting

### Server Won't Start

**Ollama not running:**
```cmd
ollama serve
```
Or use `start_server_with_ollama.bat` (auto-starts Ollama)

**Port 5000 in use:**
```cmd
netstat -ano | findstr :5000
taskkill /PID [PID] /F
```

**Missing dependencies:**
```cmd
pip install -r requirements.txt --break-system-packages
```

### ChromaDB Errors

**"readonly database" error:**
- Fixed in v3.0 - ChromaDB now uses AppData with write permissions
- Delete: `%LOCALAPPDATA%\TRAINING AI SERVER\chroma_db`
- Restart server (auto-recreates)

### Indexing Timeout

**Timeout after 5 minutes:**
- Use launcher v3+ (15 minute timeout)
- Or index via API with longer timeout

**Stuck at 55-75%:**
- Normal - downloading ONNX model (~79MB)
- Only happens first time
- Wait 2-5 minutes

### Connection Issues

**Quest can't reach server:**
1. Same WiFi network?
2. Firewall rule exists? (check Windows Firewall)
3. Server running? (check launcher)
4. Correct IP? (shown in launcher)

---

## 🗑️ Uninstallation

Run the Windows uninstaller from "Add/Remove Programs"

Or manually:
```cmd
cd "C:\Program Files\TRAINING AI SERVER\installer"
uninstaller_cleanup.bat
```

**Removes:**
- Application files
- Desktop shortcut
- Firewall rules
- Start menu entries

**Keeps:**
- User data in AppData (optional cleanup)
- Ollama installation (optional)
- Python installation (optional)

---

## 🔐 Security

- **Local Network Only** - No internet exposure
- **No Authentication** - Assumes trusted local network
- **Firewall Protected** - Only port 5000 on local network
- **Privacy Preserved** - All processing local

---

## 📝 Version History

### v3.2.0 (January 2026)
- ✅ GUI launcher v5 with logo
- ✅ Visual progress bar for indexing
- ✅ ChromaDB in AppData (fixes permissions)
- ✅ Ollama ListResponse support
- ✅ UTF-8 encoding fixes
- ✅ Optimized layout and spacing
- ✅ Auto-start Ollama option
- ✅ 15-minute indexing timeout

### v3.1.0 (January 2026)
- ✅ Inno Setup installer
- ✅ Smart installer with auto-detection
- ✅ Desktop shortcut creation
- ✅ Firewall auto-configuration

### v3.0.0 (January 2026)
- ✅ Unicode-safe server
- ✅ GUI launcher
- ✅ Requirements with precompiled wheels
- ✅ Robust error handling

---

## 📦 Dependencies

### Python Packages:
```
flask==3.1.0
flask-cors==5.0.0
ollama==0.4.4
chromadb==0.5.23
faster-whisper==1.0.3
PyPDF2==3.0.1
colorama==0.4.6
requests==2.32.3
```

### System:
- **Python:** 3.11+ (auto-installed)
- **Ollama:** Latest (auto-installed)
- **Model:** llama3.2:3b (~2GB)
- **RAM:** 8GB min, 16GB recommended
- **Storage:** 5GB free

---

## 🎯 Performance

### Expected Times:
- Health check: < 1 second
- First query: 5-15 seconds (model loading)
- Subsequent queries: 3-8 seconds
- PDF indexing (first time): 10-15 minutes
- PDF indexing (subsequent): 5-10 minutes

### Optimization:
1. Use SSD for database
2. Close unnecessary programs
3. Use wired connection if possible
4. Keep PDFs under 500 pages

---

## 📞 Support

### Logs Location:
- Installation: `C:\Program Files\TRAINING AI SERVER\logs\installation_*.log`
- Server: Launcher log window or console output
- ChromaDB: `%LOCALAPPDATA%\TRAINING AI SERVER\chroma_db\chroma.log`

### Documentation:
- This README
- Installation Manual (DOCX)
- User Manual (DOCX)

---

**Version:** 3.2.0  
**Last Updated:** January 15, 2026  
**Status:** Production Ready
