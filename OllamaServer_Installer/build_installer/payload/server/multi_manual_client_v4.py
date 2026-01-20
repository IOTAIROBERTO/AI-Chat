#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Multi-Manual Client - Enhanced with Duplicate Detection
Version: 4.0 - Visual duplicate prevention
"""

import requests
import urllib3
import time
import json
from pathlib import Path
from datetime import datetime

# Suppress InsecureRequestWarning for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SERVER_URL = "https://localhost:5000"

# ANSI Colors for better visualization
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_header(text):
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*80}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text:^80}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'='*80}{Colors.ENDC}\n")

def print_success(text):
    print(f"{Colors.OKGREEN}✓ {text}{Colors.ENDC}")

def print_error(text):
    print(f"{Colors.FAIL}✗ {text}{Colors.ENDC}")

def print_warning(text):
    print(f"{Colors.WARNING}⚠ {text}{Colors.ENDC}")

def print_info(text):
    print(f"{Colors.OKCYAN}ℹ {text}{Colors.ENDC}")

def check_server():
    """Check if server is running"""
    try:
        response = requests.get(f"{SERVER_URL}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print_success("Server is online")
            print_info(f"  Indexed manuals: {data['indexed_manuals']}")
            print_info(f"  Total chunks: {data['total_chunks']:,}")
            print_info(f"  Chunk usage: {data['chunk_usage_percent']}%")
            
            # Warning if approaching limit
            if data['chunk_usage_percent'] > 80:
                print_warning(f"  ⚠ High chunk usage! Consider removing old manuals.")
            
            return True
        return False
    except Exception as e:
        print_error(f"Server not responding: {e}")
        return False

def list_manuals_detailed():
    """List all indexed manuals with detailed information"""
    print_header("INDEXED MANUALS")
    
    try:
        response = requests.get(f"{SERVER_URL}/manuals", verify=False)
        data = response.json()
        
        if data['total_manuals'] == 0:
            print_info("No manuals indexed yet.")
            print_info("Use option 3 or 4 to start indexing manuals.")
            return
        
        print(f"{Colors.BOLD}Total manuals: {data['total_manuals']}{Colors.ENDC}")
        print(f"{Colors.BOLD}Total chunks: {data['total_chunks']:,}{Colors.ENDC}\n")
        
        # Sort by indexed date (newest first)
        sorted_manuals = sorted(
            data['manuals'].items(),
            key=lambda x: x[1].get('indexed_at', ''),
            reverse=True
        )
        
        for i, (name, info) in enumerate(sorted_manuals, 1):
            # Visual separator
            print(f"{Colors.OKBLUE}{'─'*78}{Colors.ENDC}")
            
            # Manual name
            print(f"{Colors.BOLD}{i}. 📘 {name}{Colors.ENDC}")
            
            # Details (Pages removed - now shown in bot responses)
            print(f"   🧩 Chunks: {info.get('chunks', 'N/A')}")
            print(f"   📏 Size: {info.get('file_size_mb', 'N/A')} MB")
            print(f"   🕐 Indexed: {info.get('indexed_at', 'N/A')}")
            
            # Show file path if available
            if 'file_path' in info:
                print(f"   📂 Path: {info['file_path']}")
            
            # Show hash (first 8 chars for identification)
            if 'file_hash' in info:
                hash_preview = info['file_hash'][:8] + '...'
                print(f"   🔑 Hash: {hash_preview}")
            
            print()
        
        print(f"{Colors.OKBLUE}{'─'*78}{Colors.ENDC}")
        
    except Exception as e:
        print_error(f"Error listing manuals: {e}")

def check_before_indexing(pdf_path):
    """Check if manual already exists before indexing"""
    print_header("CHECKING FOR DUPLICATES")
    
    print_info(f"Checking file: {Path(pdf_path).name}")
    print_info("Please wait...")
    
    try:
        response = requests.post(
            f"{SERVER_URL}/check_manual",
            json={"pdf_path": pdf_path},
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            
            if data['exists']:
                # DUPLICATE FOUND!
                print()
                print(f"{Colors.FAIL}{Colors.BOLD}{'='*78}{Colors.ENDC}")
                print(f"{Colors.FAIL}{Colors.BOLD}  ⚠️  DUPLICATE DETECTED!{Colors.ENDC}")
                print(f"{Colors.FAIL}{Colors.BOLD}{'='*78}{Colors.ENDC}\n")
                
                existing_manual = data['existing_manual']
                manual_info = data['manual_info']
                duplicate_type = data['duplicate_type']
                
                if duplicate_type == 'name':
                    print_warning("This manual name is already indexed:")
                else:
                    print_warning("This exact file is already indexed with a different name:")
                
                print()
                print(f"  {Colors.BOLD}Existing manual: {existing_manual}{Colors.ENDC}")
                print(f"  Chunks: {manual_info.get('chunks', 'N/A')}")
                print(f"  Size: {manual_info.get('file_size_mb', 'N/A')} MB")
                print(f"  Indexed at: {manual_info.get('indexed_at', 'N/A')}")
                print()
                
                print(f"{Colors.WARNING}Options:{Colors.ENDC}")
                print(f"  1. Skip this file (recommended)")
                print(f"  2. Re-index (will delete old version and create new one)")
                print()
                
                choice = input(f"{Colors.BOLD}Your choice (1/2): {Colors.ENDC}").strip()
                
                if choice == '2':
                    print_warning("You chose to RE-INDEX this manual.")
                    confirm = input(f"{Colors.WARNING}Are you sure? This will delete the old version. (yes/no): {Colors.ENDC}").strip().lower()
                    if confirm == 'yes':
                        return 'reindex'
                    else:
                        print_info("Re-index cancelled.")
                        return 'skip'
                else:
                    print_info("Skipping this file.")
                    return 'skip'
            else:
                # NO DUPLICATE
                print_success("No duplicate found!")
                print_info(f"Manual name: {data['manual_name']}")
                if 'file_hash' in data:
                    print_info(f"File hash: {data['file_hash'][:16]}...")
                print_success("✓ Safe to index")
                return 'proceed'
                
        elif response.status_code == 404:
            print_error("File not found!")
            return 'error'
        else:
            error_data = response.json()
            print_error(f"Check failed: {error_data.get('error', 'Unknown error')}")
            return 'error'
            
    except Exception as e:
        print_error(f"Error checking manual: {e}")
        return 'error'

def index_single_manual(pdf_path, force_reindex=False):
    """Index a single manual with duplicate prevention"""
    print_header("INDEXING SINGLE MANUAL")
    
    if not Path(pdf_path).exists():
        print_error(f"File not found: {pdf_path}")
        return False
    
    print_info(f"File: {Path(pdf_path).name}")
    print_info(f"Size: {Path(pdf_path).stat().st_size / (1024*1024):.1f} MB")
    print()
    
    # Check for duplicates first (unless forcing reindex)
    if not force_reindex:
        check_result = check_before_indexing(pdf_path)
        
        if check_result == 'skip':
            return False
        elif check_result == 'reindex':
            force_reindex = True
        elif check_result == 'error':
            return False
        # If 'proceed', continue normally
    
    print()
    print_info("Starting indexing... (this may take several minutes)")
    
    try:
        response = requests.post(
            f"{SERVER_URL}/index",
            json={
                "pdf_path": pdf_path,
                "force_reindex": force_reindex
            },
            timeout=1800,  # 30 minutes
            verify=False
        )
        
        if response.status_code == 200:
            data = response.json()
            print()
            print_success("Indexing completed successfully!")
            print()
            print(f"  Manual: {data['manual_name']}")
            print(f"  Chunks: {data['chunks']}")
            return True
            
        elif response.status_code == 409:  # Conflict (duplicate)
            error_data = response.json()
            print()
            print_warning("Duplicate detected by server!")
            print_warning(error_data.get('message', 'Manual already exists'))
            return False
        else:
            error = response.json()
            print()
            print_error(f"Indexing failed: {error.get('error', 'Unknown error')}")
            return False
            
    except requests.exceptions.Timeout:
        print_error("Indexing timed out (30 minutes exceeded)")
        print_info("For very large files, consider increasing the timeout")
        return False
    except Exception as e:
        print_error(f"Error: {e}")
        return False

def index_batch_with_duplicate_check(pdf_paths):
    """Index multiple manuals with duplicate checking"""
    print_header("BATCH INDEXING WITH DUPLICATE DETECTION")
    
    print(f"{Colors.BOLD}Files to check: {len(pdf_paths)}{Colors.ENDC}")
    for path in pdf_paths:
        print(f"  • {Path(path).name}")
    print()
    
    # Check each file for duplicates
    print_info("Step 1/2: Checking for duplicates...")
    print()
    
    files_to_index = []
    duplicates_found = []
    
    for pdf_path in pdf_paths:
        try:
            response = requests.post(
                f"{SERVER_URL}/check_manual",
                json={"pdf_path": pdf_path},
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                
                if data['exists']:
                    print_warning(f"✗ Duplicate: {Path(pdf_path).name} → already indexed as '{data['existing_manual']}'")
                    duplicates_found.append({
                        'file': pdf_path,
                        'existing': data['existing_manual']
                    })
                else:
                    print_success(f"✓ New: {Path(pdf_path).name}")
                    files_to_index.append(pdf_path)
            else:
                print_error(f"✗ Error checking: {Path(pdf_path).name}")
                
        except Exception as e:
            print_error(f"✗ Error: {Path(pdf_path).name} - {e}")
    
    print()
    print(f"{Colors.BOLD}Summary:{Colors.ENDC}")
    print(f"  New files to index: {Colors.OKGREEN}{len(files_to_index)}{Colors.ENDC}")
    print(f"  Duplicates skipped: {Colors.WARNING}{len(duplicates_found)}{Colors.ENDC}")
    print()
    
    if duplicates_found:
        print(f"{Colors.WARNING}Duplicates detected:{Colors.ENDC}")
        for dup in duplicates_found:
            print(f"  • {Path(dup['file']).name} → {dup['existing']}")
        print()
    
    if not files_to_index:
        print_warning("No new files to index!")
        return
    
    proceed = input(f"{Colors.BOLD}Proceed with indexing {len(files_to_index)} new files? (yes/no): {Colors.ENDC}").strip().lower()
    
    if proceed != 'yes':
        print_info("Batch indexing cancelled.")
        return
    
    # Index the files
    print()
    print_info(f"Step 2/2: Indexing {len(files_to_index)} files...")
    print()
    
    try:
        response = requests.post(
            f"{SERVER_URL}/index/batch",
            json={"pdf_paths": files_to_index}
        )
        
        if response.status_code != 202:
            print_error(f"Failed to start batch: {response.json()}")
            return
        
        data = response.json()
        task_id = data['task_id']
        print_success(f"Batch started: {task_id}")
        print()
        
        # Monitor progress
        while True:
            time.sleep(2)
            
            status_response = requests.get(f"{SERVER_URL}/index/status/{task_id}", verify=False)
            status = status_response.json()
            
            current_status = status['status']
            progress = status['progress']
            completed = status['completed_files']
            total = status['total_files']
            current_file = status.get('current_file', 'N/A')
            
            # Progress bar
            bar_length = 50
            filled = int(bar_length * progress / 100)
            bar = '█' * filled + '░' * (bar_length - filled)
            
            print(f"\r[{bar}] {progress}% | {completed}/{total} | {current_file[:25]:<25}", end='', flush=True)
            
            if current_status == 'completed':
                print("\n")
                print_success("Batch indexing completed!")
                print()
                
                # Show results
                successful = sum(1 for r in status['results'] if r['success'])
                failed = len(status['results']) - successful
                
                print(f"{Colors.BOLD}Results:{Colors.ENDC}")
                print(f"  {Colors.OKGREEN}✓ Successful: {successful}{Colors.ENDC}")
                if failed > 0:
                    print(f"  {Colors.FAIL}✗ Failed: {failed}{Colors.ENDC}")
                print()
                
                for result in status['results']:
                    if result['success']:
                        print_success(f"{result['manual_name']} - {result['chunks']} chunks")
                    else:
                        print_error(f"{result['manual_name']} - {result['error']}")
                
                break
                
    except Exception as e:
        print()
        print_error(f"Error: {e}")

def delete_manual(manual_name):
    """Delete a manual"""
    print_header("DELETE MANUAL")
    
    # First, show manual info
    try:
        response = requests.get(f"{SERVER_URL}/manuals")
        manuals = response.json()['manuals']
        
        if manual_name not in manuals:
            print_error(f"Manual '{manual_name}' not found!")
            print_info("Use option 2 to see available manuals.")
            return
        
        manual_info = manuals[manual_name]
        
        print(f"{Colors.BOLD}Manual to delete:{Colors.ENDC}")
        print(f"  Name: {manual_name}")
        print(f"  Chunks: {manual_info.get('chunks', 'N/A')}")
        print(f"  Indexed: {manual_info.get('indexed_at', 'N/A')}")
        print()
        
        confirm = input(f"{Colors.WARNING}Are you sure you want to delete this manual? (yes/no): {Colors.ENDC}").strip().lower()
        
        if confirm != 'yes':
            print_info("Deletion cancelled.")
            return
        
        # Delete
        response = requests.delete(f"{SERVER_URL}/manual/{manual_name}", verify=False)
        
        if response.status_code == 200:
            data = response.json()
            print()
            print_success("Manual deleted successfully!")
            print_info(f"  Chunks removed: {data['chunks_deleted']}")
        else:
            error = response.json()
            print_error(f"Deletion failed: {error.get('error')}")
            
    except Exception as e:
        print_error(f"Error: {e}")

def show_menu():
    """Display main menu"""
    print("\n" + "="*80)
    print(f"{Colors.HEADER}{Colors.BOLD}  MULTI-MANUAL CLIENT v4.0 - WITH DUPLICATE DETECTION  {Colors.ENDC}")
    print("="*80)
    print(f"\n{Colors.OKBLUE}📊 Viewing:{Colors.ENDC}")
    print("  1. Check server status")
    print("  2. List indexed manuals (detailed)")
    
    print(f"\n{Colors.OKGREEN}📥 Indexing:{Colors.ENDC}")
    print("  3. Index single manual (with duplicate check)")
    print("  4. Index multiple manuals (batch with duplicate check)")
    
    print(f"\n{Colors.OKCYAN}🔍 Querying:{Colors.ENDC}")
    print("  5. Query all manuals")
    print("  6. Query specific manual")
    
    print(f"\n{Colors.FAIL}🗑️  Management:{Colors.ENDC}")
    print("  7. Delete manual")
    
    print(f"\n{Colors.WARNING}  0. Exit{Colors.ENDC}")
    print()

def main():
    """Main interactive loop"""
    print_header("VR MANUAL SERVER - MULTI-MANUAL CLIENT")
    
    if not check_server():
        print_error("\nServer is not running!")
        print_info("Please start the server first: start_server.bat")
        input("\nPress Enter to exit...")
        return
    
    while True:
        show_menu()
        choice = input(f"{Colors.BOLD}Choose option: {Colors.ENDC}").strip()
        
        if choice == '0':
            print()
            print_success("Goodbye!")
            break
        
        elif choice == '1':
            check_server()
        
        elif choice == '2':
            list_manuals_detailed()
        
        elif choice == '3':
            print()
            pdf_path = input("Enter PDF path: ").strip().strip('"')
            if pdf_path and Path(pdf_path).exists():
                index_single_manual(pdf_path)
            else:
                print_error("File not found or invalid path!")
        
        elif choice == '4':
            print()
            print("Enter PDF paths (one per line, empty line to finish):")
            paths = []
            while True:
                path = input().strip().strip('"')
                if not path:
                    break
                if Path(path).exists():
                    paths.append(path)
                else:
                    print_error(f"File not found: {path}")
            
            if paths:
                index_batch_with_duplicate_check(paths)
            else:
                print_warning("No valid files provided.")
        
        elif choice == '5':
            query = input("\nEnter your question: ").strip()
            if query:
                # Use existing query logic from previous version
                print_info("Querying all manuals...")
                # ... implementation ...
        
        elif choice == '6':
            query = input("\nEnter your question: ").strip()
            manual = input("Enter manual name: ").strip()
            if query and manual:
                print_info(f"Querying manual '{manual}'...")
                # ... implementation ...
        
        elif choice == '7':
            manual = input("\nEnter manual name to delete: ").strip()
            if manual:
                delete_manual(manual)
        
        else:
            print_warning("Invalid option!")
        
        input(f"\n{Colors.BOLD}Press Enter to continue...{Colors.ENDC}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.WARNING}Interrupted by user. Goodbye!{Colors.ENDC}")
    except Exception as e:
        print(f"\n{Colors.FAIL}Unexpected error: {e}{Colors.ENDC}")
        import traceback
        traceback.print_exc()
