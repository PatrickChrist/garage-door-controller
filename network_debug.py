#!/usr/bin/env python3
"""
Network connectivity debugging script
Check if garage controller is accessible from local network and internet
"""
import socket
import requests
import subprocess
import json
from urllib.parse import urlparse

def check_local_service():
    """Check if garage controller is running locally"""
    print("=== Local Service Check ===")
    
    # Check if service is running on expected port
    ports_to_check = [8000, 80, 443]
    
    for port in ports_to_check:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex(('localhost', port))
            sock.close()
            
            if result == 0:
                print(f"✓ Port {port} is OPEN on localhost")
                
                # Try HTTP request
                try:
                    response = requests.get(f'http://localhost:{port}/health', timeout=5)
                    print(f"  HTTP Response: {response.status_code}")
                    if response.status_code == 200:
                        print(f"  Service is responding correctly")
                except Exception as e:
                    print(f"  HTTP Request failed: {e}")
            else:
                print(f"✗ Port {port} is CLOSED on localhost")
        except Exception as e:
            print(f"✗ Error checking port {port}: {e}")

def check_network_interfaces():
    """Check network interface configuration"""
    print("\n=== Network Interface Check ===")
    
    try:
        # Get IP addresses
        result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
        if result.returncode == 0:
            ips = result.stdout.strip().split()
            print(f"Pi IP addresses: {', '.join(ips)}")
            
            # Test service on each IP
            for ip in ips:
                if ip.startswith('192.168') or ip.startswith('10.') or ip.startswith('172.'):
                    print(f"\nTesting service on {ip}:8000...")
                    try:
                        response = requests.get(f'http://{ip}:8000/health', timeout=5)
                        print(f"  ✓ Accessible on {ip}:8000 (Status: {response.status_code})")
                    except Exception as e:
                        print(f"  ✗ Not accessible on {ip}:8000 - {e}")
        
        # Check if service is bound to all interfaces
        result = subprocess.run(['netstat', '-tlnp'], capture_output=True, text=True)
        if result.returncode == 0:
            lines = result.stdout.split('\n')
            for line in lines:
                if ':8000' in line:
                    print(f"Service binding: {line.strip()}")
                    if '0.0.0.0:8000' in line:
                        print("  ✓ Service is bound to all interfaces (0.0.0.0)")
                    elif '127.0.0.1:8000' in line:
                        print("  ✗ Service is only bound to localhost - PROBLEM!")
                        print("    Fix: Set HOST=0.0.0.0 in .env file")
    
    except Exception as e:
        print(f"Error checking network: {e}")

def check_firewall():
    """Check firewall settings"""
    print("\n=== Firewall Check ===")
    
    try:
        # Check ufw status
        result = subprocess.run(['ufw', 'status'], capture_output=True, text=True)
        if result.returncode == 0:
            print("UFW Firewall Status:")
            print(result.stdout)
            
            if 'Status: active' in result.stdout:
                if '8000' not in result.stdout:
                    print("  ✗ Port 8000 not allowed in UFW")
                    print("    Fix: sudo ufw allow 8000")
                else:
                    print("  ✓ Port 8000 is allowed in UFW")
        else:
            print("UFW not installed or accessible")
        
        # Check iptables
        result = subprocess.run(['iptables', '-L', '-n'], capture_output=True, text=True)
        if result.returncode == 0:
            if 'REJECT' in result.stdout or 'DROP' in result.stdout:
                print("iptables rules detected - may be blocking connections")
            else:
                print("iptables appears to be open")
    
    except Exception as e:
        print(f"Error checking firewall: {e}")

def check_external_connectivity():
    """Test external connectivity"""
    print("\n=== External Connectivity Check ===")
    
    domain = "frankenpower.dnshome.eu"
    port = 8000
    
    # DNS resolution test
    try:
        ip = socket.gethostbyname(domain)
        print(f"DNS Resolution: {domain} → {ip}")
    except Exception as e:
        print(f"✗ DNS Resolution failed: {e}")
        return
    
    # Port connectivity test
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        result = sock.connect_ex((domain, port))
        sock.close()
        
        if result == 0:
            print(f"✓ Port {port} is reachable on {domain}")
        else:
            print(f"✗ Port {port} is NOT reachable on {domain}")
            print("  Possible issues:")
            print("  - FRITZ!Box port forwarding not configured")
            print("  - Wrong internal IP in port forwarding")
            print("  - Pi firewall blocking connections")
            print("  - Service not running or not bound to 0.0.0.0")
    except Exception as e:
        print(f"✗ Connection test failed: {e}")

def get_public_ip():
    """Get public IP address"""
    print("\n=== Public IP Check ===")
    
    try:
        # Get public IP
        response = requests.get('https://ipify.org?format=json', timeout=10)
        if response.status_code == 200:
            public_ip = response.json()['ip']
            print(f"Public IP: {public_ip}")
            
            # Test direct IP access
            print(f"Testing direct access to {public_ip}:8000...")
            try:
                response = requests.get(f'http://{public_ip}:8000/health', timeout=10)
                print(f"  ✓ Direct IP access works (Status: {response.status_code})")
            except Exception as e:
                print(f"  ✗ Direct IP access failed: {e}")
    except Exception as e:
        print(f"Could not determine public IP: {e}")

def show_fritzbox_checklist():
    """Show FRITZ!Box configuration checklist"""
    print("\n=== FRITZ!Box Configuration Checklist ===")
    print("Please verify these settings in your FRITZ!Box:")
    print()
    print("1. Port Forwarding (Internet → Permits → Port Sharing):")
    print("   ✓ Device: Select your Raspberry Pi")
    print("   ✓ Protocol: TCP")
    print("   ✓ External Port: 8000")
    print("   ✓ Internal Port: 8000")
    print("   ✓ Internal IP: [Pi's local IP - check above]")
    print()
    print("2. DynDNS (Internet → Permits → DynDNS):")
    print("   ✓ Service enabled and updating")
    print("   ✓ Domain: frankenpower.dnshome.eu")
    print()
    print("3. Firewall (Internet → Filters → Firewall):")
    print("   ✓ Not blocking the forwarded port")
    print()
    print("4. IPv6 (if using IPv6):")
    print("   ✓ IPv6 port forwarding may be needed separately")

def main():
    print("Network Connectivity Debugging Tool")
    print("=" * 50)
    
    check_local_service()
    check_network_interfaces()
    check_firewall()
    get_public_ip()
    check_external_connectivity()
    show_fritzbox_checklist()
    
    print("\n=== Quick Fixes to Try ===")
    print("1. Restart garage controller service:")
    print("   sudo systemctl restart garage-controller")
    print()
    print("2. Check service logs:")
    print("   sudo journalctl -u garage-controller -f")
    print()
    print("3. Test local access:")
    print("   curl http://localhost:8000/health")
    print("   curl http://[Pi-IP]:8000/health")
    print()
    print("4. Allow port in firewall:")
    print("   sudo ufw allow 8000")

if __name__ == "__main__":
    main()