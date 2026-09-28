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
#define METER_WIDTH  72
#define POLL_TIME    300
#define WIN_X        2
#define WIN_Y        1
#define WIN_W        105
#define WIN_H        36
#define NAPPS        24
#define BAR_H        11

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

I64 prev_user = 0, prev_nice = 0, prev_sys = 0, prev_idle = 0;
I64 cpu_pct = 0, mem_pct = 0, gpu_pct = 0;

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

U0 ClearLine(I64 row)
{
    At(row, 1);
    Print("%s", blank);
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
    Rule(0,  "╔", "═", "╗", "HOLY SYSTEM MONITOR");
    Rule(4,  "╟", "─", "╢", "DETECTED PROCESSES & HARDWARE METRICS");
    Rule(21, "╟", "─", "╢", "RING 0 SANCTITY");
    Rule(28, "╟", "─", "╢", "SYSTEM TELEMETRY & SMITE METRICS");
    Rule(WIN_H - 1, "╚", "═", "╝", NULL);
}

U0 DrawHeader()
{
    Centered(2, C_TITLE, "TEMPLE NATIVE PROCESS GUARD & SYSTEM METRICS");
    Centered(3, C_LABEL, "640x480 16-Color Pure Resolution Architecture");
}

U0 ReadHardwareMetrics()
{
    FILE *f;
    I64 u, n, s, i, total, diff_total, diff_idle, active;
    I64 mem_total = 0, mem_avail = 0;
    U8 buf[256];

    f = fopen("/proc/stat", "r");
    if (f) {
        if (fscanf(f, "cpu %ld %ld %ld %ld", &u, &n, &s, &i) == 4) {
            total = u + n + s + i;
            diff_total = total - (prev_user + prev_nice + prev_sys + prev_idle);
            diff_idle = i - prev_idle;
            if (diff_total > 0)
                cpu_pct = 100 * (diff_total - diff_idle) / diff_total;
            prev_user = u; prev_nice = n; prev_sys = s; prev_idle = i;
        }
        fclose(f);
    }

    f = fopen("/proc/meminfo", "r");
    if (f) {
        while (fgets(buf, sizeof(buf), f)) {
            if (sscanf(buf, "MemTotal: %ld kB", &u) == 1) mem_total = u;
            if (sscanf(buf, "MemAvailable: %ld kB", &u) == 1) mem_avail = u;
        }
        fclose(f);
        if (mem_total > 0)
            mem_pct = 100 * (mem_total - mem_avail) / mem_total;
    }

    f = popen("nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null", "r");
    if (f) {
        if (fgets(buf, sizeof(buf), f)) {
            active = atoi(buf);
            if (active >= 0 && active <= 100)
                gpu_pct = active;
        }
        pclose(f);
    }
}

U0 DrawVerticalBars()
{
    I64 h, lvl_cpu, lvl_gpu, lvl_mem;

    lvl_cpu = cpu_pct * BAR_H / 100;
    lvl_gpu = gpu_pct * BAR_H / 100;
    lvl_mem = mem_pct * BAR_H / 100;

    At(5, 78);
    Print(C_TITLE);
    Print("CPU   GPU   RAM");

    for (h = 0; h < BAR_H; h++) {
        I64 idx = BAR_H - 1 - h;
        At(6 + h, 77);

        if (idx < lvl_cpu) {
            if (idx >= 8) Print(C_BAD);
            else if (idx >= 4) Print(C_WARN);
            else Print(C_GOOD);
            Print("█ ");
        } else {
            Print(C_DIM);
            Print("░ ");
        }

        Print("   ");

        if (idx < lvl_gpu) {
            if (idx >= 8) Print(C_BAD);
            else if (idx >= 4) Print(C_WARN);
            else Print(C_GOOD);
            Print("█ ");
        } else {
            Print(C_DIM);
            Print("░ ");
        }

        Print("   ");

        if (idx < lvl_mem) {
            if (idx >= 8) Print(C_BAD);
            else if (idx >= 4) Print(C_WARN);
            else Print(C_GOOD);
            Print("█");
        } else {
            Print(C_DIM);
            Print("░");
        }
    }

    At(18, 76);
    Print(C_WHITE);
    Print("%3d%%  %3d%%  %3d%%", cpu_pct, gpu_pct, mem_pct);
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

U0 DrawActiveApps()
{
    I64 i, row = 5, col = 0, displayed = 0;

    for (i = 0; i < 15; i++) {
        At(5 + i, 2);
        Print("                                                                 ");
    }

    for (i = 0; i < NAPPS; i++) {
        if (counts[i] > 0) {
            At(row, 4 + col * 22);
            Print(C_BADBLINK);
            Print("x ");
            Print(C_BAD);
            Print("%-13s", unholy_apps[i]);
            Print(C_WARN);
            Print("x%-2d", counts[i]);
            Print(C_RESET);

            displayed++;
            row++;
            if (row >= 19) {
                row = 5;
                col++;
                if (col >= 3)
                    break;
            }
        }
    }

    if (displayed == 0) {
        At(11, 22);
        Print(C_GOOD);
        Print("No unholy CIA processes active.");
        Print(C_RESET);
    }
}

U0 DrawMeter(I64 active)
{
    I64 i, filled, lvl;
    U8 buf[128];

    filled = holy_score * METER_WIDTH / MAX_HOLY;

    At(22, 4);
    Print(C_LABEL);
    Print("SANCTITY  ");
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

    At(23, 4);
    Print(C_LABEL);
    Print("HISTORY   ");
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

    ClearLine(25);
    ClearLine(26);

    if (active > 0) {
        StrPrint(buf, "Smiting all unholy apps... [%d active process(es)]", active);
        Centered(25, C_BADBLINK, buf);
    } else {
        if (holy_score == MAX_HOLY)
            Centered(25, C_GOOD, "God's lonely programmer is smiling.");
        else if (holy_score > 75)
            Centered(25, C_GOOD, "Ring 0 intact. Operating in full divine isolation.");
        else if (holy_score > 50)
            Centered(25, C_WARN, "Sanctity recovering. Purging lingering memory allocations.");
        else if (holy_score > 25)
            Centered(25, C_WARN, "Severe overhead detected. Foreign instruction sequences pending smite.");
        else
            Centered(25, C_BAD, "Critical integrity loss. Auto-purge sequence engaged.");
    }
}

U0 DrawStats(I64 active)
{
    I64 up;

    up = tS - start_time;

    At(29, 4);
    Print(C_LABEL);
    Print("UPTIME         ");
    Print(C_WHITE);
    Print("%02d:%02d:%02d", up / 3600, (up / 60) % 60, up % 60);

    At(29, 38);
    Print(C_LABEL);
    Print("ACTIVE TARGETS ");
    Print(C_WHITE);
    Print("%-3d", active);

    At(29, 72);
    Print(C_LABEL);
    Print("TOTAL PURGES   ");
    Print(C_WHITE);
    Print("%-4d", purge_count);

    At(30, 4);
    Print(C_LABEL);
    Print("SMITTEN PROCS  ");
    Print(C_WHITE);
    Print("%-6d", souls_smitten);

    At(30, 38);
    Print(C_LABEL);
    Print("PEAK HERESY    ");
    Print(C_WHITE);
    Print("%-3d", peak_heresy);

    At(30, 72);
    Print(C_LABEL);
    Print("MIN SANCTITY   ");
    Print(C_WHITE);
    Print("%d%%  ", lowest_score);

    At(31, 4);
    Print(C_LABEL);
    Print("LOAD STATE     ");
    if (cpu_pct > 80 || mem_pct > 80) {
        Print(C_BAD);
        Print("HEAVY SYSTEM LOAD");
    } else if (cpu_pct > 40 || mem_pct > 40) {
        Print(C_WARN);
        Print("MODERATE ACTIVITY");
    } else {
        Print(C_GOOD);
        Print("NOMINAL OPERATIONAL");
    }

    At(31, 38);
    Print(C_LABEL);
    Print("MEMORY STATUS  ");
    if (mem_pct > 85) {
        Print(C_BAD);
        Print("RAM PRESSURE HIGH");
    } else {
        Print(C_GOOD);
        Print("ALLOCATION CLEAN");
    }

    At(31, 72);
    Print(C_LABEL);
    Print("COMPILER MODE  ");
    Print(C_WHITE);
    Print("HOLYC DIRECT");

    Print(C_RESET);

    Centered(34, C_DIM, "In memory of Terry A. Davis (1969-2018) -- An absolute legend.");
}

U0 Render(I64 active)
{
    ReadHardwareMetrics();
    DrawActiveApps();
    DrawVerticalBars();
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
    Rule(0, "╔", "═", "╗", "DIVINE PURGE IN PROGRESS");
    Rule(WIN_H - 1, "╚", "═", "╝", NULL);
    Centered(2, C_BADBLINK, "SMITING UNHOLY PROCESSES");
    Sleep(300);

    for (i = 0; i < NAPPS; i++) {
        if (counts[i] > 0) {
            At(5 + line % 22, 6 + (line / 22) * 48);
            Print(C_BAD);
            Print("[!] SMITTEN: ");
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

    Centered(30, C_GOOD, "Unholy processes smitten. Ring 0 sanctity restored.");
    purge_count++;
    Sleep(1800);

    holy_score = MAX_HOLY;
    for (i = 0; i < METER_WIDTH; i++)
        history[i] = MAX_HOLY;

    Print("\x1b[2J");
    DrawShell();
    DrawHeader();
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

    DrawShell();
    DrawHeader();

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
