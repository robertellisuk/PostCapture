# PostCapture
Micro server solution to capture and console-stream HTTP POSTs

## Layout

```
opt/slr-test-server/
├── server.py   # Python 3 HTTP server, logs POSTs to STDOUT
├── up.sh       # Stand-up script (configure UFW, launch server)
└── down.sh     # Stand-down script (kill server, restore UFW)
```

Copy the directory tree under `/opt/slr-test-server`, make the scripts executable, then run:

```bash
sudo /opt/slr-test-server/up.sh 8443 /slr-test-9b3b4e
tail -f /opt/slr-test-server/server.log
sudo /opt/slr-test-server/down.sh
```

See `docs/PLAN.md` for the detailed requirements that guided the implementation.
