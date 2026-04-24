# winrm-tool

A Windows WinRM client for running commands and KMS activation. Implemented in pure Go standard library — no external dependencies.

## Build

```bash
go build -o winrm-tool .
```

## Init: Generate sample commands file

```bash
# Create a sample commands.json with built-in defaults
go run main.go -init commands.json

# Specify a different output path
go run main.go -init /tmp/my-commands.json
```

The file will not be overwritten if it already exists.

## Mode 1: Check / Inspect

Reads a list of commands from `commands.json` and executes them in order.

```bash
# HTTPS Basic auth (default, port 5986)
go run main.go -host 192.168.1.100 -pass <password>

# HTTP Basic auth (port 5985)
go run main.go -host 192.168.1.100 -port 5985 -https=false -pass <password>

# Custom commands file
go run main.go -host 192.168.1.100 -pass <password> -commands other.json

# Custom username
go run main.go -host 192.168.1.100 -user administrator -pass <password>
```

## Mode 2: KMS Activation

Triggered when `-kms` is specified. Performs the following steps:
1. Check KMS server connectivity
2. Set KMS server address (`slmgr /skms`)
3. Run activation with 30s timeout (`slmgr /ato`)
4. Display license status (`slmgr /dli`)

```bash
# KMS activation (default port 1688)
go run main.go -host 192.168.1.100 -pass <password> -kms 192.168.1.7

# KMS activation with explicit port
go run main.go -host 192.168.1.100 -pass <password> -kms 192.168.1.7:1688

# Install product key before activation
go run main.go -host 192.168.1.100 -pass <password> \
  -kms 192.168.1.7 \
  -ipk M7XTQ-FN8P6-TTKYV-9D4CC-J462D
```

## Flags

| Flag        | Default         | Description                                      |
|-------------|-----------------|--------------------------------------------------|
| `-host`     | (required)      | WinRM host IP                                    |
| `-pass`     | (required)      | Password                                         |
| `-user`     | `vagrant`       | Username                                         |
| `-port`     | `5986`          | WinRM port                                       |
| `-https`    | `true`          | Use HTTPS with Basic auth; `false` for HTTP      |
| `-retries`  | `6`             | Retry count on failure (3s delay between retries)|
| `-commands` | `commands.json` | Path to commands file (check mode)               |
| `-kms`      |                 | KMS server address — triggers activation mode    |
| `-ipk`      |                 | Product key to install before KMS activation     |

## commands.json format

```json
[
  {"name": "hostname",  "cmd": "hostname"},
  {"name": "ip config", "cmd": "ipconfig /all"}
]
```
