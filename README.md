# LLM CLI Tool

A command-line interface for interacting with large language models through OpenRouter.

## Setup

1. Get an API key from [OpenRouter](https://openrouter.ai)
2. Store your API key in the macOS Keychain:
```bash
security add-generic-password -s "OPENROUTER_API_KEY" -a "$USER" -w "<your-api-key>"
```

## Usage

Basic usage:
```bash
llm "your question here"
```

Use Gemini model:
```bash
llm --gemini "your question here"
```

## Features

- Direct access to powerful language models from the command line
- Automatic token usage and cost tracking
- Support for multiple models:
  - Meta's Llama 3 70B (default)
  - Google's Gemini 2.0
- Secure API key storage using macOS Keychain

## Output

The tool provides:
- The model's response
- Statistics including:
  - Input tokens used
  - Output tokens generated
  - Generation time
  - Total cost
