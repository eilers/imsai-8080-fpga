# IMSAI 8080 in Docker

This project runs the IMSAI 8080 simulator from [z80pack](https://github.com/udo-munk/z80pack) release 1.38. The container boots IMSAI CP/M 1.31 (Control Program for Microcomputers), turns the machine on, and sets RUN.

Commands below are run from this directory. Docker must be installed and running.

## Build

```sh
docker compose build
```

The first build downloads z80pack and compiles the simulator. That takes a few minutes. Later builds reuse the compiled result unless the Dockerfile changes.

## Start

```sh
docker compose up -d
```

Build and start in one step:

```sh
docker compose up --build -d
```

The container is named `imsai-8080`. It starts again whenever Docker starts, until you stop it.

Watch the boot log:

```sh
docker compose logs -f
```

A successful boot prints `IMSAI 16K CP/M VERS 1.31`. Press Ctrl-C to leave the log. That leaves the machine running.

## Stop

Stop the machine and keep the container:

```sh
docker compose stop
```

Start that same container again:

```sh
docker compose start
```

Remove the container. Disk images you changed stay in the `imsai-disks` volume:

```sh
docker compose down
```

Remove the container and that disk volume. This deletes changes made inside CP/M:

```sh
docker compose down -v
```

## Access

| What                                                 | Address                                                      |
|------------------------------------------------------|--------------------------------------------------------------|
| Front panel, with the lights and switches            | http://127.0.0.1:6080/vnc.html?autoconnect=true&resize=scale |
| Console, with the terminal, video display, and disks | http://127.0.0.1:8080/                                       |

On the console page, double-click **TTY:** to open the terminal. The `A>` prompt is CP/M. `DIR` lists the files on the disk in drive A.

Double-click **LIB:** for the disk library. It lists every floppy image ending in `.dsk` and every hard-disk image ending in `.hdd`. Names that start with `cpm-`, `altair-`, `cromemco-`, `mostek-`, or `pico-` came from the other machines in z80pack. Only images that CP/M, IMDOS, or UCSD Pascal IV can read on this IMSAI are included. Drag one onto a drive letter to mount it.

Double-click **TAPE:** for the paper tapes. These are Intel hexadecimal listings, including Life, the kaleidoscope, Microchess, and the read-only memories. Drag one onto the tape reader to load it.

The console keeps a single live connection. If the page says **System offline**, close any other tabs open on port 8080 and reload the page. If it stays offline, run `docker compose restart`.

## Choose what boots

`IMSAI_BOOT` in `docker-compose.yml` selects the disk. Recreate the container with `docker compose up -d` after you change it.

| Value         | System                                                                                                 |
|---------------|--------------------------------------------------------------------------------------------------------|
| `imsai-cpm13` | IMSAI CP/M 1.31 on drive A. This is the default                                                        |
| `shelf`       | IMSAI CP/M 1.31 on drive A, with graphics, BASIC, and XYBASIC on drives B, C, and D                    |
| `imdos`       | IMSAI Disk Operating System                                                                            |
| `imdos202`    | IMDOS 2.02                                                                                             |
| `imdos205r0`  | IMDOS 2.05                                                                                             |
| `cpm22`       | CP/M 2.2                                                                                               |
| `cpm3`        | CP/M 3                                                                                                 |
| `boot`        | Monitor read-only memory, no disk                                                                      |

Set `IMSAI_AUTORUN` to `0` when you want the front panel to wait until you flip POWER and RUN yourself.
