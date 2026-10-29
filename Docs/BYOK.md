# Adding your API Keys with GitHub Copilot -  Bring Your Own Key(BYOK)


Copilot for Xcode supports **Bring Your Own Key (BYOK)** integration with multiple model providers. You can bring your own API keys to integrate with your preferred model provider, giving you full control and flexibility.

Supported providers include:
- Anthropic
- Azure
- Gemini
- Groq
- OpenAI
- OpenRouter


## Configuration Steps


To configure BYOK in Copilot for Xcode:

- Open the Copilot chat and select “Manage Models” from the Model picker.
- Choose your preferred AI provider (e.g., Anthropic, OpenAI, and Azure).
- Enter the required provider-specific details, such as the API key and endpoint URL (if applicable).


| Model Provider    | How to get the API Keys                                                                                     |
|-------------------|------------------------------------------------------------------------------------------------------------|
| Anthropic         | Sign in to the [Anthropic Console](https://console.anthropic.com/dashboard) to generate and retrieve your API key.  |
| Gemini (Google)   | Sign in to the [Google Cloud Console](https://aistudio.google.com/app/apikey) to generate and retrieve your API key.                             |
| Groq              | Sign in to the [Groq Console](https://console.groq.com/keys) to generate and retrieve your API key.        |
| OpenAI            | Sign in to the [OpenAI’s Platform](https://platform.openai.com/api-keys) to generate and retrieve your API key.    |
| OpenRouter        | Sign in to the [OpenRouter’s API Key Settings](https://openrouter.ai/settings/keys) to generate your API key. |
| Azure             | Sign in to the [Azure AI Foundry](https://ai.azure.com/), go to your [Deployments](https://ai.azure.com/resource/deployments/), and retrieve your API key and Endpoint after the deployment is complete. Ensure the model name you enter matches the one you deployed, as shown on the Details page.|


- Click "Add" button to continue.
- Once saved, it will list available AI models in the Models setting page. You can enable the models you intend to use with GitHub Copilot.

> [!NOTE]
> Please keep your API key confidential and never share it publicly for safety.
  
