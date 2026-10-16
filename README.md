# IMSAI 8080 in Docker

This project runs the IMSAI 8080 simulator from [z80pack](https://github.com/udo-munk/z80pack) release 1.38. The container boots IMSAI CP/M 1.31 (Control Program for Microcomputers), turns the machine on, and sets RUN.

Commands below are run from this directory.

## Build

Docker is required.

```sh
docker compose build
```

The first build clones z80pack and compiles the simulator, so it takes a few minutes. Later builds reuse that result unless the Dockerfile changes.

## Start

```sh
docker compose up -d
```

To rebuild the image and start in one step:

```sh
docker compose up --build -d
```

The container is named `imsai-8080` and restarts with Docker unless you stop it.

Follow the boot log with:

```sh
docker compose logs -f
```

A successful boot ends with `IMSAI 16K CP/M VERS 1.31`. Press Ctrl-C to leave the log. That does not stop the machine.

## Stop

Stop the machine and keep the container, so the next start is quick:

```sh
docker compose stop
```

Start it again with:

```sh
docker compose start
```

Remove the container. Disk images stay in the `imsai-disks` volume:

```sh
docker compose down
```

Remove the container and the disk volume. This deletes changes made inside CP/M:

```sh
docker compose down -v
```

## Access

Both pages are served only on this machine.

| What                                                 | Address                                                        |
|------------------------------------------------------|----------------------------------------------------------------|
| Front panel, with the lights and switches            | <http://127.0.0.1:6080/vnc.html?autoconnect=true&resize=scale> |
| Console, with the terminal, video display, and disks | <http://127.0.0.1:8080/>                                       |

On the console page, double-click **TTY:** (the teletype terminal) and type a command such as `DIR`.

Use one browser tab for the console. The simulator accepts a single live connection. If the page says **System offline**, close any other tabs open on port 8080 and reload. If it stays offline, restart the container:

```sh
docker compose restart
```

## Choose what boots

`IMSAI_BOOT` in `docker-compose.yml` selects the disk. After changing it, recreate the container with `docker compose up -d`.

| Value         | System                            |
|---------------|-----------------------------------|
| `imsai-cpm13` | IMSAI CP/M 1.31, the default      |
| `imdos`       | IMSAI Disk Operating System       |
| `imdos202`    | IMDOS 2.02                        |
| `imdos205r0`  | IMDOS 2.05                        |
| `cpm22`       | CP/M 2.2                          |
| `cpm3`        | CP/M 3                            |
| `boot`        | Monitor read-only memory, no disk |

Set `IMSAI_AUTORUN` to `0` when you want the front panel to wait until you flip POWER and RUN yourself.
