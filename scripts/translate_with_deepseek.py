#!/usr/bin/env python3
"""
Translate assets/i18n/fr.json into target languages using DeepSeek API.
- Backs up existing en.json/sw.json
- Translates in batches to avoid token limits
- Requires DEEPSEEK_API_KEY environment variable

Usage:
  python3 scripts/translate_with_deepseek.py --targets en sw

"""
import os
import sys
import json
import time
import argparse
from datetime import datetime
import requests

DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions"
API_KEY = os.getenv("DEEPSEEK_API_KEY")

INPUT_PATH = "assets/i18n/fr.json"
OUT_DIR = "assets/i18n"

# Number of keys to translate per request batch. Tune if you hit token limits.
BATCH_SIZE = 25
SLEEP_BETWEEN_REQUESTS = 1.0  # seconds

HEADERS = {
    "Content-Type": "application/json",
}


def backup_file(path):
    if os.path.exists(path):
        ts = datetime.utcnow().strftime("%Y%m%d%H%M%S")
        bak = f"{path}.bak.{ts}"
        os.rename(path, bak)
        print(f"Backed up {path} -> {bak}")


def call_deepseek_translate(text_map, target_language, api_key):
    """
    text_map: dict(key->text)
    returns dict(key->translated_text)
    """
    # Compose a prompt asking the model to return a JSON object mapping keys to translated values.
    input_json = json.dumps(text_map, ensure_ascii=False)
    prompt = (
        f"You are a translation assistant. Translate the following JSON object values into {target_language}.\n"
        f"Return only a valid JSON object where keys are identical and values are the translated strings.\n"
        f"Input:\n{input_json}\n\n"
        f"Requirements:\n"
        f"- Keep placeholders like {{name}} intact.\n"
        f"- Use natural, user-facing translations (not literal word-by-word).\n"
        f"- Return only JSON, nothing else.\n"
    )

    payload = {
        "model": "deepseek-chat",
        "messages": [
            {"role": "system", "content": "You are a helpful translator for app localization JSON files."},
            {"role": "user", "content": prompt}
        ],
        "max_tokens": 4000,
        "temperature": 0.2,
    }

    headers = HEADERS.copy()
    headers["Authorization"] = f"Bearer {api_key}"

    resp = requests.post(DEEPSEEK_URL, headers=headers, json=payload, timeout=120)
    resp.raise_for_status()
    data = resp.json()
    # The API returns choices -> message -> content, similar to OpenAI-style.
    content = None
    try:
        content = data["choices"][0]["message"]["content"]
    except Exception:
        raise RuntimeError(f"Unexpected response shape: {data}")

    # Find first JSON substring in content
    start = content.find('{')
    end = content.rfind('}')
    if start == -1 or end == -1:
        raise ValueError(f"No JSON found in model response: {content}")
    json_text = content[start:end+1]
    return json.loads(json_text)


def mock_translate(text_map, target_language):
    """Return a deterministic mock translation mapping for testing without API.
    It preserves placeholders like {name} and returns the source text prefixed by the language code.
    """
    out = {}
    for k, v in text_map.items():
        # Preserve placeholders: we won't change {xxx} tokens
        # Simple mock: prefix with language code so it's easy to spot
        # Example: "Profil" -> "[en] Profil"
        out[k] = f"[{target_language}] {v}"
    return out


def translate_file(input_path, out_dir, targets, api_key):
    with open(input_path, 'r', encoding='utf-8') as f:
        src = json.load(f)

    keys = list(src.keys())

    for target in targets:
        print(f"Translating to {target}...")
        out_path = os.path.join(out_dir, f"{target}.json")
        backup_file(out_path)

        translated = {}
        # process in batches
        for i in range(0, len(keys), BATCH_SIZE):
            batch_keys = keys[i:i+BATCH_SIZE]
            batch_map = {k: src[k] for k in batch_keys}
            print(f"Translating batch {i//BATCH_SIZE + 1} ({len(batch_keys)} keys)")
            # If api_key is None, the caller may want to run in mock mode. The main() will ensure behavior.
            try:
                if not api_key:
                    # No API key: use mock translation
                    result = mock_translate(batch_map, target)
                else:
                    result = call_deepseek_translate(batch_map, target, api_key)
            except Exception as e:
                # If a real API call failed and we do have an API key, retry once after a pause.
                if api_key:
                    print(f"Error calling DeepSeek: {e}")
                    print("Retrying after 5s...")
                    time.sleep(5)
                    result = call_deepseek_translate(batch_map, target, api_key)
                else:
                    # api_key missing but call failed (shouldn't happen for mock), fallback to source
                    print(f"Mock translation error: {e}")
                    result = {k: src[k] for k in batch_keys}

            # Merge result
            for k in batch_keys:
                val = result.get(k)
                if val is None:
                    print(f"Warning: missing translation for key {k}. Falling back to source value.")
                    translated[k] = src[k]
                else:
                    translated[k] = val

            time.sleep(SLEEP_BETWEEN_REQUESTS)

        # Write output file
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(translated, f, ensure_ascii=False, indent=2)
        print(f"Wrote {out_path} ({len(translated)} keys)")


def main():
    parser = argparse.ArgumentParser(description='Translate fr.json into other languages using DeepSeek')
    parser.add_argument('--targets', nargs='+', default=['en', 'sw'], help='Target language codes (e.g. en sw)')
    parser.add_argument('--mock', action='store_true', help='Run in mock mode without calling the DeepSeek API')
    args = parser.parse_args()

    api_key = API_KEY
    if not api_key and not args.mock:
        print("ERROR: DEEPSEEK_API_KEY environment variable not set. Use --mock to run without the API key.")
        sys.exit(2)

    if not os.path.exists(INPUT_PATH):
        print(f"ERROR: input file not found: {INPUT_PATH}")
        sys.exit(2)

    # If running with --mock, pass api_key=None so translate_file uses mock_translate.
    translate_file(INPUT_PATH, OUT_DIR, args.targets, api_key if not args.mock else None)


if __name__ == '__main__':
    main()
