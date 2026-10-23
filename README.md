
## Install

```sh
curl -fsSL https://raw.githubusercontent.com/MrM11235dev/custom-tools/main/install.sh | sh
```

That installs commands that are available in bin— `custom-tools`, `aes_crypt`,
`custom_dbt_run` and `linting_dbt_models`. They all go to `~/.local/bin`, which is created
if it does not exist. Nothing is written outside your home directory — no `sudo`, no
system directories. If `~/.local/bin` is not on your `PATH`, the installer prints a
ready-to-paste command that appends the export to `~/.zshrc` and runs `exec zsh`. That
line assumes zsh, the macOS default — on bash or fish, point it at your own rc file
instead.

### Uninstall

```sh
cd ~/.local/bin && rm -f custom-tools aes_crypt custom_dbt_run linting_dbt_models
```

If you added any `source ~/.local/bin/<command>` lines to your `~/.zshrc`, remove those
too.

## Usage

```
custom-tools [-f FILENAME] [options] DIR [DIR ...]

  -f, --file FILENAME  Workspace file to write. The .code-workspace extension
                       is appended when missing, and FILENAME may include a
                       directory part. (default: name of the current directory)
  -a, --absolute       Write absolute folder paths instead of paths relative
                       to the workspace file.
  -F, --force          Overwrite FILENAME when it already exists.
  -o, --open           Open the workspace in VS Code after writing it.
  -q, --quiet          Print errors only.
  -h, --help           Show this help.
  -V, --version        Show the version.
```

Every `DIR` must be an existing directory; the workspace is written with one folder entry
per directory, in the order you list them.

`--file=FILENAME` is accepted alongside `-f FILENAME`. For a directory whose name begins
with a dash, prefix it with `./`. A bare `--` is not enough: it ends option parsing, but
the path is then handed to `cd`, which reads the leading dash as its own flags.

```sh
custom-tools -f odd ./-weird-dir ./another
```

The directory part of `-f` must already exist — it is not created for you.

### Examples

```sh
# Three projects, workspace file written to the current directory
custom-tools -f backend ~/code/api ~/code/worker ~/code/shared

# Every project under ~/code, written to the Desktop with absolute paths
custom-tools -f ~/Desktop/everything -a ~/code/*/

# Create and open straight away
custom-tools -f client --open ../web ../mobile

# Filename defaults to the current directory's name
cd ~/code && custom-tools api worker     # -> ~/code/code.code-workspace

# Regenerate an existing workspace after adding a project
custom-tools -F -f backend ~/code/api ~/code/worker ~/code/billing

# Scripted use: say nothing unless something goes wrong
custom-tools -q -f ci ~/code/api ~/code/worker
```

The `~/code/*/` form is a shell glob, not a feature of the tool — the trailing slash makes
your shell expand it to directories only.

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Workspace written. |
| `1` | Error — unknown option, missing directory, non-directory argument, or the output file exists without `--force`. The message goes to stderr. |
| `2` | No directories given. Usage is printed to stderr. |
| other | `--open` was requested and launching VS Code failed — `127` when neither `code` nor `open` is available. The workspace file had already been written at that point. |

## Behaviour worth knowing

- **Relative paths by default.** Folder paths are written relative to the workspace
  file, so the workspace keeps working when the whole tree is moved or cloned
  elsewhere. Use `-a` for absolute paths.
- **Each folder gets a name**, taken from the directory name. When two directories
  share a name, the parent is included (`api/server` vs `web/server`) so they are
  distinguishable in the VS Code explorer.
- **Symlinks are resolved.** Every input is reduced to its physical path, so a path
  through a symlinked directory is recorded as its real location.
- **Duplicates are dropped**, after resolving symlinks and `..`, with a note on stdout.
- **Missing directories are an error.** The file is only written once every path has
  been checked, so a typo never leaves a half-written workspace behind.
- **Existing files are never clobbered** without `--force`.
- **`settings` is left empty.** The tool writes `"settings": {}` and never touches an
  existing file, so any workspace settings you want are yours to add afterwards — but
  remember that regenerating with `--force` replaces the whole file, settings included.

## aes_crypt

AES-256-CBC encryption for a file or a string, wrapping `openssl enc` with PBKDF2 key
derivation and a random salt.

```sh
aes_crypt {encrypt|decrypt} [-f <file>] [-t <text>] [-p <password>]
```

| Option | Purpose |
|---|---|
| `-f FILE` | Encrypt `FILE` to `FILE.enc`, or decrypt `FILE` to `FILE.dec`. |
| `-t TEXT` | Encrypt or decrypt `TEXT`, base64, printed to stdout. |
| `-p PASSWORD` | Password to use. Omit it and `openssl` prompts instead. |

Strings:

```sh
$ aes_crypt encrypt -t "hello world"
enter aes-256-cbc encryption password:
U2FsdGVkX19X462I1FAUv71kWAXeP2YXLMt+b0cSTuE=

$ aes_crypt decrypt -t "U2FsdGVkX19X462I1FAUv71kWAXeP2YXLMt+b0cSTuE="
hello world
```

Files — the original is left alone, and the output is a new file alongside it:

```sh
$ aes_crypt encrypt -f notes.txt
Encrypted file written to: notes.txt.enc

$ aes_crypt decrypt -f notes.txt.enc
Decrypted file written to: notes.txt.dec
```

Worth knowing:

- **`-p` leaks the password.** It lands in your shell history and is visible in `ps` to
  anyone else on the machine while `openssl` runs. Leave `-p` off for interactive use and
  let `openssl` prompt; reach for it only in scripts, and ideally from a variable you
  sourced from somewhere safer.
- **A wrong password is not reported as a failure.** `openssl` prints `bad decrypt` to
  stderr, but `aes_crypt` does not check its exit status: with `-f` it still prints
  `Decrypted file written to: ...`, leaves a garbage `.dec` file behind, and exits `0`.
  Read the stderr output rather than the exit code, and check the `.dec` file before
  trusting it.
- **Existing output files are overwritten** without asking.
- **`-f` and `-t` together**: `-f` wins, `-t` is ignored.
- **Round-tripping a file** gives you `notes.txt.dec`, not `notes.txt` — rename it
  yourself if you want the original name back.

## custom_dbt_run

Turn dbt model paths into bare model names — directory and extension stripped — on one
space-separated line, ready to paste into a `--select`.

```sh
$ custom_dbt_run models/marts/orders.sql
orders

$ custom_dbt_run models/marts/orders.sql models/customers.sql
orders customers

$ dbt run --select $(custom_dbt_run models/marts/*.sql)
```

Worth knowing:

- **Names come back in the order you give them**, with no sorting and no de-duplication.
- **Any extension is stripped**, not just `.sql` — `models/schema.yml` gives `schema`, and
  a path with no extension is passed through as-is.
- **It is pure string handling.** Paths are never checked against the filesystem, so a
  typo comes back as a name rather than an error.
- **With no arguments** it prints its usage to stderr and exits `1`.

## linting_dbt_models

List the `.sql` files you have changed but not yet committed, space separated, ready to
hand to a linter.

```sh
$ linting_dbt_models
models/customers.sql models/marts/orders.sql

$ sqlfluff lint $(linting_dbt_models)
$ sqlfluff fix $(linting_dbt_models)
```

Worth knowing:

- **Repo-relative paths**, sorted — unlike `custom_dbt_run`, this one gives you paths, not
  model names. Feed one into the other if you want names:
  `custom_dbt_run $(linting_dbt_models)`.
- **Tracked, unstaged changes only.** It runs `git diff --name-only`, so new untracked
  models are not listed, and neither is anything you have already `git add`ed. Add
  `--cached` or `HEAD` to the `git diff` in `bin/linting_dbt_models` if you want those.
- **A clean tree prints an empty line** and exits `0`.

## License

MIT
