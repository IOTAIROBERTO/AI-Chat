import sys
import os
import time
from datetime import datetime

# Add the current directory to path
sys.path.append(os.getcwd())

print("Starting diagnosis...")

try:
    import offline_server
    print("Module imported successfully.")
except ImportError as e:
    print(f"Failed to import offline_server: {e}")
    sys.exit(1)

print(f"Default model: {offline_server.DEFAULT_OLLAMA_MODEL}")
print(f"Config file: {offline_server.CONFIG_FILE}")

# Mock print to capture output if needed, but standard print is fine for now
# Run initialization
print("\nRunning initialize_components()...")
try:
    start = time.time()
    success = offline_server.initialize_components()
    end = time.time()
    print(f"\nInitialization finished in {end - start:.2f}s")
    print(f"Success: {success}")
    
    if success:
        print(f"Active model: {offline_server.current_ollama_model}")
        print(f"Indexed manuals: {len(offline_server.indexed_manuals)}")
    else:
        print("Initialization returned False.")

except Exception as e:
    print(f"\nEXCEPTION during initialization: {e}")
    import traceback
    traceback.print_exc()

print("\nChecking port...")
try:
    available = offline_server.check_port_available(offline_server.SERVER_PORT)
    print(f"Port {offline_server.SERVER_PORT} available: {available}")
except Exception as e:
    print(f"Port check failed: {e}")
