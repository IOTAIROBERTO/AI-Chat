# VR Training AI Server

**Version:** 6.2  
**Status:** Production Ready  
**Platform:** Windows 10/11 — 100% Offline after setup

An AI-powered manual assistant for VR training with Meta Quest 3. Ask questions in natural language (text or voice) about indexed PDF manuals and receive cited answers — all running locally with no internet connection required.

---

## Table of Contents

- [Overview](#overview)
- [Technology Stack](#technology-stack)
- [Architecture & Pipeline](#architecture--pipeline)
- [Requirements](#requirements)
- [Installation](#installation)
- [File Structure](#file-structure)
- [GUI Server — Sections & Modules](#gui-server--sections--modules)
- [HTML Tester](#html-tester)
- [API Reference](#api-reference)
- [Configuration](#configuration)
- [Performance](#performance)
- [Troubleshooting](#troubleshooting)

---

## Overview

```
Meta Quest 3 (Client)  ←→  WiFi  ←→  Windows PC (Server)
                                           |
                           Python · Flask · Ollama · ChromaDB
                                      Faster-Whisper
```

**Key capabilities:**

- 100% offline operation after initial setup
- Voice queries via Quest 3 microphone (auto language detection)
- Bilingual support: Spanish and English in the same session
- Natural language Q&A sourced from indexed PDF manuals
- Page-level citations in every answer
- GUI launcher with real-time progress tracking
- Web-based admin/debug panel (`AI_Server_Tester.html`)
- Hot-swappable LLM models without restarting the server

---

## Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Web framework | Flask + Flask-CORS | 3.1.0 / 5.0.0 |
| LLM inference | Ollama | 0.4.4 |
| Default model | Qwen2.5:1.5b (bilingual) | — |
| Speech-to-text | Faster-Whisper | 1.0.3 | Whisper Medium
| Vector database | ChromaDB | 0.5.23 |
| PDF parsing | PyPDF2 | 3.0.1 |
| GUI | Tkinter (built-in Python) | — |
| SSL/TLS | Cryptography | 45.0.0 |
| HTTP client | Requests | 2.32.3 |
| Terminal colors | Colorama | 0.4.6 |
| Runtime | Python | 3.11+ |

### Available LLM Models

| Model | Size | Best for |
|-------|------|----------|
| `qwen2.5:1.5b` | ~1 GB | Default · fast · bilingual ES/EN |
| `qwen2.5:3b` | ~2 GB | Higher quality answers |
| `qwen2.5:7b` | ~4.7 GB | Best quality, needs more RAM |
| `granite3.1-dense:2b` | ~1.5 GB | RAG-optimized retrieval |
| `gemma2:2b` | ~1.6 GB | Balanced general use |

---

## Architecture & Pipeline

### Text Query Flow

```
Client  ──POST /query──►  Flask Server
                               │
                         ChromaDB (semantic search)
                         Top 7 most similar chunks
                               │
                         Prompt engineering
                               │
                         Ollama · Qwen2.5
                               │
                         Response + citations
                         (manual name + page)
```

### Voice Query Flow

```
Client  ──POST /query_audio──►  Flask Server
                                     │
                               Faster-Whisper (STT)
                               Auto language detection
                                     │
                               ChromaDB (Top 3 chunks)
                                     │
                               Ollama · Qwen2.5
                                     │
                               Response includes:
                               transcription · answer
                               sources · timing (ms)
```

### PDF Indexing Flow

```
PDF file  ──POST /index──►  Flask Server
                                 │
                           PyPDF2 text extraction
                                 │
                           Chunking (1000 chars, 200 overlap)
                           Metadata: manual_name · page · hash
                                 │
                           ChromaDB embedding + storage
                           (duplicate detection by name + hash)
                                 │
                           Indexed chunks ready for RAG
```

---

## Requirements

**Hardware:**
- Windows 10/11 PC on the same WiFi as Quest 3
- 8 GB RAM minimum (16 GB recommended)
- 5 GB free disk space

**Software (auto-installed by the installer):**
- Python 3.11+
- Ollama (latest)
- All Python dependencies from `requirements.txt`

**Network:**
- Server PC and Quest 3 must be on the same local WiFi
- Port 5000 TCP — opened automatically by the installer

---

## Installation

### Option A — Compiled Installer (recommended)

1. Run the `.exe` installer as Administrator
2. The installer handles: Python, Ollama, model download, dependencies, firewall rules
3. Launch from the Desktop shortcut **TRAINING AI SERVER**

### Option B — Manual Setup

```bash
# 1. Install Python 3.11+  and Ollama, then:
cd "C:\Program Files (x86)\TRAINING AI SERVER\server"

# 2. Install dependencies
pip install -r requirements.txt

# 3. Start Ollama (in a separate terminal)
ollama serve

# 4. Pull the default model
ollama pull qwen2.5:1.5b

# 5. Launch the GUI
python launcher.py
```

---

## File Structure

```
C:\Program Files (x86)\TRAINING AI SERVER\server\
├── offline_server.py       # Flask backend — RAG engine
├── launcher.py             # Tkinter GUI launcher (v6.2)
├── AI_Server_Tester.html   # Web-based admin/debug panel
├── requirements.txt        # Python dependencies
├── server_config.json      # Runtime config (model, bilingual mode)
├── server.crt / server.key # Auto-generated SSL certificates
├── chroma_db/              # ChromaDB vector store (persistent)
├── logs/                   # Server console logs
├── uploads/                # Temporary uploaded PDFs
└── whisper_cache/          # Faster-Whisper model cache

User data:
%LOCALAPPDATA%\TRAINING AI SERVER\chroma_db\   # Write-safe database location
```

---

## GUI Server — Sections & Modules

The GUI launcher (`launcher.py`) is the main control panel for the server. It is divided into six functional sections:

### 1. AI Models

Manage which LLM Ollama uses for inference.

- **Active model display** — shows the currently loaded model with bilingual quality scores (ES / EN %)
- **Model dropdown** — switch between already-downloaded models instantly (hot-swap, no restart)
- **Download** — pull a new model from Ollama's registry with a live progress bar and percentage
- **Delete** — remove a model from disk to free space
- **Info button** — opens a description card with performance specs for each model

### 2. Server Status

Start, stop, and monitor the Flask server process.

- **Status indicator** — colored dot: green = Running, red = Stopped
- **IP & Port display** — shows the local network address clients should connect to
- **Start Server** — launches `offline_server.py` as a subprocess; retries automatically on failure
- **Stop Server** — terminates the server process cleanly
- **Health Check** — sends `GET /health` and displays the JSON response inline

### 3. PDF Manual Indexing

Add new knowledge to the vector database.

- **Browse** — file picker dialog filtered to `.pdf` files
- **Index** — sends the selected PDF to `/index`; the server extracts text, chunks it, and stores embeddings in ChromaDB
- **Progress bar** — updates 0 → 100% through extraction, chunking, and embedding phases
- **Duplicate detection** — the server rejects files already indexed by filename or file hash

### 4. Manuals Browser

Inspect and manage the knowledge base.

- **Indexed manuals list** — shows every manual name along with its chunk count and indexing date
- **Right-click context menu** — delete a manual and all its chunks from ChromaDB
- **Auto-refresh** — list reloads automatically after a new manual is indexed

### 5. Real-time Log Viewer

Monitor server output without opening a terminal.

- **Scrollable log window** — tails `server_console.log` in real time
- **Color-coded messages** — INFO (white), SUCCESS (green), WARNING (yellow), ERROR (red)
- **Save logs** — writes the current log buffer to a `.txt` file
- **Clear logs** — resets the log display

### 6. Model Download Progress

Dedicated progress area shown during model downloads.

- **Progress bar** — reflects Ollama's streaming download percentage
- **Status label** — shows current download speed / phase
- **Auto-activation** — the new model is set as active automatically when the download completes

---

## HTML Tester

`AI_Server_Tester.html` is a standalone admin panel for testing the server from any browser on the same network. Open it directly — no web server needed.

### Connection Setup (left panel)

1. Toggle the **Protocol** switch to HTTP or HTTPS depending on your server config
2. Enter the server **IP address** (shown in the GUI launcher) and **Port** (default 5000)
3. Click **Connect / Health Check** — a green banner confirms a successful connection
4. If using HTTPS with a self-signed certificate, the browser will show a security warning; accept the exception once

### Server Health Dashboard

After connecting, the dashboard shows live data:

| Field | Description |
|-------|-------------|
| Server Status | healthy / unreachable |
| Whisper STT | loaded / not loaded |
| Current Model | active Ollama model |
| Indexed Chunks | total document chunks in ChromaDB |
| Latency | round-trip time in ms |
| Bilingual Mode | enabled / disabled |

### Indexed Manuals List

Displays all manuals currently in the database with chunk counts. Click **Refresh** to reload.

### Query Interface (right panel)

**Text tab:**
1. Type your question in the input field
2. Optionally select a specific manual from the dropdown to narrow the search
3. Click **Send** — the answer appears below with source citations (manual + page number)

**Audio tab:**
1. Click the microphone button and hold to record
2. The timer and file-size indicator update in real time
3. Release to stop recording and send — the panel shows the transcription alongside the answer

### Request Monitoring

While a query is processing:

- A live timer counts elapsed seconds
- The processing phase label updates (retrieving → generating → done)
- An animated progress bar provides visual feedback
- The final latency badge shows the total server response time

### Console Log Viewer

The bottom panel mirrors the server's log stream:

- Entries are color-coded by level: INFO (blue), OK (green), WARN (orange), ERROR (red), DATA (cyan)
- Each entry includes a timestamp
- Filter buttons let you show only specific log levels
- The panel auto-scrolls to the latest entry

---

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server status, model, chunk count, IP |
| GET | `/models` | Current model + list of available models |
| POST | `/switch_model` | Change active LLM: `{"model": "qwen2.5:3b"}` |
| GET | `/manuals` | All indexed manuals with metadata |
| POST | `/check_manual` | Validate a PDF before indexing (duplicate check) |
| POST | `/index` | Index a PDF: `{"pdf_path": "C:/path/to/file.pdf"}` |
| DELETE | `/delete_manual/<filename>` | Remove a manual by filename |
| DELETE | `/manual/<manual_name>` | Remove a manual by display name |
| POST | `/index/batch` | Index multiple PDFs at once |
| GET | `/index/status/<task_id>` | Poll batch indexing progress |
| POST | `/clear_all` | Wipe the entire ChromaDB collection |
| POST | `/query` | Text RAG query: `{"query": "...", "manual_name": "optional"}` |
| POST | `/query_audio` | Voice query — multipart form with `audio` field (WAV/MP3) |
| GET | `/admin` | Serve the built-in admin HTML panel |

### Example — Text Query

```bash
curl -X POST http://192.168.1.100:5000/query \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I reset the device?", "manual_name": "AMX_MAINTENANCE"}'
```

Response:
```json
{
  "answer": "To reset the device, hold the power button for 10 seconds...",
  "sources": [{"manual": "AMX_MAINTENANCE", "page": 42}],
  "model": "qwen2.5:1.5b",
  "latency_ms": 3240
}
```

### Example — Health Check

```bash
curl http://192.168.1.100:5000/health
```

Response:
```json
{
  "status": "healthy",
  "whisper_loaded": true,
  "ollama_model": "qwen2.5:1.5b",
  "indexed_chunks": 4821,
  "server_ip": "192.168.1.100",
  "bilingual_mode": true
}
```

---

## Configuration

`server_config.json` — written by the launcher, read by the server on startup:

```json
{
  "current_model": "qwen2.5:1.5b",
  "last_updated": "2026-04-07T20:16:47.147606",
  "bilingual_mode": true,
  "supported_languages": ["es", "en"]
}
```

**Key server parameters (inside `offline_server.py`):**

| Parameter | Default | Description |
|-----------|---------|-------------|
| RAG top-k (text) | 7 | Chunks retrieved per text query |
| RAG top-k (audio) | 3 | Chunks retrieved per voice query |
| Chunk size | 1000 chars | Characters per document chunk |
| Chunk overlap | 200 chars | Overlap between consecutive chunks |
| LLM temperature | 0.2 | Lower = more deterministic answers |
| Context window | 4096 tokens | Maximum tokens sent to Ollama |
| Max file size | 100 MB | Largest PDF accepted |
| Max pages | 1000 | Page limit per PDF |

### Prompt Configuration

Both `/query` (text) and `/query_audio` (voice) use the same prompt template:

```
Answer ONLY using the manual context below. Maximum 2-3 sentences.
Never start with intro phrases like "Based on...", "According to...",
"What I found...", "Here is...", "This is..." or similar.
Just state the fact directly. End with: Source: [Manual], page [number].
Respond in the user's language.
```

**Design goals:**
- **Concise** — hard cap of 2-3 sentences per answer
- **No preamble** — model must start directly with the fact, not a meta-sentence
- **Citations always included** — source manual and page number at the end of every answer
- **Context-only** — model is forbidden from using knowledge outside the indexed manuals
- **Bilingual** — responds in the same language the user asked (Spanish or English)

To adjust verbosity, change the sentence cap in the prompt string inside `offline_server.py` (same line appears in both `query_text()` and `query_audio()`).

---

## Performance

| Operation | Expected time |
|-----------|--------------|
| Health check | < 1 second |
| First query (model cold start) | 5 – 15 seconds |
| Subsequent queries | 3 – 8 seconds |
| PDF indexing (500 pages) | 5 – 15 minutes |
| First-time ONNX model download | 2 – 5 minutes (one-off) |

**Tips:**
- Use an SSD for the ChromaDB path
- Keep PDFs under 500 pages for best indexing speed
- 16 GB RAM allows the 3b/7b models to run comfortably
- Wired Ethernet between server and router reduces query latency

---

## Troubleshooting

### Server won't start

```bash
# Check if Ollama is running
ollama serve

# Check if port 5000 is already in use
netstat -ano | findstr :5000
# Kill the conflicting process
taskkill /PID <PID> /F
```

### Quest 3 can't reach the server

1. Confirm both devices are on the same WiFi network
2. Check the IP shown in the launcher matches what you type in the Quest browser
3. Verify the firewall rule: Windows Defender Firewall → Inbound Rules → look for port 5000
4. Test from the same PC first: `http://localhost:5000/health`

### Indexing stuck at 55–75%

This is normal on first run — the ONNX embedding model (~79 MB) is downloading. Wait 2–5 minutes. This only happens once.

### ChromaDB "readonly database" error

```bash
# Delete the stale database; it will be recreated on next start
rmdir /S /Q "%LOCALAPPDATA%\TRAINING AI SERVER\chroma_db"
```

### Missing Python dependencies

```bash
cd "C:\Program Files (x86)\TRAINING AI SERVER\server"
pip install -r requirements.txt
```

### HTTPS certificate warning in browser

The server uses a self-signed certificate. In Chrome/Edge click **Advanced → Proceed**. In the HTML tester, click through the SSL warning banner once per session.

---

## Security Notes

- **Local network only** — the server binds to `0.0.0.0:5000` but is firewalled to the local subnet
- **No authentication** — assumes a trusted private network (office/training facility WiFi)
- **All processing is local** — no data leaves the machine after initial model downloads
- **HTTPS optional** — SSL certificates are auto-generated; HTTP is also supported for development

---

## Logs

| Log | Location |
|-----|----------|
| Server console | GUI launcher log viewer, or `logs/server_console.log` |
| ChromaDB | `%LOCALAPPDATA%\TRAINING AI SERVER\chroma_db\chroma.log` |
| Installation | `C:\Program Files (x86)\TRAINING AI SERVER\logs\installation_*.log` |
