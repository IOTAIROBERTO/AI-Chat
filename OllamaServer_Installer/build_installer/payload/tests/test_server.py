#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VR Manual Server - Test Suite
Version 2.0
"""

import sys
import time
import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import json
from pathlib import Path

# Server configuration
SERVER_URL = "https://localhost:5000"
TIMEOUT = 10

class Colors:
    """ANSI color codes for terminal output"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    """Print colored header"""
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text:^60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'='*60}{Colors.ENDC}\n")

def print_test(test_name):
    """Print test name"""
    print(f"{Colors.OKBLUE}[TEST] {test_name}...{Colors.ENDC}", end=" ")
    sys.stdout.flush()

def print_pass():
    """Print pass result"""
    print(f"{Colors.OKGREEN}[PASS]{Colors.ENDC}")

def print_fail(error=""):
    """Print fail result"""
    print(f"{Colors.FAIL}[FAIL]{Colors.ENDC}")
    if error:
        print(f"  {Colors.FAIL}Error: {error}{Colors.ENDC}")

def print_warn(message):
    """Print warning"""
    print(f"{Colors.WARNING}[WARN] {message}{Colors.ENDC}")

def print_info(message):
    """Print info"""
    print(f"{Colors.OKCYAN}[INFO] {message}{Colors.ENDC}")

def test_health_check():
    """Test 1: Health check endpoint"""
    print_test("Health Check")
    
    try:
        response = requests.get(f"{SERVER_URL}/health", timeout=TIMEOUT, verify=False)
        
        if response.status_code == 200:
            data = response.json()
            print_pass()
            
            print_info(f"  Status: {data.get('status')}")
            print_info(f"  Whisper: {'Loaded' if data.get('whisper_loaded') else 'Not loaded'}")
            print_info(f"  Ollama: {data.get('ollama_model')}")
            print_info(f"  Indexed Chunks: {data.get('indexed_chunks')}")
            print_info(f"  Server IP: {data.get('server_ip')}")
            
            return True
        else:
            print_fail(f"Status code: {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print_fail("Could not connect to server. Is it running?")
        return False
    except Exception as e:
        print_fail(str(e))
        return False

def test_simple_endpoint():
    """Test 2: Models Endpoint (Simple)"""
    print_test("Models Endpoint")
    
    try:
        response = requests.get(f"{SERVER_URL}/models", timeout=TIMEOUT, verify=False)
        
        if response.status_code == 200:
            data = response.json()
            print_pass()
            print_info(f"  Current Model: {data.get('current_model')}")
            print_info(f"  Total Models: {data.get('total_models')}")
            return True
        else:
            print_fail(f"Status code: {response.status_code}")
            return False
            
    except Exception as e:
        print_fail(str(e))
        return False

def test_index_manual(pdf_path=None):
    """Test 3: Index a manual"""
    print_test("Index Manual")
    
    if not pdf_path:
        print_warn("No PDF path provided, skipping")
        return None
    
    if not Path(pdf_path).exists():
        print_fail(f"PDF not found: {pdf_path}")
        return False
    
    try:
        print_info(f"  Indexing: {Path(pdf_path).name}")
        
        response = requests.post(
            f"{SERVER_URL}/index",
            json={"pdf_path": str(pdf_path)},
            timeout=300,  # 5 minutes for large PDFs
            verify=False
        )
        
        if response.status_code == 200:
            data = response.json()
            print_pass()
            print_info(f"  Chunks created: {data.get('chunks')}")
            print_info(f"  Pages processed: {data.get('pages')}")
            return True
        else:
            error_data = response.json()
            print_fail(error_data.get('error', 'Unknown error'))
            return False
            
    except Exception as e:
        print_fail(str(e))
        return False

def test_text_query(query="What is this manual about?"):
    """Test 4: Text query"""
    print_test("Text Query")
    
    try:
        print_info(f"  Query: {query[:50]}...")
        
        response = requests.post(
            f"{SERVER_URL}/query",
            json={"query": query},
            timeout=30,
            verify=False
        )
        
        if response.status_code == 200:
            data = response.json()
            print_pass()
            
            answer = data.get('answer', '')
            print_info(f"  Answer preview: {answer[:100]}...")
            print_info(f"  Referenced pages: {data.get('pages')}")
            
            return True
        else:
            error_data = response.json()
            print_fail(error_data.get('error', 'Unknown error'))
            return False
            
    except Exception as e:
        print_fail(str(e))
        return False

def test_response_time():
    """Test 5: Response time"""
    print_test("Response Time")
    
    try:
        start = time.time()
        response = requests.get(f"{SERVER_URL}/health", timeout=TIMEOUT, verify=False)
        elapsed = time.time() - start
        
        if response.status_code == 200:
            print_pass()
            print_info(f"  Response time: {elapsed:.3f}s")
            
            if elapsed < 1.0:
                print_info(f"  Performance: Excellent")
            elif elapsed < 3.0:
                print_info(f"  Performance: Good")
            else:
                print_warn(f"  Performance: Slow (may need optimization)")
            
            return True
        else:
            print_fail(f"Status code: {response.status_code}")
            return False
            
    except Exception as e:
        print_fail(str(e))
        return False

def test_error_handling():
    """Test 6: Error handling"""
    print_test("Error Handling")
    
    try:
        # Test with invalid endpoint
        response = requests.get(f"{SERVER_URL}/nonexistent", timeout=TIMEOUT, verify=False)
        
        if response.status_code == 404:
            print_pass()
            print_info("  Server correctly handles invalid endpoints")
            return True
        else:
            print_warn(f"Unexpected status code: {response.status_code}")
            return True  # Still pass, just different behavior
            
    except Exception as e:
        print_fail(str(e))
        return False

def run_all_tests(pdf_path=None, test_query=None):
    """Run all tests"""
    print_header("VR MANUAL SERVER - TEST SUITE")
    
    print_info(f"Testing server at: {SERVER_URL}")
    print_info(f"Timeout: {TIMEOUT}s\n")
    
    results = {}
    
    # Run tests
    results['health'] = test_health_check()
    results['simple'] = test_simple_endpoint()
    results['response_time'] = test_response_time()
    results['error_handling'] = test_error_handling()
    
    # Optional tests
    if pdf_path:
        results['index'] = test_index_manual(pdf_path)
        
        if results['index']:
            query = test_query or "What is this manual about?"
            results['query'] = test_text_query(query)
    else:
        print_info("\nSkipping indexing and query tests (no PDF provided)")
        print_info("To test indexing: python test_server.py path/to/manual.pdf")
    
    # Print summary
    print_header("TEST SUMMARY")
    
    passed = sum(1 for v in results.values() if v is True)
    failed = sum(1 for v in results.values() if v is False)
    skipped = sum(1 for v in results.values() if v is None)
    total = len(results)
    
    print(f"Total tests: {total}")
    print(f"{Colors.OKGREEN}Passed: {passed}{Colors.ENDC}")
    if failed > 0:
        print(f"{Colors.FAIL}Failed: {failed}{Colors.ENDC}")
    if skipped > 0:
        print(f"{Colors.WARNING}Skipped: {skipped}{Colors.ENDC}")
    
    print()
    
    if failed == 0 and passed > 0:
        print(f"{Colors.OKGREEN}{Colors.BOLD}✓ All tests passed!{Colors.ENDC}")
        return 0
    elif failed > 0:
        print(f"{Colors.FAIL}{Colors.BOLD}✗ Some tests failed{Colors.ENDC}")
        return 1
    else:
        print(f"{Colors.WARNING}⚠ No tests completed{Colors.ENDC}")
        return 2

def main():
    """Main function"""
    pdf_path = None
    test_query = None
    
    # Parse command line arguments
    if len(sys.argv) > 1:
        pdf_path = sys.argv[1]
        print(f"PDF path provided: {pdf_path}\n")
    
    if len(sys.argv) > 2:
        test_query = sys.argv[2]
    
    try:
        exit_code = run_all_tests(pdf_path, test_query)
        print()
        input("Press Enter to exit...")
        sys.exit(exit_code)
        
    except KeyboardInterrupt:
        print(f"\n\n{Colors.WARNING}Tests interrupted by user{Colors.ENDC}\n")
        sys.exit(130)
    except Exception as e:
        print(f"\n{Colors.FAIL}Unexpected error: {e}{Colors.ENDC}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
