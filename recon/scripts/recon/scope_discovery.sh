#!/bin/bash

# scope_discovery.sh - Extracts and prepares the target scope for further processing
SCOPE_FILE="$1"
OUTPUT_DIR="$2"
VERBOSE="$3"
TIME="$4"

# Output file for processed scope
PROCESSED_SCOPE="$OUTPUT_DIR/processed_scope_$TIME.txt"

echo "[+] Running scope discovery..."

# Check if the scope file exists
if [[ ! -f "$SCOPE_FILE" ]]; then
    echo "[!] Scope file not found: $SCOPE_FILE"
    exit 1
fi

# Read each line in the scope file, process wildcards, and output to processed scope file
while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    # Process each scope line
    echo "$line" >> "$PROCESSED_SCOPE"
done < "$SCOPE_FILE"

# Verbose output if enabled
if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[VERBOSE] Processed scope saved to $PROCESSED_SCOPE"
fi

echo "[+] Scope discovery completed successfully."
