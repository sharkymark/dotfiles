#!/bin/bash

# Path to your list of extensions
EXTENSIONS_FILE="vs_code_extensions_list.txt"

# Read each line in the extensions file and install the extension
while IFS= read -r extension
do
    code --install-extension "$extension" --force
done < "$EXTENSIONS_FILE"
