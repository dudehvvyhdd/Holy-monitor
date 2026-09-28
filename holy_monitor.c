/*
 * HOLY MONITOR (ETERNAL) - v2
 *
 * Build:  gcc -O2 -Wall -Wextra -o holy_monitor holy_monitor.c
 * Run:    ./holy_monitor        (Linux only, reads /proc)
 *
 * WARNING: purges use `pkill -9`. Unsaved work in "unholy" apps is lost.
 */

#define _DEFAULT_SOURCE
#ifndef HOLYC_NATIVE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <signal.h>
#include <stdarg.h>
#include <dirent.h>
#include <ctype.h>
#include <time.h>
#include <sys/ioctl.h>

typedef int64_t I64;
typedef uint8_t U8;
typedef void    U0;

#define TRUE  1
#define FALSE 0
#endif

#define MAX_HOLY      100
#define METER_WIDTH   44
#define POLL_TIME     300          /* ms */
#define WIN_W         76
#define WIN_H         24
#define GRID_ROWS     8
#define GRID_COLS     3

/* ---- colours ---------------------------------------------------------- */
#define C_RESET   "\x1b[0m"
#define C_BORDER  "\x1b[36;1m"
#define C_TITLE   "\x1b[33;1m"
#define C_LABEL   "\x1b[36m"
#define C_DIM     "\x1b[90m"
#define C_GOOD    "\x1b[32;1m"
#define C_WARN    "\x1b[33;1m"
#define C_BAD     "\x1b[31;1m"
#define C_BLINK   "\x1b[5m"
#define C_WHITE   "\x1b[37;1m"

const char *unholy_apps[] = {
    "chrome", "chromium", "brave", "edge",
    "opera", "vivaldi", "discord", "slack",
    "teams", "element", "signal", "whatsapp",
    "telegram-desktop", "code", "postman", "insomnia",
    "gitkraken", "obsidian", "logseq", "spotify",
    "notion", "figma", "trello", "steam"
};
#define NAPPS ((I64)(sizeof(unholy_apps) / sizeof(unholy_apps[0])))

/* /proc/<pid>/comm is truncated to 15 chars, so match against that. */
static char app_key[NAPPS][16];

/* ---- state ------------------------------------------------------------ */
static I64 holy_score   = MAX_HOLY;
static I64 lowest_score = MAX_HOLY;
static I64 peak_heresy  = 0;
static I64 purge_count  = 0;
static I64 souls_smitten = 0;
static I64 history[METER_WIDTH];
static time_t start_time;
static volatile sig_atomic_t quit_flag = 0;

/* ---- frame buffer (one write() per frame = no flicker) ---------------- */
static char   frame[1 << 16];
static size_t flen = 0;

static void Emit(const char *fmt, ...)
{
    va_list ap;
    int n;

    if (flen >= sizeof(frame) - 1)
        return;

    va_start(ap, fmt);
    n = vsnprintf(frame + flen, sizeof(frame) - flen, fmt, ap);
    va_end(ap);

    if (n > 0) {
        flen += (size_t)n;
        if (flen >= sizeof(frame))
            flen = sizeof(frame) - 1;
    }
}

static void Flush(void)
{
    if (write(STDOUT_FILENO, frame, flen) < 0) { /* ignore */ }
    flen = 0;
}

static void SleepMs(long ms)
{
    struct timespec ts;
    ts.tv_sec  = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

static void Goto(I64 y, I64 x)
{
    Emit("\x1b[%ld;%ldH", (long)y, (long)x);
}

static void Repeat(const char *s, I64 n)
{
    I64 i;
    for (i = 0; i < n; i++)
        Emit("%s", s);
}

/* ---- process scanning (reads /proc, no shell spawns) ------------------ */
static I64 ScanProcesses(I64 *counts)
{
    DIR *d;
    struct dirent *e;
    I64 i, apps = 0;

    memset(counts, 0, sizeof(I64) * (size_t)NAPPS);

    d = opendir("/proc");
    if (!d)
        return 0;

    while ((e = readdir(d)) != NULL) {
        char path[320], comm[64];
        FILE *f;

        if (!isdigit((unsigned char)e->d_name[0]))
            continue;

        snprintf(path, sizeof(path), "/proc/%s/comm", e->d_name);
        f = fopen(path, "r");
        if (!f)
            continue;

        if (!fgets(comm, sizeof(comm), f)) {
            fclose(f);
            continue;
        }
        fclose(f);
        comm[strcspn(comm, "\n")] = '\0';

        for (i = 0; i < NAPPS; i++) {
            if (strcasecmp(comm, app_key[i]) == 0) {
                counts[i]++;
                break;
            }
        }
    }
    closedir(d);

    for (i = 0; i < NAPPS; i++)
        if (counts[i] > 0)
            apps++;

    return apps;
}

/* ---- game logic ------------------------------------------------------- */
static U0 ApplyUnholiness(I64 active)
{
    if (active <= 0)
        return;

    holy_score -= 4 + (active - 1) * 2;
    if (holy_score < 0)
        holy_score = 0;
}

static U0 RestoreHoliness(void)
{
    if (holy_score < MAX_HOLY)
        holy_score++;
}

/* ---- layout helpers --------------------------------------------------- */
static I64 origin_x, origin_y;

static void ComputeOrigin(void)
{
    struct winsize ws;
    I64 cols = 80, rows = 30;

    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) {
        cols = ws.ws_col;
        rows = ws.ws_row;
    }

    origin_x = (cols - WIN_W) / 2 + 1;
    origin_y = (rows - WIN_H) / 2 + 1;
    if (origin_x < 1) origin_x = 1;
    if (origin_y < 1) origin_y = 1;
}

/* horizontal rule with optional label: ╔══[ LABEL ]════╗ */
static void Rule(I64 row, const char *l, const char *fill, const char *r,
                 const char *label)
{
    I64 inner = WIN_W - 2;
    I64 lead  = 2;
    I64 lab   = label ? (I64)strlen(label) + 4 : 0;   /* "[ " + " ]" */

    Goto(origin_y + row, origin_x);
    Emit(C_BORDER "%s", l);

    if (label) {
        Repeat(fill, lead);
        Emit("[ " C_TITLE "%s" C_BORDER " ]", label);
        Repeat(fill, inner - lead - lab);
    } else {
        Repeat(fill, inner);
    }
    Emit("%s" C_RESET, r);
}

static void Centered(I64 row, const char *color, const char *text)
{
    I64 len = (I64)strlen(text);
    I64 x = origin_x + 1 + (WIN_W - 2 - len) / 2;

    Goto(origin_y + row, x);
    Emit("%s%s" C_RESET, color, text);
}

static void DrawShell(void)
{
    I64 r;

    for (r = 1; r < WIN_H - 1; r++) {
        Goto(origin_y + r, origin_x);
        Emit(C_BORDER "║" C_RESET);
        Repeat(" ", WIN_W - 2);
        Emit(C_BORDER "║" C_RESET);
    }

    Rule(0,  "╔", "═", "╗", "HOLY MONITOR (ETERNAL)");
    Rule(4,  "╟", "─", "╢", "MONITORED HERESIES");
    Rule(13, "╟", "─", "╢", "SANCTITY");
    Rule(18, "╟", "─", "╢", "JUDGMENT RECORDS");
    Rule(WIN_H - 1, "╚", "═", "╝", NULL);
}

static void DrawHeader(void)
{
    Centered(2, C_TITLE, "+  T E M P L E   O F   T H E   A C T I V E   P R O C E S S   G U A R D  +");
    Centered(3, C_LABEL, "God's third temple  -  640x480  -  16 colours  -  no distractions");
}

static void DrawGrid(const I64 *counts)
{
    I64 i;

    for (i = 0; i < NAPPS; i++) {
        I64 col = i / GRID_ROWS;
        I64 row = i % GRID_ROWS;
        I64 x = origin_x + 3 + col * 24;
        I64 y = origin_y + 5 + row;

        Goto(y, x);
        if (counts[i] > 0) {
            Emit(C_BAD "● %-16s" C_WARN "x%-2ld" C_RESET,
                 unholy_apps[i], (long)counts[i]);
        } else {
            Emit(C_GOOD "○ " C_DIM "%-16s" C_RESET, unholy_apps[i]);
        }
    }
}

static void DrawMeter(I64 active)
{
    static const char *spark[8] = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" };
    I64 filled = (holy_score * METER_WIDTH) / MAX_HOLY;
    I64 i;
    const char *num_color;

    num_color = holy_score > 66 ? C_GOOD : holy_score > 33 ? C_WARN : C_BAD;

    /* meter */
    Goto(origin_y + 14, origin_x + 3);
    Emit(C_LABEL "SANCTITY " C_BORDER "[");
    for (i = 0; i < METER_WIDTH; i++) {
        if (i < filled) {
            const char *c = (i * 3 < METER_WIDTH)     ? C_BAD :
                            (i * 3 < METER_WIDTH * 2) ? C_WARN : C_GOOD;
            Emit("%s█", c);
        } else {
            Emit(C_DIM "░");
        }
    }
    Emit(C_BORDER "] %s%s%3ld%%" C_RESET,
         holy_score <= 33 ? C_BLINK : "", num_color, (long)holy_score);

    /* trend sparkline */
    Goto(origin_y + 15, origin_x + 3);
    Emit(C_LABEL "TREND    " C_BORDER " ");
    for (i = 0; i < METER_WIDTH; i++) {
        I64 lvl = (history[i] * 7) / MAX_HOLY;
        const char *c = history[i] > 66 ? C_GOOD : history[i] > 33 ? C_WARN : C_BAD;
        Emit("%s%s", c, spark[lvl < 0 ? 0 : lvl > 7 ? 7 : lvl]);
    }
    Emit(C_RESET);

    /* warning + status */
    if (active > 0) {
        char buf[96];
        snprintf(buf, sizeof(buf), "!! THEY ARE WATCHING  -  %ld UNHOLY APP%s DETECTED !!",
                 (long)active, active == 1 ? "" : "S");
        Goto(origin_y + 16, origin_x + 1);
        Centered(16, C_BAD C_BLINK, buf);
    }

    if (holy_score > 66)
        Centered(17, C_GOOD, "STATUS: Pure Temple. God's lonely programmer smiles.");
    else if (holy_score > 33)
        Centered(17, C_WARN, "STATUS: Terry Davis would not approve.");
    else
        Centered(17, C_BAD, "STATUS: Await your divine judgment!");
}

static void DrawStats(I64 active)
{
    long up = (long)difftime(time(NULL), start_time);

    Goto(origin_y + 19, origin_x + 3);
    Emit(C_LABEL "UPTIME         " C_WHITE "%02ld:%02ld:%02ld" C_RESET,
         up / 3600, (up / 60) % 60, up % 60);
    Goto(origin_y + 19, origin_x + 28);
    Emit(C_LABEL "HERESY NOW     " C_WHITE "%-3ld" C_RESET, (long)active);
    Goto(origin_y + 19, origin_x + 50);
    Emit(C_LABEL "PURGES         " C_WHITE "%-4ld" C_RESET, (long)purge_count);

    Goto(origin_y + 20, origin_x + 3);
    Emit(C_LABEL "SOULS SMITTEN  " C_WHITE "%-6ld" C_RESET, (long)souls_smitten);
    Goto(origin_y + 20, origin_x + 28);
    Emit(C_LABEL "PEAK HERESY    " C_WHITE "%-3ld" C_RESET, (long)peak_heresy);
    Goto(origin_y + 20, origin_x + 50);
    Emit(C_LABEL "LOWEST HOLY    " C_WHITE "%-3ld%%" C_RESET, (long)lowest_score);

    Centered(22, C_DIM, "Ctrl+C to depart the temple  -  In memoriam: Terry A. Davis (1969-2018)");
}

static void Render(const I64 *counts, I64 active)
{
    ComputeOrigin();
    Emit("\x1b[H");
    DrawShell();
    DrawHeader();
    DrawGrid(counts);
    DrawMeter(active);
    DrawStats(active);
    Flush();
}

/* ---- the purge -------------------------------------------------------- */
static U0 PurgeAllUnholyApps(const I64 *counts)
{
    I64 i, line = 0;
    char cmd[128];

    ComputeOrigin();
    Emit("\x1b[2J\x1b[H");
    Rule(2, "╔", "═", "╗", "DIVINE JUDGMENT REACHED");
    Flush();
    Centered(4, C_BAD C_BLINK, "PURGING ALL HERESY!");
    Flush();

    for (i = 0; i < NAPPS; i++) {
        if (counts[i] <= 0)
            continue;

        Goto(origin_y + 6 + line, origin_x + 6);
        Emit(C_BAD "[!] EXECUTING PURGE ON: " C_WHITE "%-16s" C_DIM " (%ld process%s)" C_RESET,
             unholy_apps[i], (long)counts[i], counts[i] == 1 ? "" : "es");
        Flush();

        snprintf(cmd, sizeof(cmd), "pkill -9 -ix '%s' > /dev/null 2>&1", app_key[i]);
        if (system(cmd) < 0) { /* ignore */ }

        souls_smitten += counts[i];
        line++;
        SleepMs(120);
    }

    Centered(6 + line + 1, C_GOOD, "All unholy processes smitten. Sanctity restored!");
    Flush();

    purge_count++;
    SleepMs(1800);

    holy_score = MAX_HOLY;
    for (i = 0; i < METER_WIDTH; i++)
        history[i] = MAX_HOLY;

    Emit("\x1b[2J");
    Flush();
}

/* ---- setup / teardown ------------------------------------------------- */
static void OnSignal(int sig)
{
    (void)sig;
    quit_flag = 1;
}

static void Leave(void)
{
    Emit(C_RESET "\x1b[?25h\x1b[?1049l");
    Flush();
}

int main(void)
{
    I64 counts[NAPPS];
    I64 i, active;

    for (i = 0; i < NAPPS; i++) {
        snprintf(app_key[i], sizeof(app_key[i]), "%.15s", unholy_apps[i]);
        counts[i] = 0;
    }
    for (i = 0; i < METER_WIDTH; i++)
        history[i] = MAX_HOLY;

    start_time = time(NULL);
    signal(SIGINT,  OnSignal);
    signal(SIGTERM, OnSignal);

    Emit("\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H" C_RESET);   /* alt screen, hide cursor */
    Flush();

    while (!quit_flag) {
        active = ScanProcesses(counts);

        if (active > peak_heresy)
            peak_heresy = active;

        if (active > 0)
            ApplyUnholiness(active);
        else
            RestoreHoliness();

        if (holy_score < lowest_score)
            lowest_score = holy_score;

        memmove(history, history + 1, sizeof(I64) * (METER_WIDTH - 1));
        history[METER_WIDTH - 1] = holy_score;

        Render(counts, active);

        if (holy_score <= 0)
            PurgeAllUnholyApps(counts);

        SleepMs(POLL_TIME);
    }

    Leave();
    return 0;
}
