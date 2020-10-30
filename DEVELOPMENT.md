# Development

## Requirements

* See [README.md](./README.md).

## Code styling guidelines

### Bash

* See [Googles style guide](https://google.github.io/styleguide/shellguide.html).

### Markdown

* Use Github flavored markdown.
* One sentence per line - do not line break long sentences.

### TODO

* Naming conventions?
* Line length limit (except for markdown)?

## Tooling

Tools for making development easier for everyone!

### Set up git pre-commit hooks

Install pre-commit using pip:

```bash
# From the project root
sudo apt install python3-pip git rbenv
wget -qO- https://github.com/koalaman/shellcheck/releases/download/v0.7.1/shellcheck-v0.7.1.linux.x86_64.tar.xz | sudo tar -J -xf - --strip-components=1 -C /usr/local/bin/ --no-anchored shellcheck
pip3 install pre-commit
pre-commit install
```

**Note**: `pre-commit` is usually installed at `$HOME/.local/bin`.
Make sure it is on your `PATH`.

Some tests will now be performed on the staged files each commit.

To uninstall the pre-commit checks, remove the file at `.git/hooks/pre-commit`.

### Setting up editorconfig

To use common editor settings in this repository, please install and enable the [Editorconfig](https://editorconfig.org/) plugin in your editor, if available.
The plugin will set up project-specific editor configuration based on the values in the [`.editorconfig`](./.editorconfig) file.

### Editor plugins

#### VS Code

Some recommended plugins:

* `timonwong.shellcheck`
* `davidanson.vscode-markdownlint`
* `redhat.vscode-yaml`
* `editorconfig.editorconfig`

#### Other editors

Please add plugins that makes life easier :)
