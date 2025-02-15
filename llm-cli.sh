#!/bin/bash

# Load API key from macOS Keychain
API_KEY=$(security find-generic-password -s "OPENROUTER_API_KEY" -w 2>/dev/null)

# If API key is missing, exit with error
if [[ -z "$API_KEY" ]]; then
  echo "Error: API key not found. Ensure you have stored your API key using:"
  echo 'security add-generic-password -s "OPENROUTER_API_KEY" -a "$USER" -w "<your-api-key>"'
  exit 1
fi

# Ensure a question is provided
if [[ -z "$1" ]]; then
  echo "Usage: llm \"your question here\""
  exit 1
fi

# Convert input question to JSON format
QUESTION=$1
JSON_PAYLOAD=$(cat <<EOF
{
  "model": "meta-llama/llama-3.3-70b-instruct",
  "messages": [
    {
      "role": "system",
      "content": "Provide direct, concise answers."
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

# Add a small delay to ensure stats are available
sleep 0.25

# Fetch generation stats
if [[ -n "$GENERATION_ID" && "$GENERATION_ID" != "null" ]]; then
  STATS_RESPONSE=$(curl -s "https://openrouter.ai/api/v1/generation?id=$GENERATION_ID" \
    -H "Authorization: Bearer $API_KEY")

  # Check if stats response is valid JSON
  if echo "$STATS_RESPONSE" | jq empty >/dev/null 2>&1; then
    # Extract statistics
    INPUT_TOKENS=$(echo "$STATS_RESPONSE" | jq -r '.data.tokens_prompt // "?"')
    OUTPUT_TOKENS=$(echo "$STATS_RESPONSE" | jq -r '.data.tokens_completion // "?"')
    GENERATION_TIME=$(echo "$STATS_RESPONSE" | jq -r '.data.generation_time // "?"')
    TOTAL_COST=$(echo "$STATS_RESPONSE" | jq -r '.data.total_cost // "0"')

    # Print stats in a compact horizontal format
    echo -e "Input Tokens: $INPUT_TOKENS | Output Tokens: $OUTPUT_TOKENS | Time: ${GENERATION_TIME}ms | Cost: \$${TOTAL_COST}"
  else
    echo "Warning: Could not retrieve generation stats."
  fi
fi
