# 🔐 PROMPT PARA NUEVO CHAT: SEGURIDAD DEL VR TRAINING AI SERVER

## 📋 CONTEXTO DEL PROYECTO

Soy desarrollador de **VR Training AI Server v3.2**, un sistema de asistente AI para entrenamiento en VR con Meta Quest 3. El servidor está **completamente funcional** pero necesito implementar medidas de seguridad avanzadas.

### Stack Tecnológico Actual:
- **Backend:** Python 3.11+ + Flask 3.1.0
- **AI:** Ollama (llama3.2:3b) + ChromaDB (vector database)
- **Speech:** Faster-Whisper 1.0.3
- **Plataforma:** Windows 10/11
- **Cliente:** Meta Quest 3 VR headset
- **Comunicación:** REST API sobre WiFi local (puerto 5000)

### Ubicación de Instalación:
```
C:\Program Files\TRAINING AI SERVER\
├── server\
│   ├── offline_server.py      # Flask server principal
│   ├── launcher.py             # GUI launcher
│   └── requirements.txt
└── start_server.bat

User Data:
C:\Users\[Usuario]\AppData\Local\TRAINING AI SERVER\
└── chroma_db\                  # Base de datos vectorial con embeddings
```

### Arquitectura Actual:
```
Meta Quest 3 (Client) ←→ WiFi ←→ Windows PC (Server)
                                      ↓
                          Flask API (puerto 5000)
                                      ↓
                    Ollama + ChromaDB + Whisper
```

### Endpoints API Expuestos:
- `GET /health` - Status del servidor
- `GET /test` - Endpoint de prueba
- `POST /index` - Indexar PDF manual
- `POST /query` - Query de texto
- `POST /query_audio` - Query por voz (WAV)

---

## 🎯 OBJETIVO DE ESTE NUEVO CHAT

Necesito **hardening completo de seguridad** del servidor para entorno de producción. El sistema maneja manuales técnicos confidenciales y debe ser **100% seguro** contra:

1. **Accesos no autorizados** al puerto 5000
2. **Sniffing de red** (interceptar queries/respuestas)
3. **Ataques de red** (DDoS, port scanning, injection)
4. **Extracción de datos** de ChromaDB
5. **Acceso no autorizado** a PDFs indexados
6. **Ejecución de código malicioso** vía queries

---

## 🔒 REQUERIMIENTOS DE SEGURIDAD

### 1. Autenticación y Autorización
- [ ] Sistema de **API keys** o tokens
- [ ] **Whitelist de IPs** permitidas (solo Quest 3 conocidos)
- [ ] **Rate limiting** por IP/cliente
- [ ] **Sesiones seguras** con timeout

### 2. Cifrado y Privacidad
- [ ] **HTTPS/TLS** en lugar de HTTP
- [ ] Cifrado de **datos en reposo** (ChromaDB)
- [ ] **Ofuscación** de respuestas sensibles
- [ ] **Logs seguros** (sin exponer datos confidenciales)

### 3. Protección de Red
- [ ] **Firewall rules** más estrictas
- [ ] **Detección de port scanning**
- [ ] **Bloqueo automático** de IPs sospechosas
- [ ] **VPN opcional** para conexión Quest 3

### 4. Monitoreo y Auditoría
- [ ] **Logger de accesos** con timestamp e IP
- [ ] **Dashboard de monitoreo** en tiempo real
- [ ] **Alertas** de intentos de acceso no autorizado
- [ ] **Registro de queries** para auditoría

### 5. Validación de Input
- [ ] **Sanitización** de queries de texto
- [ ] **Validación** de archivos WAV
- [ ] **Prevención de SQL/NoSQL injection**
- [ ] **Límites de tamaño** en requests

### 6. Protección de Datos
- [ ] **Encriptación de ChromaDB** en disco
- [ ] **Permisos restrictivos** de archivos
- [ ] **Borrado seguro** de datos temporales
- [ ] **Backup cifrado** de la base de datos

---

## 🛠️ HERRAMIENTAS A DESARROLLAR

### Tool 1: IP Monitoring Dashboard
**Funcionalidad:**
- Ver IPs conectadas en tiempo real
- Historial de accesos por IP
- Geolocalización de IPs (si no es local, bloquear)
- Estadísticas de uso por cliente

### Tool 2: Security Scanner
**Funcionalidad:**
- Verificar configuración de firewall
- Escanear puertos abiertos
- Verificar permisos de archivos
- Chequear vulnerabilidades conocidas
- Report de seguridad PDF

### Tool 3: Network Sniffer
**Funcionalidad:**
- Capturar tráfico del puerto 5000
- Detectar patrones sospechosos
- Alertar de queries anómalas
- Log de intentos de ataque

### Tool 4: Access Control Manager
**Funcionalidad:**
- Gestionar whitelist de IPs
- Generar/revocar API keys
- Configurar rate limits
- Ver intentos bloqueados

### Tool 5: Encryption Manager
**Funcionalidad:**
- Cifrar/descifrar ChromaDB
- Gestionar certificados TLS
- Generar claves seguras
- Verificar integridad de datos

---

## 📝 IMPLEMENTACIONES ESPECÍFICAS REQUERIDAS

### Prioridad Alta:

1. **Implementar HTTPS con certificado autofirmado**
   - Usar Flask-Tls o similar
   - Generar certificado para red local
   - Configurar Quest 3 para aceptar cert

2. **Sistema de API Keys**
   - Generar keys únicas por dispositivo
   - Header: `Authorization: Bearer <key>`
   - Almacenar hashes, no plaintext
   - Expiración automática

3. **Whitelist de IPs**
   - Archivo de configuración con IPs permitidas
   - Middleware en Flask para verificar
   - Bloqueo inmediato si no está en whitelist
   - Log de intentos bloqueados

4. **Rate Limiting**
   - Límite: 10 requests/minuto por IP
   - Bloqueo temporal después de exceder
   - Diferente límite para /query (más restrictivo)

5. **Logger de Accesos**
   - Formato: `[timestamp] [IP] [endpoint] [status] [user-agent]`
   - Rotar logs diarios
   - Dashboard web para ver logs

### Prioridad Media:

6. **Encryption de ChromaDB**
   - Usar SQLCipher o similar
   - Cifrar archivos de la base de datos
   - Key management seguro

7. **Input Validation**
   - Sanitizar queries con regex
   - Validar formato WAV
   - Límites de tamaño
   - Prevenir path traversal en /index

8. **Firewall Automation**
   - Script para auto-bloquear IPs sospechosas
   - Integración con Windows Firewall
   - Desbloqueo automático después de X horas

### Prioridad Baja:

9. **VPN Integration**
   - Opción para usar WireGuard/OpenVPN
   - Quest 3 conecta vía VPN
   - Servidor solo acepta conexiones VPN

10. **Intrusion Detection System (IDS)**
    - Detectar patrones de ataque
    - Honeypot endpoints
    - Alertas por email/SMS

---

## 🚨 VULNERABILIDADES ACTUALES CONOCIDAS

### Críticas:
1. **HTTP sin cifrado** - Tráfico visible en red local
2. **Sin autenticación** - Cualquiera en WiFi puede acceder
3. **Puerto 5000 abierto** - Fácil de escanear
4. **Sin rate limiting** - Vulnerable a DoS
5. **ChromaDB sin cifrar** - Datos legibles en disco

### Importantes:
6. **Logs verbosos** - Exponen información sensible
7. **Sin validación de input** - Posible injection
8. **Sin monitoreo** - Ataques pasan desapercibidos
9. **Error messages detallados** - Info leak a atacantes
10. **Sin backup cifrado** - Pérdida de datos sensibles

---

## 💡 CASOS DE USO DE SEGURIDAD

### Escenario 1: Ataque de Fuerza Bruta
**Ataque:** Script automatizado intenta queries masivos
**Mitigación:** Rate limiting + IP blocking + CAPTCHA-like challenge

### Escenario 2: Man-in-the-Middle
**Ataque:** Interceptar WiFi y capturar queries/respuestas
**Mitigación:** HTTPS + Certificate pinning en Quest 3

### Escenario 3: Acceso No Autorizado
**Ataque:** Empleado no autorizado intenta conectarse
**Mitigación:** API keys + Whitelist + Alertas

### Escenario 4: Exfiltración de Datos
**Ataque:** Extraer base de datos ChromaDB del disco
**Mitigación:** Encryption at rest + File permissions + Auditoría

### Escenario 5: Injection Attack
**Ataque:** Query malicioso intenta ejecutar código
**Mitigación:** Input sanitization + Prepared statements + Sandboxing

---

## 📊 MÉTRICAS DE SEGURIDAD A IMPLEMENTAR

### KPIs de Seguridad:
- **Uptime seguro:** >99.9%
- **Tiempo de respuesta a incidentes:** <5 minutos
- **Intentos de acceso bloqueados/día:** Registrar todos
- **False positives:** <1%
- **Tiempo de recuperación:** <1 hora

### Logging Detallado:
```
[2026-01-16 10:23:45] [192.168.1.100] [GET /health] [200] [Quest3-Device-001]
[2026-01-16 10:24:12] [192.168.1.100] [POST /query] [200] [Quest3-Device-001]
[2026-01-16 10:24:30] [192.168.1.255] [GET /health] [403] [BLOCKED - Not in whitelist]
[2026-01-16 10:25:01] [10.0.0.50] [PORT SCAN DETECTED] [BLOCKED] [Unknown]
```

---

## 🔧 STACK TÉCNICO PARA SEGURIDAD

### Librerías Recomendadas (Python):
- `flask-limiter` - Rate limiting
- `flask-talisman` - Security headers
- `cryptography` - Cifrado/descifrado
- `pycryptodome` - Crypto avanzado
- `itsdangerous` - Token seguro
- `scapy` - Network sniffing
- `watchdog` - File monitoring
- `python-iptables` - Firewall management

### Herramientas Externas:
- **Wireshark** - Análisis de tráfico
- **nmap** - Port scanning (pentesting propio)
- **Fail2Ban** - Auto-block IPs
- **OpenSSL** - Certificados TLS
- **SQLCipher** - Encrypt SQLite

---

## 📖 ENTREGABLES ESPERADOS

Por favor, ayúdame a desarrollar:

1. **Código Python mejorado** con todas las mitigaciones de seguridad
2. **Scripts de herramientas** (IP monitor, scanner, etc.)
3. **Archivo de configuración** security_config.yaml con todos los settings
4. **Documentación** de seguridad (PDF/DOCX)
5. **Checklist** de hardening para verificar
6. **Testing scripts** para verificar cada medida de seguridad
7. **Guía de respuesta a incidentes** para el equipo

---

## 🎯 ENFOQUE DESEADO

- **Pragmático:** Soluciones implementables en Windows, no solo teoría
- **Completo:** Cubrir TODAS las vulnerabilidades, no solo las obvias
- **Automatizado:** Scripts y tools que hagan el trabajo, no solo configs manuales
- **Documentado:** Explicaciones claras de por qué cada medida es necesaria
- **Testeable:** Forma de verificar que cada medida funciona

---

## ⚠️ RESTRICCIONES Y CONSIDERACIONES

1. **Entorno Windows:** Todas las soluciones deben funcionar en Windows 10/11
2. **Performance:** No degradar tiempos de respuesta >10%
3. **Usabilidad:** El usuario final (operador de VR) no debe notar la seguridad
4. **Compatibilidad:** Debe seguir funcionando con Quest 3 sin cambios mayores
5. **Mantenibilidad:** Código limpio, comentado, fácil de actualizar

---

## 📞 PREGUNTAS INICIALES PARA CLAUDE

Por favor comienza respondiendo:

1. **¿Cuál es la vulnerabilidad más crítica que debo abordar primero?**
2. **¿Recomiendas HTTPS con cert autofirmado o hay mejor opción para red local?**
3. **¿Cuál es la mejor forma de implementar API keys sin BD compleja?**
4. **¿Qué herramienta de las 5 propuestas debería desarrollar primero?**
5. **¿Hay alguna vulnerabilidad que no haya considerado?**

Luego, proporciona:
- Plan de implementación paso a paso (priorizado)
- Código de ejemplo para las 3 medidas más críticas
- Script de una de las herramientas de monitoreo

---

## 📂 ARCHIVOS DEL PROYECTO ACTUAL

Adjuntaré en el chat:
- `offline_server.py` - Servidor actual sin seguridad
- `launcher.py` - GUI launcher
- `requirements.txt` - Dependencias actuales
- `README.md` - Documentación actual

---

**Versión del Proyecto:** 3.2.0  
**Fecha:** Enero 2026  
**Prioridad:** Alta - Producción en 2 semanas  
**Presupuesto de Tiempo:** 3-5 días para implementación completa

---

¡Gracias por tu ayuda con la seguridad del VR Training AI Server! 🔐
