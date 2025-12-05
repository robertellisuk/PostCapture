1. Overall Goal

Implement a test HTTP server + shell scripts on an Ubuntu machine that:

Can be started and stopped quickly.

When running, it:

Listens on a configurable TCP port (e.g. 8443).

Only accepts and logs POST requests to a specific URL path, e.g. /<secret-path> (path configurable).

For each valid POST, prints client IP, path, headers, and body to a log/console.

Optionally responds to GET on /health for connectivity tests.

When starting:

Modifies UFW to allow inbound TCP traffic only on the chosen port (for all IPs).

When stopping:

Kills the server process.

Restores UFW to its previous state (as of before the server was started).

All artifacts live under a single directory, e.g. /opt/slr-test-server.

No NAT or static IP configuration is required at this stage.

2. Components

HTTP server script (Python).

Stand-up script up.sh:

Backs up UFW rule files.

Opens the specified port in UFW.

Starts the HTTP server with specified port + path in background, logs to file, stores PID.

Stand-down script down.sh:

Stops the server process using stored PID.

Restores UFW rule files from backup.

Reloads UFW.

3. HTTP Server Implementation Plan
   3.1 Language & runtime

Implementation language: Python 3 (assume python3 binary is available on Ubuntu).

Use standard library only:

http.server (HTTPServer, BaseHTTPRequestHandler)

argparse, sys, typing as needed.

3.2 Executable location

Path: /opt/slr-test-server/server.py

Ownership: user account that will run the tests.

Make the script executable: chmod +x server.py.

3.3 CLI interface

server.py should accept:

--port <INT> (required)

TCP port to listen on, e.g. 8443.

--path <STRING> (required)

The exact URL path that will be accepted for POSTs.

Example: --path /slr-test-9b3b4e.

Example invocation:

python3 /opt/slr-test-server/server.py --port 8443 --path /slr-test-9b3b4e

3.4 Behaviour specification
3.4.1 Server binding

Bind address: 0.0.0.0 (listen on all interfaces).

Bind port: <PORT> from CLI.

3.4.2 Request handling

Define a PostLoggingHandler(BaseHTTPRequestHandler) with:

Override log_message:

Suppress default logging or direct it to stderr with simplified format.

Private method \_dump_request(body: bytes):

Print to stdout:

Separator, e.g. "=== New request ===".

Client IP and port: self.client_address.

Request path: self.path.

All headers: for k, v in self.headers.items().

Raw body:

Decode as UTF-8 with errors="replace" and print.

End separator: "=== End request ===".

Call sys.stdout.flush() after printing to ensure logs flush promptly.

do_POST logic:

If self.path is not equal to the configured allowed_path:

Respond with 404 or 403.

Do not log body (optional).

Return.

Else:

Parse Content-Length:

length = int(self.headers.get("Content-Length", "0")).

Read the request body: body = self.rfile.read(length).

Call \_dump_request(body).

Send a simple success response:

200 OK, no extra headers.

Body: b"OK\n".

The handler needs access to the allowed_path value. Use one of:

A module-level variable set from main().

A custom handler factory closure that passes allowed_path.

Optional: do_GET for health checks

For path /health:

Return 200 OK, body b"SLR test server is up\n".

For any other path: 404.

3.4.3 Main function

main() should:

Parse CLI arguments (--port, --path).

Store the allowed path in a global or in handler closure.

Instantiate HTTPServer(("0.0.0.0", port), handler_class).

Print a startup banner, e.g.:

"Listening on 0.0.0.0:<PORT>, allowed POST path: <PATH>".

Call serve_forever() (blocking).

4. UFW & Script Integration Plan
   4.1 UFW assumptions

UFW is installed and enabled on the Ubuntu dev box.

You want to dynamically:

Add a rule allow on a certain port at start.

Then restore the UFW rules to their previous state at shutdown.

Simplest approach:

Backup /etc/ufw/user.rules and /etc/ufw/user6.rules before adding any temporary rules.

Restore those backups at shutdown.

Assumption: You do not change UFW rules outside these scripts between up/down. If you do, those changes will be overwritten by the restore.

4.2 Directory & file layout

Use:

Base directory: /opt/slr-test-server

Contained files:

server.py (HTTP server).

up.sh (stand-up script).

down.sh (stand-down script).

server.log (stdout/stderr of the running server).

server.pid (PID of server process).

ufw-backup/user.rules.bak, ufw-backup/user6.rules.bak (backups).

Ensure scripts are executable:

sudo chmod +x /opt/slr-test-server/up.sh
sudo chmod +x /opt/slr-test-server/down.sh

5. Stand-up Script (up.sh) Specification
   5.1 Invocation

Must be run with sudo (root).

Usage:

sudo /opt/slr-test-server/up.sh <PORT> <PATH>

Where:

<PORT>: integer TCP port (e.g. 8443).

<PATH>: URL path (e.g. /slr-test-9b3b4e).

5.2 Behaviour

Argument validation

Check both args provided.

If missing: print usage and exit with non-zero.

Environment & path setup

BASE_DIR="/opt/slr-test-server".

BACKUP_DIR="${BASE_DIR}/ufw-backup".

PID_FILE="${BASE_DIR}/server.pid".

Create BACKUP_DIR if not exists.

Backup UFW configuration

Copy /etc/ufw/user.rules → ${BACKUP_DIR}/user.rules.bak.

Copy /etc/ufw/user6.rules → ${BACKUP_DIR}/user6.rules.bak.

Overwrite if they already exist.

Modify UFW to allow port

Run:

ufw allow <PORT>/tcp comment 'slr-test-server'
ufw reload

This opens the port to all remote IPs (you’re relying on port + path obscurity at this stage).

Start HTTP server

Start in background as a non-root user if desired, but simplest is root for now (since script is already root).

Command:

python3 "${BASE_DIR}/server.py" --port "${PORT}" --path "${PATH}" \

> "${BASE_DIR}/server.log" 2>&1 &

Capture $! as PID and write to server.pid.

Status output

Print messages indicating:

UFW backup done.

UFW rule added on port.

Server started with PID.

Location of server.log.

6. Stand-down Script (down.sh) Specification
   6.1 Invocation

Must be run with sudo (root).

Usage:

sudo /opt/slr-test-server/down.sh

6.2 Behaviour

Load PID and stop server

Read ${BASE_DIR}/server.pid if present.

If file exists:

Read PID, check if process exists (kill -0).

If running:

Send kill PID, wait a short time.

If still running, send kill -9 PID.

Remove server.pid.

If file missing:

Print message and continue with UFW restore.

Restore UFW rule files

Check for backup files:

${BACKUP_DIR}/user.rules.bak

${BACKUP_DIR}/user6.rules.bak

If both exist:

Copy them back to /etc/ufw/user.rules and /etc/ufw/user6.rules.

Run ufw reload.

If missing:

Print warning and skip restore (administrator may need to fix UFW manually).

Status output

Print messages indicating:

Server process stopped (or not found).

UFW rules restored (or not).

Completion.

7. Usage Examples
   7.1 Setup (one-time)
   sudo mkdir -p /opt/slr-test-server
   sudo chown $USER /opt/slr-test-server

# Place server.py, up.sh, down.sh into /opt/slr-test-server

# Make scripts executable:

sudo chmod +x /opt/slr-test-server/server.py
sudo chmod +x /opt/slr-test-server/up.sh
sudo chmod +x /opt/slr-test-server/down.sh

7.2 Start test server

Pick:

Port: 8443

Path: /slr-test-9b3b4e

cd /opt/slr-test-server
sudo ./up.sh 8443 /slr-test-9b3b4e

Check logs:

tail -f /opt/slr-test-server/server.log

Configure Cloud Run Job / other client to POST to:

http://<your-public-ip>:8443/slr-test-9b3b4e

7.3 Stop test server
cd /opt/slr-test-server
sudo ./down.sh

This kills the server and restores UFW to its prior configuration.

8. Optional Enhancements (for later)

You can instruct the AI to ignore these initially, or implement them incrementally:

Request path allowlist:

Only accept POSTs on exact match of the configured path.

For all other POSTs/paths, respond with 404 and log minimal info.

Simple shared secret:

Require a header like X-SLR-Test-Token: <random-token> and ignore requests without it.

Good additional guard if the URL leaks.

Systemd integration:

Instead of using & and PID file, define a systemd service that runs server.py.

up.sh calls systemctl start, down.sh calls systemctl stop.

This plan gives your coding partner everything needed to:

Implement server.py in Python,

Implement up.sh and down.sh in Bash,

Wire them together with UFW, and

Use path+port as your initial test “security by obscurity” mechanism.
