#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Initialize the configuration files of inlong components
#

#!/bin/bash

set -e

BASE_DIR=$(dirname "$0")
PY_SDK_DIR=$(cd "$BASE_DIR"; pwd)

echo "The python sdk directory is: $PY_SDK_DIR"

# Check if dataproxy-sdk-cpp directory exists in the parent directory
if [ ! -d "$PY_SDK_DIR/../dataproxy-sdk-cpp" ]; then
    echo "Error: cannot find the dataproxy-cpp-sdk directory! The dataproxy-cpp-sdk directory must be located in the same directory as the dataproxy-python-sdk directory."
    exit 1
fi

CPP_SDK_DIR=$(cd "$PY_SDK_DIR/../dataproxy-sdk-cpp"; pwd)

echo "The cpp sdk directory is: $CPP_SDK_DIR"

# Check CMake version
CMAKE_VERSION=$(cmake --version | head -n 1 | cut -d " " -f 3)
CMAKE_REQUIRED="3.5"
if [ "$(printf '%s\n' "$CMAKE_REQUIRED" "$CMAKE_VERSION" | sort -V | head -n1)" != "$CMAKE_REQUIRED" ]; then
    echo "CMake version must be greater than or equal to $CMAKE_REQUIRED"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python --version 2>&1 | cut -d " " -f 2)
PYTHON_REQUIRED="3.6"
if [ "$(printf '%s\n' "$PYTHON_REQUIRED" "$PYTHON_VERSION" | sort -V | head -n1)" != "$PYTHON_REQUIRED" ]; then
    echo "Python version must be greater than or equal to $PYTHON_REQUIRED"
    exit 1
fi

# Install Python packages from requirements.txt
if [ -f "$PY_SDK_DIR/requirements.txt" ]; then
    echo "Installing Python packages from requirements.txt..."
    pip install -r "$PY_SDK_DIR/requirements.txt"
else
    echo "Error: cannot find requirements.txt!"
    exit 1
fi

# Build pybind11(If the pybind11 has been compiled, this step will be skipped)
if [ ! -d "$PY_SDK_DIR/pybind11/build" ]; then
    if [ -d "$PY_SDK_DIR/pybind11" ]; then
        rm -r "$PY_SDK_DIR/pybind11"
    fi
    PYBIND11_VERSION="v2.13.0"
    git clone --branch $PYBIND11_VERSION --depth 1 https://github.com/pybind/pybind11.git "$PY_SDK_DIR/pybind11"
    mkdir "$PY_SDK_DIR/pybind11/build" && cd "$PY_SDK_DIR/pybind11/build"

    # Add a trap command to delete the pybind11 folder if an error occurs
    trap 'echo "Error occurred during pybind11 build. Deleting pybind11 folder..."; cd $PY_SDK_DIR; rm -r pybind11; exit 1' ERR

    cmake "$PY_SDK_DIR/pybind11"
    cmake --build "$PY_SDK_DIR/pybind11/build" --config Release --target check
    make -j 4

    # Remove the trap command if the build is successful
    trap - ERR
else
    echo "Skipped build pybind11"
fi

# Build dataproxy-sdk-cpp(If the dataproxy-sdk-cpp has been compiled, this step will be skipped)
if [ ! -e "$CPP_SDK_DIR/release/lib/dataproxy_sdk.a" ]; then
    echo "The dataproxy-sdk-cpp is not compiled, you should run the following commands to compile it first:"
    echo "----------------------------------------------------------------------------------------------"
    echo "cd $CPP_SDK_DIR && chmod +x build_third_party.sh && chmod +x build.sh"
    echo "./build_third_party.sh"
    echo "./build.sh"
    echo "----------------------------------------------------------------------------------------------"
    exit 1
else
    if [ -d "$PY_SDK_DIR/dataproxy-sdk-cpp" ]; then
        rm -r "$PY_SDK_DIR/dataproxy-sdk-cpp"
    fi
    cp -r "$CPP_SDK_DIR" "$PY_SDK_DIR"
    echo "Copied the dataproxy-sdk-cpp directory to the current directory"
fi

# Build Python SDK
if [ -d "$PY_SDK_DIR/build" ]; then
    rm -r "$PY_SDK_DIR/build"
fi
mkdir "$PY_SDK_DIR/build" && cd "$PY_SDK_DIR/build"
cmake "$PY_SDK_DIR"
make -j 4

# Check for virtual environment
VIRTUAL_ENV_PATH=""
VIRTUAL_ENV_SITE_PACKAGES=""

# Check if VIRTUAL_ENV variable is set
if [ -n "$VIRTUAL_ENV" ]; then
    VIRTUAL_ENV_PATH="$VIRTUAL_ENV"
    echo "Detected virtual environment: $VIRTUAL_ENV_PATH"
    # Get virtual environment's site-packages directory
    VIRTUAL_ENV_SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])" 2>/dev/null)
    
    # Double-check if the path is actually in the virtual environment
    if [[ "$VIRTUAL_ENV_SITE_PACKAGES" == *"$VIRTUAL_ENV_PATH"* ]]; then
        echo "Virtual environment site-packages: $VIRTUAL_ENV_SITE_PACKAGES"
    else
        # If not found using getsitepackages(), try another approach
        VIRTUAL_ENV_SITE_PACKAGES="$VIRTUAL_ENV_PATH/lib/python$PYTHON_VERSION/site-packages"
        if [ -d "$VIRTUAL_ENV_SITE_PACKAGES" ]; then
            echo "Virtual environment site-packages: $VIRTUAL_ENV_SITE_PACKAGES"
        else
            echo "Warning: Could not determine virtual environment site-packages directory."
            VIRTUAL_ENV_SITE_PACKAGES=""
        fi
    fi
else
    # Check for common virtual environment indicators if VIRTUAL_ENV is not set
    PYTHON_PATH=$(which python)
    if [[ "$PYTHON_PATH" == *"/venv/"* ]] || [[ "$PYTHON_PATH" == *"/virtualenv/"* ]] || [[ "$PYTHON_PATH" == *"/.virtualenvs/"* ]]; then
        VIRTUAL_ENV_PATH=$(dirname $(dirname "$PYTHON_PATH"))
        echo "Detected virtual environment: $VIRTUAL_ENV_PATH"
        
        # Try to find site-packages directory using sysconfig
        VIRTUAL_ENV_SITE_PACKAGES=$(python -c "import sysconfig; print(sysconfig.get_paths().get('platlib'))" 2>/dev/null)
        
        if [ -d "$VIRTUAL_ENV_SITE_PACKAGES" ] && [[ "$VIRTUAL_ENV_SITE_PACKAGES" == *"$VIRTUAL_ENV_PATH"* ]]; then
            echo "Virtual environment site-packages: $VIRTUAL_ENV_SITE_PACKAGES"
        else
            # Try alternative approach
            VIRTUAL_ENV_SITE_PACKAGES="$VIRTUAL_ENV_PATH/lib/python$PYTHON_VERSION/site-packages"
            if [ -d "$VIRTUAL_ENV_SITE_PACKAGES" ]; then
                echo "Virtual environment site-packages: $VIRTUAL_ENV_SITE_PACKAGES"
            else
                echo "Warning: Could not determine virtual environment site-packages directory."
                VIRTUAL_ENV_SITE_PACKAGES=""
            fi
        fi
    fi
fi

# Get all existing Python site-packages directories
SITE_PACKAGES_DIRS=($(python -c "import site,os; print(' '.join([p for p in site.getsitepackages() if os.path.isdir(p)]))" 2>/dev/null))

# Check if the SITE_PACKAGES_DIRS array is not empty
if [ ${#SITE_PACKAGES_DIRS[@]} -ne 0 ]; then
    # If not empty, display all found site-packages directories to the user
    echo "Your system's existing Python site-packages directories are:"
    for dir in "${SITE_PACKAGES_DIRS[@]}"; do
        echo "  $dir"
    done
else
    # If empty, warn the user 
    echo "Warning: No system site-packages directories found."
fi

# Function to copy .so files to a directory
copy_so_files_to() {
    local target=$1
    echo "Copying .so files to $target"
    find "$PY_SDK_DIR/build" -name "*.so" -print0 | xargs -0 -I {} cp {} "$target"
}

# Collect available installation options
options=()
options_description=()

# Check if virtual environment site-packages is available
if [ -n "$VIRTUAL_ENV_SITE_PACKAGES" ]; then
    options+=("venv")
    options_description+=("Virtual environment site-packages directory: $VIRTUAL_ENV_SITE_PACKAGES")
fi

# Check if system site-packages are available
if [ ${#SITE_PACKAGES_DIRS[@]} -ne 0 ]; then
    options+=("system")
    options_description+=("System site-packages directories")
fi

# Custom directory option is always available
options+=("custom")
options_description+=("Custom directory")

# Display available options to user
echo ""
echo "Please select the installation location for the .so files:"
for i in "${!options[@]}"; do
    echo "$((i+1)). ${options_description[$i]}"
done

# Get user choice
read -r -p "Enter your choice (1-${#options[@]}): " user_choice

# Process user choice
if ! [[ "$user_choice" =~ ^[0-9]+$ ]] || [ "$user_choice" -lt 1 ] || [ "$user_choice" -gt "${#options[@]}" ]; then
    echo "Invalid choice. Please enter a number between 1 and ${#options[@]}."
    
    # Default to the first available option
    if [ ${#options[@]} -gt 0 ]; then
        echo "Using default: ${options_description[0]}"
        user_choice=1
    else
        echo "No valid installation options available. Exiting."
        exit 1
    fi
fi

# Convert to zero-based index
selection=$((user_choice-1))
chosen_option=${options[$selection]}

# Process the selected option
case "$chosen_option" in
    "venv")
        # Install to virtual environment site-packages
        copy_so_files_to "$VIRTUAL_ENV_SITE_PACKAGES"
        ;;
    "system")
        # Install to all system site-packages
        echo "Installing to system site-packages directories:"
        for dir in "${SITE_PACKAGES_DIRS[@]}"; do
            copy_so_files_to "$dir"
        done
        ;;
    "custom")
        # Install to user-specified directory
        read -r -p "Enter the custom directory path for the .so files: " target_dir
        
        # Check if the directory exists, create if necessary
        if [ ! -d "$target_dir" ]; then
            read -r -p "Directory does not exist. Create it? (y/n): " create_dir
            if [[ "$create_dir" =~ ^[Yy]$ ]]; then
                mkdir -p "$target_dir"
            else
                echo "Installation cancelled."
                exit 1
            fi
        fi
        
        copy_so_files_to "$target_dir"
        ;;
    *)
        echo "Unexpected option. Installation failed."
        exit 1
        ;;
esac

# Clean the cpp dataproxy directory
rm -r "$PY_SDK_DIR/dataproxy-sdk-cpp"

echo "Build Python SDK successfully"