#ifndef HOLYC_NATIVE
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <signal.h>
#include <stdarg.h>
#include <time.h>

typedef int64_t I64;
typedef char    U8;
typedef void    U0;
typedef double  F64;

#define TRUE  1
#define FALSE 0

static void FixFmt(const char *in, char *out, size_t max)
{
    size_t o = 0;

    while (*in && o + 4 < max) {
        if (*in == '%') {
            out[o++] = *in++;
            if (*in == '%') {
                out[o++] = *in++;
            } else {
                while (*in && strchr("-+ #0123456789.", *in))
                    out[o++] = *in++;
                if (*in == 'd')
                    out[o++] = 'l';
                if (*in)
                    out[o++] = *in++;
            }
        } else {
            out[o++] = *in++;
        }
    }
    out[o] = '\0';
}

static void Print(const char *fmt, ...)
{
    char f[512];
    va_list ap;

    FixFmt(fmt, f, sizeof(f));
    va_start(ap, fmt);
    vprintf(f, ap);
    va_end(ap);
}

static void StrPrint(char *dst, const char *fmt, ...)
{
    char f[512];
    va_list ap;

    FixFmt(fmt, f, sizeof(f));
    va_start(ap, fmt);
    vsnprintf(dst, 256, f, ap);
    va_end(ap);
}

static I64 System(const char *cmd)
{
    return system(cmd);
}

static U0 Sleep(I64 ms)
{
    struct timespec ts;

    fflush(stdout);
    ts.tv_sec  = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

static I64 StrLen(const char *s)
{
    return (I64)strlen(s);
}

static I64 StrNICmp(const char *a, const char *b, I64 n)
{
    return strncasecmp(a, b, (size_t)n);
}

static char *FileRead(const char *name, I64 *size)
{
    char path[512];
    const char *home;
    FILE *f;
    char *buf;
    long n;

    home = getenv("HOME");
    if (name[0] == '~' && name[1] == '/' && home)
        snprintf(path, sizeof(path), "%s%s", home, name + 1);
    else
        snprintf(path, sizeof(path), "%s", name);

    f = fopen(path, "rb");
    if (!f)
        return NULL;

    fseek(f, 0, SEEK_END);
    n = ftell(f);
    rewind(f);
    if (n < 0) {
        fclose(f);
        return NULL;
    }

    buf = malloc((size_t)n + 1);
    if (!buf) {
        fclose(f);
        return NULL;
    }

    n = (long)fread(buf, 1, (size_t)n, f);
    buf[n] = '\0';
    fclose(f);

    if (size)
        *size = n;
    return buf;
}

#define Free(p) free(p)

static F64 NowSeconds(void)
{
    struct timespec ts;

    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (F64)ts.tv_sec + (F64)ts.tv_nsec / 1e9;
}

#define tS NowSeconds()

static void Cleanup(int sig)
{
    static const char m[] = "\x1b[0m\x1b[?25h\x1b[?1049l";

    (void)sig;
    if (write(STDOUT_FILENO, m, sizeof(m) - 1) < 0) {}
    _exit(0);
}
#endif

#define MAX_HOLY     100
#define METER_WIDTH  44
#define POLL_TIME    300
#define WIN_X        3
#define WIN_Y        2
#define WIN_W        76
#define WIN_H        24
#define GRID_ROWS    8
#define NAPPS        24

#define PS_CMD   "ps -eo comm= > $HOME/.holymon.tmp 2>/dev/null"
#define PS_FILE  "~/.holymon.tmp"

#define C_RESET     "\x1b[0m"
#define C_BORDER    "\x1b[36;1m"
#define C_TITLE     "\x1b[33;1m"
#define C_LABEL     "\x1b[36m"
#define C_DIM       "\x1b[90m"
#define C_GOOD      "\x1b[32;1m"
#define C_WARN      "\x1b[33;1m"
#define C_BAD       "\x1b[31;1m"
#define C_BADBLINK  "\x1b[5;31;1m"
#define C_WHITE     "\x1b[37;1m"

U8 *unholy_apps[NAPPS] = {
    "chrome", "chromium", "brave", "msedge",
    "opera", "vivaldi", "discord", "slack",
    "teams", "element", "signal", "whatsapp",
    "telegram-desktop", "code", "postman", "insomnia",
    "gitkraken", "obsidian", "logseq", "spotify",
    "notion", "figma", "trello", "steam"
};

U8 *spark[8] = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" };

I64 holy_score    = MAX_HOLY;
I64 lowest_score  = MAX_HOLY;
I64 peak_heresy   = 0;
I64 purge_count   = 0;
I64 souls_smitten = 0;
I64 start_time    = 0;
I64 counts[NAPPS];
I64 history[METER_WIDTH];
U8  blank[WIN_W];

U0 At(I64 row, I64 col)
{
    Print("\x1b[%d;%dH", WIN_Y + row, WIN_X + col);
}

U0 Rep(U8 *s, I64 n)
{
    I64 i;

    for (i = 0; i < n; i++)
        Print("%s", s);
}

U0 Rule(I64 row, U8 *l, U8 *fill, U8 *r, U8 *label)
{
    At(row, 0);
    Print(C_BORDER);
    Print("%s", l);

    if (label) {
        Rep(fill, 2);
        Print("[ ");
        Print(C_TITLE);
        Print("%s", label);
        Print(C_BORDER);
        Print(" ]");
        Rep(fill, WIN_W - 2 - 2 - 4 - StrLen(label));
    } else {
        Rep(fill, WIN_W - 2);
    }

    Print("%s", r);
    Print(C_RESET);
}

U0 Centered(I64 row, U8 *color, U8 *text)
{
    At(row, 1 + (WIN_W - 2 - StrLen(text)) / 2);
    Print(color);
    Print("%s", text);
    Print(C_RESET);
}

U0 DrawSides()
{
    I64 r;

    for (r = 1; r < WIN_H - 1; r++) {
        At(r, 0);
        Print(C_BORDER);
        Print("║");
        Print(C_RESET);
        Print("%s", blank);
        Print(C_BORDER);
        Print("║");
        Print(C_RESET);
    }
}

U0 DrawShell()
{
    DrawSides();
    Rule(0,  "╔", "═", "╗", "HOLY MONITOR (ETERNAL)");
    Rule(4,  "╟", "─", "╢", "MONITORED HERESIES");
    Rule(13, "╟", "─", "╢", "SANCTITY");
    Rule(18, "╟", "─", "╢", "JUDGMENT RECORDS");
    Rule(WIN_H - 1, "╚", "═", "╝", NULL);
}

U0 DrawHeader()
{
    Centered(2, C_TITLE, "+  T E M P L E   O F   T H E   P R O C E S S   G U A R D  +");
    Centered(3, C_LABEL, "God's third temple  -  640x480  -  16 colours  -  no distractions");
}

U0 MatchApp(U8 *comm)
{
    I64 i, n;

    for (i = 0; i < NAPPS; i++) {
        n = StrLen(unholy_apps[i]);
        if (n > 15)
            n = 15;

        if (StrLen(comm) == n && StrNICmp(comm, unholy_apps[i], n) == 0) {
            counts[i]++;
            break;
        }
    }
}

I64 ScanProcesses()
{
    U8 *buf, *p, line[64];
    I64 i, n, size, apps = 0;

    for (i = 0; i < NAPPS; i++)
        counts[i] = 0;

    System(PS_CMD);
    buf = FileRead(PS_FILE, &size);
    if (!buf)
        return 0;

    p = buf;
    while (*p) {
        n = 0;
        while (*p && *p != '\n') {
            if (n < 63) {
                line[n] = *p;
                n++;
            }
            p++;
        }
        line[n] = 0;
        if (*p == '\n')
            p++;

        MatchApp(line);
    }
    Free(buf);

    for (i = 0; i < NAPPS; i++)
        if (counts[i] > 0)
            apps++;

    return apps;
}

U0 ApplyUnholiness(I64 active)
{
    if (active <= 0)
        return;

    holy_score -= 1 + (active - 1);
    if (holy_score < 0)
        holy_score = 0;
}

U0 RestoreHoliness()
{
    holy_score += 3;
    if (holy_score > MAX_HOLY)
        holy_score = MAX_HOLY;
}

U0 DrawGrid()
{
    I64 i, col, row;

    for (i = 0; i < NAPPS; i++) {
        col = i / GRID_ROWS;
        row = i % GRID_ROWS;
        At(5 + row, 3 + col * 24);

        if (counts[i] > 0) {
            Print(C_BAD);
            Print("● %-16s", unholy_apps[i]);
            Print(C_WARN);
            Print("x%-2d", counts[i]);
        } else {
            Print(C_GOOD);
            Print("○ ");
            Print(C_DIM);
            Print("%-16s", unholy_apps[i]);
        }
        Print(C_RESET);
    }
}

U0 DrawMeter(I64 active)
{
    I64 i, filled, lvl;
    U8 buf[96];

    filled = holy_score * METER_WIDTH / MAX_HOLY;

    At(14, 3);
    Print(C_LABEL);
    Print("SANCTITY ");
    Print(C_BORDER);
    Print("[");
    for (i = 0; i < METER_WIDTH; i++) {
        if (i < filled) {
            if (i * 3 < METER_WIDTH)
                Print(C_BAD);
            else if (i * 3 < METER_WIDTH * 2)
                Print(C_WARN);
            else
                Print(C_GOOD);
            Print("█");
        } else {
            Print(C_DIM);
            Print("░");
        }
    }
    Print(C_BORDER);
    Print("] ");
    if (holy_score > 66)
        Print(C_GOOD);
    else if (holy_score > 33)
        Print(C_WARN);
    else
        Print(C_BADBLINK);
    Print("%3d%%", holy_score);
    Print(C_RESET);

    At(15, 3);
    Print(C_LABEL);
    Print("TREND    ");
    Print(C_BORDER);
    Print(" ");
    for (i = 0; i < METER_WIDTH; i++) {
        lvl = history[i] * 7 / MAX_HOLY;
        if (history[i] > 66)
            Print(C_GOOD);
        else if (history[i] > 33)
            Print(C_WARN);
        else
            Print(C_BAD);
        Print("%s", spark[lvl]);
    }
    Print(C_RESET);

    if (active > 0) {
        StrPrint(buf, "!! THEY ARE WATCHING  -  %d UNHOLY APP(S) DETECTED !!", active);
        Centered(16, C_BADBLINK, buf);
    }

    if (holy_score > 66)
        Centered(17, C_GOOD, "STATUS: Pure Temple. God's lonely programmer smiles.");
    else if (holy_score > 33)
        Centered(17, C_WARN, "STATUS: Terry Davis would not approve.");
    else
        Centered(17, C_BAD, "STATUS: Await your divine judgment!");
}

U0 DrawStats(I64 active)
{
    I64 up;

    up = tS - start_time;

    At(19, 3);
    Print(C_LABEL);
    Print("UPTIME         ");
    Print(C_WHITE);
    Print("%02d:%02d:%02d", up / 3600, (up / 60) % 60, up % 60);

    At(19, 28);
    Print(C_LABEL);
    Print("HERESY NOW     ");
    Print(C_WHITE);
    Print("%-3d", active);

    At(19, 50);
    Print(C_LABEL);
    Print("PURGES         ");
    Print(C_WHITE);
    Print("%-4d", purge_count);

    At(20, 3);
    Print(C_LABEL);
    Print("SOULS SMITTEN  ");
    Print(C_WHITE);
    Print("%-6d", souls_smitten);

    At(20, 28);
    Print(C_LABEL);
    Print("PEAK HERESY    ");
    Print(C_WHITE);
    Print("%-3d", peak_heresy);

    At(20, 50);
    Print(C_LABEL);
    Print("LOWEST HOLY    ");
    Print(C_WHITE);
    Print("%d%%  ", lowest_score);
    Print(C_RESET);

    Centered(22, C_DIM, "Ctrl+C to depart the temple  -  In memoriam: Terry A. Davis (1969-2018)");
}

U0 Render(I64 active)
{
    DrawShell();
    DrawHeader();
    DrawGrid();
    DrawMeter(active);
    DrawStats(active);
}

U0 MakeKey(U8 *dst, U8 *name)
{
    I64 i = 0;

    while (name[i] && i < 15) {
        dst[i] = name[i];
        i++;
    }
    dst[i] = 0;
}

U0 Purge()
{
    I64 i, line = 0;
    U8 cmd[128], key[16];

    Print("\x1b[2J");
    DrawSides();
    Rule(0, "╔", "═", "╗", "DIVINE JUDGMENT REACHED");
    Rule(WIN_H - 1, "╚", "═", "╝", NULL);
    Centered(2, C_BADBLINK, "PURGING ALL HERESY!");
    Sleep(300);

    for (i = 0; i < NAPPS; i++) {
        if (counts[i] > 0) {
            At(5 + line % 14, 4 + (line / 14) * 36);
            Print(C_BAD);
            Print("[!] PURGED: ");
            Print(C_WHITE);
            Print("%-16s", unholy_apps[i]);
            Print(C_DIM);
            Print("(%d)", counts[i]);
            Print(C_RESET);

            MakeKey(key, unholy_apps[i]);
            StrPrint(cmd, "pkill -9 -ix '%s' > /dev/null 2>&1", key);
            System(cmd);

            souls_smitten += counts[i];
            line++;
            Sleep(120);
        }
    }

    Centered(20, C_GOOD, "All unholy processes smitten. Sanctity restored!");
    purge_count++;
    Sleep(1800);

    holy_score = MAX_HOLY;
    for (i = 0; i < METER_WIDTH; i++)
        history[i] = MAX_HOLY;

    Print("\x1b[2J");
}

U0 HolyMon()
{
    I64 i, active;

    for (i = 0; i < WIN_W - 2; i++)
        blank[i] = ' ';
    blank[WIN_W - 2] = 0;

    for (i = 0; i < METER_WIDTH; i++)
        history[i] = MAX_HOLY;

    start_time = tS;
    Print("\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H");

    while (TRUE) {
        active = ScanProcesses();

        if (active > peak_heresy)
            peak_heresy = active;

        if (active > 0)
            ApplyUnholiness(active);
        else
            RestoreHoliness();

        if (holy_score < lowest_score)
            lowest_score = holy_score;

        for (i = 0; i < METER_WIDTH - 1; i++)
            history[i] = history[i + 1];
        history[METER_WIDTH - 1] = holy_score;

        Render(active);

        if (holy_score <= 0)
            Purge();

        Sleep(POLL_TIME);
    }
}

#ifndef HOLYC_NATIVE
int main(void)
{
    signal(SIGINT, Cleanup);
    signal(SIGTERM, Cleanup);
    setvbuf(stdout, NULL, _IOFBF, 1 << 16);
    HolyMon();
    return 0;
}
#else
HolyMon();
#endif
