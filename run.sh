#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# Trap SIGINT, SIGTERM, and EXIT to kill all child processes when the script is interrupted
# -----------------------------------------------------------------------------
trap 'echo "Terminating all processes..."; kill -- -$$' SIGINT SIGTERM EXIT

# -----------------------------------------------------------------------------
# Global Variables for Run Timestamp and Date
# -----------------------------------------------------------------------------
RUN_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
RUN_DATE=$(date +"%Y-%m-%d")

# -----------------------------------------------------------------------------
# Display Logo Function
# -----------------------------------------------------------------------------
print_logo() {
  # Set bright green color for the logo
  echo -e "\033[1;32m"
  cat <<'EOF'
__   _____  _________ __   __
\ \ / /|  \/  || ___ \\ \ / /
 \ V / | .  . || |_/ / \ V /
 /   \ | |\/| ||    /  /   \
/ /^\ \| |  | || |\ \ / /^\ \
\/   \/\_|  |_/\_| \_|\/   \/
EOF
  # Reset color
  echo -e "\033[0m"
  # Set bright blue color for the by-line
  echo -e "\033[1;34m               by ZMoneep\033[0m"
  echo
  echo "Welcome to the XMRX Tool!"
  echo
}

# Call the logo printing function immediately
print_logo

# -----------------------------------------------------------------------------
# Help Function
# -----------------------------------------------------------------------------
show_help() {
  echo "Usage: $0 -s <scope_file> [-f <function>] [-v]"
  echo "  -s  Specify scope file (e.g., './input/hackerone/target/scope.txt')"
  echo "  -f  Specify functionality (e.g., 'scope_discovery' or 'subdomain_enum')"
  echo "  -v  Enable verbose mode"
}

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------
parse_args() {
  while getopts "s:f:v" opt; do
    case ${opt} in
      s ) SCOPE_FILE=$(cd "$(dirname "$OPTARG")"; pwd)/$(basename "$OPTARG");;
      f ) FUNCTION=$OPTARG;;
      v ) VERBOSE=1;;
      \?) show_help; exit 1;;
    esac
  done
  [[ $VERBOSE ]] && echo "[VERBOSE] Parsed arguments. SCOPE_FILE: $SCOPE_FILE, FUNCTION: $FUNCTION"
}

# -----------------------------------------------------------------------------
# Logging Helpers (Single Log File per Run)
# -----------------------------------------------------------------------------
# Log file will be stored at:
# output/logs/{platform}/{target}/{run-date}/{target}-{run-timestamp}.log
set_log_file() {
  LOG_DIR="${OUTPUT_LOG_DIR}/${PLATFORM}/${TARGET_NAME}/${RUN_DATE}"
  mkdir -p "$LOG_DIR"
  LOGFILE="${LOG_DIR}/${TARGET_NAME}-${RUN_TIMESTAMP}.log"
  echo "=== Run Log for ${TARGET_NAME} at ${RUN_TIMESTAMP} ===" > "$LOGFILE"
}

log_msg() {
  local tool="$1"
  local msg="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp][$tool] $msg" >> "$LOGFILE"
  [[ $VERBOSE ]] && echo "[VERBOSE][$tool] $msg"
}

# -----------------------------------------------------------------------------
# Job Control and Delays
# -----------------------------------------------------------------------------
monitor_jobs() {
  local max_jobs=10
  while [[ $(jobs -r -p | wc -l) -ge $max_jobs ]]; do
    wait -n
  done
}

random_delay() {
  local min_delay=1
  local max_delay=5
  local delay=$((RANDOM % (max_delay - min_delay + 1) + min_delay))
  [[ $VERBOSE ]] && echo "[VERBOSE] Sleeping for $delay seconds..."
  sleep "$delay"
}

# -----------------------------------------------------------------------------
# Set Output Directories Based on Scope File Path
# -----------------------------------------------------------------------------
set_output_dir() {
  # For a scope file like ./input/bugcrowd/Pinterest/scope.txt:
  # PLATFORM will be "bugcrowd" and TARGET_NAME will be "Pinterest"
  PLATFORM=$(basename "$(dirname "$(dirname "$SCOPE_FILE")")")
  TARGET_NAME=$(basename "$(dirname "$SCOPE_FILE")")
  CONFIG_DIR="./config"
  OUTPUT_DIR="./output/target_outputs/${PLATFORM}/${TARGET_NAME}"
  OUTPUT_LOG_DIR="./output/logs"
  mkdir -p "$OUTPUT_DIR" "$OUTPUT_LOG_DIR"
  echo "Base output directory set to: $OUTPUT_DIR"
  [[ $VERBOSE ]] && echo "[VERBOSE] CONFIG_DIR: $CONFIG_DIR, OUTPUT_LOG_DIR: $OUTPUT_LOG_DIR"
  set_log_file
}

# -----------------------------------------------------------------------------
# Ensure Required Arguments
# -----------------------------------------------------------------------------
ensure_required_args() {
  if [[ -z "$SCOPE_FILE" ]]; then
    show_help
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Initialize Environment
# -----------------------------------------------------------------------------
init_environment() {
  local init_script
  init_script="$(dirname "$0")/recon/scripts/init.sh"
  if [[ -f "$init_script" ]]; then
    [[ $VERBOSE ]] && echo "[VERBOSE] Sourcing environment initialization from: $init_script"
    source "$init_script"
  else
    echo "Error: init.sh script not found in $(dirname "$0")/recon/scripts." >&2
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Check Dependencies
# -----------------------------------------------------------------------------
check_dependencies() {
  local deps=("whois" "curl" "amass" "subfinder" "assetfinder" "gau" "httpx" "gobuster" "dig")
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      if alias "$dep" &>/dev/null; then
        [[ $VERBOSE ]] && echo "[VERBOSE] Alias for $dep found, using it."
      else
        echo "Error: Required command '$dep' not found." >&2
        exit 1
      fi
    else
      [[ $VERBOSE ]] && echo "[VERBOSE] Command '$dep' is available."
    fi
  done
}

# -----------------------------------------------------------------------------
# Read and Parse Scope File
# -----------------------------------------------------------------------------
read_scope_file() {
  if [[ -f "$SCOPE_FILE" ]]; then
    if [[ "$SCOPE_FILE" == *.txt ]]; then
      SCOPE_DOMAINS=()
      while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove leading/trailing whitespace and any http/https prefixes
        domain=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's#^http[s]\?://##')
        if [[ -n "$domain" && ! " ${SCOPE_DOMAINS[@]} " =~ " ${domain} " ]]; then
          SCOPE_DOMAINS+=("$domain")
          [[ $VERBOSE ]] && echo "[VERBOSE] Added domain: $domain"
          log_msg "INIT" "Added domain: $domain"
        fi
      done < "$SCOPE_FILE"
      [[ $VERBOSE ]] && echo "Domains to be processed: ${SCOPE_DOMAINS[@]}"
    else
      echo "Error: Only .txt files are supported for the scope file." >&2
      exit 1
    fi
  else
    echo "Error: Scope file '$SCOPE_FILE' not found." >&2
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Validate Domain
# -----------------------------------------------------------------------------
validate_domain() {
  local domain="$1"
  domain="${domain#http://}"
  domain="${domain#https://}"
  if [[ "$domain" =~ ^\*\.(.*\.[a-zA-Z]{2,})$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$domain" =~ ^([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$ ]]; then
    echo "$domain"
  else
    echo ""
  fi
}

# -----------------------------------------------------------------------------
# Perform WHOIS Lookup
# -----------------------------------------------------------------------------
perform_whois() {
  local raw_domain="$1"
  local output_dir="$2"
  local domain
  domain=$(validate_domain "$raw_domain")
  if [[ -n "$domain" ]]; then
    [[ $VERBOSE ]] && echo "[VERBOSE] Performing WHOIS lookup for $domain..."
    whois_output=$(whois "$domain" 2>/dev/null)
    local whois_file="${output_dir}/$(date +"%Y-%m-%d_%H-%M-%S")_${domain}_whois_output.txt"
    echo "$whois_output" > "$whois_file"
    [[ $VERBOSE ]] && echo "[VERBOSE] WHOIS lookup completed for $domain, saved to $whois_file"
    log_msg "WHOIS" "WHOIS lookup completed for $domain, saved to $whois_file"
  else
    echo "[!] Invalid domain: $raw_domain" >&2
  fi
}

# -----------------------------------------------------------------------------
# Perform CRT Scan
# -----------------------------------------------------------------------------
perform_crt_scan() {
  local raw_domain="$1"
  local output_dir="$2"
  local domain
  domain=$(validate_domain "$raw_domain")
  if [[ -n "$domain" ]]; then
    [[ $VERBOSE ]] && echo "[VERBOSE] Performing CRT scan for $domain..."
    local crt_file="${output_dir}/$(date +"%Y-%m-%d_%H-%M-%S")_${domain}_crt_scan_output.json"
    curl -s "https://crt.sh/?q=$domain&output=json" -o "$crt_file"
    [[ $VERBOSE ]] && echo "[VERBOSE] CRT scan completed for $domain, saved to $crt_file"
    log_msg "CRT" "CRT scan completed for $domain, saved to $crt_file"
  else
    echo "[!] Invalid domain: $raw_domain" >&2
  fi
}

# -----------------------------------------------------------------------------
# Perform Amass WHOIS Lookup
# -----------------------------------------------------------------------------
perform_amass_whois() {
  local domain="$1"
  local output_dir="$2"
  [[ $VERBOSE ]] && echo "[VERBOSE] Performing Amass WHOIS lookup for $domain..."
  local amass_file="${output_dir}/$(date +"%Y-%m-%d_%H-%M-%S")_${domain}_amass_whois_output.txt"
  amass intel -whois -d "$domain" -o "$amass_file"
  [[ $VERBOSE ]] && echo "[VERBOSE] Amass WHOIS lookup completed for $domain, saved to $amass_file"
  log_msg "AMASS-WHOIS" "Amass WHOIS lookup completed for $domain, saved to $amass_file"
}

# -----------------------------------------------------------------------------
# Run Gobuster Scans
# -----------------------------------------------------------------------------
run_gobuster_scans() {
  local base_output_dir="$1"
  local domain="$2"
  local ip_range="$3"
  local wordlist="/Users/zmoneep/hunting-web-mobile/hunting-tools/SecLists-master/Discovery/Web-Content/common.txt"
  local subdomains_wordlist="/Users/zmoneep/hunting-web-mobile/hunting-tools/SecLists-master/Discovery/DNS/subdomains-top1million-110000.txt"
  local vhosts_wordlist="/Users/zmoneep/hunting-web-mobile/hunting-tools/SecLists-master/Discovery/DNS/subdomains-top1million-110000.txt"
  local buckets_wordlist="/Users/zmoneep/hunting-web-mobile/hunting-tools/SecLists-master/Discovery/DNS/aws-s3-buckets.txt"

  local output_dir="${base_output_dir}/gobuster"
  mkdir -p "$output_dir"
  mkdir -p "$output_dir/gobuster_dir" "$output_dir/gobuster_dns" "$output_dir/gobuster_vhost" "$output_dir/gobuster_s3"

  [[ $VERBOSE ]] && echo "[VERBOSE] Running Gobuster directory brute-forcing for $domain..."
  gobuster dir -u "https://$domain" -w "$wordlist" \
    -o "${output_dir}/gobuster_dir/gobuster_dir__${domain}__$(date +"%Y-%m-%d_%H-%M-%S").txt" \
    -t 50 -x php,html,js,txt,json,asp,aspx,jsp,cgi,pl,rb,css,xml,svg,bak,zip,tar,gz \
    -s 200,204,301,302,307,403,500 -b 404 -k -a "Mozilla/5.0" -r &

  [[ $VERBOSE ]] && echo "[VERBOSE] Running Gobuster DNS brute-forcing for $domain..."
  gobuster dns -d "$domain" -w "$subdomains_wordlist" \
    -o "${output_dir}/gobuster_dns/gobuster_dns__${domain}__$(date +"%Y-%m-%d_%H-%M-%S").txt" \
    -t 50 -r 1.1.1.1 -a "Mozilla/5.0" --wildcard &

  [[ $VERBOSE ]] && echo "[VERBOSE] Running Gobuster VHost brute-forcing for $domain..."
  gobuster vhost -u "https://$domain" -w "$vhosts_wordlist" \
    -o "${output_dir}/gobuster_vhost/gobuster_vhost__${domain}__$(date +"%Y-%m-%d_%H-%M-%S").txt" \
    -t 50 -a "Mozilla/5.0" -k &

  [[ $VERBOSE ]] && echo "[VERBOSE] Running Gobuster S3 bucket brute-forcing for $domain..."
  gobuster s3 -d "$domain" -w "$buckets_wordlist" \
    -o "${output_dir}/gobuster_s3/gobuster_s3__${domain}__$(date +"%Y-%m-%d_%H-%M-%S").txt" \
    -a "Mozilla/5.0" -t 50 &

  wait
  [[ $VERBOSE ]] && echo "[VERBOSE] Gobuster scans completed for $domain."
  log_msg "GOBUSTER" "Gobuster scans completed for $domain"
}

# -----------------------------------------------------------------------------
# Get IP Range for a Domain
# -----------------------------------------------------------------------------
get_ip_range() {
  local domain="$1"
  local ip_range
  ip_range=$(dig +short "$domain" | head -n 1)
  if [[ -z "$ip_range" ]]; then
    echo "[!] No IP found for domain: $domain" >&2
    return 1
  fi
  echo "$ip_range"
}

# -----------------------------------------------------------------------------
# Subdomain Enumeration Function
# -----------------------------------------------------------------------------
subdomain_enum() {
  local base_output_dir="${OUTPUT_DIR}/subdomain_enum"
  echo "Base output directory for subdomain enumeration: $base_output_dir"
  mkdir -p "$base_output_dir/amass" "$base_output_dir/subfinder" "$base_output_dir/assetfinder" "$base_output_dir/gau"

  for raw_domain in "${SCOPE_DOMAINS[@]}"; do
    local domain
    domain=$(validate_domain "$raw_domain")
    if [[ -n "$domain" ]]; then
      [[ $VERBOSE ]] && echo "[VERBOSE] Starting subdomain enumeration for: $domain"
      log_msg "ENUM" "Starting subdomain enumeration for: $domain"

      # --- Amass ---
      local amass_file="${base_output_dir}/amass/$(date +"%Y-%m-%d_%H-%M-%S")_${domain}_amass_enum.txt"
      [[ $VERBOSE ]] && echo "[VERBOSE] Running Amass for $domain..."
      amass enum --brute --config "${CONFIG_DIR}/amass/config.yaml" -d "$domain" -o "$amass_file" &

      # --- Assetfinder + gau ---
      local assetfinder_file="${base_output_dir}/assetfinder/$(date +"%Y-%m-%d_%H-%M-%S")_${domain}_assetfinder_enum.txt"
      [[ $VERBOSE ]] && echo "[VERBOSE] Running Assetfinder piped to gau for $domain..."
      assetfinder "$domain" | gau > "$assetfinder_file" &

      # --- Subfinder ---
      local subfinder_file="${base_output_dir}/subfinder/$(date +"%Y-%m-%d_%H-%M-%S")_${domain}_subfinder_enum.txt"
      [[ $VERBOSE ]] && echo "[VERBOSE] Running Subfinder for $domain..."
      subfinder -d "$domain" -o "$subfinder_file" &

      # --- gau with httpx ---
      local gau_file="${base_output_dir}/gau/$(date +"%Y-%m-%d_%H-%M-%S")_${domain}_gau_enum.json"
      [[ $VERBOSE ]] && echo "[VERBOSE] Running gau for $domain (and then httpx)..."
      gau --subs --verbose --threads 50 --config "$CONFIG_DIR/.gau.toml" "$domain" > "$gau_file" &
      httpx -l "$gau_file" -status-code -o "${gau_file%.json}_responses.txt" &

      # --- Gobuster ---
      local ip_range
      ip_range=$(get_ip_range "$domain")
      if [[ -n "$ip_range" ]]; then
        [[ $VERBOSE ]] && echo "[VERBOSE] Running Gobuster scans for $domain with IP: $ip_range..."
        run_gobuster_scans "$base_output_dir" "$domain" "$ip_range" &
      else
        echo "[!] Skipping Gobuster for $domain due to missing IP."
      fi

      random_delay
    else
      echo "[!] Invalid domain: $raw_domain" >&2
    fi
  done
  wait
  echo "Subdomain enumeration completed."
  log_msg "ENUM" "Subdomain enumeration completed for all domains"
}

# -----------------------------------------------------------------------------
# Scope Discovery Function
# -----------------------------------------------------------------------------
scope_discovery() {
  local base_output_dir="${OUTPUT_DIR}/scope_discovery"
  mkdir -p "$base_output_dir/whois" "$base_output_dir/crt_scan" "$base_output_dir/amass"
  for raw_domain in "${SCOPE_DOMAINS[@]}"; do
    local domain
    domain=$(validate_domain "$raw_domain")
    if [[ -n "$domain" ]]; then
      [[ $VERBOSE ]] && echo "[VERBOSE] Performing scope discovery for: $domain"
      log_msg "DISCOVERY" "Performing scope discovery for: $domain"
      perform_whois "$domain" "$base_output_dir/whois" &
      perform_crt_scan "$domain" "$base_output_dir/crt_scan" &
      perform_amass_whois "$domain" "$base_output_dir/amass" &
      random_delay
    else
      echo "[!] Invalid domain: $raw_domain" >&2
    fi
  done
  wait
  echo "Scope discovery completed."
  log_msg "DISCOVERY" "Scope discovery completed for all domains"
}

# -----------------------------------------------------------------------------
# Endpoint Enum Function
# -----------------------------------------------------------------------------




# -----------------------------------------------------------------------------
# Main Script Execution
# -----------------------------------------------------------------------------
parse_args "$@"
ensure_required_args
set_output_dir
init_environment
echo "Current working directory: $(pwd)"
check_dependencies
read_scope_file
echo "Current working directory: $(pwd)"

if [[ -z "$FUNCTION" ]]; then
  echo "########################################################################################################################################"
  echo "####################################################### scope discovery #######################################################"
  scope_discovery
  echo "########################################################################################################################################"
  echo "####################################################### subdomain enum #######################################################"
  subdomain_enum
else
  case "$FUNCTION" in
    "scope_discovery")
      echo "####################################################### scope discovery #######################################################"
      scope_discovery
      ;;
    "subdomain_enum")
      echo "####################################################### subdomain enum #######################################################"
      subdomain_enum
      ;;
    *)
      echo "Error: Function '$FUNCTION' not recognized. Available options: scope_discovery, subdomain_enum" >&2
      show_help
      exit 1
      ;;
  esac
fi
