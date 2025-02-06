#!/bin/bash

# Function to run subdomain enumeration
run_subdomain_enum() {
  echo "Running subdomain enumeration..."
  docker run --rm -v "$(pwd)":/mnt amass enum -df "$TARGET" -o "$OUTPUT_DIR/amass_$(date +%Y-%m-%d).txt"
  docker run --rm -v "$(pwd)":/mnt subfinder -d "$TARGET" -o "$OUTPUT_DIR/subfinder_$(date +%Y-%m-%d).txt"
  echo "Subdomain enumeration task finished."
}

# Function to run endpoint enumeration
run_endpoint_enum() {
  echo "Running endpoint enumeration..."
  bash xmrx/recon/scripts/endpoint_enum.sh
}

# Function to run JavaScript analysis
run_js_analysis() {
  echo "Running JavaScript analysis..."
  bash xmrx/recon/scripts/js_analysis.sh
}

# Function to run parameter fuzzing
run_parameter_fuzz() {
  echo "Running parameter fuzzing..."
  bash xmrx/recon/scripts/parameter_fuzz.sh
}

# Function to generate IP range
run_ip_range_generate() {
  echo "Generating IP range..."
  bash xmrx/recon/scripts/ip_range_generate.sh
}

# Function to run all tasks in the recon category
run_recon() {
  echo "Running all reconnaissance tasks..."
  for task in "$@"; do
    case $task in
      subdomain_enum) run_subdomain_enum ;;
      endpoint_enum) run_endpoint_enum ;;
      js_analysis) run_js_analysis ;;
      parameter_fuzz) run_parameter_fuzz ;;
      ip_range_generate) run_ip_range_generate ;;
      *) echo "Unknown task: $task" ;;
    esac
  done
}
