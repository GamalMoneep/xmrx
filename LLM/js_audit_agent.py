import re
import openai
import ast
import json
from collections import defaultdict

# Initialize OpenAI API (uncomment to use OpenAI)
# openai.api_key = 'your-api-key-here'

# Load secret patterns from external JSON file
with open('secret_patterns.json') as f:
    secret_patterns = json.load(f)

# Placeholder for dynamic analysis (e.g., sandbox execution or JS runtime)
def dynamic_analysis(js_code):
    """
    Simulate dynamic analysis by running the JavaScript code in a sandboxed environment.
    """
    try:
        # Use pyv8 to execute the JavaScript code in a sandboxed environment
        from pyv8 import V8
        v8 = V8()
        v8.eval(js_code)
        # Monitor and analyze the executed code's behavior
        dynamic_behaviors = []
        for prop in v8.properties:
            if prop.startswith("console."):
                dynamic_behaviors.append(f"Detected {prop} call")
        return dynamic_behaviors
    except Exception as e:
        return [f"Dynamic analysis error: {e}"]

# Function to detect secrets using regex patterns
def detect_secrets(js_code):
    """
    Static analysis to detect hardcoded secrets, API keys, tokens, etc., in JavaScript code.
    """
    regex_findings = []
    for pattern in secret_patterns:
        matches = re.findall(pattern, js_code)
        for match in matches:
            regex_findings.append(f"Found potential secret: {match}")
    return regex_findings

# AST-based analysis to identify unsafe practices like eval(), innerHTML, etc.
def ast_analysis(js_code):
    """
    Use AST analysis to detect unsafe JavaScript practices like 'eval', 'innerHTML', etc.
    """
    try:
        tree = ast.parse(js_code)  # Parse JavaScript code into AST
        unsafe_methods = ['eval', 'innerHTML', 'setTimeout', 'setInterval', 'document.write']
        detected_issues = []

        # Check for unsafe method calls in the AST
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and any(func in str(node.func) for func in unsafe_methods):
                detected_issues.append(f"Unsafe method detected: {node.func.id}")

        return detected_issues
    except Exception as e:
        return [f"AST analysis error: {e}"]

# Function to analyze code with LLaMA or OpenAI API (for more complex patterns)
def analyze_with_llama(js_code):
    """
    Analyze JavaScript code using LLaMA or OpenAI API for deeper insights into security issues.
    """
    # Placeholder for actual AI/ML model (LLaMA or OpenAI)
    llama_result = openai.Completion.create(
        model="text-davinci-003",  # Use the appropriate model
        prompt=f"Analyze potential security issues and code smells in the following JavaScript code:\n\n{js_code}",
        max_tokens=150
    )
    return llama_result['choices'][0]['text'].strip()

# Scoring function based on severity of detected issues
def score_findings(findings):
    """
    Score findings based on their severity (high, medium, low).
    """
    scoring = defaultdict(int)
    high_risk_keywords = ['AWS', 'private', 'token', 'eval', 'XSS']
    medium_risk_keywords = ['console.log', 'debug', ' setTimeout', 'setInterval']
    low_risk_keywords = ['console.info', 'console.warn']

    for finding in findings:
        if any(keyword in finding.lower() for keyword in high_risk_keywords):
            scoring[finding] = 10  # High risk
        elif any(keyword in finding.lower() for keyword in medium_risk_keywords):
            scoring[finding] = 5  # Medium risk
        elif any(keyword in finding.lower() for keyword in low_risk_keywords):
            scoring[finding] = 1  # Low risk
        else:
            scoring[finding] = 3  # Unknown risk

    return scoring

# Full JavaScript audit integrating static, dynamic, AST-based, AI/ML analysis, and scoring
def js_audit(js_code):
    """
    Perform a comprehensive audit of JavaScript code including static analysis, dynamic analysis,
    AST analysis, AI/ML analysis, and scoring.
    """
    # Step 1: Static analysis (Regex-based secret detection)
    secrets = detect_secrets(js_code)

    # Step 2: Dynamic analysis (runtime behavior)
    dynamic_behaviors = dynamic_analysis(js_code)

    # Step 3: AST-based analysis (unsafe practices detection)
    ast_issues = ast_analysis(js_code)

    # Step 4: AI/ML-based analysis (LLaMA/OpenAI analysis)
    llama_analysis = analyze_with_llama(js_code)

    # Combine all findings into a list
    all_findings = secrets + dynamic_behaviors + ast_issues + [f"AI/ML Analysis: {llama_analysis}"]

    # Step 5: Scoring the findings based on severity
    findings_scores = score_findings(all_findings)

    # Final audit report (you can format the results as needed)
    report = {
        "findings": all_findings,
        "scores": findings_scores
    }

    return report

# Example usage:
js_code = """
    // Sample JavaScript code with potential issues
    const apiKey = 'AIzaSyD8h4bD6gYhjqbFb2hX5laRGe5RtD3jqX';
    document.write('<script src="http://example.com"></script>');
    eval('alert("Hello World!")');
"""

audit_report = js_audit(js_code)
print(json.dumps(audit_report, indent=2))
