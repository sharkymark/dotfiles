#!/bin/bash

# Path to your list of extensions
if [ -d $PATH_CS_1 ]; then
    EXTENSIONS_FILE="code-server_extensions_list.txt"
elif [ -d "$PATH_VS_1" ]; then
    EXTENSIONS_FILE="vs_code_extensions_list.txt"
else
    echo "⛔️ no IDE installed"
    exit 1
fi

# Read each line in the extensions file and install the extension
while IFS= read -r extension
do
    $EXT_BINARY --install-extension "$extension" --force
done < "$EXTENSIONS_FILE"
