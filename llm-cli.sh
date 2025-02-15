#!/bin/bash

# Load API key from macOS Keychain
API_KEY=$(security find-generic-password -s "OPENROUTER_API_KEY" -w 2>/dev/null)

# If API key is missing, exit with error
if [[ -z "$API_KEY" ]]; then
  echo "Error: API key not found. Ensure you have stored your API key using:"
  echo 'security add-generic-password -s "OPENROUTER_API_KEY" -a "$USER" -w "<your-api-key>"'
  exit 1
fi

MODEL="meta-llama/llama-3.3-70b-instruct"  # Default model
MODEL_NAME="Llama"  # Default model name
if [[ "$1" == "-g" ]]; then
    MODEL="google/gemini-2.0-flash-001"
    MODEL_NAME="Gemini"
    shift  # Remove the flag from arguments
fi

# Ensure a question is provided
if [[ -z "$1" ]]; then
    echo "Usage: llm [-g] \"your question here\""
    echo "Options:"
    echo "  -g    Use Google's Gemini model instead of Llama"
    exit 1
fi

# Convert input question to JSON format
QUESTION=$1
JSON_PAYLOAD=$(cat <<EOF
{
  "model": "$MODEL",
  "messages": [
    {
      "role": "system",
      "content": "Provide direct, concise answers. Do not hallucinate if you don't have concrete answers."
    },
    {
      "role": "user",
      "content": "$QUESTION"
    }
  ]
}
EOF
)

# Make API request to OpenRouter
RESPONSE=$(curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "$JSON_PAYLOAD")

# Extract response content
MESSAGE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')
GENERATION_ID=$(echo "$RESPONSE" | jq -r '.id')

# Print the LLM response
echo -e "\n$MESSAGE\n"

# Fetch generation stats with retries
if [[ -n "$GENERATION_ID" && "$GENERATION_ID" != "null" ]]; then
  # Retry stats fetch up to 3 times with increasing delays
  for retry in {0..2}; do
    sleep $((retry * 2))  # Wait 0, 2, then 4 seconds

    STATS_RESPONSE=$(curl -s "https://openrouter.ai/api/v1/generation?id=$GENERATION_ID" \
      -H "Authorization: Bearer $API_KEY")

    # If we get valid JSON with data (not an error response), break the loop
    if echo "$STATS_RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
      break
    elif [ "$retry" -eq 0 ]; then
      echo -e "\nFetching usage stats... (Ctrl+C to skip)"
    fi
  done

  # Extract statistics with fallbacks to "?" for missing data
  if echo "$STATS_RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
    INPUT_TOKENS=$(echo "$STATS_RESPONSE" | jq -r '.data.native_tokens_prompt // "?"')
    OUTPUT_TOKENS=$(echo "$STATS_RESPONSE" | jq -r '.data.native_tokens_completion // "?"')
    GENERATION_TIME=$(echo "$STATS_RESPONSE" | jq -r '.data.generation_time // "?"')
    TOTAL_COST=$(echo "$STATS_RESPONSE" | jq -r '.data.total_cost // "?"')

    # Print stats in a compact horizontal format
    echo -e "Model: $MODEL_NAME | Input Tokens: $INPUT_TOKENS | Output Tokens: $OUTPUT_TOKENS | Time: ${GENERATION_TIME}ms | Cost: \$${TOTAL_COST}"
  else
    echo "Note: Generation stats unavailable (ID: $GENERATION_ID)"
  fi
fi
