#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VR Manual Server - Bilingual Edition (Spanish/English)
Version: 5.0 - phi4-mini default, smart SSL, auto-model fallback
"""

import sys
import os
import json
import tempfile
import time
import threading
import hashlib
from datetime import datetime
from pathlib import Path
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS  
import shutil 

# Windows console encoding fix
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except (AttributeError, OSError):
        import codecs
        sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'replace')
        sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'replace')
    
    try:
        os.system('chcp 65001 > nul 2>&1')
    except Exception:
        pass

app = Flask(__name__)
CORS(app)

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

whisper_model = None
chroma_client = None
collection = None
server_start_time = None

# Multi-manual tracking
indexed_manuals = {}
indexing_queue = []
indexing_status = {}

# Multi-model support (BILINGUAL ONLY)
current_ollama_model = None
available_models = []
model_lock = threading.Lock()

# Configuration
WHISPER_MODEL_SIZE = "medium"         # medium=769M — best Spanish accuracy (primary language)
WHISPER_LANGUAGE = None               # None = auto-detect (Spanish primary, English secondary)
WHISPER_DEVICE = "auto"              # auto = CUDA if available, else CPU
WHISPER_COMPUTE_TYPE = "auto"         # auto = float16 on GPU, int8 on CPU
DEFAULT_OLLAMA_MODEL = "phi4-mini"    # phi4-mini: exceptional document Q&A, bilingual ES/EN
USE_SSL = True                        # HTTPS required for Meta Quest WebXR
SERVER_PORT = 5000
CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200

# Performance limits
MAX_FILE_SIZE_MB = 100
MAX_PAGES_PER_FILE = 1000
MAX_TOTAL_CHUNKS = 50000

# Config file
CONFIG_FILE = Path(__file__).parent / "server_config.json"

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

def load_config():
    """Load server configuration including current model"""
    global current_ollama_model
    
    try:
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE, 'r') as f:
                config = json.load(f)
                current_ollama_model = config.get('current_model', DEFAULT_OLLAMA_MODEL)
                log_message(f"Loaded config: model = {current_ollama_model}")
        else:
            current_ollama_model = DEFAULT_OLLAMA_MODEL
            save_config()
    except Exception as e:
        log_message(f"Error loading config: {e}, using default", "WARN")
        current_ollama_model = DEFAULT_OLLAMA_MODEL

def save_config():
    """Save current configuration"""
    try:
        config = {
            'current_model': current_ollama_model,
            'last_updated': datetime.now().isoformat(),
            'bilingual_mode': True,
            'supported_languages': ['es', 'en']
        }
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
    except Exception as e:
        log_message(f"Error saving config: {e}", "WARN")

def get_available_models():
    """Get list of available Ollama models"""
    global available_models
    
    try:
        import ollama
        response = ollama.list()
        
        models = []
        if hasattr(response, 'models'):
            models = response.models
        elif isinstance(response, dict):
            models = response.get('models', [])
            
        available_models = []
        for m in models:
            if hasattr(m, 'model'):
                available_models.append(m.model)
            elif isinstance(m, dict):
                # Try 'model' first, then 'name' (older versions)
                available_models.append(m.get('model') or m.get('name'))
                
        # Filter out None values
        available_models = [m for m in available_models if m]
        
        return available_models
    except Exception as e:
        log_message(f"Error getting models: {e}", "WARN")
        return []

def verify_model_available(model_name):
    """Check if a model is available"""
    models = get_available_models()
    return model_name in models

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def get_timestamp():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def log_message(msg, level="INFO"):
    timestamp = get_timestamp()
    safe_print(f"[{timestamp}] [{level}] {msg}")

def safe_print(text):
    try:
        safe_text = str(text).encode('ascii', errors='replace').decode('ascii')
        print(safe_text)
    except Exception:
        print(repr(text))

def get_file_size_mb(filepath):
    return Path(filepath).stat().st_size / (1024 * 1024)

def calculate_file_hash(filepath, algorithm='md5'):
    hash_func = hashlib.md5() if algorithm == 'md5' else hashlib.sha256()
    
    try:
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                hash_func.update(chunk)
        return hash_func.hexdigest()
    except Exception as e:
        log_message(f"Error calculating hash: {e}", "ERROR")
        return None

def check_manual_exists(manual_name):
    return manual_name in indexed_manuals

def check_file_hash_exists(file_hash):
    for manual_info in indexed_manuals.values():
        if manual_info.get('file_hash') == file_hash:
            return manual_info.get('manual_name')
    return None

def validate_pdf(filepath, check_duplicates=True):
    if not Path(filepath).exists():
        return False, "File not found", None
    
    if not filepath.lower().endswith('.pdf'):
        return False, "Not a PDF file", None
    
    size_mb = get_file_size_mb(filepath)
    if size_mb > MAX_FILE_SIZE_MB:
        return False, f"File too large ({size_mb:.1f}MB > {MAX_FILE_SIZE_MB}MB)", None
    
    file_hash = None
    manual_name = Path(filepath).stem
    
    if check_duplicates:
        if check_manual_exists(manual_name):
            existing_info = indexed_manuals[manual_name]
            return False, f"Manual '{manual_name}' already indexed", {
                'duplicate_type': 'name',
                'existing_manual': manual_name,
                'indexed_at': existing_info['indexed_at'],
                'pages': existing_info.get('pages', 0),
                'chunks': existing_info.get('chunks', 0)
            }
        
        file_hash = calculate_file_hash(filepath)
        if file_hash:
            existing_manual = check_file_hash_exists(file_hash)
            if existing_manual:
                existing_info = indexed_manuals[existing_manual]
                return False, f"Same file already indexed as '{existing_manual}'", {
                    'duplicate_type': 'hash',
                    'existing_manual': existing_manual,
                    'indexed_at': existing_info['indexed_at'],
                    'file_hash': file_hash,
                    'pages': existing_info.get('pages', 0),
                    'chunks': existing_info.get('chunks', 0)
                }
    
    return True, "Valid", file_hash

# ============================================================================
# INITIALIZATION
# ============================================================================

def check_port_available(port):
    import socket
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) != 0

def _get_all_local_ips():
    """Get all local IP addresses across all network interfaces."""
    import socket
    ips = set()
    ips.add("127.0.0.1")
    # Method 1: hostname resolution
    try:
        hostname = socket.gethostname()
        for info in socket.getaddrinfo(hostname, None, socket.AF_INET):
            ips.add(info[4][0])
    except Exception:
        pass
    # Method 2: connect to external IP to find the default route interface
    for target in ["8.8.8.8", "1.1.1.1"]:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect((target, 80))
            ips.add(s.getsockname()[0])
            s.close()
        except Exception:
            pass
    return ips


def _cert_covers_current_ips(cert_file):
    """Check if existing cert's SANs include all current local IPs."""
    try:
        from cryptography import x509
        import ipaddress
        with open(cert_file, "rb") as f:
            cert = x509.load_pem_x509_certificate(f.read())
        san = cert.extensions.get_extension_for_class(x509.SubjectAlternativeName)
        cert_ips = set()
        for ip in san.value.get_values_for_type(x509.IPAddress):
            cert_ips.add(str(ip))
        for dns in san.value.get_values_for_type(x509.DNSName):
            cert_ips.add(dns)
        current_ips = _get_all_local_ips()
        missing = current_ips - cert_ips
        if missing:
            log_message(f"Cert missing IPs: {missing} — will regenerate", "WARN")
            return False
        return True
    except Exception as e:
        log_message(f"Cert validation error: {e} — will regenerate", "WARN")
        return False


def ensure_ssl_certificates(cert_file='server.crt', key_file='server.key'):
    """Generate self-signed SSL certificates if they don't exist or are stale."""
    # Regenerate if cert exists but doesn't cover current network IPs
    if os.path.exists(cert_file) and os.path.exists(key_file):
        if _cert_covers_current_ips(cert_file):
            log_message("SSL certificates found and valid.")
            return True
        log_message("SSL cert stale (IP changed) — regenerating...")
        try:
            os.remove(cert_file)
        except Exception:
            pass

    log_message("Generating self-signed SSL certificates...")

    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.hazmat.primitives import serialization
        import datetime
        import ipaddress
        import socket

        key = None
        key_reused = False

        # Try to load existing key to avoid permission errors
        if os.path.exists(key_file):
            try:
                with open(key_file, "rb") as f:
                    key = serialization.load_pem_private_key(f.read(), password=None)
                key_reused = True
                log_message("Reusing existing private key.")
            except Exception as e:
                log_message(f"Could not load existing key, generating new one: {e}", "WARN")
                try:
                    os.remove(key_file)
                except Exception:
                    pass

        if not key:
            key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

        # Collect ALL local IPs (WiFi, Ethernet, loopback)
        local_ips = _get_all_local_ips()
        hostname = socket.gethostname()

        subject = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, hostname),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, u"AI Training Server"),
            x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME, u"Local Dev"),
        ])

        # Build SANs with ALL discovered IPs
        alt_names = [
            x509.DNSName(u"localhost"),
            x509.DNSName(hostname),
        ]
        for ip_str in local_ips:
            try:
                alt_names.append(x509.IPAddress(ipaddress.ip_address(ip_str)))
            except ValueError:
                pass

        log_message(f"Cert SANs: localhost, {hostname}, {', '.join(sorted(local_ips))}")

        cert = x509.CertificateBuilder().subject_name(
            subject
        ).issuer_name(
            subject
        ).public_key(
            key.public_key()
        ).serial_number(
            x509.random_serial_number()
        ).not_valid_before(
            datetime.datetime.now(datetime.timezone.utc)
        ).not_valid_after(
            datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=3650)
        ).add_extension(
            x509.SubjectAlternativeName(alt_names),
            critical=False,
        ).sign(key, hashes.SHA256())

        if not key_reused:
            with open(key_file, "wb") as f:
                f.write(key.private_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PrivateFormat.TraditionalOpenSSL,
                    encryption_algorithm=serialization.NoEncryption(),
                ))

        with open(cert_file, "wb") as f:
            f.write(cert.public_bytes(serialization.Encoding.PEM))

        log_message(f"SSL certificates generated: {cert_file}, {key_file}")
        return True

    except Exception as e:
        log_message(f"Failed to generate SSL certificates: {e}", "ERROR")
        log_message("Ensure 'cryptography' library is installed.", "WARN")
        return False


def print_banner():
    banner = """
==============================================================
   VR MANUAL SERVER - BILINGUAL EDITION v4.1
   Spanish/English Support - Multi-Model
==============================================================
"""
    safe_print(banner)

def initialize_components():
    global whisper_model, chroma_client, collection, current_ollama_model
    
    safe_print("\nInitializing components...\n")
    
    load_config()
    
    try:
        log_message("Initializing ChromaDB...")
        import chromadb
        from chromadb.config import Settings
        
        if os.getenv('LOCALAPPDATA'):
            db_path = Path(os.getenv('LOCALAPPDATA')) / "TRAINING AI SERVER" / "chroma_db"
        else:
            db_path = Path.home() / ".training_ai_server" / "chroma_db"
        
        db_path.mkdir(parents=True, exist_ok=True)
        chroma_client = chromadb.PersistentClient(
            path=str(db_path), 
            settings=Settings(anonymized_telemetry=False)
        )
        collection = chroma_client.get_or_create_collection(
            name="manuals",
            metadata={"description": "Bilingual manual database"}
        )
        
        log_message("ChromaDB initialized [OK]")
    except Exception as e:
        log_message(f"ChromaDB initialization failed: {str(e)}", "ERROR")
        return False

    try:
        log_message(f"Loading Whisper model ({WHISPER_MODEL_SIZE})...")
        from faster_whisper import WhisperModel
        import ctranslate2

        # Resolve device: check ctranslate2 THEN verify the CUDA runtime DLL is
        # actually loadable — GPU drivers alone are not enough (needs CUDA toolkit).
        if WHISPER_DEVICE == "auto":
            device = "cpu"  # safe default
            try:
                cuda_types = ctranslate2.get_supported_compute_types("cuda")
                if cuda_types:
                    try:
                        import ctypes
                        ctypes.WinDLL("cublas64_12.dll")   # raises OSError if missing, AttributeError on non-Windows
                        device = "cuda"
                        log_message("CUDA 12 runtime detected — using GPU")
                    except (OSError, AttributeError):
                        log_message("CUDA drivers present but cublas64_12.dll not found — using CPU", "WARN")
            except Exception:
                pass
        else:
            device = WHISPER_DEVICE

        if WHISPER_COMPUTE_TYPE == "auto":
            compute_type = "float16" if device == "cuda" else "int8"
        else:
            compute_type = WHISPER_COMPUTE_TYPE

        # Use a controlled local cache inside the server directory (avoids Windows
        # permission issues with the user's HuggingFace hub cache)
        model_cache = Path(__file__).parent / "whisper_cache"
        model_cache.mkdir(parents=True, exist_ok=True)

        def _load_whisper():
            return WhisperModel(
                WHISPER_MODEL_SIZE,
                device=device,
                compute_type=compute_type,
                download_root=str(model_cache)
            )

        try:
            whisper_model = _load_whisper()
        except Exception as load_err:
            # Model cache is likely corrupted — wipe it and re-download
            log_message(f"Whisper cache error: {load_err} — clearing cache and retrying...", "WARN")
            import shutil as _shutil
            _shutil.rmtree(str(model_cache), ignore_errors=True)
            model_cache.mkdir(parents=True, exist_ok=True)
            whisper_model = _load_whisper()

        log_message(f"Whisper model loaded [OK] — device={device}, compute={compute_type}")
    except Exception as e:
        log_message(f"Whisper initialization failed: {str(e)}", "WARN")
        log_message("Audio queries will be unavailable until Whisper loads correctly.", "WARN")
        whisper_model = None
        # Non-fatal: server continues without STT

    try:
        log_message("Verifying Ollama...")
        import ollama
        
        models = get_available_models()
        log_message(f"Found {len(models)} Ollama models")
        
        if current_ollama_model not in models:
            log_message(f"Configured model '{current_ollama_model}' not found", "WARN")
            
            # Prefer best available in priority order (phi4-mini = default Q&A model)
            preferred = ["phi4-mini", "qwen3:4b", "qwen3:1.7b", "qwen3:8b",
                         "gemma3:4b", "qwen2.5:3b", "qwen2.5:1.5b"]
            found = next((m for m in preferred if m in models), None)
            if found:
                log_message(f"Using best available model: {found}")
                current_ollama_model = found
                save_config()
            elif DEFAULT_OLLAMA_MODEL in models:
                log_message(f"Using default: {DEFAULT_OLLAMA_MODEL}")
                current_ollama_model = DEFAULT_OLLAMA_MODEL
                save_config()
            elif models:
                log_message(f"Using first available: {models[0]}")
                current_ollama_model = models[0]
                save_config()
            else:
                log_message("No models available - server starting in degraded mode", "WARN")
                log_message("Download a model from the launcher to enable AI queries", "WARN")
                current_ollama_model = None
                # Non-fatal: server starts, queries return a clear error

        if current_ollama_model:
            log_message(f"Active model: {current_ollama_model} [OK]")
        else:
            log_message("No active model - use the launcher Download section to install one", "WARN")

    except Exception as e:
        log_message(f"Ollama verification failed: {str(e)}", "ERROR")
        log_message("Server starting without Ollama - queries will fail until Ollama runs", "WARN")
        current_ollama_model = None
        # Non-fatal: server starts in degraded mode
    
    load_manuals_metadata()
    
    return True

def load_manuals_metadata():
    global indexed_manuals
    
    try:
        results = collection.get(include=['metadatas'])
        
        if results and results['ids']:
            for metadata in results['metadatas']:
                manual_name = metadata.get('manual_name', 'unknown')
                if manual_name not in indexed_manuals:
                    indexed_manuals[manual_name] = {
                        'chunks': 0,
                        'pages': set(),
                        'indexed_at': metadata.get('indexed_at', 'unknown'),
                        'manual_name': manual_name,
                        'file_size_mb': metadata.get('file_size_mb', 0),
                        'file_path': metadata.get('file_path', 'unknown'),
                        'file_hash': metadata.get('file_hash', '')
                    }
                indexed_manuals[manual_name]['chunks'] += 1
                if 'page' in metadata:
                    indexed_manuals[manual_name]['pages'].add(metadata['page'])
            
            for manual_name in indexed_manuals:
                page_set = indexed_manuals[manual_name]['pages']
                indexed_manuals[manual_name]['pages'] = len(page_set) if page_set else 0
                
                if not isinstance(indexed_manuals[manual_name].get('file_size_mb'), (int, float)):
                    indexed_manuals[manual_name]['file_size_mb'] = 0
            
            log_message(f"Loaded {len(indexed_manuals)} existing manuals")
    except Exception as e:
        log_message(f"Error loading manuals metadata: {str(e)}", "WARN")

# ============================================================================
# INDEXING FUNCTIONS
# ============================================================================

def create_chunks(text, page_num, manual_name, file_path=None, file_size_mb=0, file_hash=''):
    chunks = []
    start = 0
    chunk_id = 0
    
    while start < len(text):
        end = start + CHUNK_SIZE
        chunk_text = text[start:end]
        
        if chunk_text.strip():
            chunks.append({
                'id': f"{manual_name}_p{page_num}_c{chunk_id}",
                'text': chunk_text,
                'metadata': {
                    'page': page_num,
                    'manual_name': manual_name,
                    'indexed_at': get_timestamp(),
                    'file_path': str(file_path) if file_path else 'unknown',
                    'file_size_mb': file_size_mb,
                    'file_hash': file_hash
                }
            })
            chunk_id += 1
        
        start = end - CHUNK_OVERLAP
    
    return chunks

def index_single_manual(pdf_path, task_id=None, callback=None, force_reindex=False):
    try:
        manual_name = Path(pdf_path).stem
        
        if task_id:
            indexing_status[task_id]['current_file'] = manual_name
            indexing_status[task_id]['status'] = 'processing'
        
        log_message(f"Indexing: {manual_name}")
        
        valid, msg, file_hash = validate_pdf(pdf_path, check_duplicates=not force_reindex)
        if not valid:
            if isinstance(file_hash, dict):
                raise ValueError(f"Duplicate detected: {msg}")
            else:
                raise ValueError(msg)
        
        from PyPDF2 import PdfReader
        reader = PdfReader(pdf_path)
        total_pages = len(reader.pages)
        
        if total_pages > MAX_PAGES_PER_FILE:
            raise ValueError(f"Too many pages ({total_pages} > {MAX_PAGES_PER_FILE})")
        
        log_message(f"Processing {total_pages} pages...")
        
        file_size_mb = get_file_size_mb(pdf_path)
        all_chunks = []
        
        for page_num, page in enumerate(reader.pages, start=1):
            text = page.extract_text()
            
            if text and text.strip():
                page_chunks = create_chunks(
                    text, 
                    page_num, 
                    manual_name,
                    file_path=pdf_path,
                    file_size_mb=round(file_size_mb, 2),
                    file_hash=file_hash
                )
                all_chunks.extend(page_chunks)
            
            progress = int((page_num / total_pages) * 100)
            if task_id:
                indexing_status[task_id]['progress'] = progress
            
            if callback:
                callback(progress, page_num, total_pages)
        
        current_total = collection.count()
        if current_total + len(all_chunks) > MAX_TOTAL_CHUNKS:
            raise ValueError(
                f"Would exceed chunk limit ({current_total + len(all_chunks)} > {MAX_TOTAL_CHUNKS})"
            )
        
        log_message(f"Adding {len(all_chunks)} chunks to database...")
        
        collection.add(
            ids=[c['id'] for c in all_chunks],
            documents=[c['text'] for c in all_chunks],
            metadatas=[c['metadata'] for c in all_chunks]
        )
        
        indexed_manuals[manual_name] = {
            'chunks': len(all_chunks),
            'pages': total_pages,
            'indexed_at': get_timestamp(),
            'file_size_mb': round(get_file_size_mb(pdf_path), 2),
            'file_hash': file_hash,
            'file_path': str(pdf_path),
            'manual_name': manual_name
        }
        
        log_message(f"✓ {manual_name} indexed successfully ({len(all_chunks)} chunks)")
        
        return {
            'success': True,
            'manual_name': manual_name,
            'chunks': len(all_chunks),
            'pages': total_pages
        }
        
    except Exception as e:
        log_message(f"✗ Error indexing {Path(pdf_path).name}: {str(e)}", "ERROR")
        return {
            'success': False,
            'manual_name': Path(pdf_path).stem,
            'error': str(e)
        }

def index_multiple_manuals_batch(pdf_paths, task_id):
    total_files = len(pdf_paths)
    results = []
    
    indexing_status[task_id] = {
        'status': 'running',
        'total_files': total_files,
        'completed_files': 0,
        'current_file': None,
        'progress': 0,
        'results': []
    }
    
    for i, pdf_path in enumerate(pdf_paths, start=1):
        indexing_status[task_id]['completed_files'] = i - 1
        
        result = index_single_manual(pdf_path, task_id)
        results.append(result)
        
        indexing_status[task_id]['results'].append(result)
        indexing_status[task_id]['completed_files'] = i
        
        overall_progress = int((i / total_files) * 100)
        indexing_status[task_id]['progress'] = overall_progress
    
    indexing_status[task_id]['status'] = 'completed'
    indexing_status[task_id]['progress'] = 100
    
    return results

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.route('/health', methods=['GET'])
def health_check():
    total_chunks = collection.count() if collection else 0
    
    available = get_available_models()
    return jsonify({
        'status': 'healthy',
        'whisper_loaded': whisper_model is not None,
        'ollama_model': current_ollama_model,
        'available_models': available,
        'no_model_available': current_ollama_model is None or len(available) == 0,
        'bilingual_mode': True,
        'supported_languages': ['es', 'en'],
        'indexed_manuals': len(indexed_manuals),
        'total_chunks': total_chunks,
        'max_chunks': MAX_TOTAL_CHUNKS,
        'chunk_usage_percent': round((total_chunks / MAX_TOTAL_CHUNKS) * 100, 1),
        'timestamp': get_timestamp()
    })

@app.route('/models', methods=['GET'])
def list_models():
    models = get_available_models()
    return jsonify({
        'success': True,
        'current_model': current_ollama_model,
        'available_models': models,
        'total_models': len(models)
    })

@app.route('/switch_model', methods=['POST'])
def switch_model():
    global current_ollama_model
    
    try:
        data = request.get_json()
        new_model = data.get('model_name')
        
        if not new_model:
            return jsonify({'error': 'No model_name provided'}), 400
        
        if not verify_model_available(new_model):
            return jsonify({
                'error': f"Model '{new_model}' not available",
                'available_models': get_available_models()
            }), 404
        
        with model_lock:
            old_model = current_ollama_model
            current_ollama_model = new_model
            save_config()
        
        log_message(f"Model switched: {old_model} → {new_model}")
        
        return jsonify({
            'success': True,
            'previous_model': old_model,
            'current_model': current_ollama_model,
            'message': f"Successfully switched to {new_model}"
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/manuals', methods=['GET'])
def list_manuals():
    # Serialize pages sets → sorted lists (sets are not JSON-serializable)
    serializable = {
        name: {**info, 'pages': sorted(list(info['pages'])) if isinstance(info.get('pages'), set) else info.get('pages', [])}
        for name, info in indexed_manuals.items()
    }
    return jsonify({
        'success': True,
        'manuals': serializable,
        'total_manuals': len(indexed_manuals),
        'total_chunks': collection.count() if collection else 0
    })


@app.route('/admin')
def admin_panel():
    """Serve the debug tester panel — access via https://IP:5000/admin"""
    tester = Path(__file__).parent / 'AI_Server_Tester.html'
    if tester.exists():
        return send_file(str(tester))
    return jsonify({'error': 'Admin panel not found. Copy AI_Server_Tester.html next to offline_server.py'}), 404

@app.route('/check_manual', methods=['POST'])
def check_manual():
    try:
        data = request.get_json()
        pdf_path = data.get('pdf_path')
        
        if not pdf_path:
            return jsonify({'error': 'No pdf_path provided'}), 400
        
        if not Path(pdf_path).exists():
            return jsonify({'error': 'File not found'}), 404
        
        manual_name = Path(pdf_path).stem
        
        exists_by_name = check_manual_exists(manual_name)
        
        file_hash = calculate_file_hash(pdf_path)
        existing_manual_by_hash = check_file_hash_exists(file_hash) if file_hash else None
        
        if exists_by_name or existing_manual_by_hash:
            existing_manual = manual_name if exists_by_name else existing_manual_by_hash
            manual_info = indexed_manuals[existing_manual]
            
            return jsonify({
                'exists': True,
                'duplicate_type': 'name' if exists_by_name else 'hash',
                'existing_manual': existing_manual,
                'manual_info': manual_info,
                'message': f"Manual already indexed as '{existing_manual}'"
            })
        else:
            return jsonify({
                'exists': False,
                'manual_name': manual_name,
                'file_hash': file_hash,
                'message': 'Manual is new, safe to index'
            })
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

#@app.route('/index', methods=['POST'])
@app.route('/index', methods=['POST'])
def index_from_path():
    """Index a PDF from a file path (used by launcher)"""
    try:
        data = request.get_json()
        pdf_path = data.get('pdf_path')
        
        if not pdf_path:
            return jsonify({'error': 'No pdf_path provided'}), 400
        
        if not Path(pdf_path).exists():
            return jsonify({'error': 'File not found'}), 404
        
        # Call the indexing function
        result = index_single_manual(pdf_path)
        
        if result.get('success'):
            return jsonify({
                'success': True,
                'manual_name': result['manual_name'],
                'chunks': result['chunks'],
                'pages': result['pages'],
                'message': f"Manual '{result['manual_name']}' indexed successfully"
            })
        else:
            return jsonify({
                'success': False,
                'error': result.get('error', 'Unknown error')
            }), 500
            
    except Exception as e:
        log_message(f"Error in /index endpoint: {e}", "ERROR")
        return jsonify({'error': str(e)}), 500


@app.route('/index_manual', methods=['POST'])
def index_manual():
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Empty filename"}), 400

    # FIX: Asegurar que la carpeta de manuales exista y guardar el archivo
    if not os.path.exists(manuals_folder):
        os.makedirs(manuals_folder)

    file_path = os.path.join(manuals_folder, file.filename)
    file.save(file_path) # Copia física a la carpeta de manuales

    # Indexar en la DB vectorial
    result = index_single_manual(file_path)

    if result['success']:
        # Devolver la lista actualizada de archivos PDF para que el cliente la vea
        indexed_files = [f for f in os.listdir(manuals_folder) if f.lower().endswith('.pdf')]
        return jsonify({
            "message": f"Manual {file.filename} indexado con éxito",
            "files": indexed_files
        })
    else:
        return jsonify({"error": result.get('error', 'Error al procesar el PDF')}), 500

@app.route('/delete_manual/<filename>', methods=['DELETE'])
def delete_manual_file(filename):
    try:
        file_path = os.path.join(manuals_folder, filename)
        
        # 1. Eliminar archivo físico
        if os.path.exists(file_path):
            os.remove(file_path)
        
        # 2. Eliminar de la base de datos vectorial (ChromaDB)
        manual_name = Path(filename).stem
        chroma_results = collection.get(where={"manual_name": manual_name})
        if chroma_results and chroma_results['ids']:
            collection.delete(ids=chroma_results['ids'])
        indexed_manuals.pop(manual_name, None)
        
        # 3. Devolver lista actualizada
        files = [f for f in os.listdir(manuals_folder) if f.lower().endswith('.pdf')]
        return jsonify({"message": "Eliminado correctamente", "files": files})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/index/batch', methods=['POST'])
def index_batch():
    try:
        data = request.get_json()
        pdf_paths = data.get('pdf_paths', [])
        
        if not pdf_paths:
            return jsonify({'error': 'No pdf_paths provided'}), 400
        
        if not isinstance(pdf_paths, list):
            return jsonify({'error': 'pdf_paths must be a list'}), 400
        
        task_id = f"batch_{int(time.time())}"
        
        thread = threading.Thread(
            target=index_multiple_manuals_batch,
            args=(pdf_paths, task_id)
        )
        thread.start()
        
        return jsonify({
            'success': True,
            'task_id': task_id,
            'total_files': len(pdf_paths)
        }), 202
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/index/status/<task_id>', methods=['GET'])
def get_indexing_status(task_id):
    if task_id not in indexing_status:
        return jsonify({'error': 'Task not found'}), 404
    
    return jsonify({
        'success': True,
        'task_id': task_id,
        **indexing_status[task_id]
    })

@app.route('/manual/<manual_name>', methods=['DELETE'])
def delete_manual(manual_name):
    try:
        if manual_name not in indexed_manuals:
            return jsonify({'error': 'Manual not found'}), 404
        
        results = collection.get(where={"manual_name": manual_name})
        
        if results and results['ids']:
            collection.delete(ids=results['ids'])
            
        del indexed_manuals[manual_name]
        
        log_message(f"Deleted manual: {manual_name}")
        
        return jsonify({
            'success': True,
            'manual_name': manual_name,
            'chunks_deleted': len(results['ids']) if results else 0
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/clear_all', methods=['POST'])
def clear_all_database():
    try:
        log_message("⚠️ Clearing entire database...")
        
        results = collection.get()
        total_chunks = len(results['ids']) if results and results['ids'] else 0
        total_manuals = len(indexed_manuals)
        
        if results and results['ids']:
            collection.delete(ids=results['ids'])
        
        indexed_manuals.clear()
        
        log_message(f"✓ Database cleared: {total_chunks} chunks, {total_manuals} manuals")
        
        return jsonify({
            'success': True,
            'chunks_deleted': total_chunks,
            'manuals_deleted': total_manuals
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/query', methods=['POST'])
def query_text():
    if not current_ollama_model:
        return jsonify({
            'error': 'No AI model installed. Open the launcher, select a model in the Download dropdown, and click Download.',
            'success': False,
            'no_model': True
        }), 503

    try:
        data = request.get_json()
        query = data.get('query', '')
        manual_filter = data.get('manual_name')
        # Aumentamos n_results de 3 a 6 para capturar más contexto
        n_results = data.get('n_results', 7)

        if not query:
            return jsonify({'error': 'No query provided'}), 400
        
        where_clause = {}
        if manual_filter:
            where_clause = {"manual_name": manual_filter}
        
        results = collection.query(
            query_texts=[query],
            n_results=n_results,
            where=where_clause if where_clause else None
        )
        
        if not results['documents'] or not results['documents'][0]:
            return jsonify({
                'success': True,
                'answer': 'No encontré información relevante en los manuales.',
                'sources': [],
                'model_used': current_ollama_model
            })
        
        context_parts = []
        sources = []
        page_references = []
        
        for doc, metadata in zip(results['documents'][0], results['metadatas'][0]):
            context_parts.append(doc)
            manual = metadata['manual_name']
            page = metadata['page']
            sources.append({'manual': manual, 'page': page})
            page_references.append(f"(Manual: {manual}, Página: {page})")
        
        context = '\n\n'.join(context_parts)
        
        import ollama
        with model_lock:
            active_model = current_ollama_model
        
        prompt = f"""Eres un asistente técnico bilingüe (español/inglés). Responde ÚNICAMENTE con la información del contexto del manual. Máximo 2-3 frases. No uses frases introductorias como "Según...", "De acuerdo con...", "Basándome en..." — ve directo al dato. Termina siempre con: Fuente: [Manual], página [número]. /no_think
Responde en el mismo idioma que la pregunta (español si la pregunta es en español, English if the question is in English).

Contexto:
{context}

Pregunta: {query}

Respuesta:"""

        log_message(f"Query using model: {active_model}")

        response = ollama.generate(
            model=active_model,
            prompt=prompt,
            options={
                "temperature": 0.2,
                "num_ctx": 4096,
                "top_p": 0.9
            }
        )
        
        return jsonify({
            'success': True,
            'answer': response['response'].strip(),
            'sources': sources,
            'manuals_used': list(set(s['manual'] for s in sources)),
            'model_used': active_model
        })
        
    except Exception as e:
        log_message(f"Error in query: {e}", "ERROR")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# MAIN
# ============================================================================

@app.route('/query_audio', methods=['POST'])
def query_audio():
    if not current_ollama_model:
        return jsonify({
            'error': 'No AI model installed. Open the launcher, select a model in the Download dropdown, and click Download.',
            'success': False,
            'no_model': True
        }), 503

    if whisper_model is None:
        return jsonify({'error': 'Speech recognition is not available. Check server logs for Whisper initialization errors.'}), 503

    try:
        if 'audio' not in request.files:
            return jsonify({'error': 'No audio file'}), 400

        audio_file = request.files['audio']
        manual_filter = request.form.get('manual_name')

        # Preserve original extension so ffmpeg/ct2 can decode it correctly
        original_filename = audio_file.filename or 'audio.wav'
        ext = os.path.splitext(original_filename)[1].lower() or '.wav'

        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
            audio_file.save(tmp.name)
            tmp_path = tmp.name

        try:
            import ollama

            # ── STEP 1: Speech-to-Text ──
            t_stt = time.time()
            log_message(f"[AUDIO] STT starting — file={os.path.basename(tmp_path)}, size={os.path.getsize(tmp_path)/1024:.1f}KB")

            # beam_size=1 (greedy) is ~5x faster than beam_size=5 — fine for voice queries
            segments, info = whisper_model.transcribe(
                tmp_path,
                language=WHISPER_LANGUAGE,
                beam_size=1,
                vad_filter=True,
                vad_parameters={"min_silence_duration_ms": 500},
                condition_on_previous_text=False,
            )
            # segments is a lazy generator — consume it to actually run transcription
            query = ' '.join([s.text for s in segments]).strip()
            stt_ms = int((time.time() - t_stt) * 1000)

            detected_language = getattr(info, 'language', 'es')
            log_message(f"[AUDIO] STT done in {stt_ms}ms — lang={detected_language} conf={getattr(info, 'language_probability', 0):.2f} text=\"{query[:80]}\"")

            if not query:
                return jsonify({'error': 'No speech detected'}), 400

            # ── STEP 2: RAG retrieval ──
            t_rag = time.time()
            where_clause = {"manual_name": manual_filter} if manual_filter else None

            results = collection.query(
                query_texts=[query],
                n_results=3,
                where=where_clause
            )
            rag_ms = int((time.time() - t_rag) * 1000)
            n_docs = len(results['documents'][0]) if results['documents'][0] else 0
            log_message(f"[AUDIO] RAG done in {rag_ms}ms — {n_docs} chunks retrieved")

            if not results['documents'][0]:
                return jsonify({
                    'success': True,
                    'transcription': query,
                    'answer': 'No relevant information found.',
                    'sources': [],
                    'detected_language': detected_language,
                    'timing': {'stt_ms': stt_ms, 'rag_ms': rag_ms}
                })

            context_parts = []
            sources = []
            page_references = []

            for doc, metadata in zip(results['documents'][0], results['metadatas'][0]):
                context_parts.append(doc)
                manual = metadata['manual_name']
                page = metadata['page']
                sources.append({'manual': manual, 'page': page})
                page_references.append(f"(Manual: {manual}, Página: {page})")

            context = '\n\n'.join(context_parts)

            # ── STEP 3: LLM generation ──
            t_llm = time.time()
            with model_lock:
                active_model = current_ollama_model
            log_message(f"[AUDIO] LLM starting — model={active_model}")

            prompt = f"""Eres un asistente técnico bilingüe (español/inglés). Responde ÚNICAMENTE con la información del contexto del manual. Máximo 2-3 frases. No uses frases introductorias como "Según...", "De acuerdo con...", "Basándome en..." — ve directo al dato. Termina siempre con: Fuente: [Manual], página [número]. /no_think
Responde en el mismo idioma que la pregunta (español si la pregunta es en español, English if the question is in English).

Contexto:
{context}

Pregunta: {query}

Respuesta:"""

            response = ollama.generate(
                model=active_model,
                prompt=prompt,
                options={
                    "temperature": 0.2,
                    "num_ctx": 4096,
                    "top_p": 0.9
                }
            )
            llm_ms = int((time.time() - t_llm) * 1000)
            total_ms = stt_ms + rag_ms + llm_ms
            log_message(f"[AUDIO] LLM done in {llm_ms}ms — total pipeline: {total_ms}ms (STT={stt_ms} RAG={rag_ms} LLM={llm_ms})")

            return jsonify({
                'success': True,
                'transcription': query,
                'answer': response['response'].strip(),
                'sources': sources,
                'manuals_used': list(set(s['manual'] for s in sources)),
                'model_used': active_model,
                'detected_language': detected_language,
                'timing': {'stt_ms': stt_ms, 'rag_ms': rag_ms, 'llm_ms': llm_ms, 'total_ms': total_ms}
            })
            
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
                
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    print_banner()
    
    log_message("Bilingual Edition Features:")
    log_message("- Spanish/English native support")
    log_message("- Multi-model hot-swapping")
    log_message("- Default: phi4-mini (exceptional document Q&A)")
    log_message("- Voice query with language detection")
    
    if initialize_components():
        # SSL Setup — disabled by default for local LAN use (avoids cert issues on Quest/browser)
        ssl_context = None
        protocol = "http"

        if USE_SSL:
            base_dir = Path(__file__).parent.absolute()
            cert_file = str(base_dir / 'server.crt')
            key_file = str(base_dir / 'server.key')
            if ensure_ssl_certificates(cert_file, key_file):
                ssl_context = (cert_file, key_file)
                protocol = "https"
            else:
                log_message("WARNING: SSL generation failed, falling back to HTTP", "WARN")

        log_message(f"Server starting on {protocol}://0.0.0.0:{SERVER_PORT}...")
        log_message(f"Active model: {current_ollama_model}")

        app.run(host='0.0.0.0', port=SERVER_PORT, threaded=True, ssl_context=ssl_context)
    else:
        log_message("Failed to initialize components", "ERROR")
        sys.exit(1)

# ============================================================================
# PORT MANAGEMENT
# ============================================================================

def find_available_port(start_port=5000, max_port=5010):
    """Find first available port in range"""
    import socket
    for port in range(start_port, max_port + 1):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(('localhost', port)) != 0:
                return port
    return None

def update_config_port(port):
    """Update config file with actual running port"""
    try:
        config = {}
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE, 'r') as f:
                config = json.load(f)
        
        config['port'] = port
        config['last_updated'] = datetime.now().isoformat()
        
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
            
        log_message(f"Config updated with port: {port}")
    except Exception as e:
        log_message(f"Error updating config port: {e}", "WARN")

