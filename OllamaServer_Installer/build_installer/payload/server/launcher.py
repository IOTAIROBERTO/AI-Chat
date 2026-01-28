#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VR Manual Server - GUI Launcher v6.2 FIXED
BILINGUAL EDITION (Spanish/English)
FIX: HTTP/HTTPS protocol detection + encoding issues resolved
"""

import sys
import os
import subprocess
import threading
import socket
import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import time
from pathlib import Path
import tkinter as tk
from tkinter import ttk, scrolledtext, filedialog, messagebox
import json

# BILINGUAL MODELS ONLY (Spanish/English native support)
RECOMMENDED_MODELS = {
    # === TIER 1: ESENCIALES (Descarga ESTOS) ===
    'qwen2.5:1.5b': {
        'size': '1.0 GB',
        'speed': '⚡⚡⚡⚡⚡',
        'quality': '⭐⭐⭐⭐⭐',
        'spanish': '96% native',
        'english': '98% native',
        'description': '🔥 BEST - Default for VR/RAG',
        'recommended': True,
        'category': 'Default'
    },
    'qwen2.5:3b': {
        'size': '1.9 GB',
        'speed': '⚡⚡⚡⚡',
        'quality': '⭐⭐⭐⭐⭐',
        'spanish': '98% native',
        'english': '99% native',
        'description': '⭐ PREMIUM - Best quality for RAG',
        'recommended': True,
        'category': 'Quality'
    },
    'granite3.1-dense:2b': {
        'size': '1.3 GB',
        'speed': '⚡⚡⚡⚡⚡',
        'quality': '⭐⭐⭐⭐',
        'spanish': '88% good',
        'english': '96% native',
        'description': '🏢 IBM - Optimized specifically for RAG',
        'recommended': True,
        'category': 'RAG Optimized'
    },
    
    # === TIER 2: OPCIONALES (Si tienes espacio/necesitas) ===
    'gemma2:2b': {
        'size': '1.6 GB',
        'speed': '⚡⚡⚡⚡',
        'quality': '⭐⭐⭐⭐',
        'spanish': '90% good',
        'english': '95% native',
        'description': '💎 GOOGLE - Excellent reasoning for manuals',
        'recommended': True,
        'category': 'Balanced'
    },
    'qwen2.5:7b': {
        'size': '4.4 GB',
        'speed': '⚡⚡',
        'quality': '⭐⭐⭐⭐⭐',
        'spanish': '99% native',
        'english': '99% native',
        'description': '💎 ULTIMATE - Best quality (slower, desktop only)',
        'recommended': False,
        'category': 'Premium'
    },
}

class ServerLauncher:
    def __init__(self, root):
        self.root = root
        self.root.title("VR Training AI Server v6.2 - Bilingual Edition")
        
        screen_width = root.winfo_screenwidth()
        screen_height = root.winfo_screenheight()
        
        window_width = min(1000, int(screen_width * 0.85))
        window_height = min(850, int(screen_height * 0.9))
        
        x = (screen_width - window_width) // 2
        y = (screen_height - window_height) // 2
        
        self.root.geometry(f"{window_width}x{window_height}+{x}+{y}")
        self.root.resizable(True, True)
        self.root.minsize(900, 700)
        
        self.server_process = None
        self.server_running = False
        self.selected_pdf = None
        self.indexing_in_progress = False
        self.indexed_manuals = {}
        
        self.available_models = {}
        self.current_model = None
        self.downloading_model = None
        
        # Auto-detect protocol (HTTP or HTTPS)
        self.server_protocol = "http"  # Default to HTTP
        self.server_url = f"{self.server_protocol}://localhost:5000"
        self.server_ip = "localhost"
        self.server_port = "5000"
        
        if getattr(sys, 'frozen', False):
            self.script_dir = Path(sys.executable).parent
        else:
            self.script_dir = Path(__file__).parent
        
        self.server_script = self.script_dir / "offline_server.py"
        self.config_file = self.script_dir / "server_config.json"
        
        self.load_config()
        self.create_widgets()
        self.update_status()
        
        self.auto_refresh_manuals()
        self.auto_refresh_models()
        
    def detect_server_protocol(self):
        """Auto-detect if server is using HTTP or HTTPS"""
        for protocol in ['https', 'http']:
            try:
                url = f"{protocol}://localhost:5000/health"
                response = requests.get(url, timeout=2, verify=False)
                if response.status_code == 200:
                    self.server_protocol = protocol
                    self.server_url = f"{protocol}://localhost:5000"
                    self.log(f"ℹ️ Server protocol detected: {protocol.upper()}")
                    return True
            except:
                continue
        return False
        
    def load_config(self):
        """Load server configuration"""
        try:
            if self.config_file.exists():
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    self.current_model = config.get('current_model', 'qwen2.5:1.5b')
            else:
                self.current_model = 'qwen2.5:1.5b'
        except:
            self.current_model = 'qwen2.5:1.5b'
    
    def save_config(self):
        """Save server configuration"""
        try:
            config = {
                'current_model': self.current_model,
                'last_updated': time.strftime("%Y-%m-%d %H:%M:%S")
            }
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
        except Exception as e:
            self.log(f"⚠ Warning: Could not save config: {e}")
    
    def create_widgets(self):
        """Create UI widgets"""
        
        # Header
        header = tk.Frame(self.root, bg="#0066cc", height=90)
        header.pack(fill=tk.X)
        header.pack_propagate(False)
        
        logo_container = tk.Frame(header, bg="#0066cc")
        logo_container.pack(expand=True)
        
        logo_frame = tk.Frame(logo_container, bg="#0066cc")
        logo_frame.pack(side=tk.LEFT, padx=(0, 15))
        
        icon = tk.Label(logo_frame, text="🎓", font=("Arial", 35), bg="#0066cc", fg="white")
        icon.pack()
        
        text_frame = tk.Frame(logo_container, bg="#0066cc")
        text_frame.pack(side=tk.LEFT)
        
        title = tk.Label(
            text_frame,
            text="VR TRAINING AI SERVER",
            font=("Arial", 16, "bold"),
            bg="#0066cc",
            fg="white"
        )
        title.pack(anchor=tk.W)
        
        subtitle = tk.Label(
            text_frame,
            text="Bilingual AI Assistant (Español/English)",
            font=("Arial", 9),
            bg="#0066cc",
            fg="#ccddff"
        )
        subtitle.pack(anchor=tk.W)
        
        # Main container
        main = tk.Frame(self.root)
        main.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # AI MODELS SECTION
        models_frame = tk.LabelFrame(main, text="🌐 AI Models (Bilingual: ES/EN)", padx=8, pady=6)
        models_frame.pack(fill=tk.BOTH, expand=False, pady=(0, 5))
        
        current_model_frame = tk.Frame(models_frame)
        current_model_frame.pack(fill=tk.X, pady=(0, 5))
        
        tk.Label(
            current_model_frame,
            text="Active Model:",
            font=("Arial", 9, "bold")
        ).pack(side=tk.LEFT)
        
        self.current_model_label = tk.Label(
            current_model_frame,
            text=self.current_model,
            font=("Arial", 10, "bold"),
            fg="#2196F3"
        )
        self.current_model_label.pack(side=tk.LEFT, padx=(5, 0))
        
        if self.current_model in RECOMMENDED_MODELS:
            model_info = RECOMMENDED_MODELS[self.current_model]
            info_text = f"ES: {model_info['spanish']} | EN: {model_info['english']}"
            tk.Label(
                current_model_frame,
                text=info_text,
                font=("Arial", 8),
                fg="#666"
            ).pack(side=tk.LEFT, padx=(10, 0))
        
        model_select_frame = tk.Frame(models_frame)
        model_select_frame.pack(fill=tk.X, pady=(0, 5))
        
        tk.Label(
            model_select_frame,
            text="Switch to:",
            font=("Arial", 9)
        ).pack(side=tk.LEFT)
        
        self.model_combo = ttk.Combobox(
            model_select_frame,
            state='readonly',
            width=25,
            font=("Arial", 9)
        )
        self.model_combo.pack(side=tk.LEFT, padx=(5, 5), fill=tk.X, expand=True)
        self.model_combo.bind('<<ComboboxSelected>>', self.on_model_selected)
        
        tk.Button(
            model_select_frame,
            text="🔄 Refresh",
            command=self.refresh_models_list,
            width=8,
            font=("Arial", 8)
        ).pack(side=tk.LEFT, padx=(0, 3))
        
        tk.Button(
            model_select_frame,
            text="🗑️ Delete",
            command=self.delete_selected_model,
            bg="#f44336",
            fg="white",
            width=8,
            font=("Arial", 8)
        ).pack(side=tk.LEFT)
        
        download_frame = tk.Frame(models_frame)
        download_frame.pack(fill=tk.X)
        
        tk.Label(
            download_frame,
            text="Download:",
            font=("Arial", 9)
        ).pack(side=tk.LEFT)
        
        self.download_combo = ttk.Combobox(
            download_frame,
            state='readonly',
            width=20,
            font=("Arial", 9)
        )
        self.download_combo.pack(side=tk.LEFT, padx=(5, 5), fill=tk.X, expand=True)
        
        model_list = []
        for model_name, info in RECOMMENDED_MODELS.items():
            if info['recommended']:
                label = f"⭐ {model_name} ({info['size']}) - {info['category']}"
                model_list.append(label)
        
        for model_name, info in RECOMMENDED_MODELS.items():
            if not info['recommended']:
                label = f"{model_name} ({info['size']}) - {info['category']}"
                model_list.append(label)
        
        self.download_combo['values'] = model_list
        
        tk.Button(
            download_frame,
            text="⬇ Download",
            command=self.download_selected_model,
            bg="#4CAF50",
            fg="white",
            font=("Arial", 9, "bold"),
            width=10
        ).pack(side=tk.LEFT, padx=(0, 3))
        
        tk.Button(
            download_frame,
            text="ℹ Info",
            command=self.show_models_info,
            bg="#2196F3",
            fg="white",
            font=("Arial", 9),
            width=6
        ).pack(side=tk.LEFT)
        
        self.download_progress_frame = tk.Frame(models_frame)
        
        self.download_progress_label = tk.Label(
            self.download_progress_frame,
            text="",
            font=("Arial", 8),
            fg="#666"
        )
        self.download_progress_label.pack()
        
        self.download_progress_bar = ttk.Progressbar(
            self.download_progress_frame,
            mode='indeterminate'
        )
        self.download_progress_bar.pack(fill=tk.X)
        
        # STATUS
        status_frame = tk.LabelFrame(main, text="Server Status", padx=8, pady=4)
        status_frame.pack(fill=tk.X, pady=(0, 5))
        
        status_info = tk.Frame(status_frame)
        status_info.pack(fill=tk.X)
        
        self.status_label = tk.Label(
            status_info,
            text="● Stopped",
            font=("Arial", 11, "bold"),
            fg="red"
        )
        self.status_label.pack(side=tk.LEFT)
        
        self.ip_label = tk.Label(
            status_info,
            text="IP: Not running",
            font=("Arial", 9),
            fg="#666"
        )
        self.ip_label.pack(side=tk.LEFT, padx=(15, 0))
        
        # CONTROL BUTTONS
        btn_frame = tk.Frame(status_frame)
        btn_frame.pack(fill=tk.X, pady=(5, 0))
        
        self.btn_start = tk.Button(
            btn_frame,
            text="▶ Start Server",
            command=self.start_server,
            bg="#4CAF50",
            fg="white",
            font=("Arial", 10, "bold"),
            width=15,
            height=1
        )
        self.btn_start.pack(side=tk.LEFT, padx=(0, 5))
        
        self.btn_stop = tk.Button(
            btn_frame,
            text="⏹ Stop Server",
            command=self.stop_server,
            bg="#f44336",
            fg="white",
            font=("Arial", 10, "bold"),
            width=15,
            height=1,
            state=tk.DISABLED
        )
        self.btn_stop.pack(side=tk.LEFT, padx=(0, 5))
        
        tk.Button(
            btn_frame,
            text="🔍 Test Connection",
            command=self.test_connection,
            bg="#2196F3",
            fg="white",
            font=("Arial", 9),
            width=15
        ).pack(side=tk.LEFT)
        
        # MANUALS SECTION
        manuals_frame = tk.LabelFrame(main, text="📚 Indexed Manuals", padx=8, pady=6)
        manuals_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 5))
        
        self.manuals_info_label = tk.Label(
            manuals_frame,
            text="No manuals",
            font=("Arial", 9),
            fg="#666"
        )
        self.manuals_info_label.pack(anchor=tk.W, pady=(0, 3))
        
        manuals_scroll_frame = tk.Frame(manuals_frame)
        manuals_scroll_frame.pack(fill=tk.BOTH, expand=True)
        
        scrollbar = tk.Scrollbar(manuals_scroll_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.manuals_listbox = tk.Listbox(
            manuals_scroll_frame,
            font=("Consolas", 9),
            yscrollcommand=scrollbar.set,
            height=8,
            selectmode=tk.EXTENDED
        )
        self.manuals_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.manuals_listbox.yview)
        
        self.manuals_listbox.bind('<Button-3>', self.show_context_menu)
        
        manuals_btn_frame = tk.Frame(manuals_frame)
        manuals_btn_frame.pack(fill=tk.X, pady=(5, 0))
        
        tk.Button(
            manuals_btn_frame,
            text="🔄 Refresh",
            command=self.refresh_manuals_list,
            font=("Arial", 8),
            width=12
        ).pack(side=tk.LEFT, padx=(0, 3))
        
        tk.Button(
            manuals_btn_frame,
            text="🗑️ Clear All",
            command=self.clear_all_database,
            bg="#ff9800",
            fg="white",
            font=("Arial", 8),
            width=12
        ).pack(side=tk.LEFT)
        
        # PDF INDEXING SECTION
        pdf_frame = tk.LabelFrame(main, text="📄 Index New Manual", padx=8, pady=6)
        pdf_frame.pack(fill=tk.X, pady=(0, 5))
        
        pdf_select_frame = tk.Frame(pdf_frame)
        pdf_select_frame.pack(fill=tk.X)
        
        self.pdf_label = tk.Label(
            pdf_select_frame,
            text="No file selected",
            font=("Arial", 9),
            fg="#666",
            anchor=tk.W
        )
        self.pdf_label.pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        tk.Button(
            pdf_select_frame,
            text="📁 Browse",
            command=self.browse_pdf,
            font=("Arial", 9),
            width=10
        ).pack(side=tk.LEFT, padx=(5, 0))
        
        tk.Button(
            pdf_select_frame,
            text="📥 Index",
            command=self.index_manual,
            bg="#4CAF50",
            fg="white",
            font=("Arial", 9, "bold"),
            width=10
        ).pack(side=tk.LEFT, padx=(5, 0))
        
        self.progress_frame = tk.Frame(pdf_frame)
        
        self.progress_label = tk.Label(
            self.progress_frame,
            text="Ready",
            font=("Arial", 8),
            fg="#666"
        )
        self.progress_label.pack()
        
        self.progress_bar = ttk.Progressbar(
            self.progress_frame,
            mode='determinate'
        )
        self.progress_bar.pack(fill=tk.X)
        
        # LOG SECTION
        log_frame = tk.LabelFrame(main, text="📋 Activity Log", padx=8, pady=6)
        log_frame.pack(fill=tk.BOTH, expand=True)
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            font=("Consolas", 9),
            height=8,
            wrap=tk.WORD
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        log_btn_frame = tk.Frame(log_frame)
        log_btn_frame.pack(fill=tk.X, pady=(5, 0))
        
        tk.Button(
            log_btn_frame,
            text="🗑️ Clear Log",
            command=self.clear_log,
            font=("Arial", 8),
            width=12
        ).pack(side=tk.LEFT)
        
        tk.Button(
            log_btn_frame,
            text="💾 Save Log",
            command=self.save_log_to_file,
            bg="#2196F3",
            fg="white",
            font=("Arial", 8),
            width=12
        ).pack(side=tk.LEFT, padx=(5, 0))
        
        # Initial log message
        self.log("🎓 VR Training AI Server v6.2 - Ready")
        self.log("ℹ️ Click 'Start Server' to begin")
    
    def log(self, message):
        """Add message to log"""
        timestamp = time.strftime("%H:%M:%S")
        self.log_text.insert(tk.END, f"[{timestamp}] {message}\n")
        self.log_text.see(tk.END)
    
    def update_progress(self, value, text=""):
        """Update progress bar"""
        self.progress_bar['value'] = value
        if text:
            self.progress_label.config(text=text)
        self.root.update()
    
    def reset_progress(self):
        """Reset progress bar"""
        self.progress_bar['value'] = 0
        self.progress_label.config(text="Ready")
        self.progress_frame.pack_forget()
    
    def refresh_models_list(self, silent=False):
        """Refresh available models from Ollama"""
        def do_refresh():
            try:
                result = subprocess.run(
                    ['ollama', 'list'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if result.returncode == 0:
                    self.available_models = {}
                    for line in result.stdout.strip().split('\n')[1:]:
                        if line.strip():
                            parts = line.split()
                            if parts:
                                model_name = parts[0]
                                self.available_models[model_name] = True
                    
                    self.root.after(0, self.update_model_combo)
                    if not silent:
                        self.log(f"✓ Found {len(self.available_models)} models")
            except FileNotFoundError:
                if not silent:
                    self.log("⚠ Ollama not installed")
            except Exception as e:
                if not silent:
                    self.log(f"⚠ Error: {e}")
        
        threading.Thread(target=do_refresh, daemon=True).start()
    
    def update_model_combo(self):
        model_names = list(self.available_models.keys())
        self.model_combo['values'] = model_names
        
        if self.current_model in model_names:
            self.model_combo.set(self.current_model)
        elif model_names:
            self.model_combo.set(model_names[0])
    
    def on_model_selected(self, event=None):
        selected = self.model_combo.get()
        if not selected or selected == self.current_model:
            return
        
        result = messagebox.askyesno(
            "Switch Model",
            f"Switch to '{selected}'?\n\nNo restart needed."
        )
        
        if result:
            self.switch_model(selected)
    
    def switch_model(self, model_name):
        self.log(f"🔄 Switching to: {model_name}...")
        
        try:
            if self.server_running:
                response = requests.post(
                    f"{self.server_url}/switch_model",
                    json={"model_name": model_name},
                    timeout=5,
                    verify=False
                )
                
                if response.status_code == 200:
                    self.current_model = model_name
                    self.current_model_label.config(text=model_name)
                    self.save_config()
                    self.log(f"✓ Now using: {model_name}")
                    messagebox.showinfo("Success", f"Switched to {model_name}")
                else:
                    error = response.json().get('error', 'Unknown')
                    self.log(f"✗ Failed: {error}")
                    messagebox.showerror("Error", error)
            else:
                self.current_model = model_name
                self.current_model_label.config(text=model_name)
                self.save_config()
                self.log(f"✓ Set to: {model_name} (will activate on start)")
                messagebox.showinfo("Success", f"Model set to {model_name}")
                
        except Exception as e:
            self.log(f"✗ Error: {e}")
            messagebox.showerror("Error", str(e))
    
    def download_selected_model(self):
        selected = self.download_combo.get()
        if not selected:
            messagebox.showwarning("No Selection", "Select a model first")
            return
        
        model_name = selected.split(' (')[0].replace('⭐ ', '')
        
        if model_name in self.available_models:
            messagebox.showinfo("Already Downloaded", f"'{model_name}' already installed")
            return
        
        if model_name in RECOMMENDED_MODELS:
            info = RECOMMENDED_MODELS[model_name]
            result = messagebox.askyesno(
                "Download Model",
                f"Download: {model_name}\n\n"
                f"Size: {info['size']}\n"
                f"Spanish: {info['spanish']}\n"
                f"English: {info['english']}\n\n"
                f"{info['description']}\n\n"
                "Continue?"
            )
            
            if not result:
                return
        
        self.log(f"⬇ Downloading {model_name}...")
        self.downloading_model = model_name
        
        self.download_progress_frame.pack(fill=tk.X, pady=(5, 0))
        self.download_progress_label.config(text=f"Downloading {model_name}... 0%")
        self.download_progress_bar['mode'] = 'determinate'
        self.download_progress_bar['value'] = 0
        
        def parse_progress(line):
            """Parse Ollama download progress from output"""
            try:
                # Ollama outputs: "pulling manifest... 100%"
                # or "downloading... 50%"
                if '%' in line:
                    parts = line.split()
                    for part in parts:
                        if '%' in part:
                            percent = int(part.replace('%', ''))
                            return percent
            except:
                pass
            return None
        
        def do_download():
            try:
                # FIXED: Use utf-8 encoding and errors='ignore' to handle Ollama's special characters
                process = subprocess.Popen(
                    ['ollama', 'pull', model_name],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    encoding='utf-8',
                    errors='ignore',  # Ignore problematic characters instead of crashing
                    bufsize=1
                )
                
                last_progress = 0
                for line in iter(process.stdout.readline, ''):
                    if not line:
                        break
                    
                    # Update progress bar
                    progress = parse_progress(line)
                    if progress is not None and progress != last_progress:
                        last_progress = progress
                        self.root.after(0, lambda p=progress: self.download_progress_bar.config(value=p))
                        self.root.after(0, lambda p=progress: self.download_progress_label.config(
                            text=f"Downloading {model_name}... {p}%"
                        ))
                    
                    # Log important lines
                    line_lower = line.lower().strip()
                    if any(word in line_lower for word in ['pulling', 'downloading', 'verifying', 'success']):
                        self.root.after(0, lambda l=line.strip(): self.log(f"  {l}"))
                
                process.wait()
                
                if process.returncode == 0:
                    self.log(f"✓ Downloaded: {model_name}")
                    self.root.after(0, lambda: self.on_download_complete(model_name, True))
                else:
                    self.log(f"✗ Download failed")
                    self.root.after(0, lambda: self.on_download_complete(model_name, False))
                    
            except Exception as e:
                self.log(f"✗ Error: {e}")
                self.root.after(0, lambda: self.on_download_complete(model_name, False))
        
        threading.Thread(target=do_download, daemon=True).start()
    
    def on_download_complete(self, model_name, success):
        self.download_progress_bar.stop()
        self.download_progress_frame.pack_forget()
        self.downloading_model = None
        
        if success:
            messagebox.showinfo("Success", f"'{model_name}' downloaded!")
            self.refresh_models_list()
        else:
            messagebox.showerror("Error", f"Failed to download '{model_name}'")
    
    def delete_selected_model(self):
        """Delete selected model from Ollama"""
        selected = self.model_combo.get()
        if not selected:
            messagebox.showwarning("No Selection", "Select a model to delete first")
            return
        
        # Don't allow deleting the active model
        if selected == self.current_model:
            messagebox.showerror(
                "Cannot Delete Active Model",
                f"'{selected}' is currently active.\n\n"
                "Switch to another model first before deleting."
            )
            return
        
        # Confirm deletion
        if selected in RECOMMENDED_MODELS:
            info = RECOMMENDED_MODELS[selected]
            msg = (
                f"Delete model: {selected}\n\n"
                f"Size: {info['size']}\n"
                f"Category: {info['category']}\n\n"
                "This will free up disk space but you'll need to\n"
                "download it again if you want to use it later.\n\n"
                "Continue?"
            )
        else:
            msg = f"Delete model: {selected}\n\nCannot be undone. Continue?"
        
        result = messagebox.askyesno("Confirm Delete Model", msg)
        if not result:
            return
        
        self.log(f"🗑️ Deleting model: {selected}...")
        
        def do_delete():
            try:
                result = subprocess.run(
                    ['ollama', 'rm', selected],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    self.log(f"✓ Deleted: {selected}")
                    self.root.after(0, lambda: messagebox.showinfo("Success", f"Model '{selected}' deleted!"))
                    self.root.after(0, self.refresh_models_list)
                else:
                    error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                    self.log(f"✗ Delete failed: {error_msg}")
                    self.root.after(0, lambda: messagebox.showerror("Error", f"Failed to delete model:\n{error_msg}"))
                    
            except Exception as e:
                self.log(f"✗ Error: {e}")
                self.root.after(0, lambda: messagebox.showerror("Error", str(e)))
        
        threading.Thread(target=do_delete, daemon=True).start()
    
    def show_models_info(self):
        info_window = tk.Toplevel(self.root)
        info_window.title("Bilingual Models Info")
        info_window.geometry("700x500")
        
        header = tk.Label(
            info_window,
            text="Bilingual AI Models (Spanish/English)",
            font=("Arial", 12, "bold"),
            bg="#2196F3",
            fg="white",
            pady=10
        )
        header.pack(fill=tk.X)
        
        text_widget = scrolledtext.ScrolledText(
            info_window,
            font=("Consolas", 9),
            wrap=tk.WORD,
            padx=10,
            pady=10
        )
        text_widget.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        info_text = "📊 BILINGUAL MODELS FOR VR (ES/EN ONLY)\n"
        info_text += "=" * 70 + "\n\n"
        
        info_text += "🔥 RECOMMENDED MODELS\n"
        info_text += "-" * 70 + "\n"
        for model_name, info in RECOMMENDED_MODELS.items():
            if info['recommended']:
                info_text += f"\n【{model_name}】 - {info['category']}\n"
                info_text += f"  Size:     {info['size']}\n"
                info_text += f"  Speed:    {info['speed']}\n"
                info_text += f"  Quality:  {info['quality']}\n"
                info_text += f"  Spanish:  {info['spanish']}\n"
                info_text += f"  English:  {info['english']}\n"
                info_text += f"  Info:     {info['description']}\n"
        
        info_text += "\n\n📦 OTHER MODELS\n"
        info_text += "-" * 70 + "\n"
        for model_name, info in RECOMMENDED_MODELS.items():
            if not info['recommended']:
                info_text += f"\n【{model_name}】 - {info['category']}\n"
                info_text += f"  Size:     {info['size']}\n"
                info_text += f"  Speed:    {info['speed']}\n"
                info_text += f"  Spanish:  {info['spanish']}\n"
                info_text += f"  English:  {info['english']}\n"
                info_text += f"  Info:     {info['description']}\n"
        
        info_text += "\n\n" + "=" * 70 + "\n"
        info_text += "💡 RECOMMENDATIONS:\n\n"
        info_text += "🥇 BEST DEFAULT: qwen2.5:1.5b\n"
        info_text += "   • Fastest bilingual model\n"
        info_text += "   • Native Spanish & English\n"
        info_text += "   • Replaces llama3.2:3b (2x faster)\n\n"
        
        info_text += "🥈 BEST QUALITY: qwen2.5:3b\n"
        info_text += "   • Maximum accuracy\n"
        info_text += "   • Technical manuals\n\n"
        
        info_text += "🥉 FASTEST: llama3.2:1b\n"
        info_text += "   • Ultra-fast responses\n"
        info_text += "   • Simple queries\n\n"
        
        info_text += "📦 LEGACY: llama3.2:3b\n"
        info_text += "   • Your current model\n"
        info_text += "   • Keep as backup\n"
        
        text_widget.insert('1.0', info_text)
        text_widget.config(state='disabled')
    
    def refresh_manuals_list(self):
        if not self.server_running:
            self.manuals_listbox.delete(0, tk.END)
            self.manuals_info_label.config(text="Server not running", fg="#ff6600")
            return
        
        try:
            response = requests.get(f"{self.server_url}/manuals", timeout=5, verify=False)
            if response.status_code == 200:
                data = response.json()
                self.indexed_manuals = data.get('manuals', {})
                
                self.manuals_listbox.delete(0, tk.END)
                
                if self.indexed_manuals:
                    for manual_name, info in sorted(self.indexed_manuals.items()):
                        pages = info.get('pages', 'N/A')
                        chunks = info.get('chunks', 'N/A')
                        size = info.get('file_size_mb', 'N/A')
                        if isinstance(size, (int, float)):
                            size = f"{size:.1f}"
                        
                        entry = f"📘 {manual_name:<35} │ {pages:>4}p │ {chunks:>5}ch │ {size:>6}MB"
                        self.manuals_listbox.insert(tk.END, entry)
                    
                    total_manuals = len(self.indexed_manuals)
                    total_chunks = data.get('total_chunks', 0)
                    self.manuals_info_label.config(
                        text=f"Total: {total_manuals} manuals, {total_chunks:,} chunks",
                        fg="#2196F3"
                    )
                else:
                    self.manuals_listbox.insert(tk.END, "No manuals indexed yet")
                    self.manuals_info_label.config(text="No manuals", fg="#666")
        except Exception as e:
            self.manuals_info_label.config(text=f"Error: {str(e)[:30]}...", fg="#f44336")
    
    def auto_refresh_manuals(self):
        if self.server_running:
            self.refresh_manuals_list()
        self.root.after(5000, self.auto_refresh_manuals)
    
    def auto_refresh_models(self):
        if self.server_running:
            self.refresh_models_list(silent=True)
        self.root.after(10000, self.auto_refresh_models)
    
    def clear_all_database(self):
        if not self.server_running:
            messagebox.showwarning("Server Not Running", "Start the server first.")
            return
        
        result = messagebox.askyesno(
            "⚠️ Confirm Clear All",
            "DELETE ALL indexed manuals?\n\nThis cannot be undone."
        )
        
        if not result:
            return
        
        try:
            response = requests.post(f"{self.server_url}/clear_all", timeout=10, verify=False)
            if response.status_code == 200:
                data = response.json()
                self.log(f"✓ Cleared: {data['chunks_deleted']} chunks")
                messagebox.showinfo("Success", f"Database cleared!")
                self.refresh_manuals_list()
            else:
                messagebox.showerror("Error", "Failed to clear")
        except Exception as e:
            messagebox.showerror("Error", str(e))
    
    def show_context_menu(self, event):
        index = self.manuals_listbox.nearest(event.y)
        self.manuals_listbox.selection_clear(0, tk.END)
        self.manuals_listbox.selection_set(index)
        
        context_menu = tk.Menu(self.root, tearoff=0)
        context_menu.add_command(
            label="Delete This Manual",
            command=self.delete_selected_manuals
        )
        
        try:
            context_menu.tk_popup(event.x_root, event.y_root)
        finally:
            context_menu.grab_release()
    
    def delete_selected_manuals(self):
        if not self.server_running:
            messagebox.showwarning("Server Not Running", "Start the server first.")
            return
        
        selection = self.manuals_listbox.curselection()
        if not selection:
            messagebox.showwarning("No Selection", "Select manual(s) to delete.")
            return
        
        selected_manuals = []
        for index in selection:
            entry = self.manuals_listbox.get(index)
            if '│' in entry:
                manual_name = entry.split('│')[0].strip().replace('📘', '').strip()
                selected_manuals.append(manual_name)
        
        if not selected_manuals:
            return
        
        if len(selected_manuals) == 1:
            msg = f"Delete '{selected_manuals[0]}'?\n\nCannot be undone."
        else:
            msg = f"Delete {len(selected_manuals)} manuals?\n\nCannot be undone."
        
        result = messagebox.askyesno("Confirm Delete", msg)
        if not result:
            return
        
        success_count = 0
        for manual_name in selected_manuals:
            try:
                response = requests.delete(
                    f"{self.server_url}/manual/{manual_name}",
                    timeout=10,
                    verify=False
                )
                if response.status_code == 200:
                    self.log(f"✓ Deleted: {manual_name}")
                    success_count += 1
                else:
                    self.log(f"✗ Failed: {manual_name}")
            except Exception as e:
                self.log(f"✗ Error: {manual_name} - {e}")
        
        if success_count > 0:
            messagebox.showinfo("Success", f"Deleted {success_count} manual(s)")
            self.refresh_manuals_list()
    
    def save_log_to_file(self):
        """Save activity log to a file"""
        try:
            from datetime import datetime
            
            # Get log content
            log_content = self.log_text.get("1.0", tk.END)
            
            if not log_content.strip():
                messagebox.showinfo("Empty Log", "Activity log is empty")
                return
            
            # Generate default filename
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            default_filename = f"VR_Training_Server_Log_{timestamp}.txt"
            
            # Ask where to save
            filepath = filedialog.asksaveasfilename(
                title="Save Activity Log",
                defaultextension=".txt",
                filetypes=[
                    ("Text files", "*.txt"),
                    ("All files", "*.*")
                ],
                initialfile=default_filename
            )
            
            if filepath:
                # Write log to file
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(f"VR Training AI Server - Activity Log\n")
                    f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                    f.write("=" * 80 + "\n\n")
                    f.write(log_content)
                
                self.log(f"✓ Log saved to: {filepath}")
                messagebox.showinfo("Success", f"Log saved successfully!\n\n{filepath}")
                
        except Exception as e:
            self.log(f"✗ Error saving log: {e}")
            messagebox.showerror("Error", f"Could not save log:\n{str(e)}")
    
    def clear_log(self):
        self.log_text.delete(1.0, tk.END)
    
    def update_status(self):
        if self.server_running:
            self.status_label.config(text="● Running", fg="green")
            
            # Obtener IP local
            try:
                hostname = socket.gethostname()
                local_ip = socket.gethostbyname(hostname)
                self.server_ip = local_ip
            except:
                self.server_ip = "localhost"
            
            # Actualizar etiqueta de IP
            ip_text = f"IP: {self.server_ip}:{self.server_port}"
            self.ip_label.config(text=ip_text, fg="#4CAF50")
            
            self.btn_start.config(state=tk.DISABLED)
            self.btn_stop.config(state=tk.NORMAL)
        else:
            self.status_label.config(text="● Stopped", fg="red")
            self.ip_label.config(text="IP: Not running", fg="#666")
            self.btn_start.config(state=tk.NORMAL)
            self.btn_stop.config(state=tk.DISABLED)
    
    def browse_pdf(self):
        manuals_dir = self.script_dir.parent / "manuals"
        if not manuals_dir.exists():
            manuals_dir = Path.home()
        
        filename = filedialog.askopenfilename(
            title="Select PDF Manual",
            initialdir=str(manuals_dir),
            filetypes=[("PDF files", "*.pdf"), ("All files", "*.*")]
        )
        
        if filename:
            self.selected_pdf = Path(filename)
            self.pdf_label.config(text=self.selected_pdf.name)
            self.log(f"Selected: {self.selected_pdf.name}")
    
    def index_manual(self):
        if not self.selected_pdf:
            messagebox.showwarning("No PDF", "Select a PDF first.")
            return
        
        if not self.server_running:
            messagebox.showwarning("Server Not Running", "Start server first.")
            return
        
        try:
            response = requests.post(
                f"{self.server_url}/check_manual",
                json={"pdf_path": str(self.selected_pdf)},
                timeout=30,
                verify=False
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('exists'):
                    result = messagebox.askyesnocancel(
                        "Duplicate",
                        f"Already indexed as '{data['existing_manual']}'.\n\nRe-index?"
                    )
                    
                    if result is None or result is False:
                        self.log("⚠ Cancelled (duplicate)")
                        return
        except:
            pass
        
        self.progress_frame.pack(fill=tk.X, pady=(5, 0))
        self.progress_bar['mode'] = 'determinate'
        self.progress_bar['value'] = 0
        self.progress_label.config(text="Starting indexing...")
        
        self.log(f"📥 Indexing {self.selected_pdf.name}...")
        
        def simulate_progress():
            """Simulate progress while indexing"""
            for i in range(10, 90, 5):
                time.sleep(0.5)
                if not self.indexing_in_progress:
                    break
                self.root.after(0, lambda p=i: self.progress_bar.config(value=p))
                self.root.after(0, lambda p=i: self.progress_label.config(text=f"Processing pages... {p}%"))
        
        def do_index():
            try:
                self.indexing_in_progress = True
                
                # Start progress simulation
                progress_thread = threading.Thread(target=simulate_progress, daemon=True)
                progress_thread.start()
                
                # Send indexing request
                response = requests.post(
                    f"{self.server_url}/index",
                    json={"pdf_path": str(self.selected_pdf)},
                    timeout=1800,
                    verify=False
                )
                
                self.indexing_in_progress = False
                
                if response.status_code == 200:
                    data = response.json()
                    chunks = data.get('chunks', 0)
                    pages = data.get('pages', 0)
                    
                    self.root.after(0, lambda: self.progress_bar.config(value=100))
                    self.root.after(0, lambda: self.progress_label.config(text=f"Complete! {chunks} chunks, {pages} pages"))
                    
                    self.log(f"✓ Indexed {chunks} chunks from {pages} pages")
                    
                    # Hide progress after 2 seconds
                    self.root.after(2000, self.progress_frame.pack_forget)
                    
                    messagebox.showinfo("Success", f"Indexed!\n\nChunks: {chunks}\nPages: {pages}")
                    self.refresh_manuals_list()
                else:
                    error = response.json().get('error', 'Unknown')
                    self.log(f"✗ Error: {error}")
                    self.root.after(0, self.progress_frame.pack_forget)
                    messagebox.showerror("Error", error)
            except Exception as e:
                self.indexing_in_progress = False
                self.log(f"✗ Error: {str(e)}")
                self.root.after(0, self.progress_frame.pack_forget)
                messagebox.showerror("Error", str(e))
        
        threading.Thread(target=do_index, daemon=True).start()
    
    def start_server(self):
        """Start server - FIXED: No stdout capture to avoid encoding issues"""
        if not self.server_script.exists():
            messagebox.showerror("Error", f"Server script not found:\n{self.server_script}")
            return
        
        self.log("🚀 Starting server...")
        
        try:
            if sys.platform == 'win32':
                # Windows: Create new console window, don't capture output
                self.server_process = subprocess.Popen(
                    [sys.executable, str(self.server_script)],
                    creationflags=subprocess.CREATE_NEW_CONSOLE,
                    # NO stdout/stderr capture - avoids encoding issues
                )
            else:
                # Linux/Mac
                self.server_process = subprocess.Popen(
                    [sys.executable, str(self.server_script)]
                )
            
            self.server_running = True
            self.update_status()
            self.log("✓ Server started in separate window!")
            self.log("ℹ Check the new console window for server output")
            
            # Detect protocol after server starts
            def detect_protocol():
                # Try multiple times with increasing delays
                delays = [2, 3, 5, 8, 10]  # Total: hasta 28 segundos
                for i, delay in enumerate(delays, 1):
                    time.sleep(delay)
                    self.root.after(0, lambda attempt=i: self.log(f"🔍 Connection attempt {attempt}/{len(delays)}..."))
                    
                    if self.detect_server_protocol():
                        self.root.after(0, lambda: self.log(f"✓ Connected! Using: {self.server_protocol.upper()}"))
                        self.root.after(0, self.refresh_manuals_list)
                        self.root.after(0, self.refresh_models_list)
                        return
                
                # Si falla después de todos los intentos
                self.root.after(0, lambda: self.log("✗ Server didn't respond after 28 seconds"))
                self.root.after(0, lambda: self.log("ℹ️ Check the console window for errors"))
                self.root.after(0, lambda: messagebox.showwarning(
                    "Server Not Responding",
                    "The server process started but is not responding.\n\n"
                    "Common issues:\n"
                    "• Ollama is not running (run 'ollama serve')\n"
                    "• Port 5000 is already in use\n"
                    "• Missing Python dependencies\n"
                    "• Check the console window for error messages\n\n"
                    "Try:\n"
                    "1. Close this launcher\n"
                    "2. Run 'ollama serve' in a terminal\n"
                    "3. Restart the launcher"
                ))
            
            threading.Thread(target=detect_protocol, daemon=True).start()
            
        except Exception as e:
            self.log(f"✗ Failed: {str(e)}")
            messagebox.showerror("Error", str(e))
    
    def stop_server(self):
        """Stop server"""
        if self.server_process:
            self.log("⏹ Stopping server...")
            try:
                self.server_process.terminate()
                self.server_process.wait(timeout=5)
            except:
                self.server_process.kill()
            
            self.server_process = None
            self.server_running = False
            self.update_status()
            self.log("✓ Server stopped")
    
    def test_connection(self):
        """Test connection"""
        self.log("🔍 Testing connection...")
        
        # Try to detect protocol first
        if not self.detect_server_protocol():
            self.log("✗ Server not responding")
            messagebox.showerror("Error", "Cannot connect to server")
            return
        
        try:
            response = requests.get(f"{self.server_url}/health", timeout=5, verify=False)
            if response.status_code == 200:
                data = response.json()
                self.log("✓ Server responding!")
                self.log(f"  Model: {data.get('ollama_model')}")
                self.log(f"  Manuals: {data.get('indexed_manuals', 0)}")
                self.log(f"  Chunks: {data.get('total_chunks', 0)}")
                messagebox.showinfo("Success", "Server is online!")
            else:
                self.log("✗ Server returned error")
                messagebox.showerror("Error", "Server error")
        except Exception as e:
            self.log(f"✗ Connection failed: {str(e)}")
            messagebox.showerror("Error", f"Cannot connect:\n{str(e)}")
    
    def quit_app(self):
        """Quit application"""
        if self.server_running:
            if messagebox.askyesno("Confirm", "Server is running. Stop and quit?"):
                self.stop_server()
                self.root.quit()
        else:
            self.root.quit()

def main():
    root = tk.Tk()
    app = ServerLauncher(root)
    root.protocol("WM_DELETE_WINDOW", app.quit_app)
    root.mainloop()

if __name__ == '__main__':
    main()
