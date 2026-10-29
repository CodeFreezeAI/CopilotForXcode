# Troubleshooting for Copilot for Xcode

If you are having trouble with Copilot for Xcode follow these steps to resolve
common issues:

1. Check for updates and restart Xcode. Ensure that Copilot for Xcode has the
   [latest release](https://github.com/github/CopilotForXcode/releases/latest)
   by clicking `Check for Updates` in the settings or under the status menu. After
   updating, restart Xcode.

2. Ensure that all required permissions are granted. GitHub Copilot for Xcode app requires these permissions to function properly:
   - [Extension Permission](#extension-permission) - Allows GitHub Copilot to integrate with Xcode
   - [Accessibility Permission](#accessibility-permission) - Enables real-time code suggestions
   - [Background Permission](#background-permission) - Allows extension to connect with host app
   - [Files & Folders Permission](#files--folders-permission) - Allows GitHub Copilot for Xcode to access files and folders
   - [Screen & System Audio Recording Permission](#screen--system-audio-recording-permission-optional) (Optional) - Allow GitHub Copilot for Xcode to capture screen when using Copilot Vision

   Please note that GitHub Copilot for Xcode may not work properly if any necessary permissions are missing.

3. Need more help? If these steps don't resolve the issue, please [open an
   issue](https://github.com/github/CopilotForXcode/issues/new/choose). Make
   sure to [include logs](#logs) and any other relevant information.

## Extension Permission

GitHub Copilot for Xcode is an Xcode Source Editor extension and requires the
extension to be enabled. In the Copilot for Xcode settings, clicking `Extension
Permission` will open the System Settings to the Extensions page where `GitHub
Copilot` can be enabled under `Xcode Source Editor`.

Or you can navigate to the permission manually depending on your OS version:

| macOS | Location |
| :--- | :--- |
| 26 | System Settings > General > Login Items & Extensions > Extensions > By Category > Xcode Source Editor |
| 15 | System Settings > General > Login Items & Extensions > Extensions > Xcode Source Editor |
| 13 & 14 | System Settings > Privacy & Security  > Extensions > Xcode Source Editor |
| 12 | System Preferences > Extensions |

## Accessibility Permission

GitHub Copilot for Xcode requires the accessibility permission to receive
real-time updates from the active Xcode editor. [The XcodeKit
API](https://developer.apple.com/documentation/xcodekit)
enabled by the Xcode Source Editor extension permission only provides
information when manually triggered by the user. In order to generate
suggestions as you type, the accessibility permission is used to read the
Xcode editor content in real-time.

The accessibility permission is also used to accept suggestions when `tab` is
pressed.

The accessibility permission is __not__ used to read or write to any
applications besides Xcode. There are no granular options for the permission,
but you can audit the usage in this repository: search for `CGEvent` and `AX`*.

Enable in System Settings under `Privacy & Security` > `Accessibility` > 
`GitHub Copilot for Xcode Extension` and turn on the toggle.

## Background Permission

GitHub Copilot for Xcode requires background permission to connect with the host app. This permission ensures proper communication between the components of GitHub Copilot for Xcode, which is essential for its functionality in Xcode.


<p align="center">
     <img alt="Background Permission" src="./Docs/Images/background-item.png" width="400" />
</p>

This permission is typically granted automatically when you first launch GitHub Copilot for Xcode. However, if you encounter connection issues, alerts, or errors as follows:

<p align="center">
     <img alt="Alert of Background Permission Required" src="./Docs/Images/background-permission-required.png" width="350" />
     <img alt="Error connecting to the communication bridge" src="./Docs/Images/connect-comm-bridge-failed.png" width="550" />
</p>

Please ensure that this permission is enabled. You can manually navigate to the background permission setting based on your macOS version:

| macOS | Location |
| :--- | :--- |
| 26 | System Settings > General > Login Items & Extensions > App Background Activity |
| 15 | System Settings > General > Login Items & Extensions > Allow in the Background |
| 13 & 14 | System Settings > General > Login Items > Allow in the Background |

Ensure that "GitHub Copilot for Xcode" is enabled in the list of allowed background items. Without this permission, the extension may not be able to properly communicate with the host app, which can result in inconsistent behavior or reduced functionality.

## Files & Folders Permission

GitHub Copilot for Xcode needs permission to read your project’s files so it can:

- Use actual file contents as contextual grounding when you ask questions in Ask and Agent mode (instead of generic language-only answers)
- Safely apply or preview multi-file edits in Agent modes (e.g. refactors, adding tests, updating related types)
- Improve precision by leveraging nearby code, patterns, and naming conventions

<p align="center">
     <img alt="Files & Folders Permission" src="./Docs/Images/document-folder-permission-request.png" width="400" />
</p>

When first prompted macOS shows a dialog asking to allow access to folders. Click "Allow". 
If you clicked "Don't Allow" or nothing appears:

| macOS | Location |
| :--- | :--- |
| 13 & 14 & 15 & 26 | System Settings > Privacy & Security > Files and Folders |
| 12 | System Preferences > Security & Privacy > Privacy > Files and Folders |

In the list, expand `GitHub Copilot for Xcode` and enable the toggles for any relevant locations (e.g. “Documents” if your repositories live there). If your code is elsewhere (e.g. `~/Developer`), macOS may instead prompt dynamically the next time Copilot tries to read those paths—accept when prompted.

## Screen & System Audio Recording Permission (Optional)

This permission is only needed if you choose to use Copilot Vision (screen-based context capture).

Copilot does NOT require screen recording for standard inline suggestions, chat, or agent operations.

<p align="center">
     <img alt="Screen & System Audio Recording Permission" src="./Docs/Images/screen-record-permission-request.png" width="400" />
</p>

This permission is typically granted automatically when you first use Copilot Vision and try to capture screen in GitHub Copilot for Xcode. You can also manually navigate to the background permission setting based on your macOS version:

| macOS | Location |
| :--- | :--- |
| 14 & 15 & 26 | System Settings > Privacy & Security > Screen & System Audio Recording |
| 13 | System Settings > Privacy & Security > Screen Recording |
| 12 | System Preferences > Security & Privacy > Privacy > Screen Recording |

Check `GitHub Copilot for Xcode` and restart the app.

## Logs

Logs can be found in `~/Library/Logs/GitHubCopilot/`. The most recent log file
is:

```
~/Library/Logs/GitHubCopilot/github-copilot-for-xcode.log
```

To enable verbose logging, open the GitHub Copilot for Xcode settings and enable
`Verbose Logging` in the `Advanced` tab. After enabling verbose logging, restart
Copilot for Xcode for the change to take effect.
