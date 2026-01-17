# 🔓 EJEMPLOS DE CÓDIGO ACTUAL (VULNERABILIDADES)

## ⚠️ ESTE DOCUMENTO MUESTRA CÓDIGO VULNERABLE

Estos son fragmentos del código actual que necesitan hardening de seguridad. Úsalos como referencia al explicar a Claude qué necesitas mejorar.

---

## 1. ENDPOINT SIN AUTENTICACIÓN

### ❌ CÓDIGO ACTUAL (VULNERABLE):

```python
# offline_server.py - líneas ~300-320

@app.route('/query', methods=['POST'])
def query():
    """Query endpoint - SIN AUTENTICACIÓN"""
    try:
        data = request.json
        query_text = data.get('query', '')
        
        # NO HAY VALIDACIÓN DE ORIGEN
        # NO HAY RATE LIMITING
        # NO HAY LOGGING DE IP
        
        # Procesar query directamente
        results = collection.query(
            query_texts=[query_text],
            n_results=3
        )
        
        # Generar respuesta con Ollama
        response = ollama.generate(
            model='llama3.2:3b',
            prompt=f"Context: {results}\n\nQuestion: {query_text}"
        )
        
        return jsonify({
            'success': True,
            'answer': response['response'],
            'pages': extract_pages(results)
        })
        
    except Exception as e:
        # ERROR MESSAGE EXPONE DETALLES INTERNOS
        return jsonify({'error': str(e)}), 500
```

### ✅ LO QUE DEBERÍA SER:

```python
@app.route('/query', methods=['POST'])
@require_api_key  # Decorator de autenticación
@rate_limit(limit=10, per=60)  # Max 10 requests/minuto
def query():
    """Query endpoint - SEGURO"""
    try:
        # Verificar IP en whitelist
        if not is_ip_allowed(request.remote_addr):
            log_blocked_attempt(request.remote_addr, '/query')
            abort(403, 'IP not authorized')
        
        data = request.json
        query_text = data.get('query', '')
        
        # VALIDAR Y SANITIZAR INPUT
        if not validate_query(query_text):
            log_suspicious_query(request.remote_addr, query_text)
            abort(400, 'Invalid query format')
        
        # Logging seguro (sin datos sensibles)
        log_access(request.remote_addr, '/query', 'POST')
        
        # Procesar query
        results = collection.query(
            query_texts=[sanitize_text(query_text)],
            n_results=3
        )
        
        response = ollama.generate(
            model='llama3.2:3b',
            prompt=build_secure_prompt(results, query_text)
        )
        
        return jsonify({
            'success': True,
            'answer': response['response'],
            'pages': extract_pages(results)
        }), 200
        
    except Exception as e:
        # NO EXPONER DETALLES INTERNOS
        log_error(request.remote_addr, '/query', str(e))
        return jsonify({'error': 'Internal server error'}), 500
```

---

## 2. SERVIDOR HTTP SIN CIFRADO

### ❌ CÓDIGO ACTUAL (VULNERABLE):

```python
# offline_server.py - líneas ~500-510

if __name__ == "__main__":
    # SERVIDOR HTTP SIN CIFRADO
    app.run(
        host='0.0.0.0',  # Acepta de CUALQUIER IP
        port=5000,
        debug=True  # DEBUG HABILITADO EN PRODUCCIÓN
    )
```

### ✅ LO QUE DEBERÍA SER:

```python
if __name__ == "__main__":
    import ssl
    
    # Crear contexto SSL
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(
        certfile='config/ssl/cert.pem',
        keyfile='config/ssl/key.pem'
    )
    
    # SERVIDOR HTTPS CIFRADO
    app.run(
        host='0.0.0.0',
        port=5000,
        ssl_context=context,
        debug=False  # NUNCA debug=True en producción
    )
```

---

## 3. CHROMADB SIN CIFRAR

### ❌ CÓDIGO ACTUAL (VULNERABLE):

```python
# offline_server.py - líneas ~100-120

# ChromaDB path
chroma_path = os.path.join(
    os.getenv('LOCALAPPDATA'),
    'TRAINING AI SERVER',
    'chroma_db'
)

# Inicializar ChromaDB SIN CIFRADO
client = chromadb.PersistentClient(path=chroma_path)
collection = client.get_or_create_collection(
    name="manual_embeddings"
)
```

**Problemas:**
- ✗ Archivos de DB legibles en disco
- ✗ Sin permisos restrictivos
- ✗ Sin backup cifrado
- ✗ Sin validación de integridad

### ✅ LO QUE DEBERÍA SER:

```python
from security.crypto_manager import CryptoManager

# ChromaDB path con permisos restrictivos
chroma_path = os.path.join(
    os.getenv('LOCALAPPDATA'),
    'TRAINING AI SERVER',
    'chroma_db'
)

# Establecer permisos restrictivos
set_secure_permissions(chroma_path)

# Inicializar con cifrado
crypto = CryptoManager()
client = chromadb.PersistentClient(
    path=chroma_path,
    settings=chromadb.config.Settings(
        anonymized_telemetry=False,
        allow_reset=False
    )
)

# Cifrar base de datos en reposo
crypto.encrypt_directory(chroma_path)

collection = client.get_or_create_collection(
    name="manual_embeddings",
    metadata={"encrypted": True}
)
```

---

## 4. LOGGING INSEGURO

### ❌ CÓDIGO ACTUAL (VULNERABLE):

```python
# offline_server.py - líneas dispersas

# Logging expone información sensible
print(f"[INFO] Processing query: {query_text}")
print(f"[INFO] Query results: {results}")
print(f"[INFO] User query from {request.remote_addr}: {query_text}")
print(f"[ERROR] Exception: {traceback.format_exc()}")
```

**Problemas:**
- ✗ Queries sensibles en logs
- ✗ IPs sin hash/ofuscación
- ✗ Stack traces completos
- ✗ Sin rotación de logs
- ✗ Logs accesibles sin cifrar

### ✅ LO QUE DEBERÍA SER:

```python
from security.logger import SecureLogger

logger = SecureLogger('server')

# Logging seguro (sin datos sensibles)
logger.info(f"Processing query from {hash_ip(request.remote_addr)}")
logger.info(f"Query length: {len(query_text)} chars")  # NO el contenido
logger.debug(f"Results count: {len(results)}")  # Solo metadata

# Errores sin stack traces detallados
try:
    # código
except Exception as e:
    logger.error(
        f"Query processing error",
        extra={
            'ip_hash': hash_ip(request.remote_addr),
            'error_type': type(e).__name__,
            'timestamp': datetime.now().isoformat()
        }
    )
    # NO: logger.error(traceback.format_exc())
```

---

## 5. SIN VALIDACIÓN DE INPUT

### ❌ CÓDIGO ACTUAL (VULNERABLE):

```python
# offline_server.py - línea ~320

@app.route('/index', methods=['POST'])
def index_manual():
    data = request.json
    pdf_path = data.get('pdf_path', '')
    
    # SIN VALIDACIÓN - Path Traversal vulnerable
    with open(pdf_path, 'rb') as f:
        pdf_reader = PyPDF2.PdfReader(f)
        # procesar...
```

**Problemas:**
- ✗ Sin validar path (permite ../../../system32/config)
- ✗ Sin validar tamaño de archivo
- ✗ Sin validar formato de archivo
- ✗ Sin sanitizar input JSON

### ✅ LO QUE DEBERÍA SER:

```python
from security.validators import validate_pdf_path, validate_file_size

@app.route('/index', methods=['POST'])
@require_api_key
def index_manual():
    data = request.json
    pdf_path = data.get('pdf_path', '')
    
    # VALIDAR PATH - Prevenir path traversal
    if not validate_pdf_path(pdf_path):
        abort(400, 'Invalid file path')
    
    # Verificar que archivo existe y es PDF
    if not os.path.isfile(pdf_path) or not pdf_path.endswith('.pdf'):
        abort(400, 'File must be a valid PDF')
    
    # VALIDAR TAMAÑO - Prevenir DoS
    if not validate_file_size(pdf_path, max_mb=50):
        abort(413, 'File too large (max 50MB)')
    
    # Verificar permisos de lectura
    if not os.access(pdf_path, os.R_OK):
        abort(403, 'File not accessible')
    
    try:
        with open(pdf_path, 'rb') as f:
            pdf_reader = PyPDF2.PdfReader(f)
            # procesar con seguridad...
    except Exception as e:
        log_error('index', 'PDF processing error')
        abort(500, 'Failed to process PDF')
```

---

## 6. SIN RATE LIMITING

### ❌ CÓDIGO ACTUAL (VULNERABLE):

```python
# offline_server.py - No existe rate limiting

# Cualquier IP puede hacer 1000+ requests/segundo
# Vulnerable a DoS
```

### ✅ LO QUE DEBERÍA SER:

```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

# Inicializar rate limiter
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["100 per hour"],
    storage_uri="memory://"
)

# Aplicar límites por endpoint
@app.route('/query', methods=['POST'])
@limiter.limit("10 per minute")  # Más restrictivo para queries
def query():
    # código
    pass

@app.route('/health', methods=['GET'])
@limiter.limit("60 per minute")  # Menos restrictivo para health
def health():
    # código
    pass

# Handler para cuando se excede límite
@app.errorhandler(429)
def ratelimit_handler(e):
    log_rate_limit_exceeded(request.remote_addr)
    return jsonify({
        'error': 'Rate limit exceeded',
        'retry_after': e.description
    }), 429
```

---

## 7. FIREWALL RULES PERMISIVAS

### ❌ CONFIGURACIÓN ACTUAL (VULNERABLE):

```batch
REM scripts/firewall_add.bat - Muy permisiva

netsh advfirewall firewall add rule ^
    name="TRAINING AI SERVER" ^
    dir=in action=allow ^
    protocol=TCP ^
    localport=5000
```

**Problemas:**
- ✗ Permite CUALQUIER IP remota
- ✗ Sin restricción de subnet
- ✗ Sin logging de intentos

### ✅ LO QUE DEBERÍA SER:

```batch
REM scripts/firewall_add_secure.bat - Restrictivo

REM Permitir solo desde subnet local
netsh advfirewall firewall add rule ^
    name="TRAINING AI SERVER" ^
    dir=in action=allow ^
    protocol=TCP ^
    localport=5000 ^
    remoteip=192.168.1.0/24 ^
    enable=yes ^
    profile=private

REM Logging habilitado
netsh advfirewall set allprofiles logging filename %systemroot%\system32\LogFiles\Firewall\pfirewall.log
netsh advfirewall set allprofiles logging maxfilesize 4096
netsh advfirewall set allprofiles logging droppedconnections enable
netsh advfirewall set allprofiles logging allowedconnections enable

REM Bloquear explícitamente desde internet
netsh advfirewall firewall add rule ^
    name="TRAINING AI SERVER - Block Public" ^
    dir=in action=block ^
    protocol=TCP ^
    localport=5000 ^
    profile=public
```

---

## 8. MANEJO DE ERRORES EXPONE INFORMACIÓN

### ❌ CÓDIGO ACTUAL (VULNERABLE):

```python
@app.errorhandler(Exception)
def handle_exception(e):
    # EXPONE STACK TRACE COMPLETO AL CLIENTE
    return jsonify({
        'error': str(e),
        'traceback': traceback.format_exc(),
        'type': type(e).__name__
    }), 500
```

**Expone:**
- ✗ Rutas de archivos del sistema
- ✗ Versiones de librerías
- ✗ Estructura del código
- ✗ Variables internas

### ✅ LO QUE DEBERÍA SER:

```python
@app.errorhandler(Exception)
def handle_exception(e):
    # Logging interno detallado
    logger.error(
        'Unhandled exception',
        exc_info=True,
        extra={
            'ip': hash_ip(request.remote_addr),
            'endpoint': request.endpoint,
            'method': request.method
        }
    )
    
    # Respuesta genérica al cliente (no expone detalles)
    if app.debug:
        # Solo en desarrollo local
        return jsonify({
            'error': 'Internal server error',
            'debug': str(e)
        }), 500
    else:
        # Producción - respuesta mínima
        return jsonify({
            'error': 'Internal server error',
            'request_id': generate_request_id()
        }), 500
```

---

## 9. SIN MONITOREO DE ACCESOS

### ❌ CÓDIGO ACTUAL (VULNERABLE):

```python
# No existe monitoreo
# No se sabe quién accede
# No se detectan ataques
```

### ✅ LO QUE DEBERÍA SER:

```python
# tools/ip_monitor.py

import time
from collections import defaultdict
from datetime import datetime

class AccessMonitor:
    def __init__(self):
        self.access_log = defaultdict(list)
        self.blocked_ips = set()
        self.suspicious_patterns = {
            'rapid_requests': 50,  # 50 requests en 1 min
            'failed_auth': 5,       # 5 fallos de auth
            'invalid_queries': 10   # 10 queries inválidas
        }
    
    def log_access(self, ip, endpoint, status):
        """Registrar acceso y detectar patrones sospechosos"""
        timestamp = datetime.now()
        self.access_log[ip].append({
            'timestamp': timestamp,
            'endpoint': endpoint,
            'status': status
        })
        
        # Detectar ataques
        self.detect_rapid_fire(ip)
        self.detect_port_scan(ip)
        self.detect_brute_force(ip)
    
    def detect_rapid_fire(self, ip):
        """Detectar muchos requests en poco tiempo"""
        recent = [
            a for a in self.access_log[ip]
            if (datetime.now() - a['timestamp']).seconds < 60
        ]
        
        if len(recent) > self.suspicious_patterns['rapid_requests']:
            self.block_ip(ip, reason='Rapid fire attack')
    
    def block_ip(self, ip, reason):
        """Bloquear IP maliciosa"""
        self.blocked_ips.add(ip)
        logger.warning(f"Blocked IP {ip}: {reason}")
        
        # Agregar a firewall de Windows
        os.system(f'netsh advfirewall firewall add rule name="Block {ip}" dir=in action=block remoteip={ip}')
```

---

## 📝 RESUMEN DE VULNERABILIDADES

### Críticas (CVSS 9.0-10.0):
1. ✗ Sin autenticación (cualquiera puede acceder)
2. ✗ HTTP sin cifrado (datos visibles en red)
3. ✗ Sin validación de input (injection attacks)
4. ✗ ChromaDB sin cifrar (data breach)

### Altas (CVSS 7.0-8.9):
5. ✗ Sin rate limiting (DoS fácil)
6. ✗ Error messages detallados (information disclosure)
7. ✗ Sin logging de seguridad (no detecta ataques)
8. ✗ Firewall muy permisivo (acceso desde cualquier IP)

### Medias (CVSS 4.0-6.9):
9. ✗ Sin monitoreo de accesos (ciego a ataques)
10. ✗ Sin rotación de logs (sin auditoría)

---

## 🎯 PRÓXIMOS PASOS

1. **Adjunta este documento** junto con el prompt principal
2. **Copia fragmentos relevantes** de tu código actual
3. **Explica a Claude** cuál es tu mayor preocupación
4. **Pide código corregido** con explicaciones

---

**Usa estos ejemplos para mostrar a Claude qué necesita mejorar.**

**IMPORTANTE:** Este código es INTENCIONALMENTE vulnerable para mostrar qué NO hacer. No uses este código en producción.
