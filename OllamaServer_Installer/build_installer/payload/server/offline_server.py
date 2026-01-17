#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VR Manual Server - Multi-Manual Support
Version: 3.0 - Enhanced with batch indexing
"""

import sys
import os
import io
import json
import tempfile
import time
import threading
import hashlib
from datetime import datetime
from pathlib import Path
from flask import Flask, request, jsonify
from flask_cors import CORS

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
indexed_manuals = {}  # {manual_name: {chunks: count, pages: count, indexed_at: timestamp}}
indexing_queue = []  # List of files being indexed
indexing_status = {}  # {task_id: {status, progress, current_file, total_files, etc}}

# Configuration
WHISPER_MODEL_SIZE = "base"
OLLAMA_MODEL = "llama3.2:3b"
SERVER_PORT = 5000
CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200

# Performance limits
MAX_FILE_SIZE_MB = 100  # Increased from 50MB
MAX_PAGES_PER_FILE = 1000  # Increased from 500 pages
MAX_TOTAL_CHUNKS = 50000

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
    """Get file size in MB"""
    return Path(filepath).stat().st_size / (1024 * 1024)

def calculate_file_hash(filepath, algorithm='md5'):
    """Calculate file hash for duplicate detection"""
    hash_func = hashlib.md5() if algorithm == 'md5' else hashlib.sha256()
    
    try:
        with open(filepath, 'rb') as f:
            # Read in chunks to handle large files
            for chunk in iter(lambda: f.read(8192), b''):
                hash_func.update(chunk)
        return hash_func.hexdigest()
    except Exception as e:
        log_message(f"Error calculating hash: {e}", "ERROR")
        return None

def check_manual_exists(manual_name):
    """Check if a manual with this name is already indexed"""
    return manual_name in indexed_manuals

def check_file_hash_exists(file_hash):
    """Check if a file with this hash is already indexed"""
    for manual_info in indexed_manuals.values():
        if manual_info.get('file_hash') == file_hash:
            return manual_info.get('manual_name')
    return None

def validate_pdf(filepath, check_duplicates=True):
    """Validate PDF before indexing with duplicate detection"""
    if not Path(filepath).exists():
        return False, "File not found", None
    
    if not filepath.lower().endswith('.pdf'):
        return False, "Not a PDF file", None
    
    size_mb = get_file_size_mb(filepath)
    if size_mb > MAX_FILE_SIZE_MB:
        return False, f"File too large ({size_mb:.1f}MB > {MAX_FILE_SIZE_MB}MB)", None
    
    # Calculate file hash for duplicate detection
    file_hash = None
    manual_name = Path(filepath).stem
    
    if check_duplicates:
        # Check by name first
        if check_manual_exists(manual_name):
            existing_info = indexed_manuals[manual_name]
            return False, f"Manual '{manual_name}' already indexed (at {existing_info['indexed_at']})", {
                'duplicate_type': 'name',
                'existing_manual': manual_name,
                'indexed_at': existing_info['indexed_at'],
                'pages': existing_info.get('pages', 0),
                'chunks': existing_info.get('chunks', 0)
            }
        
        # Check by file hash (more robust)
        file_hash = calculate_file_hash(filepath)
        if file_hash:
            existing_manual = check_file_hash_exists(file_hash)
            if existing_manual:
                existing_info = indexed_manuals[existing_manual]
                return False, f"Same file already indexed as '{existing_manual}' (at {existing_info['indexed_at']})", {
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

def print_banner():
    banner = """
==============================================================
     VR MANUAL SERVER - MULTI-MANUAL SUPPORT v3.0
==============================================================
"""
    safe_print(banner)

def initialize_components():
    global whisper_model, chroma_client, collection
    safe_print("\nInitializing components...\n")
    
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
            metadata={"description": "Multi-manual vector database"}
        )
        
        log_message("ChromaDB initialized [OK]")
    except Exception as e:
        log_message(f"ChromaDB initialization failed: {str(e)}", "ERROR")
        return False

    try:
        log_message(f"Loading Whisper model ({WHISPER_MODEL_SIZE})...")
        from faster_whisper import WhisperModel
        whisper_model = WhisperModel(WHISPER_MODEL_SIZE, device="cpu", compute_type="int8")
        log_message("Whisper model loaded [OK]")
    except Exception as e:
        log_message(f"Whisper initialization failed: {str(e)}", "ERROR")
        return False

    try:
        log_message("Verifying Ollama...")
        import ollama
        models = ollama.list()
        log_message(f"Ollama model {OLLAMA_MODEL} verified [OK]")
    except Exception as e:
        log_message(f"Ollama verification failed: {str(e)}", "ERROR")
        return False
    
    # Load existing manuals metadata
    load_manuals_metadata()
    
    return True

def load_manuals_metadata():
    """Load information about already indexed manuals"""
    global indexed_manuals
    
    try:
        # Get all documents with their metadata
        results = collection.get(include=['metadatas'])
        
        if results and results['ids']:
            # Group by manual_name
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
            
            # Convert sets to counts and ensure pages is always a number
            for manual_name in indexed_manuals:
                page_set = indexed_manuals[manual_name]['pages']
                # CRITICAL FIX: Ensure pages is always an integer, never undefined
                indexed_manuals[manual_name]['pages'] = len(page_set) if page_set else 0
                
                # Ensure file_size_mb is a number
                if not isinstance(indexed_manuals[manual_name].get('file_size_mb'), (int, float)):
                    indexed_manuals[manual_name]['file_size_mb'] = 0
            
            log_message(f"Loaded {len(indexed_manuals)} existing manuals")
            
            # Log details for debugging
            for name, info in indexed_manuals.items():
                log_message(f"  - {name}: {info['chunks']} chunks, {info['pages']} pages")
    except Exception as e:
        log_message(f"Error loading manuals metadata: {str(e)}", "WARN")

# ============================================================================
# INDEXING FUNCTIONS
# ============================================================================

def create_chunks(text, page_num, manual_name, file_path=None, file_size_mb=0, file_hash=''):
    """Create overlapping chunks from text with complete metadata"""
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
    """Index a single manual with progress tracking and duplicate detection"""
    try:
        manual_name = Path(pdf_path).stem
        
        # Update status
        if task_id:
            indexing_status[task_id]['current_file'] = manual_name
            indexing_status[task_id]['status'] = 'processing'
        
        log_message(f"Indexing: {manual_name}")
        
        # Validate PDF with duplicate detection
        valid, msg, file_hash = validate_pdf(pdf_path, check_duplicates=not force_reindex)
        if not valid:
            # Return the duplicate info if available
            if isinstance(file_hash, dict):  # This is duplicate_info
                raise ValueError(f"Duplicate detected: {msg}")
            else:
                raise ValueError(msg)
        
        # Read PDF
        from PyPDF2 import PdfReader
        reader = PdfReader(pdf_path)
        total_pages = len(reader.pages)
        
        if total_pages > MAX_PAGES_PER_FILE:
            raise ValueError(f"Too many pages ({total_pages} > {MAX_PAGES_PER_FILE})")
        
        log_message(f"Processing {total_pages} pages...")
        
        # Get file metadata for chunks
        file_size_mb = get_file_size_mb(pdf_path)
        
        all_chunks = []
        
        # Process each page
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
            
            # Update progress
            progress = int((page_num / total_pages) * 100)
            if task_id:
                indexing_status[task_id]['progress'] = progress
                indexing_status[task_id]['current_page'] = page_num
                indexing_status[task_id]['total_pages'] = total_pages
            
            if callback:
                callback(progress, page_num, total_pages)
        
        # Check total chunks limit
        current_total = collection.count()
        if current_total + len(all_chunks) > MAX_TOTAL_CHUNKS:
            raise ValueError(
                f"Would exceed chunk limit ({current_total + len(all_chunks)} > {MAX_TOTAL_CHUNKS})"
            )
        
        # Add to ChromaDB
        log_message(f"Adding {len(all_chunks)} chunks to database...")
        
        collection.add(
            ids=[c['id'] for c in all_chunks],
            documents=[c['text'] for c in all_chunks],
            metadatas=[c['metadata'] for c in all_chunks]
        )
        
        # Update indexed manuals
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
    """Index multiple manuals sequentially with progress tracking"""
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
        
        # Overall progress
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
    """Health check endpoint"""
    total_chunks = collection.count() if collection else 0
    
    return jsonify({
        'status': 'healthy',
        'whisper_loaded': whisper_model is not None,
        'ollama_model': OLLAMA_MODEL,
        'indexed_manuals': len(indexed_manuals),
        'total_chunks': total_chunks,
        'max_chunks': MAX_TOTAL_CHUNKS,
        'chunk_usage_percent': round((total_chunks / MAX_TOTAL_CHUNKS) * 100, 1),
        'timestamp': get_timestamp()
    })

@app.route('/manuals', methods=['GET'])
def list_manuals():
    """List all indexed manuals"""
    return jsonify({
        'success': True,
        'manuals': indexed_manuals,
        'total_manuals': len(indexed_manuals),
        'total_chunks': collection.count() if collection else 0
    })

@app.route('/check_manual', methods=['POST'])
def check_manual():
    """Check if a manual already exists (by name or file hash)"""
    try:
        data = request.get_json()
        pdf_path = data.get('pdf_path')
        
        if not pdf_path:
            return jsonify({'error': 'No pdf_path provided'}), 400
        
        if not Path(pdf_path).exists():
            return jsonify({'error': 'File not found'}), 404
        
        manual_name = Path(pdf_path).stem
        
        # Check by name
        exists_by_name = check_manual_exists(manual_name)
        
        # Check by hash
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

@app.route('/index', methods=['POST'])
def index_manual():
    """Index a single manual with duplicate detection"""
    try:
        data = request.get_json()
        pdf_path = data.get('pdf_path')
        force_reindex = data.get('force_reindex', False)
        
        if not pdf_path:
            return jsonify({'error': 'No pdf_path provided'}), 400
        
        # If not forcing reindex, check for duplicates first
        if not force_reindex:
            manual_name = Path(pdf_path).stem
            
            # Check by name
            if check_manual_exists(manual_name):
                manual_info = indexed_manuals[manual_name]
                return jsonify({
                    'error': 'Duplicate manual',
                    'duplicate': True,
                    'existing_manual': manual_name,
                    'manual_info': manual_info,
                    'message': f"Manual '{manual_name}' is already indexed. Use force_reindex=true to re-index."
                }), 409  # 409 Conflict
            
            # Check by hash
            file_hash = calculate_file_hash(pdf_path)
            if file_hash:
                existing_manual = check_file_hash_exists(file_hash)
                if existing_manual:
                    manual_info = indexed_manuals[existing_manual]
                    return jsonify({
                        'error': 'Duplicate file',
                        'duplicate': True,
                        'existing_manual': existing_manual,
                        'manual_info': manual_info,
                        'message': f"Same file already indexed as '{existing_manual}'. Use force_reindex=true to re-index."
                    }), 409
        
        # If forcing reindex, delete existing manual first
        if force_reindex:
            manual_name = Path(pdf_path).stem
            if check_manual_exists(manual_name):
                # Delete old version
                try:
                    results = collection.get(where={"manual_name": manual_name})
                    if results and results['ids']:
                        collection.delete(ids=results['ids'])
                    del indexed_manuals[manual_name]
                    log_message(f"Deleted old version of '{manual_name}' for re-indexing")
                except Exception as e:
                    log_message(f"Error deleting old manual: {e}", "WARN")
        
        result = index_single_manual(pdf_path, force_reindex=force_reindex)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/index/batch', methods=['POST'])
def index_batch():
    """Index multiple manuals - async with task tracking"""
    try:
        data = request.get_json()
        pdf_paths = data.get('pdf_paths', [])
        
        if not pdf_paths:
            return jsonify({'error': 'No pdf_paths provided'}), 400
        
        if not isinstance(pdf_paths, list):
            return jsonify({'error': 'pdf_paths must be a list'}), 400
        
        # Create task ID
        task_id = f"batch_{int(time.time())}"
        
        # Start indexing in background thread
        thread = threading.Thread(
            target=index_multiple_manuals_batch,
            args=(pdf_paths, task_id)
        )
        thread.start()
        
        return jsonify({
            'success': True,
            'task_id': task_id,
            'total_files': len(pdf_paths),
            'message': 'Batch indexing started'
        }), 202
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/index/status/<task_id>', methods=['GET'])
def get_indexing_status(task_id):
    """Get status of batch indexing task"""
    if task_id not in indexing_status:
        return jsonify({'error': 'Task not found'}), 404
    
    return jsonify({
        'success': True,
        'task_id': task_id,
        **indexing_status[task_id]
    })

@app.route('/manual/<manual_name>', methods=['DELETE'])
def delete_manual(manual_name):
    """Delete a specific manual and its chunks"""
    try:
        if manual_name not in indexed_manuals:
            return jsonify({'error': 'Manual not found'}), 404
        
        # Get all chunk IDs for this manual
        results = collection.get(
            where={"manual_name": manual_name}
        )
        
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
    """Clear ALL indexed manuals and reset database - DANGER!"""
    try:
        log_message("⚠️ WARNING: Clearing entire database...")
        
        # Get count before deleting
        results = collection.get()
        total_chunks = len(results['ids']) if results and results['ids'] else 0
        total_manuals = len(indexed_manuals)
        
        # Delete all chunks
        if results and results['ids']:
            collection.delete(ids=results['ids'])
        
        # Clear indexed manuals dictionary
        indexed_manuals.clear()
        
        log_message(f"✓ Database cleared: {total_chunks} chunks, {total_manuals} manuals deleted")
        
        return jsonify({
            'success': True,
            'message': 'Database cleared successfully',
            'chunks_deleted': total_chunks,
            'manuals_deleted': total_manuals
        })
        
    except Exception as e:
        log_message(f"✗ Error clearing database: {str(e)}", "ERROR")
        return jsonify({'error': str(e)}), 500

@app.route('/query', methods=['POST'])
def query_text():
    """Text query with manual filtering"""
    try:
        data = request.get_json()
        query = data.get('query', '')
        manual_filter = data.get('manual_name')  # Optional: filter by manual
        n_results = data.get('n_results', 3)
        
        if not query:
            return jsonify({'error': 'No query provided'}), 400
        
        # Build where clause
        where_clause = {}
        if manual_filter:
            where_clause = {"manual_name": manual_filter}
        
        # Query ChromaDB
        results = collection.query(
            query_texts=[query],
            n_results=n_results,
            where=where_clause if where_clause else None
        )
        
        if not results['documents'][0]:
            return jsonify({
                'success': True,
                'answer': 'No relevant information found in the indexed manuals.',
                'sources': []
            })
        
        # Build context with page references
        context_parts = []
        sources = []
        page_references = []
        
        for doc, metadata in zip(results['documents'][0], results['metadatas'][0]):
            context_parts.append(doc)
            manual = metadata['manual_name']
            page = metadata['page']
            sources.append({
                'manual': manual,
                'page': page
            })
            page_references.append(f"(Manual: {manual}, Página: {page})")
        
        context = '\n\n'.join(context_parts)
        
        # Generate answer with Ollama
        import ollama
        
        # IMPROVED PROMPT: Only answer from manual context, refuse general knowledge
        prompt = f"""Eres un asistente técnico especializado EXCLUSIVAMENTE en los manuales proporcionados.

REGLAS ESTRICTAS:
1. SOLO puedes responder preguntas basándote en el contexto del manual proporcionado
2. Si la pregunta NO está relacionada con el contenido del manual, debes responder EXACTAMENTE:
   "Lo siento, no tengo información sobre eso en los manuales indexados. Solo puedo responder preguntas sobre el contenido de los manuales técnicos disponibles."
3. NO uses conocimiento general ni información externa
4. NO inventes información
5. Responde en el MISMO IDIOMA que usa el usuario
6. IMPORTANTE: Al final de tu respuesta, SIEMPRE menciona las páginas de donde obtuviste la información usando el formato:
   "Fuente: [Manual], página [número]" o "Fuentes: [Manual], páginas [números]"

Contexto del manual con referencias:
{context}

Referencias de páginas: {', '.join(page_references)}

Pregunta del usuario: {query}

Respuesta (solo si está en el contexto del manual, incluye las páginas al final):"""
        
        response = ollama.generate(model=OLLAMA_MODEL, prompt=prompt)
        
        return jsonify({
            'success': True,
            'answer': response['response'].strip(),
            'sources': sources,
            'manuals_used': list(set(s['manual'] for s in sources))
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/query_audio', methods=['POST'])
def query_audio():
    """Voice query with transcription"""
    try:
        if 'audio' not in request.files:
            return jsonify({'error': 'No audio file'}), 400
        
        audio_file = request.files['audio']
        manual_filter = request.form.get('manual_name')  # Optional
        
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp:
            audio_file.save(tmp.name)
            tmp_path = tmp.name
        
        try:
            # Transcribe audio
            segments, info = whisper_model.transcribe(tmp_path, beam_size=5)
            query = ' '.join([s.text for s in segments]).strip()
            
            if not query:
                return jsonify({'error': 'No speech detected'}), 400
            
            # Detect language from transcription
            detected_language = info.language if hasattr(info, 'language') else 'es'
            language_name = {
                'en': 'English',
                'es': 'Spanish',
                'fr': 'French',
                'de': 'German',
                'it': 'Italian',
                'pt': 'Portuguese'
            }.get(detected_language, 'Spanish')
            
            log_message(f"Detected language: {language_name} ({detected_language})")
            
            # Use same query logic as text query
            where_clause = {"manual_name": manual_filter} if manual_filter else None
            
            results = collection.query(
                query_texts=[query],
                n_results=3,
                where=where_clause
            )
            
            if not results['documents'][0]:
                return jsonify({
                    'success': True,
                    'transcription': query,
                    'answer': 'No relevant information found.',
                    'sources': []
                })
            
            # Build context with page references
            context_parts = []
            sources = []
            page_references = []
            
            for doc, metadata in zip(results['documents'][0], results['metadatas'][0]):
                context_parts.append(doc)
                manual = metadata['manual_name']
                page = metadata['page']
                sources.append({
                    'manual': manual,
                    'page': page
                })
                page_references.append(f"(Manual: {manual}, Página: {page})")
            
            context = '\n\n'.join(context_parts)
            
            import ollama
            
            # Create language-specific prompt
            if detected_language == 'en':
                prompt = f"""You are a technical assistant specialized EXCLUSIVELY in the provided manuals.

STRICT RULES:
1. You can ONLY answer questions based on the provided manual context
2. If the question is NOT related to the manual content, you must respond EXACTLY:
   "I'm sorry, I don't have information about that in the indexed manuals. I can only answer questions about the content of the available technical manuals."
3. DO NOT use general knowledge or external information
4. DO NOT make up information
5. IMPORTANT: At the end of your response, ALWAYS mention the pages where you got the information using the format:
   "Source: [Manual], page [number]" or "Sources: [Manual], pages [numbers]"

Manual context with references:
{context}

Page references: {', '.join(page_references)}

User question: {query}

Answer (only if in manual context, include pages at the end):"""
            else:
                # Spanish or other languages
                prompt = f"""Eres un asistente técnico especializado EXCLUSIVAMENTE en los manuales proporcionados.

REGLAS ESTRICTAS:
1. SOLO puedes responder preguntas basándote en el contexto del manual proporcionado
2. Si la pregunta NO está relacionada con el contenido del manual, debes responder EXACTAMENTE:
   "Lo siento, no tengo información sobre eso en los manuales indexados. Solo puedo responder preguntas sobre el contenido de los manuales técnicos disponibles."
3. NO uses conocimiento general ni información externa
4. NO inventes información
5. Responde en el MISMO IDIOMA que usa el usuario
6. IMPORTANTE: Al final de tu respuesta, SIEMPRE menciona las páginas de donde obtuviste la información usando el formato:
   "Fuente: [Manual], página [número]" o "Fuentes: [Manual], páginas [números]"

Contexto del manual con referencias:
{context}

Referencias de páginas: {', '.join(page_references)}

Pregunta del usuario: {query}

Respuesta (solo si está en el contexto del manual, incluye las páginas al final):"""
            
            response = ollama.generate(model=OLLAMA_MODEL, prompt=prompt)
            
            return jsonify({
                'success': True,
                'transcription': query,
                'answer': response['response'].strip(),
                'sources': sources,
                'manuals_used': list(set(s['manual'] for s in sources))
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
    
    log_message("Multi-Manual Support Features:")
    log_message("- Single manual indexing")
    log_message("- Batch indexing with progress tracking")
    log_message("- Per-manual query filtering")
    log_message("- Manual deletion")
    log_message("- Performance monitoring")
    
    if initialize_components():
        log_message(f"Server starting on port {SERVER_PORT}...")
        app.run(host='0.0.0.0', port=SERVER_PORT, threaded=True)
    else:
        log_message("Failed to initialize components", "ERROR")
        sys.exit(1)
