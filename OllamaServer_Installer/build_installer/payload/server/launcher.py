#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VR Manual Server - GUI Launcher v5.1
Fixed: Layout adjustments and progress parsing
"""

import sys
import os
import subprocess
import threading
import socket
import requests
import time
from pathlib import Path
import tkinter as tk
from tkinter import ttk, scrolledtext, filedialog, messagebox

class ServerLauncher:
    def __init__(self, root):
        self.root = root
        self.root.title("VR Training AI Server v5.1")
        
        # Screen dimensions
        screen_width = root.winfo_screenwidth()
        screen_height = root.winfo_screenheight()
        
        # Window size (80% of screen)
        window_width = min(950, int(screen_width * 0.8))
        window_height = min(800, int(screen_height * 0.85))
        
        # Center window
        x = (screen_width - window_width) // 2
        y = (screen_height - window_height) // 2
        
        self.root.geometry(f"{window_width}x{window_height}+{x}+{y}")
        self.root.resizable(True, True)
        self.root.minsize(800, 600)
        
        self.server_process = None
        self.server_running = False
        self.selected_pdf = None
        self.indexing_in_progress = False
        self.indexed_manuals = {}
        
        # Get script directory
        if getattr(sys, 'frozen', False):
            self.script_dir = Path(sys.executable).parent
        else:
            self.script_dir = Path(__file__).parent
        
        self.server_script = self.script_dir / "offline_server.py"
        
        self.create_widgets()
        self.update_status()
        
        # Auto-refresh manuals
        self.auto_refresh_manuals()
        
    def create_widgets(self):
        """Create UI widgets with proper sizing"""
        
        # Header
        header = tk.Frame(self.root, bg="#0066cc", height=90)
        header.pack(fill=tk.X)
        header.pack_propagate(False)
        
        logo_path = self.script_dir / "logo.png"
        logo_image = None
        
        if logo_path.exists():
            try:
                from PIL import Image, ImageTk
                img = Image.open(logo_path)
                img = img.resize((60, 50), Image.Resampling.LANCZOS)
                logo_image = ImageTk.PhotoImage(img)
            except:
                pass
        
        logo_container = tk.Frame(header, bg="#0066cc")
        logo_container.pack(expand=True)
        
        logo_frame = tk.Frame(logo_container, bg="#0066cc")
        logo_frame.pack(side=tk.LEFT, padx=(0, 15))
        
        if logo_image:
            logo_label = tk.Label(logo_frame, image=logo_image, bg="#0066cc")
            logo_label.image = logo_image
            logo_label.pack()
        else:
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
            text="AI-Powered Assistant for VR Training",
            font=("Arial", 9),
            bg="#0066cc",
            fg="#ccddff"
        )
        subtitle.pack(anchor=tk.W)
        
        # Main container with canvas for scrolling
        main = tk.Frame(self.root)
        main.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Status section - COMPACT
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
            text=f"IP: {self.get_local_ip()}",
            font=("Arial", 9)
        )
        self.ip_label.pack(side=tk.LEFT, padx=(15, 0))
        
        # Indexed Manuals section - OPTIMIZED HEIGHT
        manuals_frame = tk.LabelFrame(main, text="📚 Indexed Manuals", padx=8, pady=4)
        manuals_frame.pack(fill=tk.BOTH, expand=False, pady=(0, 5))
        
        # Listbox with fixed height
        list_container = tk.Frame(manuals_frame)
        list_container.pack(fill=tk.BOTH, expand=True)
        
        scrollbar = tk.Scrollbar(list_container)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.manuals_listbox = tk.Listbox(
            list_container,
            height=4,  # Fixed height - 4 lines
            font=("Consolas", 9),
            yscrollcommand=scrollbar.set,
            selectmode=tk.EXTENDED  # ← Changed to EXTENDED for multi-select
        )
        self.manuals_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.manuals_listbox.yview)
        
        # Add right-click context menu
        self.manuals_listbox.bind("<Button-3>", self.show_context_menu)
        
        # Manuals controls - COMPACT
        manuals_controls = tk.Frame(manuals_frame)
        manuals_controls.pack(fill=tk.X, pady=(4, 0))
        
        self.manuals_info_label = tk.Label(
            manuals_controls,
            text="No manuals indexed",
            font=("Arial", 8),
            fg="#666"
        )
        self.manuals_info_label.pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        btn_refresh = tk.Button(
            manuals_controls,
            text="🔄",
            command=self.refresh_manuals_list,
            cursor="hand2",
            width=3,
            font=("Arial", 9)
        )
        btn_refresh.pack(side=tk.RIGHT, padx=(3, 0))
        
        btn_clear_all = tk.Button(
            manuals_controls,
            text="🗑️ Clear All",
            command=self.clear_all_database,
            cursor="hand2",
            width=10,
            bg="#f44336",
            fg="white",
            font=("Arial", 8)
        )
        btn_clear_all.pack(side=tk.RIGHT)
        
        btn_delete_selected = tk.Button(
            manuals_controls,
            text="❌ Delete Selected",
            command=self.delete_selected_manuals,
            cursor="hand2",
            width=15,
            bg="#ff9800",
            fg="white",
            font=("Arial", 8)
        )
        btn_delete_selected.pack(side=tk.RIGHT, padx=(0, 3))
        
        # Manual Selection - COMPACT
        pdf_frame = tk.LabelFrame(main, text="Manual Selection", padx=8, pady=4)
        pdf_frame.pack(fill=tk.X, pady=(0, 5))
        
        pdf_info = tk.Frame(pdf_frame)
        pdf_info.pack(fill=tk.X)
        
        self.pdf_label = tk.Label(
            pdf_info,
            text="No manual selected",
            font=("Arial", 9)
        )
        self.pdf_label.pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        btn_browse = tk.Button(
            pdf_info,
            text="Browse...",
            command=self.browse_pdf,
            width=10,
            font=("Arial", 9)
        )
        btn_browse.pack(side=tk.RIGHT, padx=3)
        
        btn_index = tk.Button(
            pdf_frame,
            text="📊 Index Manual",
            command=self.index_manual,
            bg="#4CAF50",
            fg="white",
            font=("Arial", 10, "bold"),
            cursor="hand2"
        )
        btn_index.pack(fill=tk.X, pady=(5, 0))
        
        # Progress - COMPACT
        progress_frame = tk.LabelFrame(main, text="Indexing Progress", padx=8, pady=4)
        progress_frame.pack(fill=tk.X, pady=(0, 5))
        
        self.progress_info = tk.Label(
            progress_frame,
            text="No indexing in progress",
            font=("Arial", 8),
            fg="#666666"
        )
        self.progress_info.pack(anchor=tk.W)
        
        self.progress_bar = ttk.Progressbar(
            progress_frame,
            mode='determinate',
            maximum=100
        )
        self.progress_bar.pack(fill=tk.X, pady=(3, 3))
        
        self.progress_percent = tk.Label(
            progress_frame,
            text="0%",
            font=("Arial", 9, "bold"),
            fg="#2196F3"
        )
        self.progress_percent.pack()
        
        # Control buttons - SINGLE ROW
        btn_frame = tk.Frame(main)
        btn_frame.pack(fill=tk.X, pady=(0, 5))
        
        self.btn_start = tk.Button(
            btn_frame,
            text="▶ Start",
            command=self.start_server,
            bg="#2196F3",
            fg="white",
            font=("Arial", 10, "bold"),
            cursor="hand2",
            width=12
        )
        self.btn_start.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 3))
        
        self.btn_stop = tk.Button(
            btn_frame,
            text="⏹ Stop",
            command=self.stop_server,
            bg="#f44336",
            fg="white",
            font=("Arial", 10, "bold"),
            state=tk.DISABLED,
            cursor="hand2",
            width=12
        )
        self.btn_stop.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(3, 3))
        
        btn_test = tk.Button(
            btn_frame,
            text="Test",
            command=self.test_connection,
            bg="#FF9800",
            fg="white",
            cursor="hand2",
            font=("Arial", 10),
            width=8
        )
        btn_test.pack(side=tk.LEFT, padx=(3, 3))
        
        btn_clear_log = tk.Button(
            btn_frame,
            text="Clear Log",
            command=self.clear_log,
            bg="#9E9E9E",
            fg="white",
            cursor="hand2",
            font=("Arial", 10),
            width=10
        )
        btn_clear_log.pack(side=tk.LEFT, padx=(3, 3))
        
        btn_quit = tk.Button(
            btn_frame,
            text="Quit",
            command=self.quit_app,
            bg="#f44336",
            fg="white",
            cursor="hand2",
            font=("Arial", 10),
            width=8
        )
        btn_quit.pack(side=tk.LEFT, padx=(3, 0))
        
        # Log section - EXPANDABLE
        log_frame = tk.LabelFrame(main, text="Server Log", padx=5, pady=5)
        log_frame.pack(fill=tk.BOTH, expand=True)
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            height=8,
            font=("Consolas", 8),
            bg="#1e1e1e",
            fg="#d4d4d4",
            insertbackground="white",
            wrap=tk.WORD
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
    def get_local_ip(self):
        """Get local IP"""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return "localhost"
    
    def log(self, message):
        """Add message to log"""
        timestamp = time.strftime("%H:%M:%S")
        self.log_text.insert(tk.END, f"[{timestamp}] {message}\n")
        self.log_text.see(tk.END)
        self.log_text.update()
        
        # Parse progress
        self.parse_progress(message)
    
    def parse_progress(self, message):
        """Parse progress - IMPROVED"""
        import re
        
        # Starting indexing
        if 'Indexing' in message and '.pdf' in message:
            self.indexing_in_progress = True
            self.update_progress(10, "Starting indexing...")
            return
        
        # PDF pages detected
        match = re.search(r'PDF has (\d+) pages', message)
        if match:
            total_pages = int(match.group(1))
            self.update_progress(15, f"PDF has {total_pages} pages")
            return
        
        # Processing pages
        match = re.search(r'Processing page (\d+)/(\d+)', message)
        if match:
            current = int(match.group(1))
            total = int(match.group(2))
            percent = 15 + int((current / total) * 35)  # 15-50%
            self.update_progress(percent, f"Processing: {current}/{total} pages")
            return
        
        # Creating chunks
        match = re.search(r'Created (\d+) chunks', message)
        if match:
            chunks = int(match.group(1))
            self.update_progress(55, f"Created {chunks} chunks")
            return
        
        # Adding to database
        if 'Adding' in message and 'chunks to database' in message:
            self.update_progress(60, "Adding chunks to database...")
            return
        
        # Generating embeddings
        if 'Generating embeddings' in message or 'embedding' in message.lower():
            self.update_progress(70, "Generating embeddings...")
            return
        
        # Success
        if 'Successfully indexed' in message or 'Manual indexed successfully' in message:
            match = re.search(r'(\d+) chunks', message)
            if match:
                chunks = match.group(1)
                self.update_progress(100, f"✓ Completed! {chunks} chunks indexed")
            else:
                self.update_progress(100, "✓ Indexing completed!")
            self.indexing_in_progress = False
            self.root.after(2000, self.refresh_manuals_list)
            return
        
        # Error
        if 'error' in message.lower() or 'failed' in message.lower():
            self.update_progress(0, "✗ Error during indexing")
            self.indexing_in_progress = False
            return
    
    def update_progress(self, percent, text):
        """Update progress bar"""
        try:
            self.progress_bar['value'] = percent
            self.progress_percent.config(text=f"{percent}%")
            self.progress_info.config(text=text, fg="#2196F3")
            self.root.update_idletasks()
        except:
            pass
    
    def reset_progress(self):
        """Reset progress"""
        self.indexing_in_progress = False
        self.progress_bar['value'] = 0
        self.progress_percent.config(text="0%")
        self.progress_info.config(text="No indexing in progress", fg="#666666")
    
    def refresh_manuals_list(self):
        """Refresh manuals list"""
        if not self.server_running:
            self.manuals_listbox.delete(0, tk.END)
            self.manuals_info_label.config(text="Server not running", fg="#ff6600")
            return
        
        try:
            response = requests.get("http://localhost:5000/manuals", timeout=5)
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
        """Auto-refresh every 5 seconds"""
        if self.server_running:
            self.refresh_manuals_list()
        self.root.after(5000, self.auto_refresh_manuals)
    
    def clear_all_database(self):
        """Clear all database"""
        if not self.server_running:
            messagebox.showwarning("Server Not Running", "Start the server first.")
            return
        
        result = messagebox.askyesno(
            "⚠️ Confirm Clear All",
            "This will DELETE ALL indexed manuals!\n\n"
            "This action cannot be undone.\n\n"
            "Continue?"
        )
        
        if not result:
            return
        
        try:
            response = requests.post("http://localhost:5000/clear_all", timeout=10)
            if response.status_code == 200:
                data = response.json()
                self.log(f"✓ Database cleared: {data['chunks_deleted']} chunks")
                messagebox.showinfo(
                    "Success",
                    f"Database cleared!\n\n"
                    f"Manuals: {data['manuals_deleted']}\n"
                    f"Chunks: {data['chunks_deleted']}"
                )
                self.refresh_manuals_list()
            else:
                error = response.json().get('error', 'Unknown')
                messagebox.showerror("Error", f"Failed:\n{error}")
        except Exception as e:
            messagebox.showerror("Error", str(e))
    
    def show_context_menu(self, event):
        """Show right-click context menu"""
        # Select the item under cursor
        index = self.manuals_listbox.nearest(event.y)
        self.manuals_listbox.selection_clear(0, tk.END)
        self.manuals_listbox.selection_set(index)
        
        # Create context menu
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
        """Delete selected manual(s)"""
        if not self.server_running:
            messagebox.showwarning("Server Not Running", "Start the server first.")
            return
        
        selection = self.manuals_listbox.curselection()
        if not selection:
            messagebox.showwarning("No Selection", "Please select manual(s) to delete.")
            return
        
        # Get selected manual names
        selected_manuals = []
        for index in selection:
            entry = self.manuals_listbox.get(index)
            # Extract manual name from format: "📘 manual_name │ ..."
            if '│' in entry:
                manual_name = entry.split('│')[0].strip().replace('📘', '').strip()
                selected_manuals.append(manual_name)
        
        if not selected_manuals:
            return
        
        # Confirm deletion
        if len(selected_manuals) == 1:
            msg = f"Delete manual '{selected_manuals[0]}'?\n\nThis action cannot be undone."
        else:
            msg = f"Delete {len(selected_manuals)} manuals?\n\n"
            msg += "\n".join(f"• {m}" for m in selected_manuals[:5])
            if len(selected_manuals) > 5:
                msg += f"\n... and {len(selected_manuals) - 5} more"
            msg += "\n\nThis action cannot be undone."
        
        result = messagebox.askyesno("Confirm Delete", msg)
        if not result:
            return
        
        # Delete each manual
        success_count = 0
        fail_count = 0
        
        for manual_name in selected_manuals:
            try:
                response = requests.delete(
                    f"http://localhost:5000/manual/{manual_name}",
                    timeout=10
                )
                if response.status_code == 200:
                    data = response.json()
                    self.log(f"✓ Deleted {manual_name}: {data['chunks_deleted']} chunks")
                    success_count += 1
                else:
                    error = response.json().get('error', 'Unknown')
                    self.log(f"✗ Failed to delete {manual_name}: {error}")
                    fail_count += 1
            except Exception as e:
                self.log(f"✗ Error deleting {manual_name}: {str(e)}")
                fail_count += 1
        
        # Show result
        if success_count > 0:
            messagebox.showinfo(
                "Deletion Complete",
                f"Successfully deleted: {success_count}\n"
                f"Failed: {fail_count}"
            )
            self.refresh_manuals_list()
        else:
            messagebox.showerror("Error", "All deletions failed")
    
    def clear_log(self):
        """Clear log"""
        self.log_text.delete(1.0, tk.END)
    
    def update_status(self):
        """Update status"""
        if self.server_running:
            self.status_label.config(text="● Running", fg="green")
            self.btn_start.config(state=tk.DISABLED)
            self.btn_stop.config(state=tk.NORMAL)
        else:
            self.status_label.config(text="● Stopped", fg="red")
            self.btn_start.config(state=tk.NORMAL)
            self.btn_stop.config(state=tk.DISABLED)
    
    def browse_pdf(self):
        """Browse PDF"""
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
        """Index manual"""
        if not self.selected_pdf:
            messagebox.showwarning("No PDF", "Select a PDF first.")
            return
        
        if not self.server_running:
            messagebox.showwarning("Server Not Running", "Start server first.")
            return
        
        # Check duplicates
        try:
            response = requests.post(
                "http://localhost:5000/check_manual",
                json={"pdf_path": str(self.selected_pdf)},
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('exists'):
                    result = messagebox.askyesnocancel(
                        "Duplicate",
                        f"Already indexed as '{data['existing_manual']}'.\n\n"
                        f"Re-index?\n\nYes = Re-index\nNo = Cancel"
                    )
                    
                    if result is None or result is False:
                        self.log("⚠ Cancelled (duplicate)")
                        return
        except:
            pass
        
        self.reset_progress()
        self.log(f"📥 Indexing {self.selected_pdf.name}...")
        self.update_progress(5, "Sending request...")
        
        def do_index():
            try:
                response = requests.post(
                    "http://localhost:5000/index",
                    json={"pdf_path": str(self.selected_pdf)},
                    timeout=1800
                )
                
                if response.status_code == 200:
                    data = response.json()
                    self.log(f"✓ Indexed {data.get('chunks', 0)} chunks")
                    messagebox.showinfo("Success", f"Indexed!\nChunks: {data.get('chunks', 0)}")
                    self.refresh_manuals_list()
                else:
                    error = response.json().get('error', 'Unknown')
                    self.log(f"✗ Error: {error}")
                    messagebox.showerror("Error", error)
                    self.reset_progress()
            except Exception as e:
                self.log(f"✗ Error: {str(e)}")
                messagebox.showerror("Error", str(e))
                self.reset_progress()
        
        threading.Thread(target=do_index, daemon=True).start()
    
    def start_server(self):
        """Start server"""
        if not self.server_script.exists():
            messagebox.showerror("Error", f"Server script not found:\n{self.server_script}")
            return
        
        self.log("🚀 Starting server...")
        
        try:
            startupinfo = None
            if sys.platform == 'win32':
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            
            self.server_process = subprocess.Popen(
                [sys.executable, str(self.server_script)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding='utf-8',
                errors='replace',
                bufsize=1,
                startupinfo=startupinfo
            )
            
            self.server_running = True
            self.update_status()
            self.log("✓ Server started!")
            
            self.root.after(2000, self.refresh_manuals_list)
            
            def read_output():
                for line in self.server_process.stdout:
                    self.log(line.rstrip())
            
            threading.Thread(target=read_output, daemon=True).start()
            
        except Exception as e:
            self.log(f"✗ Failed: {str(e)}")
            messagebox.showerror("Error", str(e))
    
    def stop_server(self):
        """Stop server"""
        if self.server_process:
            self.log("⏹ Stopping...")
            try:
                self.server_process.terminate()
                self.server_process.wait(timeout=5)
            except:
                self.server_process.kill()
            
            self.server_process = None
            self.server_running = False
            self.update_status()
            self.log("✓ Stopped")
    
    def test_connection(self):
        """Test connection"""
        self.log("🔍 Testing...")
        
        try:
            response = requests.get("http://localhost:5000/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log("✓ Connection OK!")
                self.log(f"  Model: {data.get('ollama_model')}")
                self.log(f"  Manuals: {data.get('indexed_manuals', 0)}")
                self.log(f"  Chunks: {data.get('total_chunks', 0)}")
                messagebox.showinfo("Success", "Server responding!")
            else:
                self.log("✗ Failed")
                messagebox.showerror("Error", "Connection failed")
        except Exception as e:
            self.log(f"✗ Error: {str(e)}")
            messagebox.showerror("Error", str(e))
    
    def quit_app(self):
        """Quit"""
        if self.server_running:
            if messagebox.askyesno("Confirm", "Server running. Stop and quit?"):
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
