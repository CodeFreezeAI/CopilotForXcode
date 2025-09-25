# Use prompt files in GitHub Copilot for Xcode

Prompt files are Markdown files that define reusable prompts for common development tasks like generating code, performing code reviews, or scaffolding project components. They are standalone prompts that you can run directly in chat, enabling the creation of a library of standardized development workflows.

They can include task-specific guidelines or reference custom instructions to ensure consistent execution. Unlike custom instructions that apply to all requests, prompt files are triggered on-demand for specific tasks.

> [!NOTE]
> Prompt files are currently experimental and may change in future releases.

GitHub Copilot for Xcode currently supports workspace prompt files, which are only available within the workspace and are stored in the `.github/prompts` folder of the workspace.

## Prompt file examples

The following examples demonstrate how to use prompt files. For more community-contributed examples, see the [Awesome Copilot repository](https://github.com/github/awesome-copilot/tree/main).

<details>
<summary>Example: generate a Swift form component</summary>


```markdown
---
description: 'Generate a new Swift sheet component'
---
Your goal is to generate a new Swift sheet component.

Ask for the sheet name and fields if not provided.

Requirements for the form:
* Use sheet design system components: [design-system/Sheet.md](../docs/design-system/Sheet.md)
* Always define Swift types for your sheet data
* Create previews for the component
```

</details>

## Prompt file format

Prompt files are Markdown files and use the `.prompt.md` extension and have this structure:

* **Header** (optional): YAML frontmatter
    * `description`: Short description of the prompt
    
* **Body**: Prompt instructions in Markdown format

    Reference other workspace files, prompt files, or instruction files by using Markdown links. Use relative paths to reference these files, and ensure that the paths are correct based on the location of the prompt file.


## Create a prompt file

1. **Open Settings > Advanced > Chat Settings**

1. To the right of "Prompt Files", click **Create** to create a new `*.prompt.md` file.

1. Enter a name for your prompt file.

1. Author the chat prompt by using Markdown formatting.

    Within a prompt file, reference additional workspace files as Markdown links (`[App](../App.swift)`).

    You can also reference other `.prompt.md` files to create a hierarchy of prompts. You can also reference [instructions files](CustomInstructions.md) in the same way.

To modify or view an existing prompt file, click **Open Prompts Folder** to open the prompts file directory.

## Use a prompt file in chat

In the Chat view, type `/` followed by the prompt file name in the chat input field.

This option enables you to pass additional information in the chat input field. For example, `/create-swift-sheet`.

## Tips for defining prompt files

* Clearly describe what the prompt should accomplish and what output format is expected.
* Provide examples of the expected input and output to guide the AI's responses.
* Use Markdown links to reference custom instructions rather than duplicating guidelines in each prompt.

## Related resources

* [Community contributed instructions, prompts, and chat modes](https://github.com/github/awesome-copilot)