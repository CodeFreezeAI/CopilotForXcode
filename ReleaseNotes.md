### GitHub Copilot for Xcode 0.42.0

**🚀 Highlights**

* Support for Bring Your Own Keys (BYOK) with model providers including Azure, OpenAI, Anthropic, Gemini, Groq, and OpenRouter. See [BYOK.md](https://github.com/github/CopilotForXcode/blob/0.42.0/Docs/BYOK.md).
* Support for custom instruction files at `.github/instructions/*.instructions.md`. See [CustomInstructions.md](https://github.com/github/CopilotForXcode/blob/0.42.0/Docs/CustomInstructions.md).
* Support for prompt files at `.github/prompts/*.prompt.md`. See [PromptFiles.md](https://github.com/github/CopilotForXcode/blob/0.42.0/Docs/PromptFiles.md).
* Default chat mode is now set to “Agent”.


**💪 Improvements**

* Use the current selection as chat context.
* Add folders as chat context.
* Shortcut to quickly fix errors in Xcode.
* Use ↑/↓ keys to reuse previous chat context in the chat view.

**🛠️ Bug Fixes**

* Cannot copy url from Safari browser to chat view.
