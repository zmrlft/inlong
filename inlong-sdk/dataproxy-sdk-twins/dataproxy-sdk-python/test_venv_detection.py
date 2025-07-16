#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

import os
import sys
import site
import sysconfig

def main():
    """
    Test script to detect virtual environments and print related path information
    """
    print("Python Virtual Environment Detection Tool")
    print("========================================")
    print(f"Python version: {sys.version}")
    print(f"Python interpreter path: {sys.executable}")

    # Check VIRTUAL_ENV environment variable
    virtual_env = os.environ.get('VIRTUAL_ENV')
    if virtual_env:
        print(f"\nDetected virtual environment variable: VIRTUAL_ENV={virtual_env}")
    else:
        print("\nVIRTUAL_ENV environment variable not detected")
        
        # Check if sys.executable path contains virtual environment markers
        if any(venv_marker in sys.executable for venv_marker in ['/venv/', '/virtualenv/', '/.virtualenvs/']):
            virtual_env = os.path.dirname(os.path.dirname(sys.executable))
            print(f"Virtual environment detected from interpreter path: {virtual_env}")
        else:
            print("No virtual environment detected from interpreter path")

    # Get site-packages directories
    print("\nPaths returned by site.getsitepackages():")
    try:
        site_packages = site.getsitepackages()
        for i, path in enumerate(site_packages):
            print(f"  {i+1}. {path}")
    except AttributeError:
        print("  site.getsitepackages() not available")
    
    # Using sysconfig
    print("\nPaths returned by sysconfig module:")
    sysconfig_paths = sysconfig.get_paths()
    platlib_path = sysconfig_paths.get('platlib')  # Platform-specific library directory
    purelib_path = sysconfig_paths.get('purelib')  # Platform-independent library directory
    
    print(f"  platlib (platform-specific packages): {platlib_path}")
    print(f"  purelib (platform-independent packages): {purelib_path}")
    
    print("\nPath returned by site.getusersitepackages():")
    try:
        user_site = site.getusersitepackages()
        print(f"  {user_site}")
    except AttributeError:
        print("  site.getusersitepackages() not available")
    
    # Summary of virtual environment detection
    print("\nSummary:")
    if virtual_env:
        print(f"Currently running in a virtual environment: {virtual_env}")
        # Check if site-packages directory is in the virtual environment
        venv_site_detected = False
        site_packages_path = ""
        
        # Check path from sysconfig
        if platlib_path and virtual_env in platlib_path:
            venv_site_detected = True
            site_packages_path = platlib_path
        elif purelib_path and virtual_env in purelib_path:
            venv_site_detected = True
            site_packages_path = purelib_path
        
        # Check paths from site.getsitepackages()
        if not venv_site_detected and 'site_packages' in locals():
            for path in site_packages:
                if virtual_env in path:
                    venv_site_detected = True
                    site_packages_path = path
                    break
        
        if venv_site_detected:
            print(f"Virtual environment site-packages directory: {site_packages_path}")
        else:
            print("Could not determine virtual environment's site-packages directory")
            # Try to guess the path based on convention
            guess_path = os.path.join(virtual_env, 'lib', f'python{sys.version_info.major}.{sys.version_info.minor}', 'site-packages')
            if os.path.exists(guess_path):
                print(f"Guessed virtual environment site-packages directory (based on convention): {guess_path}")
    else:
        print("Not running in a virtual environment, using system Python")

if __name__ == "__main__":
    main() 