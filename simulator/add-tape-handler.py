#!/usr/bin/env python3
"""Register GET /tape so the console tape shelf can list paper tapes."""
from pathlib import Path

path = Path("/src/z80pack/webfrontend/netsrv.c")
text = path.read_text()
if "TapeHandler" in text:
    raise SystemExit("tape handler already present")

handler = """int TapeHandler(HttpdConnection_t *conn, void *unused) {
	UNUSED(unused);
	return DirectoryHandler(conn, (void *) "./tapes");
}

"""
needle = "int start_net_services (int port) {"
if needle not in text:
    raise SystemExit("start_net_services not found")
text = text.replace(needle, handler + needle, 1)

disks = 'mg_set_request_handler(ctx, "/disks",'
if disks not in text:
    raise SystemExit("disks handler not found")
text = text.replace(
    disks,
    'mg_set_request_handler(ctx, "/tape", \t\tTapeHandler, \t\t0);\n    ' + disks,
    1,
)

rewrite = '/" MACHINE "/printer.txt=./printer.txt"'
if rewrite not in text:
    raise SystemExit("url rewrite not found")
text = text.replace(
    rewrite,
    '/" MACHINE "/printer.txt=./printer.txt, /" MACHINE "/tapes/=./tapes/"',
    1,
)
# The first System V queue identifier is 0. The original code treats 0 as
# "no queue", so the first console connection never receives the prompt.
replacements = {
    "\treturn dev[device].queue;\n": "\treturn dev[device].queue >= 0;\n",
    " \tif(dev[device].queue) {": " \tif (dev[device].queue >= 0) {",
    "\tif (dev[device].queue) {": "\tif (dev[device].queue >= 0) {",
    "\t\t\t\tif (res > 0) {": "\t\t\t\tif (res >= 0) {",
    "\tif (dev[d].queue && msgctl(dev[d].queue, IPC_RMID, NULL) == -1) {":
        "\tif (dev[d].queue >= 0 && msgctl(dev[d].queue, IPC_RMID, NULL) == -1) {",
    "\tdev[d].queue = 0;": "\tdev[d].queue = -1;",
}
for old, new in replacements.items():
    if old not in text:
        raise SystemExit("queue pattern not found: " + repr(old))
    text = text.replace(old, new)
init = "\tconst char *options[] = {"
init_fixed = (
    "\t{\n"
    "\t\tint i;\n"
    "\t\tfor (i = 0; i < MAX_WS_CLIENTS; i++)\n"
    "\t\t\tdev[i].queue = -1;\n"
    "\t}\n\n"
    "\tconst char *options[] = {"
)
if init not in text:
    raise SystemExit("server options not found")
text = text.replace(init, init_fixed, 1)
path.write_text(text)

fif = Path("/src/z80pack/iodevices/imsai-fif.c")
fif_text = fif.read_text()
old = 'httpdPrintf(conn, ",\\"HD0\\": { \\"type\\": \\"Z80P\\", \\"file\\": \\"%s\\"}",'
new = 'httpdPrintf(conn, ",\\"I\\": \\"%s\\"",'
if old not in fif_text:
    raise SystemExit("hard disk status line not found")
fif.write_text(fif_text.replace(old, new, 1))
